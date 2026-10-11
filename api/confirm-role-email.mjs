import { canConfirmRole } from '../functions/role-email-policy.mjs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';

export default async function handler(req, res) {
  res.setHeader('Cache-Control','no-store');
  res.setHeader('Referrer-Policy','no-referrer');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Content-Security-Policy',"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");
  const token = req.method === 'POST' ? req.body?.token : req.query?.token;
  if (!['GET','POST'].includes(req.method)) return res.status(405).send('Method not allowed.');
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) return res.status(400).send('Invalid verification link.');
  // GET is non-consuming: mail scanners must not verify a role automatically.
  if (req.method === 'GET') {
    res.setHeader('Content-Type','text/html; charset=utf-8');
    return res.status(200).send(`<!doctype html><html><meta name="viewport" content="width=device-width,initial-scale=1"><title>RoadAssist email confirmation</title><body style="font:16px Arial;max-width:480px;margin:60px auto;padding:24px"><h1>Confirm your RoadAssist role</h1><p>Confirm this email, then return to RoadAssist and tap the verification check button.</p><form method="post"><input type="hidden" name="token" value="${token}"><button type="submit" style="padding:14px">Confirm email</button></form></body></html>`);
  }
  try {
    if (!getApps().length) initializeApp({credential:cert({
      projectId:process.env.FIREBASE_PROJECT_ID,
      clientEmail:process.env.FIREBASE_CLIENT_EMAIL,
      privateKey:process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g,'\n'),
    })});
    const db = getFirestore();
    const digest = createHash('sha256').update(token).digest('hex');
    const ref = db.doc(`roleEmailChallenges/${digest}`);
    const initial = await ref.get();
    const challenge = initial.data();
    if (!challenge) return res.status(400).send('This link is invalid or expired. Request a new email in RoadAssist.');
    const user = await getAuth().getUser(challenge.uid);
    if (!user.emailVerified || user.email?.toLowerCase() !== challenge.email || user.disabled) {
      return res.status(403).send('Account email verification is required. Return to RoadAssist.');
    }
    const confirmed = await db.runTransaction(async tx => {
      const [current, profile] = await Promise.all([tx.get(ref), tx.get(db.doc(`users/${challenge.uid}`))]);
      const data=current.data(), p=profile.data();
      if (!canConfirmRole(data, p, user)) return false;
      tx.set(db.doc(`roleEmailVerifications/${data.uid}`), {
        [data.role]: {email:data.email, verifiedAt:FieldValue.serverTimestamp()},
      }, {merge:true});
      tx.update(ref,{used:true,usedAt:FieldValue.serverTimestamp()});
      return true;
    });
    return res.status(confirmed ? 200 : 400).send(confirmed
      ? 'Email confirmed. Return to RoadAssist and check verification to continue.'
      : 'This link has expired or was already used. Return to RoadAssist.');
  } catch (_) {
    return res.status(500).send('Unable to confirm email right now. Try again later.');
  }
}
