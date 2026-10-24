# Role-first login release — 24 October 2026

Public URL: https://vehiclebreakdownapp.vercel.app
Deployment: https://vehiclebreakdown-2s8oqjod0-breakers-projects-d332ab9a.vercel.app
Deployment ID: dpl_GFVHDqf93DnLVkNHP2Nu1JytJc7N
Client SHA256: 7ac188dc8fc0bd0450394bc20fb241646b9144eacb07c1e12401d38fc62ec26d
Rollback: dpl_6NMJa1aRV69oafqVA3u15L8Veeqh

Welcome Get Started now opens the existing RoleSelectionScreen. Driver and Provider cards open explicit role logins. Provider login uses the existing provider van scene; driver uses the existing car scene. Splash handshake and welcome transitions remain unchanged.

The dashboard HTML concepts remain previews; they were not applied to Flutter screens.

Validation: 381 Flutter tests, 79 backend tests, 94 Firestore rule tests and guest emulator integration passed. Static analysis has zero errors and 20 existing warnings. Six staged release checks passed and matched the local client hash. Firestore guest exclusion rule deployed successfully before the web release.

Guest API source is included, but guest requests remain gated by GUEST_REQUESTS_ENABLED. Anonymous provider setup and a live guest request check are still required before activating this feature. No paid SMS, billing upgrade, Android APK build or notification-functions deployment was performed.
