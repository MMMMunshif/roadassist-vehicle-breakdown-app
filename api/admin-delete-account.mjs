import {services} from './role-auth.mjs';
import {deletionBlockers} from '../functions/account-deletion-policy.mjs';

export function createAdminDeleteAccountHandler({getServices=services}={}) {
return async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({message:'POST required.'});
  if (!/^Bearer \S+$/.test(req.headers.authorization ?? '')) return res.status(401).json({code:'unauthenticated',message:'Sign in again before deleting an account.'});
  try {
    const {auth,db,timestamp}=await getServices();
    let actor;
    try {actor=await auth.verifyIdToken(req.headers.authorization.slice(7),true);}
    catch {return res.status(401).json({code:'unauthenticated',message:'Your session expired. Sign in again before deleting an account.'});}
    const access=(await db.doc(`adminAccess/${actor.uid}`).get()).data();
    const actorStatus=(await db.doc(`accountModeration/${actor.uid}`).get()).data();
    if (!actor.admin || !actor.email_verified || !access?.enabled || (access.role ?? 'super_admin') !== 'super_admin' || (actorStatus?.status === 'suspended' || actorStatus?.verification === 'rejected'))
      return res.status(403).json({message:'Main admin permission required.'});
    if (!Number.isFinite(actor.auth_time) || Date.now()/1000-actor.auth_time > 600) return res.status(401).json({message:'Sign out and sign in again before deleting an account.'});
    const {uid, reason, confirmation}=req.body ?? {};
    if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid) || typeof reason !== 'string' || reason.trim().length<10 || reason.length>500 || confirmation!==uid)
      return res.status(400).json({message:'Provide the account ID confirmation and a reason (10–500 characters).'});
    if (uid===actor.uid || (await db.doc(`adminAccess/${uid}`).get()).data()?.enabled)
      return res.status(409).json({message:'Your own account and enabled admin accounts cannot be deleted.'});
    const groups=await Promise.all(['driverId','providerId'].map(field=>db.collection('requests').where(field,'==',uid).get()));
    async function blockersFor(groups) {
      const jobs=[...new Map(groups.flatMap(g=>g.docs).map(doc=>[doc.id,doc])).values()];
      const checked=await Promise.all(jobs.map(async doc=> {
        const [dispute,review]=await Promise.all([doc.ref.collection('disputes').doc('case').get(),db.doc(`complaintReviews/${doc.id}`).get()]);
        return {...doc.data(),hasDispute:dispute.exists,complaintStatus:review.data()?.status};
      }));
      return deletionBlockers(checked);
    }
    // Do not suspend a working account merely because deletion is currently blocked.
    if ((await blockersFor(groups)).length) return res.status(409).json({code:'deletion-blocked',message:'Complete or cancel active jobs, confirm payments and resolve complaints before deleting this account. Account access has not been changed.'});
    const profile=db.doc(`users/${uid}`), moderation=db.doc(`accountModeration/${uid}`);
    const audit=db.doc(`adminAudit/deletion_${uid}`);
    // Suspend before checking jobs so new participant writes are blocked by existing rules.
    await db.runTransaction(async tx => {
      const [p,m,a]=await Promise.all([tx.get(profile),tx.get(moderation),tx.get(audit)]);
      if (a.data()?.state==='complete') return;
      if (!p.exists && !a.exists) throw Object.assign(new Error('Profile missing'),{code:'account-not-found'});
      tx.set(moderation,{status:'suspended',verification:m.data()?.verification ?? 'pending',reason:reason.trim(),updatedBy:actor.uid,updatedAt:timestamp()}, {merge:true});
      tx.set(audit,{kind:'account_deletion',target:uid,actor:actor.uid,reason:reason.trim(),state:'checking',createdAt:timestamp()},{merge:true});
    });
    if ((await audit.get()).data()?.state==='complete') return res.status(200).json({ok:true});
    const directory=db.doc(`providerDirectory/${uid}`);
    if ((await directory.get()).exists) await directory.update({online:false,updatedAt:timestamp()});
    // Recheck after suspension to close the race with a job accepted during preflight.
    const frozenGroups=await Promise.all(['driverId','providerId'].map(field=>db.collection('requests').where(field,'==',uid).get()));
    if ((await blockersFor(frozenGroups)).length) {
      await audit.update({state:'blocked'});
      return res.status(409).json({code:'deletion-blocked',message:'A job changed during deletion. Account is suspended; review the job and restore account access if appropriate.'});
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
    await audit.update({state:'complete',completedAt:timestamp()});
    return res.status(200).json({ok:true});
  } catch(error) {
    if(error.code==='account-not-found') return res.status(404).json({code:'account-not-found',message:'This account profile no longer exists. Refresh the accounts list.'});
    console.error('Account deletion failed',error.code ?? 'deletion-error');
    return res.status(500).json({message:'Deletion did not finish. Review the audit entry and retry; a partial deletion keeps the account blocked.'});
  }
}

}
export default createAdminDeleteAccountHandler();
