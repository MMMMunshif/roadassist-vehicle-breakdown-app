# Workflow rollout

Deploy the matching security rules before using cancellation reasons and complaint review history. Deploy api/job-start-code.mjs to the existing Vercel project with the existing FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY server environment. Never put service credentials in Flutter.

Deploy Firebase functions notifyRequestUpdates and notifyComplaintReview for completion, discount, job-start and support updates. Then build the normal app with --dart-define=JOB_START_CODE_ENABLED=true. An alternative HTTPS endpoint can be supplied with --dart-define=JOB_START_CODE_API_URL=... .

The job start feature defaults off until the endpoint and rules are deployed. Existing requests keep their original driver arrival confirmation. Both participants see the code flow on code-required jobs regardless of the build flag. Only the driver can generate a code, only the assigned currently approved provider can verify, and verification is atomic and single-use. Codes expire after ten minutes; five wrong attempts lock a code, and regeneration is limited to once per minute. The server stores salted digests in private jobStartChallenges records. Raw codes are returned only to the driver and are not logged or stored in shared request documents.

Manual two-device checks: new code-required request, provider arrival, driver generate code, wrong code, correct code, repeat use, expiry, stranger account, completed/cancelled job; final bill approval, discount, completion, invoice, immutable rating, cancellation reason, support decision/history and notification tap. Check denied GPS, stale location, offline, reconnect, foreground/resume. Location heartbeat uses fresh GPS only while the active-job screen is foregrounded. Continuous operating-system background tracking is not included.

History starts with new support decisions; historical decisions are not fabricated. The latest existing public support decision remains visible.

Production status (2026-10-09): explicit production approval received. Firestore rules successfully released to roadassist-lk-munshif as ruleset b67ef2c8-fff4-4e35-9976-7a366b1e9ebe. Notification function deployment failed because Firebase requires the Blaze plan to enable artifactregistry.googleapis.com; billing was not changed. OTP API deployment is pending Vercel access verification. Keep JOB_START_CODE_ENABLED off until API deployment and two-device checks are complete.

Upgrade both driver and provider app installations before enabling code-required new requests. Older apps cannot confirm arrival on code-required jobs.
