import {BillingError,visitFee,distanceKm,finalBill,assertVisitQuote} from '../functions/visit-billing-policy.mjs';
export function createBillingHandler({loadAdmin = defaultAdmin} = {}) {
  return async function handler(req,res) {
    res.setHeader('Access-Control-Allow-Origin','*');
    res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
    res.setHeader('Cache-Control','no-store');
    if (req.method==='OPTIONS') return res.status(204).end();
    if (req.method!=='POST') return res.status(405).json({message:'POST required.'});
    if (!/^Bearer .+/.test(req.headers.authorization??'')) return res.status(401).json({message:'Sign in again.'});
    const input = req.body ?? {};
    if (!['prepare','accept','bill','correct','dismiss','checkout','estimate','decide_estimate'].includes(input.action)) return res.status(400).json({message:'Invalid billing action.'});
    const validId = id => typeof id==='string' && /^[a-zA-Z0-9_-]{1,128}$/.test(id);
    if (!validId(input.action==='prepare' ? input.providerId : input.requestId)) return res.status(400).json({message:'Invalid request or provider.'});
    try {
      const {auth,db,FieldValue,Timestamp} = await loadAdmin();
      const actor = await auth.verifyIdToken(req.headers.authorization.substring(7),true);
      if (!actor.email_verified) throw new BillingError('Verify your email first.',403);
      const result = await db.runTransaction(async tx => {
        const profileRef=db.doc(`users/${actor.uid}`), moderationRef=db.doc(`accountModeration/${actor.uid}`);
        const [profileSnap,moderationSnap,roleEmailSnap] = await Promise.all([tx.get(profileRef),tx.get(moderationRef),tx.get(db.doc(`roleEmailVerifications/${actor.uid}`))]);
        const profile=profileSnap.data(), moderation=moderationSnap.data(), role=['prepare','correct','checkout','decide_estimate'].includes(input.action)?'driver':'provider', now=Date.now();
        if (!profile || ![profile.role,...(profile.roles??[])].includes(role) || ['suspended','deleted','disabled'].includes(moderation?.status) || moderation?.verification==='rejected') throw new BillingError('Account access is unavailable.',403);
        if ((profile.roleEmailRequired??[]).includes(role) && roleEmailSnap.data()?.[role]?.email!==actor.email?.toLowerCase()) throw new BillingError('Verify your email for this role first.',403);
        const stamp=()=>FieldValue.serverTimestamp();
        if (input.action==='prepare') {
          if (role!=='driver' || input.providerId===actor.uid) throw new BillingError('Sign in as a driver.',403);
          const [directorySnap,approvalSnap,applicationSnap]=await Promise.all([tx.get(db.doc(`providerDirectory/${input.providerId}`)),tx.get(db.doc(`accountModeration/${input.providerId}`)),tx.get(db.doc(`providerApplications/${input.providerId}`))]);
          const directory=directorySnap.data(), approval=approvalSnap.data(), application=applicationSnap.data();
          requireApproval(approval,application,now);
          requireAvailable(directory,now);
          const km=distanceKm(input,directory);
          const radius=Number(/\d+/.exec(directory.serviceRadius??'15')?.[0]??15);
          if (km>radius) throw new BillingError('This location is outside the provider service radius.');
          const quoteRef=db.collection('visitFeeQuotes').doc();
          const quote={driverId:actor.uid,providerId:input.providerId,latitude:input.latitude,longitude:input.longitude,distanceKm:km,visitFee:visitFee(km),baseFee:100,includedKm:1,perExtraKm:20,distanceMethod:'straight_line',expiresAt:Timestamp.fromMillis(now+15*60*1000),createdAt:stamp()};
          tx.set(quoteRef,quote);
          return {quoteId:quoteRef.id,visitFee:quote.visitFee,distanceKm:km,expiresAtMs:now+15*60*1000};
        }
        const jobRef=db.doc(`requests/${input.requestId}`), jobSnap=await tx.get(jobRef), job=jobSnap.data();
        if (!job || job.workflowVersion!==3) throw new BillingError('This request uses the previous billing flow.');
        if (input.action==='decide_estimate') {
          if (job.driverId!==actor.uid) throw new BillingError('Only the driver can approve this work.',403);
          if (job.status!=='arrived' || job.completionState==='pending' || job.workEstimate?.status!=='pending' || job.workEstimate.revision!==input.revision || typeof input.approve!=='boolean') throw new BillingError('This work estimate has changed. Review it again.');
          const estimate={...job.workEstimate,status:input.approve?'approved':'declined',decidedBy:actor.uid,decidedAt:stamp()};
          tx.update(jobRef,{workEstimate:estimate,updatedAt:stamp()});
          tx.set(jobRef.collection('workEstimates').doc(String(estimate.revision)),estimate);
          return {approved:input.approve};
        }
        if (input.action==='checkout') {
          if (job.driverId!==actor.uid) throw new BillingError('Only the driver can accept this bill.',403);
          if (!['cash','external','demo_card'].includes(input.checkoutMethod) || !Number.isInteger(input.expectedFinalCost)) throw new BillingError('Select a payment method and review the bill.',400);
          if (job.finalCost!==input.expectedFinalCost) throw new BillingError('The final amount changed. Review it before confirming.');
          if (job.status==='completed' && job.completionState==='confirmed') {
            if (job.paymentMethod!==input.checkoutMethod) throw new BillingError('This bill has already been confirmed with another payment method.');
            return {completed:true};
          }
          if (job.status!=='arrived' || job.completionState!=='pending' || job.pendingDiscountId) throw new BillingError('This bill is not ready for confirmation.');
          if (job.arrivalConfirmedBy!==actor.uid || (job.jobStartCodeRequired && !job.jobStartCodeVerifiedAt)) throw new BillingError('Confirm provider arrival before accepting the bill.');
          const dispute=await tx.get(jobRef.collection('disputes').doc('case'));
          if (dispute.exists) {
            const review=await tx.get(db.doc(`complaintReviews/${input.requestId}`));
            if (!['resolved','dismissed'].includes(review.data()?.status)) throw new BillingError('Support must resolve the complaint before this job can be closed.');
          }
          const providerDirectoryRef=db.doc(`providerDirectory/${job.providerId}`), providerProfileRef=db.doc(`users/${job.providerId}`);
          const [directory,providerProfile]=await Promise.all([tx.get(providerDirectoryRef),tx.get(providerProfileRef)]);
          const payment=input.checkoutMethod==='demo_card'
            ? {paymentMethod:'demo_card',demoPayment:{status:'simulated',amount:job.finalCost,createdAt:stamp()}}
            : {paymentMethod:input.checkoutMethod,driverReportedPayment:true,paymentReportedAt:stamp()};
          tx.update(jobRef,{...payment,status:'completed',completionState:'confirmed',driverCompletedAt:stamp(),completedAt:stamp(),updatedAt:stamp()});
          if (directory.data()?.activeRequestId===input.requestId) tx.update(providerDirectoryRef,{activeRequestId:null});
          if (providerProfile.data()?.activeRequestId===input.requestId) tx.update(providerProfileRef,{activeRequestId:null,updatedAt:stamp()});
          return {completed:true};
        }
        if (input.action==='correct') {
          if (role!=='driver' || job.driverId!==actor.uid) throw new BillingError('Only the driver can request a bill correction.',403);
          const reason=typeof input.reason==='string' ? input.reason.trim() : '';
          if (reason.length<10 || reason.length>500) throw new BillingError('Explain the correction in 10?500 characters.',400);
          if (job.status!=='arrived' || job.completionState!=='pending' || job.pendingDiscountId) throw new BillingError('This bill cannot be returned for correction.');
          tx.update(jobRef,{completionState:'revision_requested',billCorrectionReason:reason,billCorrectionAt:stamp(),updatedAt:stamp()});
          return {corrected:true};
        }
        if (role!=='provider' || job.driverId===actor.uid) throw new BillingError('Sign in as the assigned provider.',403);
        const applicationSnap=await tx.get(db.doc(`providerApplications/${actor.uid}`));
        requireApproval(moderation,applicationSnap.data(),now);
        const directoryRef=db.doc(`providerDirectory/${actor.uid}`), directorySnap=await tx.get(directoryRef), directory=directorySnap.data();
        if (input.action==='dismiss') {
          if (job.status!=='searching' || job.preferredProviderId!==actor.uid) throw new BillingError('This request is no longer available.');
          tx.update(jobRef,{status:'cancelled',cancelledBy:actor.uid,cancellationType:'provider_declined',cancellationReason:'The selected provider is unable to attend. Please choose another provider.',cancelledAt:stamp(),updatedAt:stamp()});
          return {dismissed:true};
        }
        if (input.action==='accept') {
          if (job.providerId===actor.uid && ['accepted','en_route','arrived'].includes(job.status)) return {accepted:true};
          if (job.status!=='searching' || job.providerId || job.preferredProviderId!==actor.uid || job.rejectedBy?.includes(actor.uid)) throw new BillingError('This request is no longer available.');
          requireAvailable(directory,now);
          if (!(job.issues??[]).every(issue=>(directory.services??[]).includes(issue)) || !(directory.vehicleTypes??[]).includes(job.vehicleType)) throw new BillingError('This request does not match your services or vehicle types.');
          const quoteSnap=await tx.get(db.doc(`visitFeeQuotes/${job.visitFeeQuoteId}`));
          assertVisitQuote(job,quoteSnap.data());
          const driverModeration=await tx.get(db.doc(`accountModeration/${job.driverId}`));
          if (['suspended','deleted','disabled'].includes(driverModeration.data()?.status)) throw new BillingError('The driver account is unavailable.');
          if (profile.activeRequestId && profile.activeRequestId!==input.requestId) {
            const active=await tx.get(db.doc(`requests/${profile.activeRequestId}`));
            if (['accepted','en_route','arrived'].includes(active.data()?.status) && !active.data()?.serviceCompletedAt) throw new BillingError('Complete your active job first.');
          }
          tx.update(jobRef,{providerId:actor.uid,providerName:profile.displayName??'Service Provider',providerPhone:profile.phone??'',status:'accepted',acceptedAt:stamp(),updatedAt:stamp()});
          tx.update(directoryRef,{activeRequestId:input.requestId});
          tx.update(profileRef,{activeRequestId:input.requestId,activeJobStartedAt:stamp(),updatedAt:stamp()});
          return {accepted:true};
        }
        if (job.providerId!==actor.uid || job.status!=='arrived' || job.completionState==='pending' || job.pendingDiscountId) throw new BillingError('This job is not ready for a final bill.');
        if (job.arrivalConfirmedBy!==job.driverId || (job.jobStartCodeRequired && !job.jobStartCodeVerifiedAt)) throw new BillingError('Ask the driver to confirm arrival first.');
        const bill=finalBill(job,input);
        if (input.action==='estimate') {
          if (job.serviceCompletedAt) throw new BillingError('Work is already finished. Correct the bill within the approved amounts.');
          if (job.workEstimate?.status==='pending') throw new BillingError('Wait for the driver to review the current estimate.');
          const revision=(job.workEstimate?.revision??0)+1;
          const estimate={...bill,revision,status:'pending',createdBy:actor.uid,createdAt:stamp()};
          tx.update(jobRef,{workEstimate:estimate,updatedAt:stamp()});
          tx.set(jobRef.collection('workEstimates').doc(String(revision)),estimate);
          return {total:bill.finalCost};
        }
        if (job.workEstimate?.status==='pending') throw new BillingError('Wait for the driver to approve or decline the extra work.');
        const approved=job.workEstimate?.status==='approved' ? job.workEstimate : null;
        if (job.workApprovalRequired && bill.billItems.length && !approved) throw new BillingError('Ask the driver to approve replacement parts before sending the final bill.');
        if (approved && (bill.finalCost>approved.finalCost || bill.inspectionFee>approved.inspectionFee || bill.serviceFee>approved.serviceFee || !approvedItemsCover(approved.billItems,bill.billItems))) throw new BillingError('The bill exceeds the approved work. Request approval for the revised estimate first.');
        const revision=(job.billRevision??0)+1;
        tx.set(jobRef.collection('billRevisions').doc(String(revision)),{...bill,providerId:actor.uid,createdAt:stamp(),revision});
        tx.update(jobRef,{...bill,billRevision:revision,completionState:'pending',completionSubmittedAt:stamp(),...(job.workApprovalRequired?{serviceCompletedAt:job.serviceCompletedAt??stamp()}:{}),servicePhotoData:job.servicePhotoData??[],billCorrectionReason:null,updatedAt:stamp()});
        if (job.workApprovalRequired) {
          if (directory?.activeRequestId===input.requestId) tx.update(directoryRef,{activeRequestId:null});
          if (profile.activeRequestId===input.requestId) tx.update(profileRef,{activeRequestId:null,updatedAt:stamp()});
        }
        return {total:bill.finalCost};
      });
      return res.status(200).json(result);
    } catch (error) {
      if (typeof error.code==='string' && error.code.startsWith('auth/')) return res.status(401).json({message:'Sign in again.'});
      if (error instanceof BillingError) return res.status(error.status).json({message:error.message});
      console.error('Visit billing failed',error.code??'server-error');
      return res.status(500).json({message:'Billing is temporarily unavailable. Please retry.'});
    }
  };
}
function approvedItemsCover(approved, items) {
  const totals = rows => rows.reduce((map,item) => { const key=JSON.stringify([item.label,item.reason]); map.set(key,(map.get(key)??0)+item.amount); return map; },new Map());
  const caps=totals(approved);
  return [...totals(items)].every(([key,amount])=>amount<=(caps.get(key)??0));
}
function requireApproval(m,a,now) {
  if (m?.status!=='active' || m?.verification!=='verified' || (m.validUntil?.toMillis()??0)<=now || !a || a.applicationStatus==='withdrawn' || a.revision!==m.verificationRevision) throw new BillingError('Current provider approval is required.',403);
}
function requireAvailable(d,now) {
  if (!d || !d.online || d.requestsPaused || d.activeRequestId || !d.locationUpdatedAt || now-d.locationUpdatedAt.toMillis()>120000 || d.locationUpdatedAt.toMillis()>now+30000) throw new BillingError('The provider is busy, offline or needs to refresh location.');
  if (!d.available24Hours && d.scheduleConfigured && (d.hoursOverrideUntil?.toMillis()??0)<=now) {
    const date=new Date(now+19800000), minute=date.getUTCHours()*60+date.getUTCMinutes(), start=d.workStartMinute,end=d.workEndMinute;
    if (!(start<end ? minute>=start&&minute<end : start>end && (minute>=start||minute<end))) throw new BillingError('The provider is outside working hours.');
  }
}
async function defaultAdmin() {
  const [{cert,getApps,initializeApp},{getAuth},{getFirestore,FieldValue,Timestamp}]=await Promise.all([import('firebase-admin/app'),import('firebase-admin/auth'),import('firebase-admin/firestore')]);
  if (!getApps().length) initializeApp({credential:cert({projectId:process.env.FIREBASE_PROJECT_ID,clientEmail:process.env.FIREBASE_CLIENT_EMAIL,privateKey:process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g,'\n')})});
  return {auth:getAuth(),db:getFirestore(),FieldValue,Timestamp};
}
export default createBillingHandler();
