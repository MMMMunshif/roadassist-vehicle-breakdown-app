import {randomBytes,createHash} from 'node:crypto';
import {createBillingHandler,defaultAdmin,requireApproval,requireAvailable} from './visit-billing.mjs';
import {BillingError,distanceKm,assertVisitQuote} from '../functions/visit-billing-policy.mjs';
import {phoneActor,guestActor,guestPhone,assertGuest,assertGuestRequest,guestName,guestDraft,guestActions} from '../functions/guest-policy.mjs';
const validId=id=>typeof id==='string' && /^[a-zA-Z0-9_-]{1,128}$/.test(id);
export function createGuestHandler({loadAdmin=defaultAdmin,enabled=()=>process.env.GUEST_REQUESTS_ENABLED==='true'}={}) {
 const billing=createBillingHandler({loadAdmin});
 return async (req,res)=>{
  res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');res.setHeader('Access-Control-Allow-Methods','GET, POST, OPTIONS');res.setHeader('Cache-Control','no-store');
  if(req.method==='OPTIONS') return res.status(204).end();
  if(req.method==='GET') return res.status(200).json({enabled:enabled()});
  if(req.method!=='POST') return res.status(405).json({message:'POST required.'});
  if(!enabled()) return res.status(503).json({message:'Guest requests are not enabled yet. Emergency Help is still available.'});
  if(!/^Bearer .+/.test(req.headers.authorization??'')) return res.status(401).json({message:'Open guest access first.'});
  const input=req.body??{};
  if(!['bootstrap','recover','providers','create','read','cancel','arrive','message','report_cash',...guestActions].includes(input.action)) return res.status(400).json({message:'Unsupported guest action.'});
  try {
   const admin=await loadAdmin(),{auth,db,FieldValue,Timestamp}=admin;
   const actor=await auth.verifyIdToken(req.headers.authorization.substring(7),true);
   if(!guestActor(actor)) throw new BillingError('Open a guest session first.',403);
   const sessionRef=db.doc(`guestSessions/${actor.uid}`),profileRef=db.doc(`users/${actor.uid}`),moderationRef=db.doc(`accountModeration/${actor.uid}`);
   const stamp=()=>FieldValue.serverTimestamp();
   if(input.action==='recover') {
    // 256-bit bearer secret: neither phone numbers nor request IDs grant access.
    if(typeof input.recoveryCode!=='string'||!/^gs_[a-f0-9]{64}$/.test(input.recoveryCode)) throw new BillingError('Invalid recovery code.',403);
    const hash=createHash('sha256').update(input.recoveryCode).digest('hex');
    const saved=(await db.doc(`guestRecovery/${hash}`).get()).data();
    if(!saved?.uid) throw new BillingError('Invalid recovery code.',403);
    const [rp,rs,rm]=await Promise.all([db.doc(`users/${saved.uid}`).get(),db.doc(`guestSessions/${saved.uid}`).get(),db.doc(`accountModeration/${saved.uid}`).get()]);
    assertGuest({...actor,uid:saved.uid,firebase:{sign_in_provider:'anonymous'}},rp.data(),rs.data(),rm.data());
    if(rs.data()?.recoveryHash!==hash) throw new BillingError('Recovery code is no longer active.',403);
    return res.status(200).json({token:await auth.createCustomToken(saved.uid,{guestSession:true})});
   }
   if(input.action==='bootstrap') {
    const result=await db.runTransaction(async tx=>{
     const [p,s,m]=await Promise.all([tx.get(profileRef),tx.get(sessionRef),tx.get(moderationRef)]);
     if(p.exists && p.data()?.accountType!=='guest') throw new BillingError('This phone belongs to a member account. Use member sign-in.',409);
     if(['suspended','deleted','disabled'].includes(m.data()?.status)||m.data()?.verification==='rejected') throw new BillingError('Account access is unavailable.',403);
     if(s.exists){assertGuest(actor,p.data(),s.data(),m.data());return {requestId:s.data().currentRequestId??null,name:p.data().displayName??'',phone:p.data().phone};}
     const name=guestName(input.name),phone=phoneActor(actor)?actor.phone_number:guestPhone(input.phone);
     const recoveryCode='gs_'+randomBytes(32).toString('hex'), recoveryHash=createHash('sha256').update(recoveryCode).digest('hex');
     tx.set(profileRef,{role:'guest',roles:[],accountType:'guest',displayName:name,phone,phoneVerified:phoneActor(actor),createdAt:stamp(),updatedAt:stamp()});
     tx.set(sessionRef,{enabled:true,phone,recoveryHash,currentRequestId:null,createdAt:stamp()});
     tx.set(db.doc(`guestRecovery/${recoveryHash}`),{uid:actor.uid,createdAt:stamp()});
     return {requestId:null,name,phone,recoveryCode};
    });return res.status(200).json(result);
   }
   const [p,s,m]=await Promise.all([profileRef.get(),sessionRef.get(),moderationRef.get()]);
   const session=s.data();assertGuest(actor,p.data(),session,m.data());
   if(guestActions.has(input.action)) return billing(req,res);
   if(input.action==='providers') {
    const draft=guestDraft(input);
    const dirs=await db.collection('providerDirectory').where('online','==',true).limit(100).get();
    const rows=await Promise.all(dirs.docs.map(async d=>{
     try{const data=d.data();requireAvailable(data,Date.now());
      const [approval,application]=await Promise.all([db.doc(`accountModeration/${d.id}`).get(),db.doc(`providerApplications/${d.id}`).get()]);
      requireApproval(approval.data(),application.data(),Date.now());
      if(!(data.services??[]).includes(draft.issue)||!(data.vehicleTypes??[]).includes(draft.vehicleType)) return null;
      const km=distanceKm(draft,data),radius=Number(/\d+/.exec(data.serviceRadius??'15')?.[0]??15);
      if(km>radius || km>500 || d.id===actor.uid) return null;
      return {id:d.id,name:data.displayName??'Provider',distanceKm:km};
     }catch(e){if(e instanceof BillingError)return null;throw e;}
    }));return res.status(200).json({providers:rows.filter(Boolean).sort((a,b)=>a.distanceKm-b.distanceKm)});
   }
   if(input.action==='create') {
    if(!validId(input.submissionId)||!validId(input.quoteId)||!validId(input.providerId)) throw new BillingError('Review a provider and visit fee first.',400);
    const draft=guestDraft(input),ref=db.doc(`requests/${input.submissionId}`);
    await db.runTransaction(async tx=>{
     const [freshSession,profile,moderation,existing,quote]=await Promise.all([tx.get(sessionRef),tx.get(profileRef),tx.get(moderationRef),tx.get(ref),tx.get(db.doc(`visitFeeQuotes/${input.quoteId}`))]);
     assertGuest(actor,profile.data(),freshSession.data(),moderation.data());
     const operations=(await tx.get(db.doc('appSettings/operations'))).data();
     if(operations?.maintenance || (Array.isArray(operations?.enabledServices) && !operations.enabledServices.includes(draft.issue))) throw new BillingError('New requests for this service are temporarily paused.');
     const current=freshSession.data()?.currentRequestId;
     if(existing.exists){assertGuestRequest(actor,freshSession.data(),existing.data(),ref.id);return;}
     if(current){const old=await tx.get(db.doc(`requests/${current}`));if(old.exists && old.data()?.status!=='cancelled' && !(old.data()?.status==='completed'&&old.data()?.providerConfirmedPayment===true)) throw new BillingError('Finish your current request and receipt before starting another.');}
     const job={...draft,driverId:actor.uid,driverName:profile.data().displayName,driverPhone:profile.data().phone,driverPhoneVerified:phoneActor(actor),guestRequest:true,
      preferredProviderId:input.providerId,providerId:null,status:'searching',workflowVersion:3,workApprovalRequired:true,
      arrivalVerificationRequired:true,jobStartCodeRequired:false,visitFeeQuoteId:input.quoteId,dispatchFee:quote.data()?.visitFee,
      providerDistanceKm:quote.data()?.distanceKm,serviceFee:0,estimatedCost:quote.data()?.visitFee,priority:'normal',partsPreference:'discuss',
      rejectedBy:[],description:phoneActor(actor)?'':'Guest contact number is not verified. Call the driver to confirm before travelling.',vehiclePhotoUrls:[],photoAnnotations:[],createdAt:Timestamp.now(),updatedAt:stamp()};
     assertVisitQuote(job,quote.data());
     const [directory,approval,application]=await Promise.all([tx.get(db.doc(`providerDirectory/${input.providerId}`)),tx.get(db.doc(`accountModeration/${input.providerId}`)),tx.get(db.doc(`providerApplications/${input.providerId}`))]);
     requireApproval(approval.data(),application.data(),Date.now());requireAvailable(directory.data(),Date.now());
     if(!(directory.data().services??[]).includes(draft.issue)||!(directory.data().vehicleTypes??[]).includes(draft.vehicleType))throw new BillingError('This provider no longer matches your request.');
     tx.set(ref,job);tx.update(sessionRef,{currentRequestId:ref.id,updatedAt:stamp()});tx.update(profileRef,{activeRequestId:ref.id,updatedAt:stamp()});
    });return res.status(200).json({requestId:ref.id});
   }
   if(!validId(input.requestId))throw new BillingError('Open your current guest request.',400);
   const jobRef=db.doc(`requests/${input.requestId}`);
   if(input.action==='read') {
    const job=await jobRef.get();assertGuestRequest(actor,session,job.data(),input.requestId);
    const messages=await jobRef.collection('messages').orderBy('createdAt','desc').limit(40).get();
    return res.status(200).json({job:jsonValue(job.data()),messages:messages.docs.map(d=>({id:d.id,...jsonValue(d.data())})).reverse(),syncedAt:Date.now()});
   }
   await db.runTransaction(async tx=>{
    const [jobDoc,freshSession,profile,moderation]=await Promise.all([tx.get(jobRef),tx.get(sessionRef),tx.get(profileRef),tx.get(moderationRef)]);
    const job=jobDoc.data();assertGuest(actor,profile.data(),freshSession.data(),moderation.data());assertGuestRequest(actor,freshSession.data(),job,input.requestId);
    if(input.action==='cancel') {
     if(job.status==='cancelled')return;
     if(!['searching','accepted','en_route'].includes(job.status)||job.completionState==='pending'||job.serviceCompletedAt) throw new BillingError('This request cannot be cancelled at this stage.');
     const reason=typeof input.reason==='string'?input.reason.trim():'';if(reason.length<10||reason.length>500)throw new BillingError('Choose a cancellation reason.',400);
     const dir=job.providerId?await tx.get(db.doc(`providerDirectory/${job.providerId}`)):null;
     tx.update(jobRef,{status:'cancelled',cancelledBy:actor.uid,cancellationReason:reason,cancelledAt:stamp(),updatedAt:stamp()});
     if(dir?.data()?.activeRequestId===input.requestId)tx.update(dir.ref,{activeRequestId:null});
     tx.update(profileRef,{activeRequestId:FieldValue.delete(),updatedAt:stamp()});
    }else if(input.action==='arrive') {
     if(job.status!=='arrived'||!job.providerId)throw new BillingError('Wait for the provider to mark arrival.');
     if(job.arrivalConfirmedBy===actor.uid)return;
     tx.update(jobRef,{arrivalConfirmedBy:actor.uid,arrivalConfirmedAt:stamp(),arrivalConfirmationReason:'Guest confirms physically meeting the assigned provider.',updatedAt:stamp()});
    }else if(input.action==='message') {
     const text=typeof input.text==='string'?input.text.trim():'';
     if(!job.providerId||['cancelled','completed'].includes(job.status)||text.length<1||text.length>2000)throw new BillingError('Messaging is available during your assigned job only.',400);
     if(Date.now()-(freshSession.data().lastMessageAt?.toMillis()??0)<1500)throw new BillingError('Wait a moment before sending another message.',429);
     tx.set(jobRef.collection('messages').doc(),{senderId:actor.uid,text,createdAt:stamp()});tx.update(sessionRef,{lastMessageAt:stamp()});
    }else if(input.action==='report_cash') {
     if(job.status!=='completed'||job.paymentMethod!=='cash')throw new BillingError('Review and accept the final cash bill first.');
     if(!job.driverReportedPayment)tx.update(jobRef,{driverReportedPayment:true,paymentReportedAt:stamp(),updatedAt:stamp()});
    }else throw new BillingError('Unsupported action.',400);
   });return res.status(200).json({ok:true});
  }catch(e){if(e instanceof BillingError)return res.status(e.status).json({message:e.message});if(e.code?.startsWith('auth/'))return res.status(401).json({message:'Reopen guest access.'});console.error('Guest assistance failed',e.code??'server-error');return res.status(500).json({message:'Unable to update guest assistance. Retry when connected.'});}
 };
}
function jsonValue(value){if(value?.toMillis)return value.toMillis();if(Array.isArray(value))return value.map(jsonValue);if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,jsonValue(v)]));return value;}
export default createGuestHandler();
