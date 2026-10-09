# RoadAssist Admin on Android

The existing ADMIN_PORTAL build flag selects both the admin entry screen and a separate Android package. No new backend or admin privileges are created.

| Build | Package | Phone label |
| --- | --- | --- |
| Normal (existing commands) | com.roadassist.app | RoadAssist |
| ADMIN_PORTAL=true | com.roadassist.admin | RoadAssist Admin |

Both apps can be installed together, with independent Firebase Auth sessions. Admin access still requires the existing custom claim, verified email and enabled adminAccess record. The normal app keeps its existing FirebaseOptions; Admin Android reads its registered native Firebase options. Web admin builds keep their existing web configuration.

## Current Firebase setup

The Admin Android app has been registered in the existing project as `com.roadassist.admin` (Firebase app ID `1:364238545986:android:5fa043c95004ed2f5b39db`). Its genuine client config has been merged into `android/app/google-services.json`, preserving the normal app client. The following setup instructions are for checkouts missing that client.

## One-time Firebase setup

In Firebase project `roadassist-lk-munshif`, add an Android app with package name `com.roadassist.admin` and nickname `RoadAssist Admin`. Download its real `google-services.json`. Do not rename the normal app package in its existing Firebase config.

From the project directory:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/configure-admin-firebase.ps1 -DownloadedConfig "C:\Users\ZIMTHI\Downloads\google-services.json"
powershell -ExecutionPolicy Bypass -File scripts/build-admin.ps1
```

The configure script checks the Firebase project/package and merges the admin client without removing the original client. Do not use a fabricated Firebase app ID.

## Build and install

```powershell
# Test build:
powershell -ExecutionPolicy Bypass -File scripts/build-admin.ps1 -Debug
# Release-mode APK:
powershell -ExecutionPolicy Bypass -File scripts/build-admin.ps1
# Run directly on a connected Android device:
flutter run -d <device-id> --dart-define=ADMIN_PORTAL=true
# Normal app remains:
flutter build apk --release
```

Install `build/app/outputs/flutter-apk/RoadAssist-Admin.apk` on your phone. Install normal RoadAssist separately. Sign in to Admin using your existing authorized admin account.

The current project signs release builds using the debug signing key. This is suitable for local testing, not a final production distribution configuration. Keep a stable private release keystore before distributing updates; installing an APK signed with a different key over an existing installation fails.

## Phone acceptance checks

Verify both icons/apps coexist and signing out of one does not sign out the other. Verify a non-admin account is denied access. With a real authorized admin account, check provider document viewing, approve/reject, complaint actions, user moderation, job monitoring, confirmation dialogs, keyboard/scroll behavior and network errors. Check narrow widths, large accessibility text and light/dark mode. These authenticated flows require a device and real test accounts; analyzer/build success alone does not verify them. Do not perform permanent deletion on a real account as a smoke test.

## Existing admin API settings

If your web admin build uses `ADMIN_ACCOUNT_DELETE_API_URL` or `PROVIDER_APPROVAL_EMAIL_API_URL`, pass the same deployed HTTPS endpoints to the Android build. Otherwise those features retain their existing unconfigured-endpoint behavior. Do not put private API keys or service-account credentials into Dart defines.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-admin.ps1 -DartDefinesFile "path/to/your-existing-admin-defines.json"
```

The APK built in this setup does not include optional admin API endpoint defines. Approval email and permanent deletion need explicit endpoint configuration; database admin operations retain existing behavior. A read-only check of the existing account-deletion endpoint returned HTTP 500, so that backend also needs repair before permanent deletion can be used. No accounts were deleted and no approval emails were sent during setup.
