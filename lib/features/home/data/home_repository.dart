import 'package:flutter/widgets.dart' show Locale;

import '../domain/models/home_booking_summary.dart';
import '../domain/models/home_user.dart';
import '../domain/models/offer.dart';
import '../domain/models/service_item.dart';
import '../domain/models/vehicle_summary.dart';

/// Data seam for the Home dashboard. [MockHomeRepository] is the only
/// implementation for this milestone; a Firebase-backed implementation can
/// replace it later without the Home widgets or providers changing.
///
/// Content-bearing calls take the requested [Locale] and return text already
/// resolved to it (services are a small curated catalog, the same way a real
/// backend would localize based on the request) — Home's UI chrome strings
/// still go through gen-l10n as usual.
abstract class HomeRepository {
  Future<HomeUser> fetchUser();
  Future<List<VehicleSummary>> fetchVehicles();
  Future<HomeBookingSummary?> fetchActiveBooking(Locale locale);
  Future<List<ServiceItem>> fetchServices(Locale locale);
  Future<List<Offer>> fetchOffers(Locale locale);
}
