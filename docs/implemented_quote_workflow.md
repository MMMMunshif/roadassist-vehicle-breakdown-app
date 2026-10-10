# Saved vehicles and driver-approved offers

Implemented locally on 4 October 2026.

## Driver walkthrough

1. Open Profile -> My Vehicles. Add/edit/archive vehicles and set a default. In Archived vehicles, restore a vehicle or permanently delete it; deletion removes only the saved vehicle record and retains assistance history. These actions require the current `firestore.rules` to be deployed. Breakdown Details automatically fills the default when starting a fresh form; Saved vehicles lets you change it. Manual entry remains supported.
2. Tap Get Help. Select provider service capabilities, or choose I don't know the problem to request a mechanic inspection. Describe symptoms and optionally add photos/voice dictation.
3. Choose budget compatible, branded aftermarket, genuine manufacturer, or discuss-with-provider as a parts preference. This is a preference, not a compatibility guarantee or an inventory reservation.
4. Confirm location and review nearby providers. Default to receiving offers from all suitable providers, or select a preferred provider.
5. Submit without a system-generated repair price. Compare itemized offers on the Searching screen. Direct-service and inspection-only offers are distinguished and grouped separately.
6. Approve one offer. Assignment and the provider reservation happen in one transaction. A competing selection fails if that provider is already reserved.
7. Track the job and use assigned-job chat/calling. At arrival, review repair/additional-work proposals and approve or reject them. An inspection approval does not authorize repair. Each proposal remains an immutable document; client decisions are recorded separately.
8. On completion, open Invoice from tracking or request history. View the approved breakdown, any discount, and final total. Record cash/external payment only after paying; provider confirmation is separate. No payment gateway is integrated.

## Provider walkthrough

1. Stay online and review incoming requests, vehicle details, symptoms, and parts preference.
2. Enter actual service/inspection, travel, and other stated charges. Explain included work, parts and exclusions. The app no longer invents a per-kilometre travel charge.
3. Send a direct-service or inspection-only offer. Sending an offer does not assign the job.
4. When selected, the request appears in Active Job. Mark en route and arrived.
5. At arrival, submit a full replacement total for repairs or extra work, including the inspection/call-out already approved. Do not treat a revision as a second bill. Wait for approval.
6. Complete at or below the approved total. Pending revisions and unapproved inspection repairs block completion.
7. View the invoice and confirm payment received after the driver records payment.

## Data and compatibility

- Existing request documents retain their legacy acceptance flow. New requests have `workflowVersion: 2`.
- New vehicles: `users/{uid}/vehicles/{id}`; default reference in the user's profile. Archiving retains historical data.
- Vehicle ID and snapshot are carried through local drafts and stored on requests. Existing requests need no backfill.
- Offers: `requests/{id}/quotes/{providerId}`. One current offer per provider per open request; providers can update it before selection. Selected offers cannot be edited afterward.
- Repair proposals: `requests/{id}/repairQuotes/{revisionId}`. Decisions: `requests/{id}/repairDecisions/{revisionId}`. The initial driver report remains separate from provider diagnosis.
- Provider reservation: `providerDirectory/{id}.activeRequestId`. Released during completion/cancellation.
- Drafts and offline retry flags are scoped to the account. Old unscoped local drafts are not automatically imported because they do not identify their owner.
- Unknown price is represented by an unquoted request with zero legacy fee fields and explicit quote-required UI; zero is not displayed as a free-service offer.
- Payment flags are manual declarations, not gateway verification.

## Deployment and tests

Deploy the updated `firestore.rules` to the existing Firebase project before running this client against production. Old deployed rules reject vehicle collections and the new quote workflow. No collection renames or destructive data migration are required.

The local Firebase CLI currently has no authorized account. From the project directory:

```powershell
.\tools\rules-tests\node_modules\.bin\firebase.cmd login
.\tools\rules-tests\node_modules\.bin\firebase.cmd deploy --only firestore:rules --project roadassist-lk-munshif
```

Local rules testing uses a demo project, never production:

```powershell
npm install --prefix tools/rules-tests
node tools/rules-tests/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --only firestore --project demo-roadassist --config firebase.emulator.json "npm --prefix tools/rules-tests test"
```

The tests cover owner-only vehicles, offer totals, driver selection/reservations, cancellation, final-charge limits, inspection approval, immutable revisions/decisions, new request creation, and payment declarations.

## Further releases

Structured multiple compatible parts options with brand/part-number/warranty fields, supplier inventory, provider ETA/review sorting, full symptom questionnaires, towing destinations, localization, warranty/dispute cases, online payments, and backend job-event push delivery remain separate work. Current FCM token registration does not establish end-to-end push delivery.

Before a production release, exercise both accounts on real devices and confirm rules deployment. The existing profile widget tests need a Firebase fixture; this release does not pretend those guest tests validate authenticated profile persistence.

Final local verification: static analysis had zero errors/warnings (informational brace style findings remain); all 11 rules tests passed, including chat markers/location/documentation regression checks; the Flutter suite had 17 passes and two existing profile-test failures. Photo decoding and draft-to-location navigation tests now pass. The profile tests still expect authenticated persistence without a Firebase fixture or an outdated guest success message.

Price changes with evidence

Before a job is marked completed, a changed final amount opens the full replacement quote form. All new revisions require a 10-300 character reason and an included-work description. An increase requires one or two compressed evidence photos (at most 210,000 base64 characters each); decreases do not require a photo. These fields are stored immutably on repairQuotes as changeReason and evidencePhotoData. Driver approval remains separate and immutable on repairDecisions. A pending revision cannot be overwritten. Final completion remains capped at the driver-approved total; completed invoices cannot be revised through this flow.

Driver tracking and invoice history show the reason and evidence, with photo enlargement. Legacy revisions without these fields remain readable. Updated Firestore rules must be deployed before this build sends revisions. Older app builds that omit the new required fields must be updated before submitting revisions.

Verification: 27 Flutter tests and 13 Firestore emulator tests passed. Both previously failing profile tests now pass. New checks cover reason/evidence requirements, oversized photos, pending revision protection, completed invoice immutability, form validation and dark-theme invoice values. Code analysis has no errors or warnings; informational brace-style findings remain.