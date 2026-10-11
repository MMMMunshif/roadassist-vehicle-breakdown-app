import { createHash } from 'node:crypto';

export function roleAddress(email, role) {
  if (!['driver', 'provider'].includes(role)) throw new Error('Invalid role');
  const normalized = String(email).trim().toLowerCase();
  if (normalized.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(normalized)) throw new Error('Invalid email');
  const digest = createHash('sha256').update(`${role}\0${normalized}`).digest('hex').slice(0, 48);
  return `${digest}.${role}@roles.roadassist.invalid`;
}

export async function resolveRoleUser(auth, db, email, role) {
  const internal = roleAddress(email, role);
  let user;
  try { user = await auth.getUserByEmail(internal); }
  catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
  if (user) {
    const profile = (await db.doc(`users/${user.uid}`).get()).data();
    // An orphan or disabled identity must never fall back to another account.
    if (!profile || profile.authIdentity !== 'role-v1' || profile.role !== role ||
        profile.email !== String(email).trim().toLowerCase() || user.disabled) return null;
    return {user, profile};
  }
  try { user = await auth.getUserByEmail(String(email).trim().toLowerCase()); }
  catch (e) { if (e.code === 'auth/user-not-found') return null; throw e; }
  const profile = (await db.doc(`users/${user.uid}`).get()).data();
  // Keep the original primary account and UID; never enroll a second role.
  if (!profile || profile.role !== role || user.disabled) return null;
  return {user, profile};
}

export function contactEmail(user, profile) {
  if (profile?.authIdentity !== 'role-v1') return user.email;
  const email = profile.email;
  if (roleAddress(email, profile.role) !== user.email) throw new Error('Identity mismatch');
  return email;
}
