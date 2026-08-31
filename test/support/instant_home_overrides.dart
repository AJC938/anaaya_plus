import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:anaaya_plus/features/home/application/home_providers.dart';
import 'package:anaaya_plus/features/home/domain/models/home_user.dart';
import 'package:anaaya_plus/features/home/domain/models/offer.dart';
import 'package:anaaya_plus/features/home/domain/models/service_item.dart';
import 'package:anaaya_plus/features/home/domain/models/vehicle_summary.dart';

/// Every test in this app boots the real [AnaayaPlusApp], which always
/// starts at Home. Tests that aren't actually about Home's own content
/// (e.g. Services tests reached by navigating away from Home) still need
/// Home's data providers to resolve — otherwise the real
/// `MockHomeRepository`'s `Future.delayed` calls schedule uncancellable
/// timers that outlive the test and fail the "pending timer" teardown
/// check. These overrides resolve instantly with harmless empty/null data
/// so Home mounts cleanly without ever touching the real repository.
List<Override> instantHomeOverrides() {
  return [
    homeUserProvider.overrideWith((ref) async => const HomeUser(id: 'u0', name: 'Test')),
    homeVehiclesProvider.overrideWith((ref) async => const <VehicleSummary>[]),
    homeActiveBookingProvider.overrideWith((ref) async => null),
    homeServicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
    homeOffersProvider.overrideWith((ref) async => const <Offer>[]),
  ];
}
