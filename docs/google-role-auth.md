# Google login for separate role profiles

Implemented for Flutter web and Android. Select Driver or Provider before continuing with Google. Existing matching role profile is reused; no role profile/password is overwritten. New role registration requires name and Sri Lankan mobile number; a driver also requires the existing photo upload. Google proof must be a current, non-revoked, Google-provider Firebase ID token with verified email. The backend derives contact email from proof, never request input. It issues a custom session for the selected role UID. Provider documents/admin review remain required.

A secondary Firebase app isolates the Google proof session. Its Firebase Google identity may exist without a RoadAssist profile; this is a proof identity, not an enrolled role. It is signed out after the exchange. New role identities have no password until a role-aware password reset sets one. Google sessions use Firebase custom sign-in; email/password sessions still use native password sign-in.

## Remaining live configuration

Read-only project check on 2026-10-10: Google provider config returns 404 (not configured). Authorized domains currently: localhost, roadassist-lk-munshif.firebaseapp.com, roadassist-lk-munshif.web.app.

1. Firebase console > Authentication > Sign-in method > Google: enable and select project support email. Save to provision OAuth credentials.
2. Add actual frontend deployment domain under Authentication > Settings > Authorized domains. Backend-only domains need not be authorized unless serving the app.
3. Deploy api/google-role-auth.mjs with api/role-auth.mjs and functions/role-identity.mjs. Configure existing independent-auth and Firebase Admin environment. Google endpoint defaults to the existing Vercel API host; GOOGLE_ROLE_AUTH_API_URL can override the client URL.
4. Rebuild/deploy Flutter frontend. Test popup success/cancel, new role profile, existing role reuse, both roles, disabled accounts and provider approval gate.

No Google OAuth credentials were created or enabled during implementation. Google backend deployed to production on 2026-10-10: dpl_GBrUfxC19dDHCCs3KCMiLNKjKmiC, READY, aliased to https://vehiclebreakdownapp.vercel.app. Frontend web build succeeded locally; frontend hosting remains pending. Android Google sign-in now uses google_sign_in and registered signing fingerprints; iOS still requires platform OAuth setup.

Validation: six new endpoint tests plus eight existing role-auth tests pass. Tests cover separate verified roles, preserved matching profile/password, rejection of password/unverified proof, required registration details, moderation and disabled-identity overwrite prevention.

26 Flutter authentication/layout regressions passed; release web build succeeded. Focused analyzer reported no errors, seven existing info diagnostics. Real Google popup has not been tested because Google provider is not configured.

## Frontend deployment - 2026-10-10

Production deployment dpl_E1zb7xeAXRyYsZL255xDrYwNrjxE is READY at https://vehiclebreakdownapp.vercel.app. It contains the current build/web static artifact in public plus existing APIs. The staging vercel.json sets outputDirectory=public and filesystem-first SPA fallback excluding api paths. Preserve this combined deployment configuration on future releases; a backend-only stage would remove the frontend.

Firebase authorizedDomains now additionally includes vehiclebreakdownapp.vercel.app; all original domains were preserved. Google provider is still unconfigured (404, no OAuth client configured). Owner must enable Google and choose support email in Firebase Console. Real Google popup/end-to-end login has not been exercised.

Six public deployment checks passed: homepage HTML, Flutter bootstrap, main JS, SPA deep link, Google endpoint no-auth rejection and existing role-auth method guard.

## Android APK support - 2026-10-10

Added google_sign_in 7.2.0. Android obtains a Google ID token with the native plugin and signs the isolated proof Firebase app in with GoogleAuthProvider.credential before using the same role-aware backend. Web continues to use Firebase popup sign-in.

Refreshed genuine Firebase Android configs for com.roadassist.app and com.roadassist.admin. Registered this machine's existing debug signing certificate SHA1 and SHA256 for both Firebase apps. Current release APKs use that existing debug signing key for local phone installation. Native login has not been tested on a physical phone.

Button uses the official multicolour Google G PNG downloaded from https://developers.google.com/identity/images/g-logo.png. Email button appears first, followed by an or divider and full-width light/charcoal Google button. RoadAssist branding/background unchanged. 26 authentication/layout regression tests passed after these changes.

Android release-mode local-install APKs built successfully: build/install/RoadAssist.apk (com.roadassist.app, 163180292 bytes) and build/install/RoadAssist-Admin.apk (com.roadassist.admin, 165330944 bytes). Both signatures verified, Android min SDK24. Admin build includes production approval-email and account-delete API URLs. Background Java/Gradle imports caused initial cache-lock timeout; after user-approved pause both builds completed. Import hosts resumed and temporary workspace settings removed afterward.
