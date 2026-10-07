# RoadAssist page-wise structure

Screens are grouped by feature so each page is easy to find. Existing screen APIs and Firebase behavior are preserved.

## Feature folders

| Folder | Purpose |
|---|---|
| `lib/src/features/auth/` | Auth pages |
| `lib/src/features/driver/` | Driver pages |
| `lib/src/features/vehicles/` | Vehicles pages |
| `lib/src/features/request/` | Request pages |
| `lib/src/features/provider/` | Provider pages |
| `lib/src/features/admin/` | Admin pages |
| `lib/src/features/settings/` | Settings pages |
| `lib/src/features/support/` | Support pages |
| `lib/src/features/chat/` | Chat pages |
| `lib/src/features/billing/` | Billing pages |
| `lib/src/features/complaints/` | Complaints pages |
| `lib/src/features/media/` | Media pages |

Theme: `lib/src/core/theme/app_theme.dart`. Shared screen helpers/notices: `lib/src/shared/`. Shared UI: `lib/src/widgets/`. Models: `lib/src/models/`. Firebase/API/device logic: `lib/src/services/`.

## Authentication

`login_screen.dart` is the sign-in entry. `registration_screen.dart` is the registration entry. Both reuse `auth_form.dart` for existing fields, validators, controller lifecycle and AuthService calls. The current Sign In/Create Account switch remains compatible; separating files does not change account creation or role handling.

## Dart library compatibility

`screens.dart` now serves as an index of part files, not the page implementation. These files still share a Dart library so private helpers and cross-page navigation remain valid. They are not independently importable Dart libraries. This refactor deliberately does not claim to have removed the part architecture. Application/tests continue to import `screens.dart`.

## Viva explanation

“I group pages by feature. A screen file owns its page UI, services handle Firebase and device operations, models describe data, and shared widgets avoid duplicated components. screens.dart connects the page files into the existing Dart library.”

## File moves

| Previous | Current |
|---|---|
| `lib/src/screens/splash_screen.dart` | `lib/src/features/auth/splash_screen.dart` |
| `lib/src/screens/legacy_welcome_screen.dart` | `lib/src/features/auth/legacy_welcome_screen.dart` |
| `lib/src/screens/welcome_screen.dart` | `lib/src/features/auth/welcome_screen.dart` |
| `lib/src/screens/role_selection_screen.dart` | `lib/src/features/auth/role_selection_screen.dart` |
| `lib/src/screens/login_screen.dart` | `lib/src/features/auth/login_screen.dart` |
| `lib/src/screens/email_verification_screen.dart` | `lib/src/features/auth/email_verification_screen.dart` |
| `lib/src/screens/driver_shell.dart` | `lib/src/features/driver/driver_shell.dart` |
| `lib/src/screens/driver_home_screen.dart` | `lib/src/features/driver/driver_home_screen.dart` |
| `lib/src/screens/driver_notifications_screen.dart` | `lib/src/features/driver/driver_notifications_screen.dart` |
| `lib/src/screens/driver_profile_screen.dart` | `lib/src/features/driver/driver_profile_screen.dart` |
| `lib/src/screens/history_screen.dart` | `lib/src/features/driver/history_screen.dart` |
| `lib/src/screens/driver_request_details_screen.dart` | `lib/src/features/driver/driver_request_details_screen.dart` |
| `lib/src/screens/realtime_driver_request_details_screen.dart` | `lib/src/features/driver/realtime_driver_request_details_screen.dart` |
| `lib/src/screens/provider_directory_screen.dart` | `lib/src/features/driver/provider_directory_screen.dart` |
| `lib/src/screens/emergency_screen.dart` | `lib/src/features/driver/emergency_screen.dart` |
| `lib/src/screens/vehicles_screen.dart` | `lib/src/features/vehicles/vehicles_screen.dart` |
| `lib/src/screens/breakdown_details_screen.dart` | `lib/src/features/request/breakdown_details_screen.dart` |
| `lib/src/screens/location_screen.dart` | `lib/src/features/request/location_screen.dart` |
| `lib/src/screens/providers_screen.dart` | `lib/src/features/request/providers_screen.dart` |
| `lib/src/screens/review_screen.dart` | `lib/src/features/request/review_screen.dart` |
| `lib/src/screens/searching_screen.dart` | `lib/src/features/request/searching_screen.dart` |
| `lib/src/screens/tracking_screen.dart` | `lib/src/features/request/tracking_screen.dart` |
| `lib/src/screens/gps_issue_screen.dart` | `lib/src/features/request/gps_issue_screen.dart` |
| `lib/src/screens/provider_shell.dart` | `lib/src/features/provider/provider_shell.dart` |
| `lib/src/screens/provider_home_screen.dart` | `lib/src/features/provider/provider_home_screen.dart` |
| `lib/src/screens/provider_notifications_screen.dart` | `lib/src/features/provider/provider_notifications_screen.dart` |
| `lib/src/screens/provider_history_screen.dart` | `lib/src/features/provider/provider_history_screen.dart` |
| `lib/src/screens/provider_profile_screen.dart` | `lib/src/features/provider/provider_profile_screen.dart` |
| `lib/src/screens/provider_active_job_screen.dart` | `lib/src/features/provider/provider_active_job_screen.dart` |
| `lib/src/screens/provider_completed_screen.dart` | `lib/src/features/provider/provider_completed_screen.dart` |
| `lib/src/screens/provider_case_details_screen.dart` | `lib/src/features/provider/provider_case_details_screen.dart` |
| `lib/src/screens/provider_request_details_screen.dart` | `lib/src/features/provider/provider_request_details_screen.dart` |
| `lib/src/screens/customer_contact_screen.dart` | `lib/src/features/provider/customer_contact_screen.dart` |
| `lib/src/screens/provider_verification_screen.dart` | `lib/src/features/provider/provider_verification_screen.dart` |
| `lib/src/screens/provider_professional_fields.dart` | `lib/src/features/provider/provider_professional_fields.dart` |
| `lib/src/screens/admin_portal_screen.dart` | `lib/src/features/admin/admin_portal_screen.dart` |
| `lib/src/screens/admin_user_activity.dart` | `lib/src/features/admin/admin_user_activity.dart` |
| `lib/src/screens/admin_verification_panel.dart` | `lib/src/features/admin/admin_verification_panel.dart` |
| `lib/src/screens/admin_operations_screen.dart` | `lib/src/features/admin/admin_operations_content.dart` |
| `lib/src/screens/account_security_screen.dart` | `lib/src/features/settings/account_security_screen.dart` |
| `lib/src/screens/notification_settings_screen.dart` | `lib/src/features/settings/notification_settings_screen.dart` |
| `lib/src/screens/privacy_safety_screen.dart` | `lib/src/features/settings/privacy_safety_screen.dart` |
| `lib/src/screens/appearance_screen.dart` | `lib/src/features/settings/appearance_screen.dart` |
| `lib/src/screens/support_screen.dart` | `lib/src/features/support/support_screen.dart` |
| `lib/src/screens/chat_screen.dart` | `lib/src/features/chat/chat_screen.dart` |
| `lib/src/screens/invoice_screen.dart` | `lib/src/features/billing/invoice_screen.dart` |
| `lib/src/screens/dispute_screen.dart` | `lib/src/features/complaints/dispute_screen.dart` |
| `lib/src/screens/camera_capture_screen.dart` | `lib/src/features/media/camera_capture_screen.dart` |
| `lib/src/screens/screen_helpers.dart` | `lib/src/shared/screen_helpers.dart` |
| `lib/src/screens/service_notice.dart` | `lib/src/shared/service_notice.dart` |

The previous combined admin file is further split into portal, dashboard, account, complaint, audit detail, job monitor and shared admin components. Each of the eleven tab pages has its own named file. VehiclesScreen and VehicleEditorScreen now have distinct files; provider access gating and verification application also have distinct files. Chat inbox page and inbox preview widget are separated.
