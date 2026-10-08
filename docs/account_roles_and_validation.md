# Shared driver/provider account

An email address identifies one Firebase Auth user. The same existing password is required to add or use the other role; a second UID is never created. Registering the same role again still reports an existing account.

`role` retains the original primary role for backward compatibility. `roles` stores driver/provider memberships, and `lastRole` restores the last selected dashboard on startup. Existing profiles without these fields remain readable and are upgraded on login. Registering the second role preserves the existing name, phone and email. Documents, jobs and vehicles remain under the same UID.

Email verification is required for driver service access and provider application submission. Provider work additionally requires current document approval. A dual-role account cannot quote its own request. Admin provider lists and user filters include memberships rather than only the original role. Account suspension/rejection continues to apply to the shared account.

Profile creation validates name, phone, email, memberships and timestamps. Updates validate changed profile fields so unrelated updates to legacy profiles remain possible. Owner updates cannot change the primary role, remove an enrolled role, or enroll administrative roles.

The quote dialog now disposes controllers after its DialogRoute is fully removed. The invoice test that previously failed following dialog teardown now passes without an invoice UI change.

Validation: 31 selected Flutter tests passed; 55 Firestore emulator tests passed. Live signed-in phone flows have not been tested.

Firestore rules were deployed to roadassist-lk-munshif on 2026-10-08 after user approval. Active ruleset: 65d4bbc8-5729-4b1e-b45b-67246222037a. Install newly built normal/Admin APKs to use the client changes. The provider approval email API also uses membership checks and requires its usual separate backend deployment to enable approval emails for driver-first dual-role accounts. No email endpoint configuration is changed by this work.
