import 'models/admin_audit_presentation.dart';
import 'services/admin_identity_service.dart';
import 'models/admin_earnings_report.dart';
import 'services/admin_earnings_pdf_service.dart';
import 'models/provider_document_correction.dart';
import 'models/completion_report.dart';
import 'models/service_invoice.dart';
import 'services/invoice_pdf_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontVariation, ImageFilter;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:speech_to_text/speech_to_text.dart';

import 'app.dart';
import 'models/request_draft.dart';
import 'models/location_freshness.dart';
import 'models/account_roles.dart';
import 'models/vehicle.dart';
import 'models/provider_availability.dart';
import 'models/provider_analytics.dart';
import 'services/report_export.dart';
import 'models/repair_revision.dart';
import 'services/vehicle_service.dart';
import 'services/vehicle_image_service.dart';
import 'services/auth_service.dart';
import 'services/admin_service.dart';
import 'services/provider_verification_service.dart';
import 'services/chat_inbox_controller.dart';
import 'services/device_service.dart';
import 'services/request_service.dart';
import 'services/job_start_service.dart';
import 'services/request_draft_store.dart';
import 'services/photo_upload_service.dart';
import 'services/route_service.dart';

// Screen files share this library's imports and private helpers.
part 'features/request/assistance_type_screen.dart';
part 'shared/screen_helpers.dart';
part 'features/vehicles/vehicles_screen.dart';
part 'features/billing/invoice_screen.dart';
part 'features/billing/invoice_bill_view.dart';
part 'features/complaints/dispute_screen.dart';
part 'widgets/shared_widgets.dart';
part 'widgets/themed_scaffold.dart';
part 'widgets/provider_design.dart';
part 'widgets/driver_design.dart';
part 'widgets/admin_design.dart';
part 'widgets/admin_provider_activity.dart';
part 'widgets/admin_operations_chart.dart';
part 'widgets/admin_earnings_report_panel.dart';
part 'widgets/provider_correction_dialog.dart';
part 'widgets/quote_offers.dart';
part 'widgets/chat_inbox.dart';
part 'widgets/repair_quote_panel.dart';
part 'widgets/job_start_code_panel.dart';
part 'widgets/live_location_status.dart';
part 'widgets/complaint_progress_panel.dart';
part 'widgets/completion_review_panel.dart';
part 'widgets/provider_earnings_panel.dart';
part 'features/auth/splash_screen.dart';
part 'features/auth/legacy_welcome_screen.dart';
part 'features/auth/welcome_screen.dart';
part 'features/auth/role_selection_screen.dart';
part 'features/auth/login_screen.dart';
part 'features/auth/email_verification_screen.dart';
part 'features/settings/account_security_screen.dart';
part 'features/admin/admin_portal_screen.dart';
part 'features/admin/admin_user_activity.dart';
part 'features/provider/provider_verification_screen.dart';
part 'features/provider/provider_professional_fields.dart';
part 'features/admin/admin_verification_panel.dart';
part 'features/admin/admin_operations_content.dart';
part 'shared/service_notice.dart';
part 'features/settings/notification_settings_screen.dart';
part 'features/driver/driver_shell.dart';
part 'features/driver/driver_home_screen.dart';
part 'features/driver/driver_notifications_screen.dart';
part 'features/driver/provider_directory_screen.dart';
part 'features/request/breakdown_details_screen.dart';
part 'features/media/camera_capture_screen.dart';
part 'features/request/location_screen.dart';
part 'features/request/providers_screen.dart';
part 'features/request/review_screen.dart';
part 'features/request/searching_screen.dart';
part 'features/driver/history_screen.dart';
part 'features/driver/realtime_driver_request_details_screen.dart';
part 'features/driver/driver_profile_screen.dart';
part 'features/support/support_screen.dart';
part 'features/settings/privacy_safety_screen.dart';
part 'features/driver/emergency_screen.dart';
part 'features/provider/provider_shell.dart';
part 'features/provider/provider_home_screen.dart';
part 'features/provider/provider_notifications_screen.dart';
part 'features/provider/provider_history_screen.dart';
part 'features/provider/provider_profile_screen.dart';
part 'features/request/tracking_screen.dart';
part 'features/chat/chat_screen.dart';
part 'features/provider/provider_active_job_screen.dart';
part 'features/provider/provider_completed_screen.dart';
part 'features/driver/driver_request_details_screen.dart';
part 'features/provider/provider_case_details_screen.dart';
part 'features/request/gps_issue_screen.dart';
part 'features/provider/provider_request_details_screen.dart';
part 'features/provider/customer_contact_screen.dart';

part 'widgets/service_warranty.dart';
part 'widgets/vehicle_photo_preview.dart';

part 'features/vehicles/vehicle_editor_screen.dart';

part 'features/provider/provider_access_gate.dart';

part 'features/auth/auth_form.dart';

part 'features/auth/registration_screen.dart';

part 'features/admin/admin_dashboard_screen.dart';

part 'features/admin/admin_overview_content.dart';

part 'features/admin/admin_records.dart';

part 'features/admin/admin_action_dialog.dart';

part 'features/admin/admin_account_screen.dart';

part 'features/admin/admin_complaint_screen.dart';

part 'features/admin/admin_audit_detail_screen.dart';

part 'features/admin/account_access_gate.dart';

part 'features/admin/admin_user_row.dart';

part 'features/admin/admin_job_monitor_screen.dart';

part 'features/admin/admin_private_notes.dart';

part 'features/admin/admin_status_badge.dart';

part 'features/admin/admin_overview_screen.dart';

part 'features/admin/admin_providers_screen.dart';

part 'features/admin/admin_users_screen.dart';

part 'features/admin/admin_complaints_screen.dart';

part 'features/admin/admin_jobs_screen.dart';

part 'features/admin/admin_audit_screen.dart';

part 'features/admin/admin_operations_screen.dart';

part 'features/admin/admin_payments_screen.dart';

part 'features/admin/admin_reports_screen.dart';

part 'features/admin/admin_settings_screen.dart';

part 'features/admin/admin_team_screen.dart';

part 'features/chat/chat_inbox_screen.dart';

part 'features/auth/auth_visuals.dart';

part 'features/auth/role_email_gate.dart';
