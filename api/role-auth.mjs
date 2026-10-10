import { createHash } from 'node:crypto';
import { roleAddress, resolveRoleUser } from '../functions/role-identity.mjs';

async function services() {
  const {cert, getApps, initializeApp} = await import('firebase-admin/app');
  const {getAuth} = await import('firebase-admin/auth');
  const {getFirestore, FieldValue} = await import('firebase-admin/firestore');
  if (!getApps().length) initializeApp({credential:cert({
    projectId:process.env.FIREBASE_PROJECT_ID, clientEmail:process.env.FIREBASE_CLIENT_EMAIL,
    privateKey:process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  })});
  return {auth:getAuth(), db:getFirestore(), timestamp:()=>FieldValue.serverTimestamp()};
}

async function nativePasswordSignIn(email, password) {
  if (!process.env.FIREBASE_WEB_API_KEY) throw Error('Missing web API key');
  const check = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${process.env.FIREBASE_WEB_API_KEY}`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email, password, returnSecureToken:true}),
    signal:AbortSignal.timeout(15000),
  });
  const result = await check.json();
  return check.ok ? result.localId : null;
}

export function createRoleAuthHandler({getServices = services, passwordSignIn = nativePasswordSignIn,
  enabled = () => process.env.INDEPENDENT_ROLE_AUTH === 'true',
  testEmail = () => process.env.ROLE_AUTH_TEST_EMAIL} = {}) {
return async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({code:'method-not-allowed'});
  if (!enabled()) return res.status(503).json({code:'role-auth-unavailable'});
  const {email:input, role, password, action, displayName, phone} = req.body ?? {};
  let email, identity;
  try {
    email = String(input ?? '').trim().toLowerCase();
    if (testEmail() && email !== testEmail().trim().toLowerCase()) {
      return res.status(503).json({code:'role-auth-unavailable'});
    }
    identity = roleAddress(email, role);
    if (!['register','login'].includes(action) || typeof password !== 'string' || password.length > 4096) throw Error();
    if (action === 'register' && (password.length < 8 || !/[a-z]/i.test(password) || !/\d/.test(password) ||
      typeof displayName !== 'string' || displayName.trim().length < 2 || displayName.trim().length > 100 ||
      !/^\+947\d{8}$/.test(phone))) throw Error();
  } catch { return res.status(400).json({code:'invalid-argument'}); }
  try {
    const {auth, db, timestamp} = await getServices();
    // Durable per-address and per-account throttles shared across server instances.
    const address = String(req.headers['x-forwarded-for'] ?? req.socket?.remoteAddress ?? 'unknown').split(',')[0].trim();
    const keys = [`ip:${address}`, `account:${identity}`].map(x => createHash('sha256').update(x).digest('hex'));
    const allowed = await db.runTransaction(async tx => {
      const refs = keys.map(k => db.doc(`roleAuthLimits/${k}`));
      const snapshots = await Promise.all(refs.map(r => tx.get(r)));
      const now = Date.now();
      const counts = snapshots.map(s => now - (s.data()?.start ?? 0) < 900000 ? s.data().count : 0);
      if (counts[0] >= 40 || counts[1] >= 10) return false;
      refs.forEach((r,i) => tx.set(r, {count:counts[i]+1, start:counts[i] ? snapshots[i].data().start : now}));
      return true;
    });
    if (!allowed) return res.status(429).json({code:'too-many-requests'});
    if (action === 'register') {
      // A suspended legacy account cannot evade moderation by enrolling a fresh role.
      let legacy;
      try { legacy = await auth.getUserByEmail(email); }
      catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
      if (legacy) {
        const moderation = (await db.doc(`accountModeration/${legacy.uid}`).get()).data();
        if (legacy.disabled || ['suspended','deleted','disabled'].includes(moderation?.status)) {
          return res.status(403).json({code:'user-disabled'});
        }
      }
      const existing = await resolveRoleUser(auth, db, email, role);
      if (existing) return res.status(409).json({code:'email-already-in-use'});
      // createUser's unique email constraint also serializes parallel registration.
      const user = await auth.createUser({email:identity, password, displayName:displayName.trim(), emailVerified:false});
      try {
        await db.doc(`users/${user.uid}`).create({email, displayName:displayName.trim(), phone,
          role, roles:[role], lastRole:role, authIdentity:'role-v1', online:false,
          createdAt:timestamp(), updatedAt:timestamp()});
      } catch (error) {
        await auth.deleteUser(user.uid);
        throw error;
      }
      return res.status(201).json({authEmail:user.email});
    }
    const account = await resolveRoleUser(auth, db, email, role);
    if (!account) return res.status(401).json({code:'invalid-credential'});
    const moderation = (await db.doc(`accountModeration/${account.user.uid}`).get()).data();
    if (['suspended','deleted','disabled'].includes(moderation?.status)) return res.status(401).json({code:'user-disabled'});
    const uid = await passwordSignIn(account.user.email, password);
    if (uid !== account.user.uid) return res.status(401).json({code:'invalid-credential'});
    return res.status(200).json({authEmail:account.user.email});
  } catch (error) {
    if (error?.code === 'auth/email-already-exists') return res.status(409).json({code:'email-already-in-use'});
    // Never log request bodies, credentials, action links or session tokens.
    console.error('Role authentication failed', error?.code ?? error?.name);
    return res.status(503).json({code:'role-auth-unavailable'});
  }
}

}

export default createRoleAuthHandler();
