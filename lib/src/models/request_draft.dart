int serviceFeeForIssue(String issue) => switch (issue) {
  'Vehicle Towing' => 3500,
  'General Mechanic' => 2200,
  'Flat Tyre' => 1500,
  'Battery Jumpstart' => 1400,
  _ => 1800,
};

int dispatchFeeForIssue(String issue) => switch (issue) {
  'Vehicle Towing' => 750,
  'General Mechanic' => 500,
  _ => 400,
};

int estimatedCostForIssue(String issue) =>
    serviceFeeForIssue(issue) + dispatchFeeForIssue(issue);

class RequestDraft {
  const RequestDraft({
    required this.issue,
    required this.vehicleType,
    required this.modelYear,
    required this.registration,
    required this.description,
    this.notes = '',
    this.location = 'Select current GPS or enter location manually',
    this.latitude = 6.9271,
    this.longitude = 79.8612,
    this.provider = '',
    this.preferredProviderId = '',
    this.vehiclePhotoUrls = const [],
  });

  final String issue;
  final String vehicleType;
  final String modelYear;
  final String registration;
  final String description;
  final String notes;
  final String location;
  final double latitude;
  final double longitude;
  final String provider;
  final String preferredProviderId;
  final List<String> vehiclePhotoUrls;

  int get serviceFee => serviceFeeForIssue(issue);

  int get dispatchFee => dispatchFeeForIssue(issue);

  int get estimatedCost => serviceFee + dispatchFee;

  RequestDraft copyWith({
    String? location,
    double? latitude,
    double? longitude,
    String? provider,
    String? preferredProviderId,
    List<String>? vehiclePhotoUrls,
  }) => RequestDraft(
    issue: issue,
    vehicleType: vehicleType,
    modelYear: modelYear,
    registration: registration,
    description: description,
    notes: notes,
    location: location ?? this.location,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    provider: provider ?? this.provider,
    preferredProviderId: preferredProviderId ?? this.preferredProviderId,
    vehiclePhotoUrls: vehiclePhotoUrls ?? this.vehiclePhotoUrls,
  );
}
