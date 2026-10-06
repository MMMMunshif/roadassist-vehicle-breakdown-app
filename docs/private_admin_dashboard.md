# Private admin portal

Requested admin: zimthimuhammed@gmail.com. This is NOT an email allowlist in the app. Admin authorization requires all three: verified Firebase email, admin=true in the signed ID token, and a protected adminAccess/{uid} record with enabled=true. Existing driver/provider roles are preserved.

## Owner provisioning for new admin accounts

The existing admin reported successful access after owner provisioning. For additional admin accounts, use trusted owner credentials. Firebase CLI login is not automatically an Admin SDK credential. Never share passwords or private keys.

The project owner should use a trusted computer or Google Cloud Shell with Application Default Credentials for roadassist-lk-munshif and permission to manage Firebase Authentication plus Firestore. On a trusted local machine, Google Cloud CLI's `gcloud auth application-default login` can supply ADC; select the owner's authorized account. Do not upload credential JSON files to chat or commit them.

From the project root, after installing the functions package dependencies, run:

```powershell
Push-Location functions
npm.cmd install
Pop-Location
node functions/provision-admin.mjs zimthimuhammed@gmail.com grant
```

The script looks up the existing account and requires it to have verified email and not be disabled. It preserves other custom claims and profile roles, writes the protected admin registry and a provisioning record. This is a local Admin SDK script, not a deployed Cloud Function. No Blaze upgrade is involved. Sign out and sign back in after granting permission.

Revoke with `node functions/provision-admin.mjs zimthimuhammed@gmail.com revoke`. The protected registry disables database admin operations immediately; the script also removes the claim and revokes refresh tokens. Existing cached data/export files are not erased by revocation.

## Launch

```powershell
flutter run -d chrome --web-port=6100 --dart-define=ADMIN_PORTAL=true
```

Normal builds retain driver/provider signup only. Admin builds display a separate verified-account sign-in without registration. Knowing the portal URL or inspecting its source does not grant access. Admin pages are responsive up to 1200 px. Use a separate browser profile for admin work.

## Features and operational policy

- Overview: live counts from at most 100 documents per card, explicitly labelled as loaded counts, not whole-project analytics.
- Users/providers: 50 records initially, Load 50 more, search within loaded records, pending provider filter, manual verify/reject, app-access suspension/restore, suspicious-account flags, reasons, and private append-only notes.
- Verification currently reviews the existing profile/photo/services; provider qualification document uploads are not implemented. Pending legacy providers remain operational. Rejection suspends access and clears online directory status; verification does not automatically undo an existing suspension. Use Restore separately after reviewing why the account was suspended.
- Complaints: collection-group inbox, driver-report unresolved filter, evidence/replies and invoice/approval links, priority, assign to current admin, public next steps/resolution/dismissal. Original participant reports are immutable to admins. Administrative decisions are stored separately and visible to the assigned participants; the driver's own resolution status remains separate. No refunds, payment edits or automatic reassignment occur.
- Jobs: live read-only records with active-only filter and last update time. A 60-minute stale-update hint is a review prompt, not proof of misconduct. Admin cannot impersonate providers or update job status.
- Audit: admin moderation and complaint decisions atomically write immutable actor/timestamp/reason/before/after records. Rules reject unaudited writes, fabricated actors and rewritten evidence. Private notes are append-only authored records visible only to admins, distinct from public complaint decisions.
- Suspension: denies normal app database business operations and shows a support-review message. It does not disable the Firebase Auth account; historical database access is also blocked. Review active jobs before suspending anyone. Owner tooling is required for actual Firebase Auth disable/delete.
- Admins cannot suspend/reject themselves through the dashboard. Admin privileges are provisioned/revoked only by trusted tooling; public clients cannot edit the registry or assign custom claims.

Admin access permits user profile, job, quote, repair evidence, dispute and audit reads. It does not grant arbitrary chat-message/device-token writes or blanket database access. A user's profile admin field has no effect on authorization. Security rules apply regardless of which app build is used.

Firestore reads are subject to Spark quotas. Load-more searches are not a full-text service. Private notes are capped at 50 loaded per target; use a future paginated archive if case histories grow. Provider identity submission, reviewer checklist, role separation and operational panels are now implemented. See [provider verification and operations](provider_verification_and_admin_operations.md) for deployment, email configuration and limits. Multi-admin approval and an identity retention/deletion workflow remain follow-up work.

References: https://firebase.google.com/docs/auth/admin/custom-claims and https://cloud.google.com/docs/authentication/application-default-credentials

## Provider document verification update

Profile-only provider approval has been replaced by private document submission, a reviewer checklist, revision binding and expiring approvals. Existing providers need to submit documents too. Operations, Payments, Reports, Settings and Admin team panels are available. See [updated setup and workflow](provider_verification_and_admin_operations.md).
