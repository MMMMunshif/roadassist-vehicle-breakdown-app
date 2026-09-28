# RoadAssist two-phone test

APK: `build/app/outputs/flutter-apk/app-debug.apk`

## Install

1. Copy the APK to both Android phones.
2. Allow installation from the selected file manager when Android asks.
3. Install RoadAssist on both phones and keep internet, GPS and notifications enabled.

## Create the accounts

Phone A:

1. Select **I am a Driver**.
2. Choose **Create Account**.
3. Register with a unique driver email, Sri Lankan phone number and password.

Phone B:

1. Select **I am a Service Provider**.
2. Choose **Create Account**.
3. Register with a different provider email, phone number and password.

Do not use the same email for both roles.

## Realtime request test

1. Keep the provider online on Phone B.
2. On Phone A, create a roadside request and confirm it.
3. The request should appear on Phone B without refreshing.
4. Accept it on Phone B.
5. Phone A should automatically move from searching to live tracking.

## Status, location and chat test

1. On Phone B, advance the job through **En Route**, **Arrived** and **Completed**.
2. Confirm every status changes on Phone A in real time.
3. Open Chat on both phones and send messages in both directions.
4. Move Phone B at least 25 metres and confirm its map marker updates on Phone A.
5. Tap Call and confirm the correct phone number opens in the device dialer.

## Expected permissions

- Driver: location and notifications.
- Provider: location and notifications.
- Provider location is shared only while the active-job screen is open.
