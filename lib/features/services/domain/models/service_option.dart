import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/localization/locale_text.dart';

/// A selectable product/option for a [Service] that `requiresProductSelection`
/// (e.g. an oil grade for Oil Change). Not a general e-commerce product —
/// just enough structure for a mock Services catalog.
class ServiceOption {
  const ServiceOption({
    required this.id,
    required this.serviceId,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.price,
    required this.imageAsset,
    required this.compatibleVehicleIds,
    required this.isAvailable,
  });

  final String id;
  final String serviceId;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;

  /// Added on top of the service's starting price when this option is
  /// selected — see `calculatePrice` in domain/pricing.dart.
  final double price;

  /// Semantic asset key resolved by [AssetVisual] — this option's own
  /// product image, not its parent [Service]'s.
  final String imageAsset;

  /// Compatibility rule: an EMPTY list means universally compatible (works
  /// with any vehicle). A non-empty list is an explicit allow-list of
  /// vehicle IDs. This is the only compatibility rule this mock model
  /// expresses — a real fitment engine would replace the call site, not
  /// this field.
  final List<String> compatibleVehicleIds;

  final bool isAvailable;

  String name(Locale locale) => pickLocalized(locale, ar: nameAr, en: nameEn);
  String description(Locale locale) => pickLocalized(locale, ar: descriptionAr, en: descriptionEn);

  bool isCompatibleWith(String vehicleId) => compatibleVehicleIds.isEmpty || compatibleVehicleIds.contains(vehicleId);
}
