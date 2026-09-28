# RoadAssist LK — Project History and Current Status

**Document date:** 31 August 2026  
**Project path:** `D:\vehicle_breakdown_app`  
**Firebase project:** `roadassist-lk-munshif`  
**Application package:** `com.roadassist.app`

> இந்த document, project ஆரம்பித்ததிலிருந்து இப்போது வரை chat மூலம் செய்த development work-ஐ ஒரு structured project report ஆக பதிவு செய்கிறது. இது word-for-word chat transcript அல்ல; requests, decisions, fixes மற்றும் completed work-ன் chronological technical summary ஆகும்.

## 1. Project Overview

RoadAssist LK என்பது Sri Lanka-க்கான **vehicle breakdown and roadside assistance mobile/web application** ஆகும். Breakdown ஏற்பட்ட driver ஒரு assistance request உருவாக்கலாம். Online service providers அந்த request-ஐ realtime-ல் பார்க்க, accept/reject செய்ய, driver location-க்கு செல்ல, status update செய்ய, call/chat செய்ய முடியும்.

### Main user roles

1. **Driver**
   - Account create/sign in
   - Profile and vehicle details manage
   - Current breakdown location select
   - Vehicle photos attach
   - Online providers view/search
   - Assistance request submit/cancel
   - Provider status and location track
   - Provider-க்கு call/chat
   - Request history and notifications view

2. **Service Provider**
   - Provider account sign in
   - Online/offline availability control
   - Incoming requests realtime-ல் பார்க்க
   - Request accept/reject
   - Driver-க்கு call/chat
   - Live provider location share
   - Job status update
   - Provider history/profile manage

## 2. Technology Stack

- Flutter / Dart
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging token registration
- OpenStreetMap via `flutter_map`
- Device GPS via `geolocator`
- Reverse geocoding via `geocoding`
- Phone calls via `url_launcher`
- Gallery selection via `image_picker`
- Native camera preview/capture via `camera`
- Image resize/compression via `image`

### Important package decision

`firebase_core_web 3.11.0` Chrome compile error (`Object.isA`) காரணமாக `firebase_core_web: 3.10.0` dependency override pin செய்யப்பட்டுள்ளது.

## 3. Main Project Files

- `lib/main.dart` — application entry point
- `lib/firebase_options.dart` — Firebase Android/Web configuration
- `lib/src/app.dart` — theme, design tokens, shared helpers, calling/location helpers
- `lib/src/screens.dart` — driver/provider screens and reusable UI widgets
- `lib/src/models/request_draft.dart` — assistance request draft model
- `lib/src/services/auth_service.dart` — authentication and profile/provider-directory operations
- `lib/src/services/request_service.dart` — requests, status, chat and provider location operations
- `lib/src/services/photo_upload_service.dart` — image compression and Base64 preparation
- `lib/src/services/device_service.dart` — notification device-token registration
- `firestore.rules` — Firestore security rules
- `firestore.indexes.json` — request query indexes
- `test/frontend_flow_test.dart` — frontend flow widget tests

## 4. UI/UX Design Direction

User-selected design direction:

- White background
- Light-blue cards
- Corporate/professional appearance
- Dark navy-heavy appearance reduced
- Clean spacing and consistent reusable components
- Medium/light blue primary actions

### Completed global design changes

- Global app color tokens refined in `app.dart`.
- White canvas and light-blue card system introduced.
- Buttons, cards, inputs, navigation and status pills made consistent.
- Overflow issue (`OVERFLOWED BY ... PIXELS` red warning) addressed in form layouts.
- Role selection and dashboards redesigned to look more professional.

## 5. Welcome and Authentication Flow

### Completed

- Welcome screen changed to a full-screen roadside assistance background image.
- Old top RoadAssist logo/banner requested by the user was removed.
- Role selection screen redesigned professionally.
- Driver and provider have separate login/registration paths.
- Firebase Authentication validates the selected role.
- Wrong-role login signs out and displays a role error.
- Driver registration supports optional profile photo.
- User profile is created in `users/{uid}` with role, display name, email, phone and online status.
- Logout returns to the welcome screen.

### Role data separation

- Driver login opens Driver dashboard.
- Provider login opens Provider dashboard.
- Logged-in account display name is loaded from Firebase instead of default John/Driver values.

## 6. Driver Dashboard

### Completed

- Actual logged-in driver name displayed realtime.
- Current location card is interactive.
- Driver can:
  - Use current GPS location
  - Enter a location manually
  - Save location label and coordinates to profile
- Reverse geocoding converts GPS coordinates into a readable address where supported.
- Web GPS limitation documented: localhost or HTTPS and browser permission are required.
- Notification bell loads request status updates and shows unread count.
- Opening notifications records `notificationsSeenAt`.
- “My Requests” shows the latest actual Firestore request.
- Hardcoded Nearby Assistance providers were removed from the active dashboard.
- Dashboard now watches actual online providers from `providerDirectory`.
- Provider `online/offline` changes update the Driver dashboard realtime.
- “See All” opens an actual provider directory with search.
- Provider cards open the assistance request flow.

## 7. Driver Profile

### Completed

- Actual driver display name, email and phone loaded realtime.
- Vehicle details persisted in Firestore.
- Emergency contact persisted in Firestore.
- Edit Profile works and updates Firebase profile data.
- Profile photo can be selected from gallery.
- “Take a photo” opens a real native camera preview instead of the gallery.
- Camera supports capture, preview and retry.
- Profile image is compressed before saving.
- Sign Out button works.

## 8. Emergency Contacts

### Completed

- Police Emergency (`119`) call flow.
- Suwa Seriya Ambulance (`1990`) call flow.
- Hardcoded family contact removed.
- Driver’s saved emergency contact appears realtime on the Home screen.
- Add/Change emergency number supported.
- Call button uses the actual saved number.
- Saved current-location label can be copied/shared from the emergency screen.
- Guest, loading, error and missing-contact states handled.

## 9. Breakdown Request Creation

### Completed request steps

1. Select assistance type
2. Enter vehicle/breakdown details
3. Select GPS/manual/map location
4. Review request
5. Submit to Firestore

### Request data saved

- Driver ID/name/phone
- Issue type
- Vehicle type/model/year/registration
- Detailed description and additional notes
- Compressed vehicle photos
- Location label, latitude and longitude
- Estimated cost
- Status and timestamps
- Provider assignment fields

### Vehicle photos

- Gallery and camera supported.
- Maximum of three photos.
- Photos resized/compressed before saving.

## 10. Photo Storage Decision

Firebase Storage console requested a paid Blaze upgrade/card for this project. User requested a no-card alternative.

### Implemented alternative

- Firebase Storage dependency/rules were removed.
- Images are compressed and encoded as Base64 strings.
- Profile photo is stored in the user Firestore document.
- Vehicle photos are stored with the request document.

### Limitation

Firestore documents have a 1 MB limit. This Base64 approach is suitable for the current prototype with strict compression, but production should move images to object storage/CDN.

## 11. Finding a Provider

### Completed

- Animated searching circle and rotating/pulsing location icon.
- Actual Firestore request ID displayed.
- Hardcoded `RA-8829-XJ` removed from the active searching flow.
- Fake three-second automatic tracking navigation removed.
- Request document is watched realtime.
- Provider accept automatically opens tracking.
- Accepted, en-route, arrived and completed states handled.
- Cancel request updates Firestore to `cancelled`.
- Remote cancellation and connection error messages handled.
- Guest/fake request submission is blocked; driver sign-in is required so providers can receive the request.

## 12. Driver Live Tracking

### Completed

- Actual breakdown coordinates displayed on the map.
- Provider marker/route appears only after a real provider GPS update exists.
- Fake provider position removed from active tracking.
- Provider location updates realtime.
- Actual provider name and phone shown.
- Fake company, vehicle registration, rating, ETA and distance removed.
- Call button is enabled only when a real provider phone number exists.
- Chat connects to the actual request.
- Accepted, En Route, Arrived, Completed and Cancelled status timeline supported.
- Actual request ID and estimated cost displayed.
- Completed/cancelled request provides Back to Home action.

## 13. Driver Notifications

### Completed

- Notifications are derived realtime from the driver’s request updates.
- Unread badge compares request `updatedAt` against `notificationsSeenAt`.
- Messages exist for searching, accepted, en-route, arrived, completed and cancelled states.
- Empty/error/sign-in-required screens provided.

### Not yet production-complete

- Device FCM token registration exists.
- A server/Cloud Function that sends background push notifications has not yet been implemented.
- Open-app realtime notifications work; reliable background push still needs backend sending logic.

## 14. Driver Request History

### Completed

- Hardcoded Kasun/Chaminda/Rohan history cards removed from the active history UI.
- Actual driver requests loaded realtime from Firestore.
- All, Completed and Cancelled filters work.
- Searching, Accepted, En Route, Arrived, Completed and Cancelled status labels supported.
- Cards show actual provider, vehicle, location and estimated cost.
- Request Details displays real request information and map.
- Assigned provider call/chat actions use actual request data.
- Guest, loading, empty and error states handled.

## 15. Provider Dashboard

### Completed

- Actual provider name loaded from logged-in profile.
- Default John’s Towing content removed from active data flow.
- Provider online/offline toggle persists to Firestore.
- Provider directory synchronizes provider name and online state.
- Incoming open requests load realtime.
- New, active and completed counters use real request data.
- Provider can accept or reject requests.
- Accept uses a transaction to prevent two providers accepting the same request.
- Rejected request records the provider in `rejectedBy` without cancelling it for other providers.
- Driver-cancelled requests disappear when query/status updates.

## 16. Provider Active Job

### Completed

- Active job receives actual request data.
- Driver name, phone, vehicle, issue and location displayed.
- Provider can call the actual driver number.
- Provider can open request-specific chat.
- Provider can update job status.
- Provider GPS is streamed to the request document using `providerLatitude` and `providerLongitude`.
- Driver tracking watches those coordinates.

## 17. Provider History

### Completed

- Provider history loads assigned jobs realtime.
- All, Completed and Cancelled filters supported.
- Dynamic job cards show driver, service, location and cost.
- Job Details opens the actual request data and map.
- Call Driver and Open Chat use actual request information.

## 18. Provider Profile

### Completed

- Actual logged-in provider name/contact loaded realtime.
- Provider business/name and phone editing supported.
- Provider photo can be selected from gallery or captured with camera.
- Profile photo stored in provider’s private user document.
- Online/offline availability persisted.
- Working hours and service radius persisted.
- Profile edits synchronize the public provider-directory name.
- Sign Out works.

### Privacy/security decision

Provider directory currently exposes only:

- `displayName`
- `online`
- `updatedAt`

Provider Base64 photo/phone/settings were not added to the public directory because that required deploying expanded shared Firestore access-control rules. Existing safe fields were retained.

## 19. Realtime Chat and Calling

### Completed

- Messages stored under `requests/{requestId}/messages`.
- Driver and assigned provider can read/create messages.
- Messages show sender alignment using Firebase user ID.
- Hardcoded initial chat conversation removed.
- Chat header uses actual request ID.
- Call buttons use `tel:` links through `url_launcher`.
- Fake fallback phone numbers removed from active tracking/provider-job paths.
- Call button is disabled when no real number exists.

## 20. Maps and Location

### Completed

- OpenStreetMap tiles via `flutter_map`.
- Breakdown position selection.
- GPS permission handling.
- Manual location fallback.
- Reverse geocoding.
- Provider live-location sharing.
- Driver/provider route visualization.

### Platform requirements

- Android/iOS location permission must be granted.
- Web geolocation requires localhost or HTTPS.
- Web camera also requires a secure origin and browser permission.

## 21. Firebase Data Model

### `users/{uid}`

Typical fields:

- `email`
- `displayName`
- `phone`
- `role` (`driver` or `provider`)
- `online`
- `photoData`
- `vehicle`
- `emergencyContact`
- `currentLocationLabel`
- `currentLatitude`
- `currentLongitude`
- `workingHours`
- `serviceRadius`
- `notificationsSeenAt`
- timestamps

### `providerDirectory/{providerId}`

- `displayName`
- `online`
- `updatedAt`

### `requests/{requestId}`

- driver/provider identity fields
- request description and vehicle fields
- location fields
- compressed vehicle photos
- `status`
- `rejectedBy`
- estimated cost
- provider live coordinates
- timestamps

### `requests/{requestId}/messages/{messageId}`

- `senderId`
- `text`
- `createdAt`

### `users/{uid}/devices/{deviceId}`

- Device/FCM token registration data used for future push notifications.

## 22. Firestore Security

Implemented security principles:

- Users can read/update only their own profile.
- Signed-in users can read the provider directory.
- A provider can update only its own directory record and only approved public fields.
- A driver can create a request only for its own user ID.
- Request access is limited to the request’s driver, assigned provider, or online provider discovery of searching requests.
- Only driver/assigned provider can access request messages.
- Deletes are disabled for users, provider directory, requests and messages.

## 23. Firestore Indexes

Indexes exist for:

- `status + createdAt`
- `driverId + createdAt`
- `providerId + createdAt`

These support realtime dashboards and histories.

## 24. Important Problems Fixed During Development

- Flutter UI overflow red warning in Breakdown Details.
- Provider dashboard showing default name/photo.
- Driver Nearby Providers showing static names.
- Provider rejected/cancelled requests staying incorrectly visible.
- Driver profile edit/logout not working.
- Profile/vehicle photo controls marked “coming next”.
- “Take a photo” opening only gallery instead of camera.
- Current Location card not editable.
- Driver home authentication crash (`Bad state: Authentication is required`).
- Chrome `firebase_core_web` `isA` compile error via compatible version pin.
- Hardcoded history, searching request ID, tracking provider data and chat messages removed from active flows.
- Real cross-device Firestore request/status/chat/location flow introduced.

## 25. Commands Used to Run the Project

### Android phone

```powershell
flutter pub get
flutter devices
flutter run -d <device-id>
```

When only one Android phone is connected:

```powershell
flutter run
```

### Chrome

```powershell
flutter run -d chrome
```

### Useful Flutter run controls

- `r` — hot reload
- `R` — hot restart
- `q` — quit

### Verification

```powershell
flutter analyze --no-pub
flutter test test\frontend_flow_test.dart --no-pub
```

## 26. Previous Verification Results

At earlier stable milestones:

- `flutter analyze --no-pub` returned no issues.
- `frontend_flow_test.dart` passed all four tests.
- Android debug APK built and installed successfully after camera integration.

### Current local tooling note

In recent turns, `dart format`, `flutter analyze` and `flutter test` started hanging without output because long-running Dart/Flutter processes appear to hold the local Flutter tool. Recent changes received source-level inspection, but a clean full analyzer/test run should be completed after closing active Flutter/IDE Dart processes or restarting the machine/IDE.

## 27. Current Known Limitations and Pending Work

1. Run a complete analyzer/widget test pass after resolving the local Flutter tool hang.
2. Perform final two-device end-to-end testing:
   - Phone A: Driver
   - Phone B: Provider
   - Request → accept → chat/call → location → status → completion/cancellation
3. Implement backend Cloud Function/server for real background FCM push sending.
4. Replace Firestore Base64 images with production object storage when billing/storage is available.
5. Remove or refactor remaining legacy/demo screen classes and hardcoded content that are no longer used by the active flow.
6. Add provider service configuration editing instead of fixed service tiles.
7. Add real ETA/distance calculation from provider and driver coordinates.
8. Add stronger phone-number validation.
9. Add request ratings/receipts as real Firestore data.
10. Add automated integration tests against Firebase Emulator Suite.
11. Verify Android release signing and create production APK/AAB.
12. Review and tighten request status-transition rules before production launch.

## 28. Recommended Final Testing Checklist

### Driver phone

- Register/login as driver.
- Upload profile photo using gallery and camera.
- Add vehicle and emergency contact.
- Change GPS/manual current location.
- Submit breakdown with vehicle photo.
- Verify searching animation and real request ID.
- Verify provider acceptance opens tracking.
- Verify live location, call and chat.
- Verify status timeline.
- Verify completed/cancelled history and notifications.

### Provider phone

- Register/login as provider.
- Edit provider name/phone/photo.
- Toggle online.
- Verify incoming driver request.
- Accept/reject request.
- Verify driver call/chat.
- Allow location and verify location sharing.
- Update En Route → Arrived → Completed.
- Verify provider history and dashboard counts.

### Cross-device expected result

Both devices must use different Firebase accounts and the same Firebase project. Firestore realtime listeners should synchronize request status, chat messages and provider location without restarting the applications.

## 29. Current Project Position

The project has progressed from a mostly static high-fidelity UI prototype to a functional Firebase-backed roadside assistance prototype with:

- Role-based authentication
- Realtime driver/provider request matching
- Realtime dashboards and histories
- GPS/map support
- Provider live tracking
- Request-specific chat
- Real phone call integration
- Camera/gallery photo capture
- Persistent profiles and settings
- Firestore security and indexes

The main remaining phase is **final cleanup, complete two-device QA, production notification backend, production media storage and release hardening**.

## 30. Latest Completion Pass

- Existing Firebase sessions now restore automatically after app restart and route to the correct Driver or Provider dashboard.
- Persistent sessions re-register the device notification token.
- Provider presence changes to offline when the app is backgrounded/closed and returns active when resumed.
- Provider sign-out clears online presence before ending the Firebase session.
- Foreground Firebase messages display an in-app alert.
- Chat photo attachment is implemented for gallery and camera; photos are compressed and synchronized through the request chat.
- The provider dashboard no longer exposes a hardcoded demo request when authentication is missing.
- Firestore chat rules validate attached images; the updated rules and indexes were deployed successfully to `roadassist-lk-munshif`.
- Direct Dart analysis completed with zero errors and zero warnings; only existing style-info notices remain.
- Flutter test runner was attempted, but the local Flutter wrapper remained blocked without output, consistent with the known local tool/cache lock.

### Production work that still needs external setup

1. Complete a two-device driver/provider acceptance test.
2. Add a trusted backend for background FCM push delivery.
3. Move Base64 media to object storage when Firebase Storage billing is available.
4. Configure a private Android release keystore before Play Store delivery.
5. Add App Check, crash reporting, privacy policy and account deletion before public release.
