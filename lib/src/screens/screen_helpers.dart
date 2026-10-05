part of '../screens.dart';

String requestIssueLabel(Map<String, dynamic> data) {
  final issues = (data['issues'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .where((issue) => issue.trim().isNotEmpty)
      .toList();
  return issues.isNotEmpty
      ? issues.join(' + ')
      : data['issue'] as String? ?? 'Roadside assistance';
}

String requestPriorityLabel(String priority) => switch (priority) {
  'urgent' => 'Urgent',
  'road_blocking' => 'Vehicle blocking road',
  'safety_risk' => 'Passenger safety risk',
  _ => 'Normal',
};

bool isHighPriority(String priority) => priority != 'normal';

RequestDraft requestDraftFromData(Map<String, dynamic> data) {
  final savedIssues = (data['issues'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList();
  return RequestDraft(
    vehicleId: data['vehicleId'] as String?,
    vehicleSnapshot: (data['vehicleSnapshot'] as Map?)?.cast<String, dynamic>(),
    issues: savedIssues.isNotEmpty
        ? savedIssues
        : [data['issue'] as String? ?? 'Roadside assistance'],
    vehicleType: data['vehicleType'] as String? ?? '',
    modelYear: data['modelYear'] as String? ?? '',
    registration: data['registration'] as String? ?? '',
    description: data['description'] as String? ?? '',
    notes: data['notes'] as String? ?? '',
    priority: data['priority'] as String? ?? 'normal',
    partsPreference: data['partsPreference'] as String? ?? 'discuss',
    location: data['locationLabel'] as String? ?? 'Pinned location',
    landmark: data['landmark'] as String? ?? '',
    locationAccuracyMeters: (data['locationAccuracyMeters'] as num?)
        ?.toDouble(),
    latitude: (data['latitude'] as num?)?.toDouble() ?? 6.9034,
    longitude: (data['longitude'] as num?)?.toDouble() ?? 79.8525,
    provider:
        data['providerName'] as String? ??
        data['preferredProviderName'] as String? ??
        '',
    preferredProviderId: data['preferredProviderId'] as String? ?? '',
    vehiclePhotoUrls: (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    photoAnnotations: (data['photoAnnotations'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => BreakdownPhotoAnnotation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(),
  );
}

bool get firebaseReady => Firebase.apps.isNotEmpty;
bool get signedIn => firebaseReady && FirebaseAuth.instance.currentUser != null;

// Email actions are delivered through the authenticated RoadAssist Vercel API
// while Firebase Support case 10427798 remains open.
const enforceEmailVerification = true;

String normalizeSriLankaPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('07') && digits.length == 10) {
    return '+94${digits.substring(1)}';
  }
  if (digits.startsWith('947') && digits.length == 11) return '+$digits';
  return digits;
}

String? validateSriLankaPhone(String? value) {
  final phone = normalizeSriLankaPhone(value?.trim() ?? '');
  return RegExp(r'^\+947\d{8}$').hasMatch(phone)
      ? null
      : 'Use a valid Sri Lankan mobile number (e.g. 077 123 4567)';
}

String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)
      ? null
      : 'Enter a valid email address';
}

String normalizeVehicleRegistration(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*-\s*'), '-');

String? validateVehicleRegistration(String? value) {
  final registration = normalizeVehicleRegistration(value ?? '');
  return RegExp(r'^(?:[A-Z]{1,3}\s*){1,2}-?\s*\d{4}$').hasMatch(registration)
      ? null
      : 'Use a format such as WP CAB-1234 or CAA-1234';
}

String? validateVehicleModelYear(String? value) {
  final model = value?.trim() ?? '';
  if (model.length < 3 || !RegExp(r'[A-Za-z]').hasMatch(model)) {
    return 'Enter the vehicle model and year';
  }
  final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(model);
  final year = int.tryParse(match?.group(0) ?? '');
  if (year == null || year < 1950 || year > DateTime.now().year + 1) {
    return 'Include a valid year, e.g. Toyota Aqua 2018';
  }
  return null;
}

String? validateCustomVehicleType(String? value) {
  final type = value?.trim() ?? '';
  if (type.isEmpty) return 'Enter your vehicle type';
  if (type.length < 2 || !RegExp(r'[A-Za-z]').hasMatch(type)) {
    return 'Enter a valid vehicle type';
  }
  return null;
}

String? validateBreakdownDescription(String? value) {
  // The selected assistance type already identifies the problem. Drivers can
  // add extra context here when it is safe and convenient to type.
  return null;
}

// ============================================================
// SPLASH / ONBOARDING
// ============================================================
