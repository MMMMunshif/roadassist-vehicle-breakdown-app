# Provider verification and admin operations

## Provider journey

Create provider account → verify email → submit private application → waiting for review → corrections (if requested) → document approval → provider dashboard.

Required: legal name, Sri Lankan NIC number, address, business/independent-provider name, emergency phone, years of experience, services, supported vehicle types, NIC front/back, recent face photo, and qualification/business/experience evidence. Towing also requires recovery vehicle registration or authorization proof, declared safe capacity, and recovery truck equipment. Registered businesses require a registration number and registration document. Professional details include service contact phone, work history, qualifications/practical training, training workplace/institute and year, specializations, coverage areas/radius, working days/hours or 24-hour service, languages, equipment and optional insurance/permit details. These claims are manually reviewed; declarations alone do not establish qualifications. The provider confirms ownership and authorizes private review.

Applications are locked after submission. An admin requests corrections with a public reason before the provider can replace the application. A new revision invalidates the prior approval. Rejection suspends access; support must review an appeal before restoration. Existing providers need documents too: legacy profile-only verification no longer authorizes jobs.

An authorized reviewer sees documents, completes identity/face/capability/contact checks, chooses approval expiry (maximum 366 days), and records a reason. Choose the earliest applicable document expiry; this is manual review, not government identity validation or a guarantee of service quality. Do not approve unreadable documents. If an account is suspended, document approval alone does not restore it; review the suspension and explicitly restore access when appropriate.

Firestore rules enforce approval, current revision, expiry, and email verification before provider business operations. A bypassed Flutter screen does not grant access. Public directory verification/expiry/services/vehicle types must match the protected approval/application. Drivers see only current verified providers. The provider remains offline until they choose to go online.

**Active jobs:** requesting corrections, rejection, suspension, or expiry can remove provider business access, including ongoing jobs. Check active jobs and contact both participants before changing access. This release does not automatically reassign jobs or settle disputes/refunds.

## Document storage and privacy

No Firebase Storage or Blaze upgrade is required by this implementation. Compressed JPG photos are kept in a separate private `providerApplications/{uid}` Firestore document, never in user profiles, public directory, chat, CSV or email. Up to six photos at <=160,000 base64 characters plus bounded metadata stay below Firestore's 1 MiB limit. Inputs above 8 MB are rejected. JPG/PNG photos are supported; PDF uploads are not implemented. Providers preview the compressed image and reviewers must check readability.

Only the owner and reviewer/super-admin roles can read applications. Support cannot read NIC documents. The provider cannot set an approval field or rewrite a locked application. Fields containing documents, NIC and address are excluded from indexes in `firestore.indexes.json`.

The SDK/project administrators still have their normal trusted database access. No document encryption beyond Firebase transport/storage controls, automated background check, duplicate-NIC registry, liveness test, automatic retention cleanup, or identity-document deletion workflow is implemented. Set an operational retention/deletion policy before collecting real identity documents; account deletion currently does not purge these protected records. Test with dummy documents, and keep real identity evidence out of screenshots, exports, and free-text audit notes. Cached browser/device copies are not remotely erased by permission revocation.

## Administrative roles

Owner-controlled provisioning supports:

```powershell
node functions/provision-admin.mjs staff@example.com grant super_admin
node functions/provision-admin.mjs reviewer@example.com grant reviewer
node functions/provision-admin.mjs support@example.com grant support
node functions/provision-admin.mjs staff@example.com revoke
```

The existing account must verify its email. Custom claims plus the protected enabled registry are still required; public signup has no admin option. Legacy enabled admin registries without a role remain super-admin for backward compatibility. Provisioning requires trusted credentials; do not put credentials in Flutter or share them in chat.

- Super admin: all current administrative panels, provider/driver moderation and audited settings.
- Reviewer: private provider documents, provider moderation/verification, monitoring and audit reads; cannot suspend drivers, decide complaints or change settings.
- Support: user/job/invoice/dispute monitoring and audited complaint decisions; cannot read NIC documents, approve providers or change app settings.

Admin roles restrict sensitive reads and writes. General profile/job/audit monitoring is shared with all admins. Team UI is read-only; owner provisioning controls grants/revocation.

## Additional panels

- Operations: waiting requests (15+ minutes), active jobs with no recorded update (60+ minutes), overdue complaint follow-ups; clock refreshes each minute while open. Job details show provider presence and dialer actions for recorded participant phone numbers. Alerts are review prompts, not misconduct findings.
- Payments: completed invoices separated into provider-confirmed receipt, driver-reported only, and unreported payments. Admin cannot fabricate receipt confirmation, alter approved prices, or refund cash.
- Reports: completed/cancelled metrics, service counts, confirmed invoice value, and CSV of loaded jobs. CSV excludes identity documents and user email/phone; spreadsheet formula prefixes are escaped. Counts cover loaded recent records only, with load-more controls, not lifetime totals or platform profit.
- Complaints: assign to yourself, set priority/deadline, view evidence and invoice approval history, resolve/dismiss/reopen with an immutable audit reason. Overdue reviews appear in Operations. Participant complaint status remains separate from the admin decision.
- Settings: maintenance pauses NEW assistance requests, enabled services constrain new requests, and a public notice/coverage description appears on driver home. Existing jobs, chats and invoices are not paused by maintenance. Coverage description is informational; no geofence is enforced. Settings require super admin and a matching audit transaction.

## Approval email setup (no Cloud Functions deployment)

`api/provider-approval-email.mjs` uses the existing Vercel/Gmail server architecture. It checks the caller's verified custom claim, enabled admin registry, reviewer/super-admin role and suspension status, then loads the approved provider's email from Firebase Authentication. The client cannot supply an arbitrary recipient. Approval must match the latest document revision and unexpired moderation record. Emails contain an approval notice and expiry only, never NIC or document data.

1. The existing Vercel project owner redeploys this repository including the new endpoint.
2. Reuse the existing server-only variables: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `GMAIL_USER`, `GMAIL_APP_PASSWORD`. Never set these as Flutter dart defines or public environment variables.
3. Configure the admin build with your own deployed HTTPS endpoint:

```powershell
flutter run -d chrome --web-port=6100 --dart-define=ADMIN_PORTAL=true --dart-define=PROVIDER_APPROVAL_EMAIL_API_URL=https://vehiclebreakdownapp.vercel.app/api/provider-approval-email
```

The approval-email integration defaults to disabled until an endpoint is configured. Approval is saved before mail is attempted, so mail failure does not undo approval. A retry action is available. Server delivery receipts prevent routine repeat sends for the same audit approval. SMTP acceptance is not proof of inbox delivery; after a crash between SMTP acceptance and recording success, a retry can duplicate an email. No guaranteed background retry or email provider delivery webhook is implemented. Rejection/correction reasons are live in-app, not emailed automatically.

## Deploy and check

After local tests pass, publish rules and index exclusions to the existing Firebase project:

```powershell
.\tools\rules-tests\node_modules\.bin\firebase.cmd deploy --only firestore:rules,firestore:indexes --project roadassist-lk-munshif
```

Rebuild/restart admin and normal app. Test a new provider with dummy identity photos: before approval, jobs and online publishing are denied; request corrections and resubmit; approve; confirm the dashboard unlocks; go online and check driver listing; test an approval-email failure/retry; check support-role document denial, payment monitoring and maintenance. Test admin actions against an active job deliberately with both test participants informed.

Sources: [Firestore document limits](https://firebase.google.com/docs/firestore/quotas), [Firebase Storage billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).


Existing older applications without professional details can submit one upgraded revision without waiting for a correction request. They cannot provide service until that revision is reviewed and approved. Driver profile photos are required only during new-account creation; ordinary login/session restoration does not ask for or require an upload.

## Admin user controls and deletion
Account review includes related driver/provider jobs, payment confirmation, complaint review links, and account audit history. Job and audit lists show up to 50 records; these are not complete-history exports.

Suspension/restoration/flagging require reasons and are recorded in audit history. Suspension blocks database access rather than Firebase Authentication login.

Permanent deletion is main-admin only, blocks self-deletion and enabled admin accounts, and requires a recent sign-in (10 minutes), a reason and exact UID confirmation. The trusted API first suspends the target and checks every related job. Active work, unconfirmed completed-job payments and unresolved disputes block deletion; the account stays suspended for admin review. A blocked account may be restored if appropriate.

The API disables Authentication, revokes sessions, removes profile subcollections (vehicles/device tokens), private provider applications and directory records, then deletes Authentication. Requests, invoices, complaint evidence and audit history are retained for the other participant. This is account removal, not erasure of all historical personal data. Failures remain blocked and can be retried using the same UID; inspect adminAudit/deletion_UID.

Deploy api/admin-delete-account.mjs with functions/account-deletion-policy.mjs on the existing trusted Vercel backend using its Firebase service credentials. Build Flutter with --dart-define=ADMIN_ACCOUNT_DELETE_API_URL=https://YOUR-HOST/api/admin-delete-account. No Blaze upgrade is needed for this external backend. Until configured, the UI reports that deletion is unavailable. Never put service credentials in Flutter. No accounts are deleted during development or tests.
## Simplified registration
Registration now asks only for legal name, NIC, address, years of experience, service phone, service radius, services and supported vehicles, identity photos and one service/experience proof. A brief experience description and emergency phone are optional. Business name, registration number and business proof appear only for registered businesses; recovery vehicle registration, capacity and proof appear only for towing. Training institute, training year, specializations, working schedule, languages, tools and insurance are no longer registration questions. Previously submitted optional details remain available to reviewers; new applications do not fabricate these details.
Working hours and spoken languages have been restored to the simplified form. Providers can choose 24-hour availability or enter start/end times (overnight hours supported), and select English, Sinhala and/or Tamil. Other extra professional questions remain removed. Live simplified-rule deployment is still pending approval.

## Provider cancellation recovery
Assigned providers may withdraw before arrival, with a recorded reason. Drivers may release an accepted provider who has not departed after 10 minutes. Both writes atomically release the provider reservation and preserve the cancelled job and quote. Driver tracking updates live and offers a new request review with no preferred provider; a new request ID prevents old quotes from carrying over. Existing 90-second unresponsive preferred-provider fallback remains. Cancellation reasons and actors are retained on requests for admin review. After-arrival cancellations and compensation need manual support; no automatic refund or reassignment is implied. Notifications require an open app; background email/push remains separately configured.
