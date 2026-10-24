# Approved UI redesign — local source completion

The approved navy/blue panel system, original shield logo, original road artwork and Plus Jakarta Sans remain in use. This pass finishes the remaining core workflow layouts and shared control consistency. Already approved feature layouts are retained; this does not mean every source file was rewritten.

## Coverage

| Area | Implementation |
| --- | --- |
| Opening, Welcome, login, registration, verification | Existing approved car/provider/handshake motion retained. Login and role-account rules unchanged. |
| Driver home, requests, history, profile | Existing premium member surfaces and floating navigation retained; tab changes now animate without rebuilding stored tab state. |
| Active driver request | Current stage and provider contact first; live map while travelling; secondary map/details collapse after arrival; arrival, parts approval and final bill actions remain visible. |
| Provider home, nearby requests, profile, verification, history | Existing premium layouts retained with unified controls, menus, empty states and tab transitions. |
| Active provider job | Shared animated stage card, driver contact before map, map/details disclosures after arrival, submitted work form removed from the editable area, pending confirmation shown without a redundant disabled action. |
| Request issue, vehicle/location, search, review | Existing step and search motion retained; provider selection condensed; selection animation and selected semantics; informational distance fee tiers; meaningful retry retains selection. Server review still supplies the actual signed visit fee. |
| Final bill, payment, invoice | Cash + clearly labelled card demo. No method preselected. Card demo collects no card data and returns no payment action. Cash uses the existing provider-receipt flow. Invoice total is prominent and payment wording agrees with available methods. Historical bank-transfer receipts remain readable. |
| Vehicles/editor, messages, complaints, support, settings | Existing feature layouts use the shared premium surfaces, original typography, button feedback, disclosure/menu/list controls and route transitions. Unsaved forms, uploads, permissions and support actions retain their existing rules. |
| Admin workspace | Existing responsive admin layouts use the same shared control system. Verification, suspension/restoration, deletion confirmations, payment records, reports and audit authorization unchanged. |
| Native camera | Full camera visibility and native controls retained; no decorative panel covers the camera preview. |

## Motion and state

- Navigation transitions run once per route; tab transitions take 240 ms and retain child state/scroll. Offscreen tab tickers pause.
- Stage text changes with actual request state. GPS refreshes do not restart the stage transition or fabricate an ETA.
- Selection, press and details animations are short. OS reduced-motion/accessibility settings are respected, including changes while a tab remains open.
- Details keep children mounted so collapsing does not discard form input.
- No animation confirms arrival, approval, receipt or payment independently of the existing action/backend result.

## Validation

- Full Flutter suite: **369 tests passed**.
- Final motion-setting/provider-layout regression run after the last polish: **49 tests passed**.
- Native visual render checks: provider job, invoice, appearance and cash/card screens in dark and light modes (10 PNGs).
- Static analysis: **0 errors**; 20 existing warnings and 229 informational lints remain.
- `git diff --check` passed.

No release APK/web build or deployment was run. Live user-account/device acceptance testing and a genuine payment gateway are separate remaining work; card is intentionally a non-charging demo.

Native renders: `build/previews/redesign-final/`. Open `tools/previews/redesign-final/index.html` for the review board; all shown records are sample data.


## Usability follow-up

- Normal checkout offers cash only. The non-charging card preview is visible only when `DEMO_PAYMENTS=true` or when the explicit preview/test option is supplied; no real gateway has been introduced.
- Existing Driver/Provider active-job shortcuts are retained. The driver's existing card is now above the new-request hero; it is not duplicated. Completed real payment reports awaiting provider receipt show a reminder that opens the invoice and says not to pay again.
- Existing location freshness remains. Request streams now include Firestore metadata changes; cached details are labelled as saved data, with the last server-sync time when available. Cached data is not called a proven network failure.
- The existing cancellation sheet explains that its action adds no cancellation fee and does not automatically refund previous payments. No unsupported charge/refund policy or new fee is introduced.
- Long provider request references and invoice reference/date are in disclosures. Invoice PDFs and stored identifiers remain intact.
- Pending receipt copy clearly distinguishes reporting payment from provider confirmation. Historical bank-transfer and demo records remain readable.
- Full Flutter suite for this follow-up: 373 tests passed. No release build, deployment or live phone test was performed.


## Subsequent authorized production release

The web client/APIs were subsequently tested, built and deployed with user authorization. See [production release report](production-release-2026-10-24.md). The earlier no-build statements describe the implementation stages before that authorization. Physical-phone acceptance testing and Android/admin APK updates remain separate.
