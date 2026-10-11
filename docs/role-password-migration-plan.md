# Independent driver/provider accounts

Status: production auth backend enabled and deployed with explicit user approval on 2026-10-10. Matching Firestore rules are live. The client defaults to independent role authentication; INDEPENDENT_ROLE_AUTH=false is available for an explicit legacy/rollback build.

## Confirmed behavior

The same contact email can register separate driver/provider accounts, each with its own native Firebase password, UID, profile and history. Each new identity starts unverified. Driver verification opens the dashboard. Provider verification retains document submission and administrator review. Password reset inherits the role of its login page; account settings uses the signed-in profile's primary role.

`api/role-auth.mjs` registers or authenticates one role. Firebase stores and verifies passwords; the application does not store password hashes. After role resolution, the client signs in with native Firebase email/password credentials. No custom sign-in tokens are minted, so native password-reset session behavior remains intact. A SHA-256-derived internal Firebase email identifies each email/role pair. `users/{uid}.email` contains the real contact email. Verification and reset actions belong to the internal identity and are mailed to the real contact address. Firebase's standard action page may display the internal identity; a branded action handler can replace that presentation later.

Client writes cannot add/change the server-owned identity marker or change an independent account's email/role enrollment. Suspended legacy identities cannot enroll a fresh role. Backend authentication uses durable Firestore limits. Native verification resend has a one-minute limit. Password reset IP throttling is also stored in private Firestore records across server instances.

## Existing accounts

The original primary Firebase identity and its UID/history remain unchanged. Independent login supports that primary role. Previously shared secondary-role records are not copied, deleted or relabeled. Registering the secondary role creates a fresh profile and history; existing secondary-role history stays attached to the legacy UID. This is a migration limitation, not a completed transfer of historical data. Existing clients and legacy sessions retain their old behavior until replaced; this change does not revoke all old shared sessions.

## Configuration and rollout

1. Deploy `api/role-auth.mjs`, updated reset/verification/approval APIs, `functions/role-identity.mjs`, existing policy modules and `vercel.json` together.
2. Keep Firebase service-account and Gmail settings. Add `FIREBASE_WEB_API_KEY` for the same Firebase project (public web API key). Set server `INDEPENDENT_ROLE_AUTH=true` only in the environment being tested.
3. Deploy matching `firestore.rules` before allowing independent registration. Old deployed rules do not protect the real contact email mapping.
4. Build the Flutter client with `--dart-define=INDEPENDENT_ROLE_AUTH=true`. Use `ROLE_AUTH_API_URL` to point to a staging API when testing. Verification/reset API URLs must also point to the corresponding environment.
5. Test real registration, both verification emails, provider approval, both password resets and deletion using dedicated test accounts. Confirm native Firebase session invalidation after reset. Then activate the coordinated release.
6. Rollback disables new enrollment and client use of the new flow; it does not merge new UIDs into old accounts. Keep the updated mail recipient mapping for identities already created.

No Firebase Blaze upgrade is required. No production accounts or histories were migrated during implementation.

## Validation performed

- 22 Node tests passed: endpoint handler, role identity mapping, crossed-password rejection, duplicate registration protection, native password independence using a test double, durable authentication limits, moderation and existing policies.
- 70 Firestore emulator tests passed, including contact-email/identity tampering and role-enrollment rejection.
- 23 auth entry/layout widget tests passed with independent role auth enabled (light/dark, narrow screens, enlarged text).
- 3 existing deleted-profile login regressions passed with the legacy path.
- Flutter analyzer completed with no errors; 216 warnings/info diagnostics remain across the existing codebase.
- Live driver verification email was delivered and the user opened the link. Native emailVerified became true; refreshing the session allowed the driver to query its own protected requests.
- Live driver-only reset email was delivered and the user reset the test password. The old driver password and old refresh token were both rejected afterward.
- The existing primary provider account was already verified and was not re-enrolled, reset, renamed or deleted.
- Initial isolated tests with two fresh role identities confirmed distinct UIDs, crossed-password rejection and unverified access denial. Those temporary profiles/auth identities were deleted after the user corrected the mailbox.
- Newly created temporary driver test identities are cleaned up after tests. Existing accounts/history are preserved. Real new-provider document submission/admin review and a provider password reset have not been exercised in this rollout; existing emulator coverage applies. These checks are not a claim of a full physical-device end-to-end test.

Sources: Firebase native password authentication https://firebase.google.com/docs/reference/rest/auth and custom email delivery of native action links https://firebase.google.com/docs/auth/admin/email-action-links .

## Deployment audit ? 2026-10-10

- Firestore release: `projects/roadassist-lk-munshif/rulesets/63ea82f1-400d-4f38-b6e4-4a6968defa3c`, released at 10:09:04 UTC.
- Vercel public web API key configured; global `INDEPENDENT_ROLE_AUTH=false` remains in production settings.
- Final protected test candidate: `dpl_3kskxc1ckPdnMCfmPykWWvZUQM5x`, https://vehiclebreakdown-1pp1ond2u-breakers-projects-d332ab9a.vercel.app . Its deployment-scoped flag is enabled only with the `ROLE_AUTH_TEST_EMAIL` mailbox restriction; other mailbox requests return 503.
- The `--skip-domain` candidate retains Vercel authentication protection. Vercel also assigns the protected project-system alias; the app domain https://vehiclebreakdownapp.vercel.app remains on the previous deployment, with `/api/role-auth` returning 404.
- The superseded wrong-mailbox candidate was removed. Its two temporary Auth users and profiles were deleted after identity/name/contact validation.
- Automatic approval review rejected production-wide activation before live checks. Work continued through restricted candidates; broad activation has not been retried or bypassed. Request explicit owner approval for the coordinated backend activation after reviewing these results and migration limitations.
- Temporary test credentials live only in ignored `build/role-auth-live/` files. Cleanup removes created account credentials from retained state; do not upload this directory.

## Approved production activation ? 2026-10-10

The user explicitly approved production-wide activation after reviewing the driver verification/reset/session checks and remaining provider/migration limitations.

- Vercel production deployment: `dpl_FnB1GceU1BkgDyVBh5KcqCZLw2wX`, READY.
- Live auth API base: https://vehiclebreakdownapp.vercel.app/api . This release deploys the backend; the Flutter web artifact is built locally in `build/web`.
- Project production `INDEPENDENT_ROLE_AUTH=true`; no designated-mailbox guard is configured on this release.
- 10 public production smoke checks passed: role-auth method/CORS/validation, unknown-account rejection for both roles, verification/approval/OTP authentication guards, reset/deletion method guards. An initial transport timeout cleared on retry.
- The client now defaults to the approved new flow. Existing legacy-path tests explicitly select legacy mode; 9 passed. Three new client tests confirm native driver/provider sign-in and duplicate-account rejection. 23 auth UI tests passed with the production default.
- Temporary test profiles/auth identities were removed; the original primary provider account and its history were preserved.
- The earlier automatic-review rejection applied before live checks and explicit approval. The subsequent activation used the user's explicit approval; no restriction was bypassed.
- Existing new-provider/admin workflow and provider password-reset live-test limitations above still apply. Production smoke checks are not a claim of full device/end-to-end coverage.
