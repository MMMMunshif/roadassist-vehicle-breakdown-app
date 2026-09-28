import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import nodemailer from 'nodemailer';

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
    const decoded = await auth.verifyIdToken(idToken);
    const user = await auth.getUser(decoded.uid);
    if (!user.email) {
      return response.status(400).json({
        ok: false,
        message: 'This account does not have an email address.',
      });
    }
    if (user.emailVerified) return response.status(200).json({ ok: true });

    const verificationLink = await auth.generateEmailVerificationLink(
      user.email,
    );
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
      to: user.email,
      subject: 'Verify your RoadAssist email',
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
    console.info('Verification email accepted by SMTP', {
      accepted: delivery.accepted,
      rejected: delivery.rejected,
      messageId: delivery.messageId,
    });
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
