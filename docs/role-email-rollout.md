# Role email confirmation rollout

First account role uses Firebase email verification. Every newly added driver/provider role, including addition through sign-in, is added to a monotonic roleEmailRequired profile list. The primary verified role remains accessible. Existing primary roles remain available. Sign-in enrolls an existing secondary role for one-time confirmation if no pending marker exists; subsequent confirmed-role logins skip verification.

Only Admin SDK writes roleEmailVerifications. Confirmation requires a random single-use email token (SHA-256 stored privately), 30-minute expiry and explicit POST confirmation to avoid consuming links in mail scanners. Sending is rate limited to once per minute. Initial unverified Firebase identity must first complete native email verification; resend then confirms the additional role.

Deploy updated request-email-verification.mjs, new confirm-role-email.mjs, updated job-start-code.mjs, functions/role-email-policy.mjs and vercel.json to the existing Vercel owner project. Keep existing Firebase/Gmail environment variables. Optional ROLE_EMAIL_PUBLIC_ORIGIN must be the trusted HTTPS production origin. Deploy matching firestore.rules before releasing the updated client. No deployment performed by this change. Firebase Blaze is not required for these Vercel endpoints.

Manual checks: existing verified provider adds driver -> email page; existing provider still usable; new email link GET does not consume; POST verifies driver; wrong/expired/replayed token rejected; client cannot forge confirmations or remove roleEmailRequired; ordinary login to verified role skips email; fresh first-role email remains required. Physical-device and real SMTP checks are still pending.
