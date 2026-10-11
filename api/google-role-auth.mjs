import {createHash} from 'node:crypto';
import {services} from './role-auth.mjs';
import {roleAddress, resolveRoleUser} from '../functions/role-identity.mjs';

export function createGoogleRoleAuthHandler({getServices=services, enabled=()=>process.env.INDEPENDENT_ROLE_AUTH==='true'}={}) {
  return async (req,res)=>{
    res.setHeader('Cache-Control','no-store');
    res.setHeader('Access-Control-Allow-Origin','*');
    res.setHeader('Access-Control-Allow-Headers','Content-Type, Authorization');
    res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
    if(req.method==='OPTIONS') return res.status(204).end();
    if(req.method!=='POST') return res.status(405).json({code:'method-not-allowed'});
    if(!enabled()) return res.status(503).json({code:'role-auth-unavailable'});
    const {role,displayName,phone,photoData}=req.body??{};
    if(!['driver','provider'].includes(role)) return res.status(400).json({code:'invalid-argument'});
    const token=req.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if(!token) return res.status(401).json({code:'invalid-credential'});
    try {
      const {auth,db,timestamp}=await getServices();
      let proof;
      try {proof=await auth.verifyIdToken(token,true);} catch {return res.status(401).json({code:'invalid-credential'});}
      if(proof.firebase?.sign_in_provider!=='google.com'||proof.email_verified!==true||!proof.email)
        return res.status(401).json({code:'invalid-credential'});
      const email=proof.email.trim().toLowerCase();
      const identity=roleAddress(email,role);
      const key=createHash('sha256').update(`google:${proof.uid}:${role}`).digest('hex');
      const allowed=await db.runTransaction(async tx=>{
        const ref=db.doc(`roleAuthLimits/${key}`), snap=await tx.get(ref), now=Date.now();
        const old=snap.data(), count=now-(old?.start??0)<900000?(old?.count??0):0;
        if(count>=20) return false;
        tx.set(ref,{count:count+1,start:count?old.start:now});return true;
      });
      if(!allowed) return res.status(429).json({code:'too-many-requests'});
      // Check both the Google principal and legacy contact-email account for moderation.
      const principals=[proof.uid];
      try {const legacy=await auth.getUserByEmail(email); if(legacy.disabled) return res.status(403).json({code:'user-disabled'}); principals.push(legacy.uid);}
      catch(e){if(e.code!=='auth/user-not-found') throw e;}
      for(const uid of principals){
        const moderation=(await db.doc(`accountModeration/${uid}`).get()).data();
        if(['suspended','disabled','deleted'].includes(moderation?.status)) return res.status(403).json({code:'user-disabled'});
      }
      let account=await resolveRoleUser(auth,db,email,role);
      if(!account){
        if(typeof displayName!=='string'||displayName.trim().length<2||displayName.trim().length>100||!/^\+947\d{8}$/.test(phone??'')||
          (role==='driver'&&(typeof photoData!=='string'||!/^data:image\/(jpeg|png|webp);base64,/.test(photoData)||photoData.length>210000)))
          return res.status(400).json({code:'profile-details-required'});
        // Unique internal email serializes creation; never overwrite an orphan/disabled identity.
        const user=await auth.createUser({email:identity,displayName:displayName.trim(),emailVerified:true});
        const profile={email,displayName:displayName.trim(),phone,role,roles:[role],lastRole:role,authIdentity:'role-v1',online:false,
          ...(role==='driver'?{photoData}:{}),createdAt:timestamp(),updatedAt:timestamp()};
        try {await db.doc(`users/${user.uid}`).create(profile);} catch(e){await auth.deleteUser(user.uid);throw e;}
        account={user,profile};
      }
      const moderation=(await db.doc(`accountModeration/${account.user.uid}`).get()).data();
      if(account.user.disabled||['suspended','disabled','deleted'].includes(moderation?.status)) return res.status(403).json({code:'user-disabled'});
      // Verified Google ownership can verify the matching contact email, without changing its password/profile.
      if(!account.user.emailVerified) await auth.updateUser(account.user.uid,{emailVerified:true});
      return res.status(200).json({customToken:await auth.createCustomToken(account.user.uid)});
    } catch(e){
      if(e.code==='auth/email-already-exists') return res.status(409).json({code:'account-conflict'});
      console.error('Google role sign-in failed',e.code??e.name);
      return res.status(503).json({code:'role-auth-unavailable'});
    }
  };
}
export default createGoogleRoleAuthHandler();
