import {newChallenge, checkCode, validateParticipant} from '../functions/job-start-policy.mjs';
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({message:'POST required.'});
  if (!/^Bearer .+/.test(req.headers.authorization ?? '')) return res.status(401).json({message:'Sign in again.'});
  const {requestId, action, code} = req.body ?? {};
  if (typeof requestId !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(requestId) || !['issue','verify'].includes(action) || (action === 'verify' && (typeof code !== 'string' || !/^\d{6}$/.test(code)))) return res.status(400).json({message:'Provide a valid request and six-digit code.'});
  try {
    const [{cert,getApps,initializeApp},{getAuth},{getFirestore,FieldValue}] = await Promise.all([import('firebase-admin/app'),import('firebase-admin/auth'),import('firebase-admin/firestore')]);
    if (!getApps().length) initializeApp({credential:cert({projectId:process.env.FIREBASE_PROJECT_ID, clientEmail:process.env.FIREBASE_CLIENT_EMAIL, privateKey:process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g,'\n')})});
    const actor = await getAuth().verifyIdToken(req.headers.authorization.substring(7), true);
    const db = getFirestore(), jobRef = db.doc(`requests/${requestId}`), secretRef = db.doc(`jobStartChallenges/${requestId}`);
    const challenge = action === 'issue' ? newChallenge() : null;
    const result = await db.runTransaction(async tx => {
      const [job, secret, profile, moderation, application] = await Promise.all([tx.get(jobRef),tx.get(secretRef),tx.get(db.doc(`users/${actor.uid}`)),tx.get(db.doc(`accountModeration/${actor.uid}`)),action === 'verify' ? tx.get(db.doc(`providerApplications/${actor.uid}`)) : Promise.resolve(null)]);
      const error = validateParticipant(job.data(), actor, action);
      if (error) return {status:403,message:error};
      if (!profile.exists || moderation.data()?.status === 'suspended' || moderation.data()?.verification === 'rejected') return {status:403,message:'Account access is unavailable.'};
      const role = action === 'issue' ? 'driver' : 'provider';
      if ((profile.data()?.roleEmailRequired ?? []).includes(role)) {
        const roleEmail = await tx.get(db.doc(`roleEmailVerifications/${actor.uid}`));
        if (roleEmail.data()?.[role]?.email !== actor.email?.toLowerCase()) return {status:403,message:'Verify email for this account role first.'};
      }
      const data = secret.data(), now = Date.now();
      if (action === 'verify' && (moderation.data()?.verification !== 'verified' || moderation.data()?.status !== 'active' || (moderation.data()?.validUntil?.toMillis() ?? 0) <= now || !application?.exists || application.data().applicationStatus === 'withdrawn' || application.data().revision !== moderation.data()?.verificationRevision)) return {status:403,message:'Current provider approval is required.'};
      if (action === 'issue') {
        if (data?.issuedAtMs && now - data.issuedAtMs < 60000) return {status:429,message:'Wait one minute before generating a replacement code.'};
        tx.set(secretRef, {...challenge.record, driverId:job.data().driverId, providerId:job.data().providerId});
        return {status:200,code:challenge.code,expiresAt:challenge.record.expiresAtMs};
      }
      if (data?.providerId !== actor.uid || data?.driverId !== job.data().driverId) return {status:409,message:'Ask the driver to generate a new code.'};
      const verdict = checkCode(data, code, now);
      if (verdict === 'incorrect') {
        tx.update(secretRef,{attempts:(data.attempts ?? 0)+1});
        return {status:400,message:'Incorrect code. Check the code with the driver.'};
      }
      if (verdict !== 'verified') return {status:409,message:verdict === 'locked' ? 'Too many attempts. Ask the driver for a new code.' : 'Code expired or unavailable. Ask the driver for a new code.'};
      tx.update(secretRef,{usedAtMs:now});
      tx.update(jobRef,{arrivalConfirmedBy:job.data().driverId,arrivalConfirmedAt:FieldValue.serverTimestamp(),arrivalConfirmationMethod:'job_start_code',arrivalConfirmationReason:'Driver shared the job start code with the assigned provider.',arrivalDistanceMeters:null,jobStartCodeVerifiedAt:FieldValue.serverTimestamp(),workStartedAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
      return {status:200,verified:true};
    });
    const {status,...body} = result;
    return res.status(status).json(body);
  } catch(error) {
    if (error.code?.startsWith('auth/')) return res.status(401).json({message:'Sign in again to continue.'});
    console.error('Job start verification failed', error.code ?? 'server-error');
    return res.status(500).json({message:'Unable to verify job start. Please try again.'});
  }
}
