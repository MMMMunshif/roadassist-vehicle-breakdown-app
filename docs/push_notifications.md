# Background push notifications

Implemented: notification preferences in Account Security, permission requested only on explicit enable, account-wide disable, device token refresh/sign-out cleanup, foreground View action, notification tap routing on web/Android, and server alerts for new requests, provider offers, job status, chat (including completed jobs), repair approval decisions, and payment reports/confirmation.

## Activation

1. Firebase Console -> Project settings -> Cloud Messaging -> Web Push certificates. Generate a key pair if absent and copy the PUBLIC key. Never copy a private key.
2. Stop and restart Flutter (hot reload cannot change dart-define):

```powershell
flutter run -d chrome --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_PUBLIC_KEY
```

3. Ask the project owner whether Blaze billing is already enabled. Functions deployment requires Blaze; do not upgrade billing without the owner's agreement. Once confirmed, install dependencies and deploy from the project root:

```powershell
Push-Location functions
npm.cmd install
Pop-Location
.\tools\rules-tests\node_modules\.bin\firebase.cmd deploy --only functions:notifications --project roadassist-lk-munshif
```

Functions target Node 22 and asia-south1. Use Node 22 for local installation and deployment. No service-account private key or client-side sending credential is required. Firebase Admin uses the function's runtime credentials.

4. On each account/device, open Account Security -> Push notifications -> Enable. Test with separate normal browser profiles or two phones. Web push requires HTTPS or localhost and browser notification permission.
5. Send a chat message with the other app in the background, tap the notification, and verify it opens the correct account's chat. Repeat provider offers, repair proposals/decisions, job completion, and payment confirmation. Disable notifications and verify subsequent pushes stop. Sign out and confirm the device stops receiving that account's messages.

## Delivery limits

These are event-triggered notification messages, not an online payment processor. Chat contents are excluded from lock-screen payloads. Notification links check the signed-in recipient and read the request through Firestore rules before opening it.

Server delivery receipts in notificationDeliveries reduce duplicate sends and invalid tokens are removed. Rare duplicates remain possible if a process stops immediately after FCM accepts a send. FCM acceptance does not guarantee the browser displays a notification. Configure a Firestore TTL policy on notificationDeliveries.expiresAt to clean up receipts; TTL deletion may incur Firestore usage charges.

Activation and actual browser/device delivery remain unverified until the public key is supplied and the Cloud Functions are deployed. Existing in-app real-time notifications continue independently.

References: https://firebase.google.com/docs/cloud-messaging/flutter/get-started and https://firebase.google.com/docs/functions/get-started