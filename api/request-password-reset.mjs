import { createHash } from 'node:crypto';
import { getFirestore } from 'firebase-admin/firestore';
import { resolveRoleUser } from '../functions/role-identity.mjs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import nodemailer from 'nodemailer';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

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

async function isRateLimited(request, db) {
  const forwarded = request.headers['x-forwarded-for'];
  const address = String(Array.isArray(forwarded) ? forwarded[0] : forwarded || request.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  const key = createHash('sha256').update(`reset:${address}`).digest('hex');
  const ref = db.doc(`roleAuthLimits/${key}`);
  return db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const now = Date.now();
    const data = snapshot.data();
    const count = now - (data?.start ?? 0) < 900000 ? data.count : 0;
    if (count >= 5) return true;
    tx.set(ref, {count:count+1, start:count ? data.start : now});
    return false;
  });
}

function setResponseHeaders(response) {
  response.setHeader('Content-Type', 'application/json');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

export default async function handler(request, response) {
  setResponseHeaders(response);

  if (request.method === 'OPTIONS') return response.status(204).end();
  if (request.method !== 'POST') {
    return response.status(405).json({ ok: false, message: 'Method not allowed.' });
  }

  const email = String(request.body?.email || '').trim().toLowerCase();
  // Honeypot used by the Flutter client. Bots commonly fill hidden fields.
  if (request.body?.website) return response.status(200).json({ ok: true });
  if (!emailPattern.test(email)) {
    return response.status(400).json({
      ok: false,
      message: 'Enter a valid email address.',
    });
  }

  try {
    const auth = firebaseAuth();
    if (await isRateLimited(request, getFirestore())) {
      return response.status(429).json({ok:false,message:'Too many attempts. Wait 15 minutes and try again.'});
    }
    let user;
    try {
      const role = request.body?.role;
      if (role != null && !['driver','provider'].includes(role)) {
        return response.status(400).json({ok:false, message:'Select driver or provider.'});
      }
      if (role) {
        const account = await resolveRoleUser(auth, getFirestore(), email, role);
        if (!account) return response.status(200).json({ok:true});
        user = account.user;
      } else {
        user = await auth.getUserByEmail(email);
      }
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        // Keep the response generic to prevent account enumeration.
        return response.status(200).json({ ok: true });
      }
      throw error;
    }

    const resetLink = await auth.generatePasswordResetLink(user.email);
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
      to: email,
      subject: `Reset your RoadAssist ${request.body?.role ?? 'account'} password`,
      text: `Hello ${displayName},\n\nUse this secure link to reset your RoadAssist password:\n${resetLink}\n\nIf you did not request this, you can ignore this email.`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#18324a">
          <h2>Reset your RoadAssist password</h2>
          <p>Hello ${displayName},</p>
          <p>Use the button below to choose a new password. This link is intended only for you.</p>
          <p style="margin:28px 0">
            <a href="${resetLink}" style="background:#4a90cf;color:#fff;padding:13px 22px;border-radius:8px;text-decoration:none;font-weight:700">Reset password</a>
          </p>
          <p style="font-size:13px;color:#60758a">If you did not request this change, ignore this email.</p>
        </div>`,
    });
    console.info('Password reset email accepted by SMTP', {
      accepted: delivery.accepted,
      rejected: delivery.rejected,
      messageId: delivery.messageId,
    });
    if (!delivery.accepted?.length) {
      throw new Error('SMTP did not accept the password reset recipient.');
    }

    return response.status(200).json({ ok: true });
  } catch (error) {
    console.error('Password reset request failed', error);
    return response.status(500).json({
      ok: false,
      message: 'Password reset service is temporarily unavailable.',
    });
  }
}
