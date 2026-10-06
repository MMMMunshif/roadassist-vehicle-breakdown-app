import {deletionBlockers} from '../functions/account-deletion-policy.mjs';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({message:'POST required.'});
  try {
    const [{cert,getApps,initializeApp},{getAuth},{getFirestore,FieldValue}] = await Promise.all([
      import('firebase-admin/app'), import('firebase-admin/auth'), import('firebase-admin/firestore'),
    ]);
    if (!getApps().length) initializeApp({credential:cert({projectId:process.env.FIREBASE_PROJECT_ID,
      clientEmail:process.env.FIREBASE_CLIENT_EMAIL, privateKey:process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g,'\n')})});
    const auth=getAuth(), db=getFirestore();
    const actor=await auth.verifyIdToken((req.headers.authorization ?? '').replace(/^Bearer /,''),true);
    const access=(await db.doc(`adminAccess/${actor.uid}`).get()).data();
    const actorStatus=(await db.doc(`accountModeration/${actor.uid}`).get()).data();
    if (!actor.admin || !actor.email_verified || !access?.enabled || (access.role ?? 'super_admin') !== 'super_admin' || (actorStatus?.status === 'suspended' || actorStatus?.verification === 'rejected'))
      return res.status(403).json({message:'Main admin permission required.'});
    if (Date.now()/1000-actor.auth_time > 600) return res.status(401).json({message:'Sign out and sign in again before deleting an account.'});
    const {uid, reason, confirmation}=req.body ?? {};
    if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid) || typeof reason !== 'string' || reason.trim().length<10 || reason.length>500 || confirmation!==uid)
      return res.status(400).json({message:'Provide the account ID confirmation and a reason (10–500 characters).'});
    if (uid===actor.uid || (await db.doc(`adminAccess/${uid}`).get()).data()?.enabled)
      return res.status(409).json({message:'Your own account and enabled admin accounts cannot be deleted.'});
    const profile=db.doc(`users/${uid}`), moderation=db.doc(`accountModeration/${uid}`);
    const audit=db.doc(`adminAudit/deletion_${uid}`);
    // Suspend before checking jobs so new participant writes are blocked by existing rules.
    await db.runTransaction(async tx => {
      const [p,m,a]=await Promise.all([tx.get(profile),tx.get(moderation),tx.get(audit)]);
      if (a.data()?.state==='complete') return;
      if (!p.exists && !a.exists) throw new Error('Profile missing');
      tx.set(moderation,{status:'suspended',verification:m.data()?.verification ?? 'pending',reason:reason.trim(),updatedBy:actor.uid,updatedAt:FieldValue.serverTimestamp()}, {merge:true});
      tx.set(audit,{kind:'account_deletion',target:uid,actor:actor.uid,reason:reason.trim(),state:'checking',createdAt:FieldValue.serverTimestamp()},{merge:true});
    });
    if ((await audit.get()).data()?.state==='complete') return res.status(200).json({ok:true});
    const directory=db.doc(`providerDirectory/${uid}`);
    if ((await directory.get()).exists) await directory.update({online:false,updatedAt:FieldValue.serverTimestamp()});
    const groups=await Promise.all(['driverId','providerId'].map(field=>db.collection('requests').where(field,'==',uid).get()));
    const jobs=[...new Map(groups.flatMap(g=>g.docs).map(doc=>[doc.id,doc])).values()];
    const checked=await Promise.all(jobs.map(async doc=> {
      const [dispute,review]=await Promise.all([doc.ref.collection('disputes').doc('case').get(),db.doc(`complaintReviews/${doc.id}`).get()]);
      return {...doc.data(),hasDispute:dispute.exists,complaintStatus:review.data()?.status};
    }));
    if (deletionBlockers(checked).length) {
      await audit.update({state:'blocked'});
      return res.status(409).json({message:'Deletion blocked by active jobs, unconfirmed payments or unresolved complaints. Account remains suspended; review and restore it if appropriate.'});
    }
    try {
 await auth.updateUser(uid,{disabled:true}); await auth.revokeRefreshTokens(uid); }
    catch(error) { if(error.code!=='auth/user-not-found') throw error; }
    await audit.update({state:'deleting'});
    // Keep requests, invoices, complaint evidence and audit history for both participants.
    await db.recursiveDelete(profile);
    await db.recursiveDelete(db.doc(`providerApplications/${uid}`));
    await db.recursiveDelete(directory);
    try {
 await auth.deleteUser(uid); } catch(error) { if(error.code!=='auth/user-not-found') throw error; }
    await audit.update({state:'complete',completedAt:FieldValue.serverTimestamp()});
    return res.status(200).json({ok:true});
  } catch(error) {
    console.error('Account deletion failed',error.code ?? 'deletion-error');
    return res.status(500).json({message:'Deletion did not finish. Review the audit entry and retry; a partial deletion keeps the account blocked.'});
  }
}
