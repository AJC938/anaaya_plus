/// Lightweight vehicle projection for Home (existence checks, quick access).
/// Not the full Cars-feature Vehicle model.
class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
    required this.imageAsset,
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String plateNumber;

  /// Semantic asset key resolved by [AssetVisual] — not a file path, so the
  /// lookup can later point at a Firebase Storage URL instead.
  final String imageAsset;

  String get displayName => '$make $model';
}
