# Google login for separate role profiles

Implemented for Flutter web. Select Driver or Provider before continuing with Google. Existing matching role profile is reused; no role profile/password is overwritten. New role registration requires name and Sri Lankan mobile number; a driver also requires the existing photo upload. Google proof must be a current, non-revoked, Google-provider Firebase ID token with verified email. The backend derives contact email from proof, never request input. It issues a custom session for the selected role UID. Provider documents/admin review remain required.

A secondary Firebase app isolates the Google proof session. Its Firebase Google identity may exist without a RoadAssist profile; this is a proof identity, not an enrolled role. It is signed out after the exchange. New role identities have no password until a role-aware password reset sets one. Google sessions use Firebase custom sign-in; email/password sessions still use native password sign-in.

## Remaining live configuration

Read-only project check on 2026-10-10: Google provider config returns 404 (not configured). Authorized domains currently: localhost, roadassist-lk-munshif.firebaseapp.com, roadassist-lk-munshif.web.app.

1. Firebase console > Authentication > Sign-in method > Google: enable and select project support email. Save to provision OAuth credentials.
2. Add actual frontend deployment domain under Authentication > Settings > Authorized domains. Backend-only domains need not be authorized unless serving the app.
3. Deploy api/google-role-auth.mjs with api/role-auth.mjs and functions/role-identity.mjs. Configure existing independent-auth and Firebase Admin environment. Google endpoint defaults to the existing Vercel API host; GOOGLE_ROLE_AUTH_API_URL can override the client URL.
4. Rebuild/deploy Flutter frontend. Test popup success/cancel, new role profile, existing role reuse, both roles, disabled accounts and provider approval gate.

No Google OAuth credentials were created or enabled during implementation. Google backend deployed to production on 2026-10-10: dpl_GBrUfxC19dDHCCs3KCMiLNKjKmiC, READY, aliased to https://vehiclebreakdownapp.vercel.app. Frontend web build succeeded locally; frontend hosting remains pending. Native Android/iOS Google sign-in needs google_sign_in plus platform OAuth setup; this release intentionally reports web-only support there.

Validation: six new endpoint tests plus eight existing role-auth tests pass. Tests cover separate verified roles, preserved matching profile/password, rejection of password/unverified proof, required registration details, moderation and disabled-identity overwrite prevention.

26 Flutter authentication/layout regressions passed; release web build succeeded. Focused analyzer reported no errors, seven existing info diagnostics. Real Google popup has not been tested because Google provider is not configured.

## Frontend deployment - 2026-10-10

Production deployment dpl_E1zb7xeAXRyYsZL255xDrYwNrjxE is READY at https://vehiclebreakdownapp.vercel.app. It contains the current build/web static artifact in public plus existing APIs. The staging vercel.json sets outputDirectory=public and filesystem-first SPA fallback excluding api paths. Preserve this combined deployment configuration on future releases; a backend-only stage would remove the frontend.

Firebase authorizedDomains now additionally includes vehiclebreakdownapp.vercel.app; all original domains were preserved. Google provider is still unconfigured (404, no OAuth client configured). Owner must enable Google and choose support email in Firebase Console. Real Google popup/end-to-end login has not been exercised.

Six public deployment checks passed: homepage HTML, Flutter bootstrap, main JS, SPA deep link, Google endpoint no-auth rejection and existing role-auth method guard.
