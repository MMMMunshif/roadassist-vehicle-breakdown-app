# RoadAssist simplified workflow

Source update: 23 October 2026. Brand assets, road-pattern backgrounds and light/dark themes are preserved. Unreferenced prototype photos are excluded from bundles; original image files remain in the repository.

## Driver journey

1. Problem and vehicle: service chips, default saved vehicle, optional symptoms/photos. Urgency, parts preferences and notes are collapsed into More details.
2. Location: existing automatic GPS with map/address fallback.
3. Provider: nearest matching providers, then a compact confirmation sheet with a server-issued visit fee. First km Rs. 100; each additional started km Rs. 20. Distance remains straight-line, explicitly labelled.
4. Live assistance: accepted, travelling, arrival confirmation, work, bill, payment, receipt. Waiting requests offer a new provider after 90 seconds without changing price or sending another request automatically. Changing providers cancels the previous request before the new provider/fee is reviewed.

Cancel uses a single reason sheet. Choosing a preset requires no typing; Other requires 10?500 characters. Submission IDs and owner-scoped drafts remain in place.

## Provider journey

Online availability, incoming requests, accept, navigate, arrival, service summary, final bill. The driver confirms arrival before work can be billed. Navigation/automatic arrival and manual fallback remain.

New requests set `workApprovalRequired: true`. Before adding replacement parts, providers send a work estimate containing inspection, labour, item names/reasons and amounts. The driver approves or declines a specific revision. Server validation prevents a final bill exceeding approved category or aggregated item limits. Normal work without parts may proceed directly to a final bill; there is no automatic threshold for mandatory labour estimates.

Sending a final bill records `serviceCompletedAt` and releases only matching provider directory/profile locks. Driver review/payment remains pending independently. A late correction or checkout cannot release a newer job's lock. Finished visits cannot be cancelled while the bill is being corrected. The provider dashboard and Jobs list retain payment follow-ups.

The service summary/photo controls no longer require a separate Save in new billing flows. Finish service saves the summary and opens a prefilled final bill. Draft summary edits remain on that screen until submitted; they are not advertised as background autosave.

## Payment and support

Cash and bank transfer are manual declarations. The driver reports paying; only the provider's confirmation marks receipt. No payment gateway is configured. Card simulation is hidden by default and requires a build with `--dart-define=DEMO_PAYMENTS=true`; existing simulated records remain readable and cannot claim real received funds.

Question this bill groups correction, discount and service-problem reporting. Existing dispute, invoice, warranty and audit records remain available.

## Authentication and administration

Typography uses bundled static Plus Jakarta Sans weights through local style helpers, so theme changes and offline use never wait for Google Fonts downloads. The variable source and OFL license are retained; `tools/instantiate_fonts.py` reproduces static weights with fonttools.

Driver profile photos are optional. Email verification, role-separated credentials/history and provider document approval remain enforced. Admin desktop navigation is grouped by Overview, People, Services, Support/payments and Management without changing role permissions.

## Compatibility and deployment

Existing workflow 1/2 jobs retain their quote/approval controls. Existing workflow 3 jobs without the new flag retain their previous lock timing. Older installed builds may omit the new flag when creating a request; explicit false values are rejected. Only the trusted API writes estimates, decisions and service-finished metadata. Client mutation is denied by rules.

Deploy API, Firestore rules, notification functions and web together; verify the released rules source matches local source. Install the rebuilt APK to receive the new screens. A rules-only update does not install new UI on phones.

## Verification

Relevant automated checks cover ownership, submission retries, cancellations, server-only approvals, stale revisions, declined work, bill limits, duplicate item aggregation, payment flags and concurrent provider reservations. The Admin SDK emulator integration covers accepting a second job while the first waits for payment, then correcting/settling the first without releasing the second.

`flutter test tools/previews/remodel_preview_test.dart` renders actual Flutter sample-data previews to `build/previews/`. These are UI previews, not evidence of a live paid job. Real-device GPS, background push delivery and two-account cash confirmation still require an acceptance run.

Tamil/Sinhala localization, a real card gateway and road-distance pricing are separate releases. No merchant account, production payment or new paid service is created by this remodel.

## Notification deployment requirement

The checked Firebase project currently has no deployed Functions. Deployment was attempted and Firebase rejected it because Spark cannot enable Cloud Build; Blaze billing is required. No billing plan was upgraded. Notification event code/tests are updated, but background push delivery is not claimed live until this deployment succeeds. In-app request streams remain available.

## Release verification (23 October 2026)

- Full Flutter suite: 346 passed; subsequent availability/role regressions: 14 passed (including the newly added active-service predicate check).
- Actual light/dark Flutter UI previews: 4 passed.
- Backend suite: 65 passed. Firestore rules suite: 94 passed. Real Firestore Admin SDK integration: 1 passed.
- Static analysis: zero errors; 20 warnings remain in the project.
- Signed universal APKs: RoadAssist 79.1 MiB; RoadAssist Admin 81.1 MiB. Package identities and signatures verified. APK inspection verifies original logo/background files remain and all eight unused prototype photos are absent.
- Web/API deployed to https://vehiclebreakdownapp.vercel.app. Released Firestore rules were downloaded and compared with the tested local source. New API actions reject invalid authentication.
- Automated tests and UI previews do not establish physical-device GPS, background delivery or live cash receipt. Background Functions deployment remains blocked by the Spark-plan requirement above.
