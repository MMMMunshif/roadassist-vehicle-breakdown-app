# Approved premium UI redesign

Updated: 24 October 2026.

## Current user decisions

- Latest approved entry: Welcome / Get Started -> common login. Create account opens an account-type sheet, followed by role-specific registration and the existing verification/access gates. Explicit legacy role-login routes remain compatible.
- Common password login resolves roles only after validating their independent passwords. If both passwords match, choose between authenticated accounts. Google resolves roles only after verified Google ownership. No implicit Google registration occurs. Password reset asks which role to reset. These API changes were deployed together with the web client on 24 October 2026.
- Preserve existing Plus Jakarta Sans typography, weights, sizes and spacing. Existing typography helpers, role text themes and bundled fonts remain the source of truth.
- Preserve the original shield logo assets, welcome backgrounds and road-pattern painter.
- Use the last approved blue/glass UI direction throughout the application.
- The user explicitly authorized deployment on 24 October 2026. The normal web client was built and deployed. Android and admin APK builds remain on hold; installed APKs belong to the previous release.

## Shared implementation

`lib/src/widgets/premium_style.dart` supplies layered neutral surfaces, dimensional service icons, short press feedback, reduced-motion-aware page transitions and a one-shot confirmed-success check. Static panel gradients avoid a blur layer for every card in a long list. Frosted glass is concentrated on navigation. Existing warning, danger and success colours remain explicit.

The shared theme applies the approved control, field, card, dialog and sheet treatment to every route that consumes the app theme. Local card/surface wrappers are also migrated throughout the feature modules. Task layouts, media, maps, permissions and business rules retain their purpose; this is a consistent visual system, not a claim that every screen has the same layout.

## Specific journey changes

- Driver home: default vehicle showcase, selectable service tiles, then the existing Request Assistance action. Selected services reach the real request form. Existing pending submission IDs resume review rather than being overwritten.
- Provider home: availability, daily collected totals from provider-confirmed payments, incoming request cards and payment follow-ups. Active work is prioritised when busy. Existing job and earnings views remain accessible.
- Provider request cards: shared dashboard/list presentation, explicit Dismiss and View request actions, real dispatch fee and fresh-location distance. No invented distance, fee, rating or route is shown.
- Request forms: shared dimensional service icons, themed selections and current validations.
- Tracking: state-driven timeline transitions. Completion check animation appears only for confirmed completion.
- Billing/invoices, vehicle management, history, messaging, profile/settings, support/disputes and admin workspaces use the same shared material and controls, with their existing workflows.

## Authentication motion

`lib/src/widgets/auth_journey_scene.dart` is native Flutter motion using one immutable silver-car PNG. It supports arrival, wheel rotation, a small settle, password-focus window tint, a headlight/road treatment during authentication and departure only after actual successful authentication. Registration milestones reflect local form completion. Errors return to the input state. No account is created or verified by an animation.

The scene remains alive while the form scrolls. Valid submission returns the header into view, and keyboard insets compact the header. Reduced Motion and accessible-navigation settings disable nonessential movement. Motion has no sound and no continuous idle animation.

## Assets and generation provenance

Added assets (built-in imagegen tool; originals remain under Codex generated_images):

- `assets/images/auth_journey_car.png`: transparent silver hatchback in right-facing side profile for compositing. Prompt: one isolated premium realistic 2.5D silver compact five-door hatchback, orthographic side profile facing right, visible wheels, dark window glass, cool blue reflections, no text, logos, scenery, shadow or background; transparent output.
- `assets/images/premium_service_icons.png`: transparent 2x2 sprite sheet. Prompt: four isolated cohesive premium 2.5D roadside-service icons on transparent equal quadrants: silver/blue mechanic wrench top left, dark tyre with silver-blue rim top right, blue battery with white lightning bottom left, blue flatbed tow truck bottom right; no words, labels, grid, frames or scenery. Runtime rendering clips each quadrant; source images are not edited.

Both assets are bundled locally. The app does not call an image-generation or remote-font service at runtime. Original logo/background files have no changes.

## Module inventory

All feature modules inherit the shared app controls and/or the scoped role theme. The inventory below records source scope, not a claim of physical-device verification for every route.

| Module | Dart files | Screen classes |
|---|---:|---|
| admin | 27 | _AccountAccessCheckingScreen, _AccountAccessBlockedScreen, _AdminAccountScreen, AdminAuditDetailScreen, _AdminAuditScreen, AdminAuditScreen, AdminComplaintsScreen, _AdminComplaintScreen, AdminDashboardScreen, AdminJobsScreen, AdminJobMonitorScreen, AdminOperationsScreen, AdminOverviewScreen, AdminPaymentsScreen, AdminPortalScreen, _RaAdminLoginScreen, AdminProvidersScreen, AdminReportsScreen, AdminSettingsScreen, AdminTeamScreen, AdminUsersScreen |
| auth | 10 | EmailVerificationScreen, LegacyWelcomeScreen, LoginScreen, RegistrationScreen, RoleSelectionScreen, SplashScreen, WelcomeScreen |
| billing | 2 | InvoiceScreen |
| chat | 2 | _ChatInboxScreen, ChatScreen |
| complaints | 1 | DisputeScreen |
| driver | 9 | DriverHomeScreen, DriverNotificationsScreen, DriverProfileScreen, DriverRequestDetailsScreen, EmergencyScreen, HistoryScreen, ProviderDirectoryScreen, RealtimeDriverRequestDetailsScreen |
| media | 1 | CameraCaptureScreen |
| provider | 13 | CustomerContactScreen, ProviderActiveJobScreen, ProviderCaseDetailsScreen, ProviderCompletedScreen, ProviderHistoryScreen, ProviderHomeScreen, _RaProviderActiveWorkScreen, ProviderNotificationsScreen, ProviderProfileScreen, ProviderRequestDetailsScreen, ProviderVerificationScreen |
| request | 8 | AssistanceTypeScreen, BreakdownDetailsScreen, GpsIssueScreen, LocationScreen, ProvidersScreen, ReviewScreen, SearchingScreen, TrackingScreen |
| settings | 4 | AccountSecurityScreen, AppearanceScreen, NotificationSettingsScreen, PrivacySafetyScreen |
| support | 1 | SupportScreen |
| vehicles | 2 | VehiclesScreen, VehicleEditorScreen |

## Verification and remaining release work

- Auth regressions cover the original role-first route, registration, reset, privacy focus/visibility, success-only departure and reduced motion.
- Dashboard action regressions cover service selection reaching the real form, collected totals excluding unpaid/old jobs, and Dismiss/View request controls.
- Existing comprehensive responsive tests cover narrow screens, large text, light/dark themes, active jobs, completion, billing, profile and admin views.
- Final results: 355 Flutter tests passed; 14 original role-auth/Google-auth server tests passed; 8 native preview renders passed. Analyzer: 0 errors and 20 warnings. Logs: build/premium-role-first-all-tests.log, build/premium-role-first-server-tests.log, build/premium-release-previews.log and build/premium-release-analyze.log.
- Native test-rendered previews can be regenerated with `flutter test tools/previews/auth_journey_preview_test.dart tools/previews/remodel_preview_test.dart`. These are widget renders, not app release builds.
- Physical-device motion performance, real GPS, provider receipt confirmation and real Google authentication still require the later installed-app acceptance pass.
- APK/web/admin release builds and deployment remain on hold until the user asks.

## Approved arrival study 03 implementation

Login/signup use a continuous layout with translucent inputs and light-blue actions. Driver registration uses the original silver-car asset; provider registration uses a local Flutter CustomPainter van and technician with arrival, wheel rotation and step-forward motion. The original logo, font assets and road painter remain unchanged. Real phone/photo requirements are retained even though the concept preview shortened its form. Reduced-motion settings skip nonessential movement. Verification/approval remains driven by real account state.

The user subsequently authorized the normal web build and deployment. The hosted site is updated; installed APKs are unchanged.

## Production release: 24 October 2026

- User explicitly approved deployment after the UI implementation.
- Vercel project: `vehicle_breakdown_app`; deployment `dpl_FoAT4gbAA8YBDAQ6rtVVXBtut2Z8`, Ready and promoted.
- Public origin: https://vehiclebreakdownapp.vercel.app .
- Client SHA-256: `3652ac92482b283dd330541f08abbd4d406b4d4d5def6692d35e7ef00447e83d`; public downloaded artifact matches the local web build.
- 359 Flutter tests, 66 backend tests, 6 native auth renders passed. Static analysis has zero errors and 20 existing warnings.
- 12 public smoke checks passed, including common-login unknown-account rejection, Google authentication guard, verification/billing guards and static asset delivery. These checks created no accounts and sent no emails; real Google popup/password login was not exercised with user credentials.
- Firebase rules/functions and Android/admin APKs were not deployed by this release.
- For repeatable web/API packaging use `scripts/prepare-vercel-web.py`, then deploy its stage directory. Previous production deployment for rollback: `dpl_CfurAHcYu6nefJu4qdMebna7SUBu`.

- Live Chromium smoke check passed: Welcome -> common login -> account-type sheet -> provider registration. No browser JavaScript errors were recorded; no account form was submitted.

## Approved handshake opening (local source, not deployed)

The selected concept is handshake -> scene fades -> shared logo and wordmark move into the existing Welcome header -> headline/cards/actions reveal in sequence. The car-window concept was rejected. Loading indicators and loading copy were removed entirely.

The new native `SplashRescueScene` uses the original car PNG and local vector van/characters, with finite arrival, doors, stepping, walking, handshake and release. The original road-pattern painter, logo assets, Welcome image assets and Plus Jakarta Sans typography remain in use. Startup auth resolution still selects Welcome, verification or the correct role shell; the visual never approves or verifies an account. Startup resolution runs concurrently with the 4.2-second opening. Normal Welcome handoff lasts 750ms; reduced motion/accessibility skips the cinematic wait and handoff. Slow auth resolution leaves a static scene with no invented loading progress. Disposal cancels the motion safely.

No APK/web release build or deployment was authorized by this implementation request. The previously deployed web release remains unchanged.

Validation for the local handshake opening: 363 Flutter tests passed; two native preview tests rendered handshake, finished splash, in-flight handoff and Welcome in both light/dark modes. Startup tests cover delayed destination resolution, disposal during startup, reduced motion, no loading indicators, shared Hero handoff and Welcome-to-common-login navigation. Installed APKs and the hosted release remain unchanged.
