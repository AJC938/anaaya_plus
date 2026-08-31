import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/data/booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/cars/application/cars_providers.dart';
import 'package:anaaya_plus/features/cars/data/cars_repository.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/domain/vehicle_association.dart';
import 'package:anaaya_plus/features/location/application/location_providers.dart';
import 'package:anaaya_plus/features/location/data/location_repository.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/scheduling/application/scheduling_providers.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/availability_day.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';
import 'package:anaaya_plus/features/services/application/services_providers.dart';
import 'package:anaaya_plus/features/services/domain/models/service.dart';
import 'package:anaaya_plus/features/services/domain/models/service_option.dart';

import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/payment/application/payment_providers.dart';
import 'package:anaaya_plus/features/payment/data/mock_payment_repository.dart';
import 'package:anaaya_plus/features/payment/data/payment_repository.dart';

import 'auth_fixtures.dart';
import 'instant_home_overrides.dart';

const testServiceId = 's1';

const testService = Service(
  id: testServiceId,
  nameAr: 'Oil Change',
  nameEn: 'Oil Change',
  descriptionAr: 'Oil change description',
  descriptionEn: 'Oil change description',
  category: 'maintenance',
  startingPrice: 89,
  estimatedDuration: Duration(minutes: 40),
  imageAsset: 'oil_change',
  isActive: true,
  requiresVehicle: true,
  requiresProductSelection: true,
  includedItemsAr: ['Included item'],
  includedItemsEn: ['Included item'],
);

const testOption = ServiceOption(
  id: 'opt-mineral',
  serviceId: testServiceId,
  nameAr: 'Mineral',
  nameEn: 'Mineral',
  descriptionAr: 'Basic protection',
  descriptionEn: 'Basic protection',
  price: 25,
  imageAsset: 'oil_mineral',
  compatibleVehicleIds: ['v1'],
  isAvailable: true,
);

const testVehicle = Vehicle(
  id: 'v1',
  make: 'Toyota',
  model: 'Camry',
  year: 2023,
  plateNumber: 'ABC 1234',
  imageAsset: 'vehicle_sedan',
  isDefault: true,
);

const testVehicle2 = Vehicle(
  id: 'v2',
  make: 'Hyundai',
  model: 'Tucson',
  year: 2024,
  plateNumber: 'XYZ 5678',
  imageAsset: 'vehicle_suv',
  isDefault: false,
);

const testHomeLocation = BookingLocation(
  id: 'loc-home',
  labelAr: 'Home',
  labelEn: 'Home',
  cityAr: 'Jeddah',
  cityEn: 'Jeddah',
  districtAr: 'Al Zahra District',
  districtEn: 'Al Zahra District',
  addressLineAr: 'Prince Sultan Street',
  addressLineEn: 'Prince Sultan Street',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

const testWorkLocation = BookingLocation(
  id: 'loc-work',
  labelAr: 'Work',
  labelEn: 'Work',
  cityAr: 'Jeddah',
  cityEn: 'Jeddah',
  districtAr: 'Al Rawdah District',
  districtEn: 'Al Rawdah District',
  latitude: 21.5645,
  longitude: 39.1758,
  isSimulatedCurrentLocation: false,
);

final testAvailableDate = DateTime(2026, 1, 5);

final testAvailableDay = AvailabilityDay(date: testAvailableDate, hasAvailability: true);

final testSlot = TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 9), isAvailable: true);
final testUnavailableSlot = TimeSlot(id: 'slot-2', start: DateTime(2026, 1, 5, 11), isAvailable: false);

typedef ServiceLookup = Future<Service?> Function(Ref ref, String id);
typedef OptionsLookup = Future<List<ServiceOption>> Function(Ref ref, String id);
typedef LocationsLookup = Future<List<BookingLocation>> Function();
typedef DatesLookup = Future<List<AvailabilityDay>> Function(Ref ref, String id);
typedef SlotsLookup = Future<List<TimeSlot>> Function(Ref ref, TimeSlotsQuery query);

/// Builds a fresh app + router + container, seeds the booking draft (if
/// any), and navigates to [route] — used by every Booking screen test so
/// each one only has to say what's different about its own scenario. Every
/// provider a Booking screen (or one of its route ancestors) depends on has
/// a named parameter here with a harmless instant-data default, so a test
/// overriding one scenario (e.g. a failing [locations] fetch) never
/// collides with the harness's own default override for that same
/// provider — Riverpod forbids overriding the same provider twice in one
/// container.
///
/// Booking's sub-routes nest under Service Details (or, for Tracking, under
/// Bookings), so go_router mounts every ancestor page in the same Navigator
/// stack — each of those ancestor screens' own providers need harmless
/// instant data too, exactly like `service_details_screen_test.dart`'s
/// `_pumpServiceDetails` already established.
///
/// [locations] covers the common fetch-only scenarios (loading/empty/error);
/// pass [locationRepository] instead — never both, Riverpod forbids
/// overriding the same provider twice in one container — when a test needs
/// genuine add/update/delete behavior (e.g. the map picker's save/edit/
/// delete flows).
Future<ProviderContainer> pumpBookingScreen(
  WidgetTester tester, {
  required String route,
  BookingDraft? draft,
  ServiceLookup? service,
  OptionsLookup? serviceOptions,
  List<Vehicle>? carsVehicles,
  LocationsLookup? locations,
  LocationRepository? locationRepository,
  DatesLookup? availableDates,
  SlotsLookup? timeSlots,
  BookingRepository? bookingRepository,
  PaymentRepository? paymentRepository,
  List<Override> extraOverrides = const [],
}) async {
  // Shared between the router (constructor-injected) and the Riverpod
  // provider chain — carsControllerProvider.build() now waits on
  // authStateChangesProvider before ever touching carsRepositoryProvider
  // (see its own doc comment), so both need to see the same identity.
  final fakeAuth = FakeAuthRepository(uid: testUid);
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      servicesListProvider.overrideWith((ref) async => const <Service>[]),
      serviceByIdProvider.overrideWith(service ?? (ref, id) async => testService),
      serviceOptionsProvider.overrideWith(serviceOptions ?? (ref, id) async => const [testOption]),
      carsRepositoryProvider.overrideWithValue(_InstantCarsRepository(carsVehicles ?? const [testVehicle, testVehicle2])),
      locationRepositoryProvider.overrideWithValue(
        locationRepository ?? _InstantLocationRepository(locations ?? () async => const [testHomeLocation, testWorkLocation]),
      ),
      availableDatesProvider.overrideWith(availableDates ?? (ref, id) async => [testAvailableDay]),
      timeSlotsProvider.overrideWith(timeSlots ?? (ref, query) async => [testSlot, testUnavailableSlot]),
      if (bookingRepository != null) bookingRepositoryProvider.overrideWithValue(bookingRepository),
      // BE-07: every Booking screen sits in a route tree that can reach
      // Payment (Review's Confirm action now lands there — see
      // review_screen.dart), so paymentRepositoryProvider needs a harmless
      // default the same way every other repository above does, or a test
      // that never mentions Payment at all would otherwise hit real
      // Firestore the moment it lands on PaymentScreen.
      paymentRepositoryProvider.overrideWithValue(paymentRepository ?? MockPaymentRepository(bookingAmounts: const {})),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  await _useTallViewport(tester);

  if (draft != null) {
    container.read(bookingDraftControllerProvider.notifier).startOrUpdateDraft(
      serviceId: draft.serviceId,
      serviceOptionId: draft.serviceOptionId,
      vehicleId: draft.vehicleId,
    );
    if (draft.location != null) {
      container.read(bookingDraftControllerProvider.notifier).setLocation(draft.location!);
    }
    if (draft.date != null) {
      container.read(bookingDraftControllerProvider.notifier).setDate(draft.date!);
    }
    if (draft.timeSlot != null) {
      container.read(bookingDraftControllerProvider.notifier).setTimeSlot(draft.timeSlot!);
    }
  }

  final router = createAppRouter(authRepository: fakeAuth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  router.go(route);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  // Review's vehicle/option lookups are a second, chained round of async
  // provider resolution on top of the route's own — one more bare pump
  // (no duration) picks up whatever became AsyncData right at the tail end
  // of the settle window above but hadn't been rebuilt into the tree yet.
  await tester.pump();
  return container;
}

Future<void> _useTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A no-latency stand-in for [CarsRepository] so the real, unmodified
/// [CarsController] resolves instantly — Review's vehicle lookup and the
/// Vehicle Edit sheet both go through it.
class _InstantCarsRepository implements CarsRepository {
  _InstantCarsRepository(this._vehicles);

  final List<Vehicle> _vehicles;

  @override
  Future<List<Vehicle>> getVehicles() async => _vehicles;

  @override
  Future<Vehicle> addVehicle({required String make, required String model, required int year, required String plateNumber}) =>
      throw UnimplementedError();

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) => throw UnimplementedError();

  @override
  Future<void> deleteVehicle(String id) => throw UnimplementedError();

  @override
  Future<void> setDefaultVehicle(String id) => throw UnimplementedError();

  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) => throw UnimplementedError();
}

/// A no-latency stand-in for [LocationRepository] driven by a plain fetch
/// callback — covers every existing loading/empty/error/retry scenario,
/// matching [_InstantCarsRepository]'s exact role. Mutation methods are
/// deliberately unimplemented: tests that need real add/update/delete
/// behavior (the map picker's save flow, edit, delete) override
/// `locationRepositoryProvider` directly with their own richer fake via
/// `extraOverrides`, rather than stretching this one to do both jobs.
class _InstantLocationRepository implements LocationRepository {
  _InstantLocationRepository(this._fetch);

  final LocationsLookup _fetch;

  @override
  Future<List<BookingLocation>> fetchSavedLocations() => _fetch();

  @override
  Future<BookingLocation> addLocation(BookingLocation location) => throw UnimplementedError();

  @override
  Future<BookingLocation> updateLocation(BookingLocation location) => throw UnimplementedError();

  @override
  Future<void> deleteLocation(String id) => throw UnimplementedError();
}
