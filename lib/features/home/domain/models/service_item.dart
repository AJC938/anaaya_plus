class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.startingPrice,
    required this.imageAsset,
  });

  final String id;

  /// Already resolved to the requested locale by [HomeRepository] — services
  /// are a small, curated catalog, so the mock (and later Firestore) source
  /// returns locale-appropriate text directly rather than an app-string key.
  final String name;
  final String category;
  final double startingPrice;

  /// Semantic asset key resolved by [AssetVisual] — not a file path, so the
  /// lookup can later point at a Firebase Storage URL instead.
  final String imageAsset;
}
