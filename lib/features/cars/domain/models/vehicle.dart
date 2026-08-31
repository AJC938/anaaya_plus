/// The canonical vehicle model — deliberately minimal. Cars is not a
/// vehicle-management system: only fields that matter for the service
/// experience (compatibility, product selection, booking association)
/// belong here. Do not add fields (VIN, mileage, color, insurance, ...)
/// without an explicit product requirement.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
    required this.imageAsset,
    required this.isDefault,
  });

  /// System-generated — the user never enters this.
  final String id;

  final String make;
  final String model;
  final int year;
  final String plateNumber;

  /// Semantic asset key resolved by [AssetVisual].
  final String imageAsset;

  final bool isDefault;

  String get displayName => '$make $model';

  Vehicle copyWith({String? make, String? model, int? year, String? plateNumber, bool? isDefault}) {
    return Vehicle(
      id: id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      plateNumber: plateNumber ?? this.plateNumber,
      imageAsset: imageAsset,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
