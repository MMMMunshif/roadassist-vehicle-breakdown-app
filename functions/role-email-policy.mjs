export function canConfirmRole(data, profile, user, now = Date.now()) {
  return !!data && !!profile && !!user && !data.used &&
    Number.isFinite(data.expiresAtMs) && data.expiresAtMs > now &&
    ['driver','provider'].includes(data.role) && user.uid === data.uid &&
    user.emailVerified === true && !user.disabled &&
    user.email?.toLowerCase() === data.email &&
    (profile.roleEmailRequired ?? []).includes(data.role) &&
    [profile.role, ...(profile.roles ?? [])].includes(data.role);
}
