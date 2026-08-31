import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/localization/locale_text.dart';

/// The Services catalog entry. Carries both language variants directly
/// (rather than being pre-localized by the repository, as Home's
/// `ServiceItem` is) so a locale switch just re-renders Service Details —
/// no re-fetch needed.
///
/// Not the final Firestore schema — just enough structure to drive a real
/// catalog UI from data instead of hardcoded widget text.
class Service {
  const Service({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.category,
    required this.startingPrice,
    required this.estimatedDuration,
    required this.imageAsset,
    required this.isActive,
    required this.requiresVehicle,
    required this.requiresProductSelection,
    required this.includedItemsAr,
    required this.includedItemsEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String category;
  final double startingPrice;
  final Duration estimatedDuration;

  /// Semantic asset key resolved by [AssetVisual] — not a file path, so the
  /// lookup can later point at a Firebase Storage URL instead.
  final String imageAsset;

  final bool isActive;
  final bool requiresVehicle;
  final bool requiresProductSelection;
  final List<String> includedItemsAr;
  final List<String> includedItemsEn;

  String name(Locale locale) => pickLocalized(locale, ar: nameAr, en: nameEn);
  String description(Locale locale) => pickLocalized(locale, ar: descriptionAr, en: descriptionEn);
  List<String> includedItems(Locale locale) => locale.languageCode == 'ar' ? includedItemsAr : includedItemsEn;
}
