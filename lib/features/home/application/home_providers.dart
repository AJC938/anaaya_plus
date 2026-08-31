import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../data/home_repository.dart';
import '../data/mock_home_repository.dart';
import '../domain/models/home_booking_summary.dart';
import '../domain/models/home_user.dart';
import '../domain/models/offer.dart';
import '../domain/models/service_item.dart';
import '../domain/models/vehicle_summary.dart';

/// Which mock backend state Home should render. Tests override this (or the
/// individual data providers below) to exercise specific states; the running
/// app defaults to a populated dashboard with an upcoming booking.
class HomeMockScenarioController extends Notifier<HomeMockScenario> {
  @override
  HomeMockScenario build() => HomeMockScenario.upcomingBooking;

  void set(HomeMockScenario scenario) => state = scenario;
}

final homeMockScenarioProvider = NotifierProvider<HomeMockScenarioController, HomeMockScenario>(
  HomeMockScenarioController.new,
);

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return MockHomeRepository(scenario: ref.watch(homeMockScenarioProvider));
});

/// Each Home section reads its own provider so a failure or slow load in one
/// (e.g. Services) can't take down sections that already loaded fine.
final homeUserProvider = FutureProvider<HomeUser>((ref) {
  return ref.watch(homeRepositoryProvider).fetchUser();
});

final homeVehiclesProvider = FutureProvider<List<VehicleSummary>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchVehicles();
});

final homeActiveBookingProvider = FutureProvider<HomeBookingSummary?>((ref) {
  final locale = ref.watch(localeProvider);
  return ref.watch(homeRepositoryProvider).fetchActiveBooking(locale);
});

final homeServicesProvider = FutureProvider<List<ServiceItem>>((ref) {
  final locale = ref.watch(localeProvider);
  return ref.watch(homeRepositoryProvider).fetchServices(locale);
});

final homeOffersProvider = FutureProvider<List<Offer>>((ref) {
  final locale = ref.watch(localeProvider);
  return ref.watch(homeRepositoryProvider).fetchOffers(locale);
});
