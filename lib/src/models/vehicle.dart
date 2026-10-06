class Vehicle {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleType,
    required this.registration,
    required this.fuelType,
    required this.transmission,
    this.photoData = '',
  });
  final String id,
      make,
      model,
      vehicleType,
      registration,
      fuelType,
      transmission;
  final int year;
  final String photoData;
  String get label => '$make $model $year';
  Map<String, dynamic> toJson() => {
    'make': make,
    'model': model,
    'year': year,
    'vehicleType': vehicleType,
    'registration': registration,
    'fuelType': fuelType,
    'transmission': transmission,
    'photoData': photoData,
  };
  factory Vehicle.fromJson(String id, Map<String, dynamic> data) => Vehicle(
    id: id,
    make: data['make'] as String,
    model: data['model'] as String,
    year: (data['year'] as num).toInt(),
    vehicleType: data['vehicleType'] as String,
    registration: data['registration'] as String,
    fuelType: data['fuelType'] as String,
    transmission: data['transmission'] as String,
    photoData: data['photoData'] as String? ?? '',
  );
}
