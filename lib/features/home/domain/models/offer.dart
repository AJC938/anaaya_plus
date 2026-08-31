class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.badgeLabel,
    required this.ctaLabel,
  });

  final String id;

  /// Already resolved to the requested locale by [HomeRepository] — see
  /// [ServiceItem.name] for why content strings arrive pre-localized.
  final String title;
  final String description;

  /// Semantic asset key resolved by [AssetVisual] — not a file path, so the
  /// lookup can later point at a Firebase Storage URL instead.
  final String imageAsset;

  /// e.g. "20% OFF" or "Free" — the price/discount badge shown on the card.
  final String badgeLabel;
  final String ctaLabel;
}
