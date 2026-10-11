import { contactEmail } from '../functions/role-identity.mjs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import nodemailer from 'nodemailer';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { randomBytes, createHash } from 'node:crypto';

function requireEnvironment(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing server environment variable: ${name}`);
  return value;
}

function firebaseAuth() {
  if (getApps().length === 0) {
    initializeApp({
      credential: cert({
        projectId: requireEnvironment('FIREBASE_PROJECT_ID'),
        clientEmail: requireEnvironment('FIREBASE_CLIENT_EMAIL'),
        privateKey: requireEnvironment('FIREBASE_PRIVATE_KEY').replace(
          /\\n/g,
          '\n',
        ),
      }),
    });
  }
  return getAuth();
}

function setResponseHeaders(response) {
  response.setHeader('Content-Type', 'application/json');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader(
    'Access-Control-Allow-Headers',
    'Authorization, Content-Type',
  );
  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

export default async function handler(request, response) {
  setResponseHeaders(response);
  if (request.method === 'OPTIONS') return response.status(204).end();
  if (request.method !== 'POST') {
    return response.status(405).json({ ok: false, message: 'Method not allowed.' });
  }

  const authorization = request.headers.authorization || '';
  const idToken = authorization.startsWith('Bearer ')
    ? authorization.substring(7)
    : '';
  if (!idToken) {
    return response.status(401).json({
      ok: false,
      message: 'Authentication is required.',
    });
  }

  try {
    const auth = firebaseAuth();
    const decoded = await auth.verifyIdToken(idToken, true);
    const user = await auth.getUser(decoded.uid);
    if (!user.email) {
      return response.status(400).json({
        ok: false,
        message: 'This account does not have an email address.',
      });
    }
    const role = request.body?.role;
    if (role != null && !['driver', 'provider'].includes(role)) {
      return response.status(400).json({ok:false, message:'Invalid account role.'});
    }
    const db = getFirestore();
    const profile = (await db.doc(`users/${user.uid}`).get()).data();
    if (!profile) return response.status(403).json({ok:false,message:'Account profile unavailable.'});
    if (profile.authIdentity === 'role-v1') {
      if (role && role !== profile.role) return response.status(403).json({ok:false,message:'Sign in to this role first.'});
      contactEmail(user, profile); // Validate server-owned recipient mapping.
      if (!user.emailVerified) {
        const limiter = db.doc(`roleEmailSendLimits/${user.uid}_native`);
        const allowed = await db.runTransaction(async tx => {
          const last = await tx.get(limiter);
          if (Date.now() - (last.data()?.issuedAtMs ?? 0) < 60000) return false;
          tx.set(limiter, {issuedAtMs:Date.now()});
          return true;
        });
        if (!allowed) return response.status(429).json({ok:false,message:'Wait one minute before requesting another email.'});
      }
    }
    const roleRequired = role && (profile.roleEmailRequired ?? []).includes(role);
    if (roleRequired && ![profile.role, ...(profile.roles ?? [])].includes(role)) {
      return response.status(403).json({ok:false,message:'Register this role first.'});
    }
    if (user.emailVerified && !roleRequired) return response.status(200).json({ ok: true });
    // First verify the Firebase identity, then independently confirm a new role.
    let verificationLink;
    if (!user.emailVerified) {
      verificationLink = await auth.generateEmailVerificationLink(user.email);
    } else {
      const token = randomBytes(32).toString('hex');
      const digest = createHash('sha256').update(token).digest('hex');
      const limiter = db.doc(`roleEmailSendLimits/${user.uid}_${role}`);
      const issued = await db.runTransaction(async tx => {
        const last = await tx.get(limiter);
        if (Date.now() - (last.data()?.issuedAtMs ?? 0) < 60000) return false;
        tx.set(limiter, {issuedAtMs:Date.now()});
        tx.set(db.doc(`roleEmailChallenges/${digest}`), {
          uid:user.uid, role, email:user.email.toLowerCase(),
          expiresAtMs:Date.now()+30*60*1000, used:false,
          createdAt:FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!issued) return response.status(429).json({ok:false,message:'Wait one minute before requesting another email.'});
      const origin = process.env.ROLE_EMAIL_PUBLIC_ORIGIN || 'https://vehiclebreakdownapp.vercel.app';
      verificationLink = `${origin}/api/confirm-role-email?token=${token}`;
    }
    const gmailUser = requireEnvironment('GMAIL_USER');
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: requireEnvironment('GMAIL_APP_PASSWORD').replace(/\s/g, ''),
      },
    });
    const displayName = user.displayName?.trim() || 'RoadAssist user';
    const delivery = await transporter.sendMail({
      from: `RoadAssist <${gmailUser}>`,
      to: contactEmail(user, profile),
      subject: `Verify your RoadAssist ${profile.authIdentity === 'role-v1' ? profile.role + ' ' : ''}email`,
      text: `Hello ${displayName},\n\nVerify your RoadAssist email using this secure link:\n${verificationLink}\n\nIf you did not create this account, ignore this email.`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#18324a">
          <h2>Verify your RoadAssist email</h2>
          <p>Hello ${displayName},</p>
          <p>Confirm your email address to finish securing your RoadAssist account.</p>
          <p style="margin:28px 0">
            <a href="${verificationLink}" style="background:#4a90cf;color:#fff;padding:13px 22px;border-radius:8px;text-decoration:none;font-weight:700">Verify email</a>
          </p>
          <p style="font-size:13px;color:#60758a">If you did not create this account, ignore this email.</p>
        </div>`,
    });
    console.info('Verification email accepted by SMTP');
    if (!delivery.accepted?.length) {
      throw new Error('SMTP did not accept the verification recipient.');
    }
    return response.status(200).json({ ok: true });
  } catch (error) {
    console.error('Email verification request failed', error);
    const unauthorized =
      error?.code === 'auth/id-token-expired' ||
      error?.code === 'auth/argument-error';
    return response.status(unauthorized ? 401 : 500).json({
      ok: false,
      message: unauthorized
        ? 'Your session expired. Sign in again.'
        : 'Verification email service is temporarily unavailable.',
    });
  }
}
