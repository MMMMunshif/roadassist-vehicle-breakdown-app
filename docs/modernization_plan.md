# RoadAssist architecture review and modernization plan

Review date: 4 October 2026. Based on local source code; deployed Firebase rules, live data, and external notification services have not been verified.

## Current architecture

- `lib/main.dart` initializes Flutter/Firebase and launches the app.
- `lib/src/app.dart` contains theme tokens, application setup, navigation helpers, and foreground FCM handling.
- `lib/src/screens.dart` is the library entry point for screen parts. Screens are in `lib/src/screens/`; assistance selection remains in `lib/src/features/request/assistance_type_screen.dart`.
- `lib/src/widgets/shared_widgets.dart` contains reusable UI and private screen helpers.
- `lib/src/models/request_draft.dart` contains the request draft, photo annotations, JSON serialization, and hardcoded service/dispatch estimates.
- Services separate authentication, request operations, local drafts, photo preparation, device tokens, and route lookup. Some Firestore access and matching logic still lives in widgets.
- `api/` contains Vercel email-verification/password-reset endpoints. No job-event FCM sender was found in the inspected source.

## Existing screens and flows

Authentication: splash, welcome, role selection, login/registration, email verification, account security.

Driver: home, notifications, provider directory, assistance selection, breakdown details, camera capture, location, nearby providers, review, searching, tracking, request history/details, profile, help, privacy/safety, emergency, and GPS help.

Provider: dashboard, notifications, request details, active job, completion, history, profile, customer contact, and case details.

Shared: request chat and appearance settings. Some legacy/detail screens coexist with realtime versions; verify navigation before retiring any of them.

Current driver flow: assistance selection -> vehicle/details/photos -> location -> preferred provider or available-provider search -> review -> searching -> provider acceptance -> tracking -> completion/history.

Current provider flow: online availability -> incoming request -> fee entry and acceptance -> en route -> arrived -> completed with final cost.

## Implemented capabilities

- Firebase authentication, driver/provider roles, verification/reset email integration.
- Provider directory and online/offline availability.
- Matching by selected services and service radius; not yet a full vehicle/skills/equipment match.
- Multiple selected issues, vehicle details, priority, photo evidence/annotations, GPS/location/landmark.
- Local saved draft and pending-submission flag in SharedPreferences. Submission still needs confirmed network success.
- Transaction-based request creation/assignment and active-request checks.
- Provider service/travel/extra fee entry during acceptance.
- Live request status/location, route lookup, request-linked text/image chat.
- Cancellation, provider rejection/search expansion, job notes/evidence, driver ratings and history.
- FCM device token registration and foreground message handling. This does not establish end-to-end background delivery.

## Current Firestore structure

```text
users/{uid}                         # private profile, role, availability, activeRequestId
  devices/{deviceId}                # FCM token and platform
providerDirectory/{providerId}      # public-to-signed-in provider summary
requests/{requestId}                # request, assignment, job status, fees, rating, evidence
  messages/{messageId}              # request-linked chat
```

Current job statuses are `searching`, `accepted`, `en_route`, `arrived`, `completed`, and `cancelled`.

Rules explicitly allow only four service categories and restrict document keys and status transitions. New fields, symptoms, quote types, or approval states require coordinated rules changes. Do not update the UI alone.

## Gaps to address

1. No persistent multi-vehicle model or management screen.
2. Driver-reported symptoms are not separated from service categories or provider diagnosis.
3. Estimates are hardcoded before diagnosis.
4. Provider acceptance both quotes and assigns the job; no multiple offers or driver quote approval.
5. No inspection-only authorization, repair authorization, or immutable price revisions.
6. Final cost can differ from the quoted amount without a recorded driver approval.
7. No structured parts options, itemized invoice, payment confirmation, warranty case, or dispute workflow.
8. Photos are compressed base64 strings stored in documents despite `vehiclePhotoUrls` naming. Video/voice media need a real storage pipeline; do not put them in Firestore documents.
9. Ratings/provider statistics are client maintained; authoritative aggregates should move to trusted backend logic.
10. Local drafts use global preference keys; scope drafts to the authenticated driver before expanding saved vehicle functionality.

## Safe data evolution

- Keep existing `users`, `providerDirectory`, `requests`, and request-linked messages. Avoid wholesale renaming or introducing a separate `jobs` copy in the first release.
- Use an explicit workflow version on new requests. Keep legacy request rendering and progression until old jobs are closed.
- Add owner-only `users/{uid}/vehicles/{vehicleId}` and an owner default-vehicle reference. Archive vehicles referenced by jobs rather than deleting history.
- Add optional `vehicleId` and an immutable `vehicleSnapshot` to new requests. Vehicle edits must not rewrite past request details.
- Add `requests/{id}/quotes/{quoteId}` for itemized, typed offers and revisions. Store selected/approved quote references on the request.
- Quote statuses and job statuses are separate. A submitted offer must not lock a provider's active job. Driver selection must atomically check availability and assign the job.
- Do not overwrite approved quotes: revisions reference the earlier quote and require a new driver decision.
- Use integer monetary amounts in a documented currency/unit, validate line items, and derive totals. Missing prices remain unknown, never a fabricated zero-price offer.
- Use rules or trusted backend validation for ownership, totals, immutable approval records, assignment, and allowed transitions. UI disabling alone is insufficient.
- Deploy compatible rules/indexes/backend changes before enabling clients that depend on them. Preserve legacy data and test both workflows with the Firebase emulator.

## Phased implementation

### Phase 2: Saved vehicles

Add `models/vehicle.dart`, `services/vehicle_service.dart`, vehicle list/editor/selection screens, owner-only vehicle rules, and tests. Add My Vehicles entry in driver profile/home. Extend request draft JSON with optional vehicle references/snapshot and preserve old drafts. Support a temporary vehicle without requiring permanent storage.

Acceptance: two accounts cannot access each other's vehicle records; one default reference; archived vehicles remain visible in historical snapshots; errors and empty states are handled.

### Phase 3: Driver request intake

Select vehicle first. Replace service-price cards with symptoms and an unknown-problem option. Keep provider service capabilities separate from symptoms so matching remains meaningful. Reuse breakdown details, photos, location, and local draft services. Add structured fuel/transmission/symptoms fields and scope drafts to the driver. Remove synthetic pricing from new-flow review/request creation, with coordinated rules changes.

Primary existing files: `request_draft.dart`, `request_draft_store.dart`, `assistance_type_screen.dart`, `breakdown_details_screen.dart`, `location_screen.dart`, `review_screen.dart`, `request_service.dart`, and `firestore.rules`.

### Phase 4: Provider offers and comparison

Add quote model/service, provider quote editor, driver quote list/details. Support direct-service and inspection-only quotes with explicit scope, fee breakdown, ETA, exclusions, and expiry. Reuse realtime request streams and provider request detail UI. Sort inspection offers separately from repair totals to avoid misleading comparisons. Do not invent prices or auto-select the cheapest offer.

### Phase 5: Driver selection and tracking

Add transactional quote selection and provider availability checks, participant access rules, and job-event notifications from a trusted backend. Adapt searching/tracking/provider active-job screens and history to the new workflow while retaining legacy reads. Include no-response timeout, retry, alternate offers, and provider cancellation recovery.

### Phase 6: Inspection and repair approval

Add inspection records, separate provider diagnosis, repair quotes, compatible parts options, driver approval/rejection, and immutable additional-work revisions. Enforce authorization in rules/backend before repair progression. Reuse job documentation, photos, and chat. Document cancellation charges in the approved offer rather than inventing a universal penalty.

### Phase 7: Completion, invoice, payment, and history

Generate an invoice from approved items. Record completion evidence, issue-resolved confirmation, payment method/status, receipt, ratings, and per-vehicle history. Distinguish a provider marking payment received from actual gateway verification. No online-payment success claims without integration.

### Later releases

Warranty cases, disputes, localization, trip sharing with explicit access/expiry, storage-backed voice/video, payment gateway integration, workshop/insurance integrations, and fleet accounts.

## Verification and release checks

- Previous refactor verification: library analysis had no errors/warnings and 25 informational style findings. Existing tests had 12 passes and four failures in image decoding/form/profile flows; establish and resolve that baseline before treating the suite as a release gate.
- Add meaningful model/serialization and rules tests for each phase, especially ownership, assignment races, quote approval, totals, revisions, and legacy requests.
- Exercise driver/provider flows on two authenticated devices, including cancellation, stale offers, offline transitions, and notification delivery.
- No production data migration or deployment is part of this architecture review.
