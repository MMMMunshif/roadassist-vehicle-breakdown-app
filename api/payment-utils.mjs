import {createHash, randomBytes} from 'node:crypto';

export function md5(value) {
  return createHash('md5').update(value).digest('hex').toUpperCase();
}

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

export function amount(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) throw new Error('Invalid payment amount.');
  return parsed.toFixed(2);
}

export function newToken() {
  return randomBytes(32).toString('hex');
}

export function publicBase(req) {
  const configured = process.env.PAYMENT_PUBLIC_BASE_URL?.replace(/\/$/, '');
  if (configured) return configured;
  const host = req.headers['x-forwarded-host'] ?? req.headers.host;
  const proto = req.headers['x-forwarded-proto'] ?? 'https';
  if (!host) throw new Error('Set PAYMENT_PUBLIC_BASE_URL for payment callbacks.');
  return `${proto}://${host}`;
}

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
}

export async function admin() {
  const [{cert, getApps, initializeApp}, {getAuth}, {getFirestore, FieldValue}] = await Promise.all([
    import('firebase-admin/app'), import('firebase-admin/auth'), import('firebase-admin/firestore'),
  ]);
  if (!getApps().length) initializeApp({credential: cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  })});
  return {auth: getAuth(), db: getFirestore(), FieldValue};
}
