class BreakdownPhotoAnnotation {
  const BreakdownPhotoAnnotation({
    required this.photoIndex,
    required this.markerX,
    required this.markerY,
    this.note = '',
  });

  final int photoIndex;
  final double markerX;
  final double markerY;
  final String note;

  Map<String, dynamic> toJson() => {
    'photoIndex': photoIndex,
    'markerX': markerX,
    'markerY': markerY,
    'note': note,
  };

  factory BreakdownPhotoAnnotation.fromJson(Map<String, dynamic> json) =>
      BreakdownPhotoAnnotation(
        photoIndex: (json['photoIndex'] as num?)?.toInt() ?? 0,
        markerX: ((json['markerX'] as num?)?.toDouble() ?? .5).clamp(0.0, 1.0),
        markerY: ((json['markerY'] as num?)?.toDouble() ?? .5).clamp(0.0, 1.0),
        note: json['note'] as String? ?? '',
      );
}

class RequestDraft {
  const RequestDraft({
    required this.issues,
    required this.vehicleType,
    required this.modelYear,
    required this.registration,
    required this.description,
    this.vehicleId,
    this.vehicleSnapshot,
    this.partsPreference = 'discuss',
    this.notes = '',
    this.priority = 'normal',
    this.location = 'Select current GPS or enter location manually',
    this.landmark = '',
    this.locationAccuracyMeters,
    this.latitude = 6.9271,
    this.longitude = 79.8612,
    this.provider = '',
    this.preferredProviderId = '',
    this.vehiclePhotoUrls = const [],
    this.photoAnnotations = const [],
  }) : assert(issues.length > 0);

  final List<String> issues;
  final String? vehicleId;
  final Map<String, dynamic>? vehicleSnapshot;
  final String partsPreference;
  final String vehicleType;
  final String modelYear;
  final String registration;
  final String description;
  final String notes;
  final String priority;
  final String location;
  final String landmark;
  final double? locationAccuracyMeters;
  final double latitude;
  final double longitude;
  final String provider;
  final String preferredProviderId;
  final List<String> vehiclePhotoUrls;
  final List<BreakdownPhotoAnnotation> photoAnnotations;

  String get primaryIssue => issues.first;
  String get issue => issues.join(' + ');

  RequestDraft copyWith({
    String? vehicleId,
    Map<String, dynamic>? vehicleSnapshot,
    String? partsPreference,
    List<String>? issues,
    String? vehicleType,
    String? modelYear,
    String? registration,
    String? description,
    String? notes,
    String? priority,
    String? location,
    String? landmark,
    double? locationAccuracyMeters,
    bool clearLocationAccuracy = false,
    double? latitude,
    double? longitude,
    String? provider,
    String? preferredProviderId,
    List<String>? vehiclePhotoUrls,
    List<BreakdownPhotoAnnotation>? photoAnnotations,
  }) => RequestDraft(
    vehicleId: vehicleId ?? this.vehicleId,
    vehicleSnapshot: vehicleSnapshot ?? this.vehicleSnapshot,
    partsPreference: partsPreference ?? this.partsPreference,
    issues: issues ?? this.issues,
    vehicleType: vehicleType ?? this.vehicleType,
    modelYear: modelYear ?? this.modelYear,
    registration: registration ?? this.registration,
    description: description ?? this.description,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    location: location ?? this.location,
    landmark: landmark ?? this.landmark,
    locationAccuracyMeters: clearLocationAccuracy
        ? null
        : locationAccuracyMeters ?? this.locationAccuracyMeters,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    provider: provider ?? this.provider,
    preferredProviderId: preferredProviderId ?? this.preferredProviderId,
    vehiclePhotoUrls: vehiclePhotoUrls ?? this.vehiclePhotoUrls,
    photoAnnotations: photoAnnotations ?? this.photoAnnotations,
  );

  Map<String, dynamic> toJson() => {
    if (vehicleId != null) 'vehicleId': vehicleId,
    if (vehicleSnapshot != null) 'vehicleSnapshot': vehicleSnapshot,
    'partsPreference': partsPreference,
    'issues': issues,
    'vehicleType': vehicleType,
    'modelYear': modelYear,
    'registration': registration,
    'description': description,
    'notes': notes,
    'priority': priority,
    'location': location,
    'landmark': landmark,
    'locationAccuracyMeters': locationAccuracyMeters,
    'latitude': latitude,
    'longitude': longitude,
    'provider': provider,
    'preferredProviderId': preferredProviderId,
    'vehiclePhotoUrls': vehiclePhotoUrls,
    'photoAnnotations': photoAnnotations.map((item) => item.toJson()).toList(),
  };

  factory RequestDraft.fromJson(Map<String, dynamic> json) {
    final savedIssues = (json['issues'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((issue) => issue.trim().isNotEmpty)
        .toList();
    final legacyIssue = json['issue'] as String?;
    return RequestDraft(
      vehicleId: json['vehicleId'] as String?,
      partsPreference: json['partsPreference'] as String? ?? 'discuss',
      vehicleSnapshot: (json['vehicleSnapshot'] as Map?)
          ?.cast<String, dynamic>(),
      issues: savedIssues.isNotEmpty
          ? savedIssues
          : [
              legacyIssue?.trim().isNotEmpty == true
                  ? legacyIssue!
                  : 'General Mechanic',
            ],
      vehicleType: json['vehicleType'] as String? ?? 'Sedan / Hatchback',
      modelYear: json['modelYear'] as String? ?? '',
      registration: json['registration'] as String? ?? '',
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      priority: switch (json['priority']) {
        'urgent' => 'urgent',
        'road_blocking' => 'road_blocking',
        'safety_risk' => 'safety_risk',
        _ => 'normal',
      },
      location:
          json['location'] as String? ??
          'Select current GPS or enter location manually',
      landmark: json['landmark'] as String? ?? '',
      locationAccuracyMeters: (json['locationAccuracyMeters'] as num?)
          ?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 79.8612,
      provider: json['provider'] as String? ?? '',
      preferredProviderId: json['preferredProviderId'] as String? ?? '',
      vehiclePhotoUrls: (json['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .take(3)
          .toList(),
      photoAnnotations: (json['photoAnnotations'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => BreakdownPhotoAnnotation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .take(3)
          .toList(),
    );
  }
}
