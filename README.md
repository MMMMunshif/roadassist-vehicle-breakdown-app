# RoadAssist

RoadAssist is a Flutter-based roadside assistance platform for Sri Lanka. It
connects drivers experiencing a vehicle breakdown with nearby service
providers and supports the complete request lifecycle in real time.

## Main features

- Separate driver and service-provider registration and authentication
- Mandatory driver profile photograph and editable user profiles
- Vehicle details and emergency-contact management
- GPS and manually entered breakdown locations
- Real-time assistance requests through Cloud Firestore
- Nearby provider discovery and provider availability controls
- Provider quotation with service, travel and additional charge breakdowns
- Request stages: Searching, Accepted, En Route, Arrived and Completed
- Driver/provider live-location updates and external map navigation
- Request-specific real-time chat, photographs and unread indicators
- Driver and provider request history, receipts and ratings
- Email verification and password reset through a Vercel serverless backend
- Light, dark and system appearance modes

## Technology stack

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Geolocator and Flutter Map/OpenStreetMap
- Vercel serverless functions
- Firebase Admin SDK and Nodemailer

## Prerequisites

- Flutter SDK and Android SDK
- An Android device with USB debugging enabled, or Chrome/Edge
- A Firebase project with Authentication and Cloud Firestore configured
- Node.js 20 or later for the serverless email API

## Install dependencies

```powershell
flutter pub get
npm install
```

## Run on Android

List connected devices:

```powershell
flutter devices
```

Run using the displayed Android device ID:

```powershell
flutter run -d <ANDROID_DEVICE_ID>
```

## Run on the web

```powershell
flutter run -d chrome
```

or:

```powershell
flutter run -d edge
```

Web geolocation requires localhost or HTTPS. Allow location permission when
the browser requests it.

## Firebase configuration

1. Create Android and web applications in Firebase.
2. Place the Android configuration at `android/app/google-services.json`.
3. Configure the generated Flutter Firebase options used by the app.
4. Enable Email/Password authentication.
5. Create a Cloud Firestore database.
6. Deploy the included rules and indexes:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

## Password-reset and verification email backend

The API endpoints are located in `api/`. Copy `.env.example` and configure the
listed values as encrypted Vercel environment variables. Never commit a
service-account private key or Gmail application password.

Deploy after configuring the environment:

```powershell
npx vercel --prod
```

## Build an installable APK

```powershell
flutter build apk --release
```

The generated APK is available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Testing

```powershell
flutter test
flutter analyze
```

For the real-time workflow, use two different accounts on separate devices:
one driver and one provider. Put the provider online before submitting the
driver request.

## Security

- Real credentials belong only in Firebase/Vercel environment settings.
- `.env` files and local deployment metadata are ignored by Git.
- Firestore access is controlled through the included role-based rules.

## Academic project

This application was developed for the IT3060 Human Computer Interaction
Milestone 03 assignment. Team workload, testing evidence and prototype
traceability are documented in the consolidated project report.
