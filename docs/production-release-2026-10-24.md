# Production web release — 2026-10-24

User authorized final testing and deployment. The latest approved redesign/usability source was built and published to https://vehiclebreakdownapp.vercel.app .

- Deployment: `dpl_FvoQ4xmGhRxUKrTM6uMgPm22JHG1` (Ready, promoted).
- Unique URL: https://vehiclebreakdown-226vc8ogt-breakers-projects-d332ab9a.vercel.app
- Previous production / rollback: `dpl_FoAT4gbAA8YBDAQ6rtVVXBtut2Z8`.
- Public client SHA-256: `38ae6bf28e4f1bb75e3440449c47c1285851ecdda16da3eae2ee3555a6f5f032`. Downloaded live client matches the local release build.
- 373 Flutter tests and 66 backend tests passed. Static analysis: 0 errors, 20 existing warnings.
- 6 staged smoke checks and 12 public client/API smoke checks passed. No real account was created and no verification/reset email was requested by the checks.
- Live Chromium mobile-viewport smoke check passed: Welcome → common login → role selection → provider registration. No page JavaScript errors. This is browser validation, not a physical phone or authenticated service/payment end-to-end test.
- Card demo is hidden in this normal production build (`DEMO_PAYMENTS` is false). No merchant/card gateway or real card charge was introduced.
- No Android/admin APK, Firebase rules/indexes/functions deployment or cleanup was performed.

Production alias propagation briefly served the previous client immediately after promotion; the subsequent public check verified the new hash and all 12 checks passed.

Evidence: `build/final-release-tests.log`, `build/final-release-backend.log`, `build/final-release-analyze.log`, `build/final-release-staged-checks.json`, `build/final-release-public-checks.json`, `build/final-release-browser.log`. Mobile browser screenshots are under `build/previews/final-release/`.
