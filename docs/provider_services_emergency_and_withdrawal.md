# Provider services, emergency access and application withdrawal

Additional services are declared in the verification application as up to five name/description/category records. Fuel delivery, lockout, electrical and overheating work can be added under an appropriate existing matching category. Categories remain the four existing approved roadside categories, so existing requests and older APKs continue matching normally. Every additional service category must be selected in the application. New service declarations are reviewed with the application; approved providers cannot silently change their reviewed application.

Provider selfie is required and private already. The upload is now labelled clearly, camera capture prefers the front camera, and the admin review shows selfie and NIC together (stacked on narrow screens). Gallery upload remains available. This is manual visual review, not biometric verification or liveness detection.

Pending providers can continue as drivers using the same verified account. Roles are enrolled without duplicating Firebase users or cancelling the pending application. Withdrawal preserves private documents and sets applicationStatus=withdrawn. Owner-only rules forbid document changes during withdrawal and forbid withdrawal after approval/rejection. Admin approval reads the application in its transaction and rules reject withdrawn applications. Apply Again restores editing and resubmits a new revision; old approval revisions cannot grant access. Withdrawn applications disappear from the pending-only admin list and remain labelled in account history.

Emergency hotlines are built into the screen and work without authentication, Firestore, or internet: 1990 ambulance, 119 police, 110 fire/rescue, 117 disaster management. Calling opens the platform dialer. GPS is requested only on tap; the current location can be copied or shared using an SMS composer (nothing is sent automatically). GPS/call/SMS availability depends on the device.

Sources checked: https://www.1990.lk/ ; https://www.police.lk/?page_id=1334 ; https://www.police.lk/wp-content/uploads/2025/12/Media-on-2025.12.18-at-1530-_compressed.pdf ; https://117.dmc.gov.lk/

Verification: local Firestore emulator workflow tests plus Flutter emergency/email-role regression tests. A real signed-in phone walkthrough, selfie-camera capture, dialer and SMS composer still require device verification. New APK builds are required to install these client changes.
