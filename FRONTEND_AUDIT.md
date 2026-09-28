# RoadAssist frontend audit

Status: frontend prototype in progress. Backend integration is intentionally deferred.

## What is already present

- Driver onboarding, role selection, login and guest entry.
- Driver request flow: assistance type, vehicle details, location, provider choice, review, search and tracking.
- Driver request history, request details, profile, emergency screen and chat prototype.
- Provider dashboard, incoming request accept/reject, active-job status flow, history and profile.
- Shared visual components, a consistent Material 3 theme and local image assets.

## P0 — required before backend work

- Replace all no-op controls with a working frontend interaction or a clearly disabled state.
- Add complete form state and validation for login and breakdown details; carry entered request data through every review/tracking screen.
- Add confirmation and failure states for request cancellation, provider rejection, sign-out, GPS retry and job completion.
- Standardize Sri Lankan sample data. The current screens mix Sri Lankan names/numbers with US `+1` contacts.
- Split the 3,000+ line `screens.dart` into feature folders and separate reusable widgets, models and prototype repositories.
- Add routing that prevents replacement-stack inconsistencies and supports predictable back navigation.
- Add widget tests for both critical journeys: driver request completion and provider job completion.
- Verify Android, iOS and web builds, launcher metadata and app identity.

## P1 — product completeness

- Driver: registration/forgot-password, vehicle management, editable profile, photo picker UI, manual location entry, provider contact actions, ratings and receipt view.
- Provider: profile/settings editing, working hours, radius and service selection, request details before acceptance, rejection reason and earnings summary.
- Common: notifications, empty/loading/error/offline states, call/share intents, chat attachments and confirmation dialogs.
- Replace automatic three-second provider assignment with explicit prototype states: searching, accepted, no providers and retry.
- Preserve shell/tab state when returning from nested flows.

## P1 — UX and accessibility

- Test at 320–430 px width, large text scale and keyboard-open layouts.
- Add semantics/tooltips to tappable icons and ensure 48 px minimum targets.
- Improve contrast and visible focus/error states.
- Avoid hard-coded personal data in widgets; centralize display strings and prototype fixtures.
- Add localization readiness (English, Sinhala and Tamil) before copy spreads further.

## P2 — engineering quality

- Introduce immutable request, vehicle, provider, user and job-status models.
- Use a small frontend state layer and repository interfaces so mock data can later be replaced by APIs without rewriting screens.
- Add lint/format checks and tests to CI.
- Add golden tests for the highest-value screens and unit tests for validation/status transitions.
- Document environment setup and supported platforms in the README.

## Backend readiness gate

Backend work should start only when:

1. Both end-to-end frontend journeys work without dead controls.
2. All request/user/provider data comes from models rather than screen literals.
3. Loading, empty, failure, retry and offline states are represented.
4. Widget tests cover the critical state transitions.
5. `flutter analyze`, tests and target builds pass.

The backend can then implement the existing repository contracts for authentication, requests, providers, tracking, chat, notifications and payments.
