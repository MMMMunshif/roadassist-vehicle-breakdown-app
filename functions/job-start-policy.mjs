import {createHash, randomBytes, randomInt, timingSafeEqual} from 'node:crypto';
export const CODE_TTL_MS = 10 * 60 * 1000;
export const MAX_ATTEMPTS = 5;
export function codeDigest(code, salt) { return createHash('sha256').update(`${salt}:${code}`).digest('hex'); }
export function newChallenge(now = Date.now()) {
  const code = String(randomInt(0, 1000000)).padStart(6, '0');
  const salt = randomBytes(24).toString('hex');
  return {code, record: {salt, digest: codeDigest(code, salt), issuedAtMs: now, expiresAtMs: now + CODE_TTL_MS, attempts: 0}};
}
export function checkCode(record, code, now = Date.now()) {
  if (!record || record.usedAtMs) return 'unavailable';
  if (record.expiresAtMs <= now) return 'expired';
  if (record.attempts >= MAX_ATTEMPTS) return 'locked';
  if (typeof code !== 'string' || !/^\d{6}$/.test(code)) return 'invalid';
  const expected = Buffer.from(record.digest, 'hex');
  const actual = Buffer.from(codeDigest(code, record.salt), 'hex');
  return expected.length === actual.length && timingSafeEqual(expected, actual) ? 'verified' : 'incorrect';
}
export function validateParticipant(job, actor, action) {
  if (!actor?.uid || !actor.email_verified) return 'Verified sign-in required.';
  if (!job || job.status !== 'arrived' || job.arrivalConfirmedBy || !job.providerId || job.providerId === job.driverId) return 'Job start is not available.';
  if (action === 'issue' && actor.uid !== job.driverId) return 'Only the driver can generate this code.';
  if (action === 'verify' && actor.uid !== job.providerId) return 'Only the assigned provider can verify this code.';
  if (!['issue','verify'].includes(action)) return 'Unsupported action.';
  return null;
}
