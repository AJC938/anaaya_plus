import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/localization/locale_text.dart';

/// A service location the technician will travel to. Carries both language
/// variants directly (like Services' `Service`), so a locale switch just
/// re-renders — no re-fetch needed.
///
/// Not a real address/geocoding record — see [LocationRepository] for the
/// seam a real Places/Maps integration would replace.
class BookingLocation {
  const BookingLocation({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.cityAr,
    required this.cityEn,
    required this.districtAr,
    required this.districtEn,
    this.addressLineAr,
    this.addressLineEn,
    required this.latitude,
    required this.longitude,
    required this.isSimulatedCurrentLocation,
  });

  final String id;
  final String labelAr;
  final String labelEn;
  final String cityAr;
  final String cityEn;
  final String districtAr;
  final String districtEn;
  final String? addressLineAr;
  final String? addressLineEn;
  final double latitude;
  final double longitude;

  /// True only for the mock "Current Location" entry — the UI must make
  /// clear this is simulated, never a real GPS fix.
  final bool isSimulatedCurrentLocation;

  String label(Locale locale) => pickLocalized(locale, ar: labelAr, en: labelEn);
  String city(Locale locale) => pickLocalized(locale, ar: cityAr, en: cityEn);
  String district(Locale locale) => pickLocalized(locale, ar: districtAr, en: districtEn);
  String? addressLine(Locale locale) {
    final ar = addressLineAr;
    final en = addressLineEn;
    if (ar == null || en == null) return null;
    return pickLocalized(locale, ar: ar, en: en);
  }
}
