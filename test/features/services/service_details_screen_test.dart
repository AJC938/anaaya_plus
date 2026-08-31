import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/asset_visual.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/location_screen.dart';
import 'package:anaaya_plus/features/cars/application/cars_providers.dart';
import 'package:anaaya_plus/features/cars/data/cars_repository.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/domain/vehicle_association.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/cars_screen.dart';
import 'package:anaaya_plus/features/services/application/services_providers.dart';
import 'package:anaaya_plus/features/services/domain/models/service.dart';
import 'package:anaaya_plus/features/services/domain/models/service_option.dart';
import 'package:anaaya_plus/features/services/presentation/screens/service_details_screen.dart';
import 'package:anaaya_plus/features/services/presentation/widgets/product_option_card.dart';
import 'package:anaaya_plus/features/services/presentation/widgets/service_hero.dart';

import '../../support/auth_fixtures.dart';
import '../../support/instant_home_overrides.dart';

// Both language fields are the same plain-English string here (matching
// Home's own fixture convention) so string-equality assertions never depend
// on Arabic transcription matching — the default test locale is Arabic.
const _oilChange = Service(
  id: 's1',
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

const _inactiveService = Service(
  id: 's1',
  nameAr: 'Oil Change',
  nameEn: 'Oil Change',
  descriptionAr: '',
  descriptionEn: '',
  category: 'maintenance',
  startingPrice: 89,
  estimatedDuration: Duration(minutes: 40),
  imageAsset: 'oil_change',
  isActive: false,
  requiresVehicle: true,
  requiresProductSelection: true,
  includedItemsAr: [],
  includedItemsEn: [],
);

// Realistic Firestore auto-generated document IDs (not the retired 'v1'/'v2'
// mock ids) — proof that a real users/{uid}/cars/{carId} id flows through
// selection unchanged, not just something that happens to look like one.
const _camryId = 'iBUZvrXIH6ZJ6GGQTu5u';
const _tucsonId = 'qP3mZnR8xT2vK5jL9wDs';

const _camry = Vehicle(id: _camryId, make: 'Toyota', model: 'Camry', year: 2023, plateNumber: 'ABC 1234', imageAsset: 'vehicle_sedan', isDefault: true);
const _tucson = Vehicle(id: _tucsonId, make: 'Hyundai', model: 'Tucson', year: 2024, plateNumber: 'XYZ 5678', imageAsset: 'vehicle_suv', isDefault: false);

// Each option has its own distinct product image key — never the parent
// service's ('oil_change') — so the fixtures double as a regression check
// against that mistake.
const _mineral = ServiceOption(
  id: 'opt-mineral',
  serviceId: 's1',
  nameAr: 'Mineral',
  nameEn: 'Mineral',
  descriptionAr: 'Basic protection',
  descriptionEn: 'Basic protection',
  price: 25,
  imageAsset: 'oil_mineral',
  compatibleVehicleIds: [_camryId],
  isAvailable: true,
);
const _semiSynthetic = ServiceOption(
  id: 'opt-semi',
  serviceId: 's1',
  nameAr: 'Semi-Synthetic',
  nameEn: 'Semi-Synthetic',
  descriptionAr: 'Balanced protection',
  descriptionEn: 'Balanced protection',
  price: 40,
  imageAsset: 'oil_semi_synthetic',
  compatibleVehicleIds: [_camryId, _tucsonId],
  isAvailable: true,
);
const _fullSynthetic = ServiceOption(
  id: 'opt-full',
  serviceId: 's1',
  nameAr: 'Full Synthetic',
  nameEn: 'Full Synthetic',
  descriptionAr: 'Advanced protection',
  descriptionEn: 'Advanced protection',
  price: 60,
  imageAsset: 'oil_full_synthetic',
  compatibleVehicleIds: [_tucsonId],
  isAvailable: true,
);

Future<ProviderContainer> _pumpServiceDetails(
  WidgetTester tester, {
  String serviceId = 's1',
  Future<Service?> Function(Ref ref, String id)? serviceOverride,
  List<Vehicle>? carsVehicles,
  Future<List<ServiceOption>> Function(Ref ref, String id)? optionsOverride,
}) async {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      // `/home/services` is also mounted as the parent of the nested
      // `/home/services/:id` route, so it needs harmless instant data too.
      servicesListProvider.overrideWith((ref) async => const <Service>[]),
      serviceByIdProvider.overrideWith(serviceOverride ?? (ref, id) async => _oilChange),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      // The Details vehicle picker is backed directly by real Cars data now
      // (carsControllerProvider → carsRepositoryProvider), never a
      // Services-local catalog — see service_details_screen.dart. A
      // no-latency fake (not MockCarsRepository's real 400ms delay) so
      // pump()-based tests never leave a dangling timer.
      carsRepositoryProvider.overrideWithValue(_InstantCarsRepository(carsVehicles ?? const [_camry, _tucson])),
      serviceOptionsProvider.overrideWith(optionsOverride ?? (ref, id) async => const [_mineral, _semiSynthetic, _fullSynthetic]),
    ],
  );
  addTearDown(container.dispose);
  await _useTallViewport(tester);
  // A fresh router per test — the shared appRouter singleton retains nested
  // branch state (by design, for real navigation), which would otherwise
  // leak a previous test's pushed route into this one.
  final router = createAppRouter(authRepository: FakeAuthRepository(uid: testUid));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)),
  );
  await tester.pump();
  router.go(AppRoutes.serviceDetails(serviceId));
  // The screen watches a chain of providers (service, then its vehicles and
  // options once the service itself resolves); none of these overrides use
  // a real delay, so pumpAndSettle safely flushes however many rebuild
  // rounds that chain needs instead of guessing a fixed number of pumps.
  await tester.pumpAndSettle();
  return container;
}

Future<void> _useTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ServiceDetailsScreen)));

void main() {
  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    await _pumpServiceDetails(tester, serviceOverride: (ref, id) => Completer<Service?>().future);

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    var attempt = 0;
    await _pumpServiceDetails(
      tester,
      serviceOverride: (ref, id) async {
        attempt++;
        if (attempt == 1) throw Exception('mock service failure');
        return _oilChange;
      },
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Oil Change'), findsWidgets);
  });

  testWidgets('renders service information: name, image, price, duration, included items', (tester) async {
    await _pumpServiceDetails(tester, carsVehicles: const []);
    final l10n = _l10n(tester);

    expect(find.text('Oil Change'), findsWidgets);
    expect(find.byType(ServiceHero), findsOneWidget);
    expect(find.text(l10n.startingFromPrice('89')), findsOneWidget);
    expect(find.text(l10n.estimatedDurationLabel(l10n.durationMinutesLabel('40'))), findsOneWidget);
    expect(find.text('Included item'), findsOneWidget);
  });

  testWidgets('an inactive service shows unavailable and no booking CTA', (tester) async {
    await _pumpServiceDetails(tester, serviceOverride: (ref, id) async => _inactiveService);
    final l10n = _l10n(tester);

    expect(find.text(l10n.serviceUnavailableMessage), findsOneWidget);
    expect(find.text(l10n.bookThisServiceCta), findsNothing);
  });

  testWidgets('no vehicles prompts to add one, and navigates to Cars', (tester) async {
    await _pumpServiceDetails(tester, carsVehicles: const []);
    final l10n = _l10n(tester);

    expect(find.text(l10n.addVehicleToContinuePrompt), findsOneWidget);
    expect(find.text(l10n.selectVehicleAction), findsOneWidget); // the disabled CTA, not the vehicle list

    await tester.tap(find.text(l10n.addVehicleCta));
    await tester.pumpAndSettle();
    // Lands on the real Cars screen, backed by the same carsRepositoryProvider
    // override above — both screens now share the one real Cars data source.
    expect(find.byType(CarsScreen), findsOneWidget);
  });

  testWidgets('selecting a vehicle shows only its compatible options, hiding incompatible ones', (tester) async {
    await _pumpServiceDetails(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Camry: Mineral + Semi-Synthetic compatible, Full Synthetic is not.
    expect(find.text('Mineral'), findsOneWidget);
    expect(find.text('Semi-Synthetic'), findsOneWidget);
    expect(find.text('Full Synthetic'), findsNothing);
    expect(find.text(l10n.noCompatibleOptionsMessage), findsNothing);
  });

  testWidgets('each product option resolves its own distinct image, not the parent service image', (tester) async {
    await _pumpServiceDetails(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final cards = tester.widgetList<ProductOptionCard>(find.byType(ProductOptionCard)).toList();
    expect(cards.length, 2); // Mineral + Semi-Synthetic are compatible with the Camry.

    final imageKeys = cards.map((card) => card.option.imageAsset).toSet();
    expect(imageKeys, {'oil_mineral', 'oil_semi_synthetic'});
    expect(imageKeys, isNot(contains(_oilChange.imageAsset))); // never the parent service's image

    for (final card in cards) {
      final assetVisual = tester.widget<AssetVisual>(
        find.descendant(of: find.byWidget(card), matching: find.byType(AssetVisual)),
      );
      expect(assetVisual.assetKey, card.option.imageAsset);
    }
  });

  testWidgets('selecting an option shows the selected state and updates the price summary', (tester) async {
    await _pumpServiceDetails(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.selectedLabel), findsNothing);

    await tester.tap(find.text('Mineral'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.selectedLabel), findsOneWidget);
    // Base 89 + Mineral 25 = 114.
    expect(find.text(l10n.priceSar('114')), findsOneWidget);
    expect(find.text(l10n.bookThisServiceCta), findsOneWidget);
  });

  testWidgets('changing vehicle clears an option that is no longer compatible', (tester) async {
    await _pumpServiceDetails(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mineral')); // only compatible with Camry
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.selectedLabel), findsOneWidget);

    await tester.tap(find.text('Hyundai Tucson'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mineral isn't even offered for Tucson, and nothing is selected anymore.
    expect(find.text('Mineral'), findsNothing);
    expect(find.text(l10n.selectedLabel), findsNothing);
    expect(find.text(l10n.selectOptionAction), findsOneWidget); // CTA fell back to "select an option"
  });

  testWidgets('no compatible options for the selected vehicle shows an explanation', (tester) async {
    await _pumpServiceDetails(
      tester,
      carsVehicles: const [_camry],
      optionsOverride: (ref, id) async => const [_fullSynthetic], // only compatible with the Tucson
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.noCompatibleOptionsMessage), findsOneWidget);
  });

  testWidgets('the ready booking CTA creates a draft and enters Booking at Location', (tester) async {
    final container = await _pumpServiceDetails(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mineral'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(l10n.bookThisServiceCta));
    await tester.pump();
    // Lands on the real Location screen, backed by the real (unoverridden)
    // mock repository — give its latency time to flush.
    await tester.pump(const Duration(milliseconds: 500));

    final draft = container.read(bookingDraftControllerProvider);
    expect(draft, isNotNull);
    expect(draft!.serviceId, 's1');
    expect(draft.serviceOptionId, 'opt-mineral');
    // The real Firestore-style Cars id, unchanged from selection through the
    // draft — proof the vehicle picker no longer hands off a Services-local
    // mock id like the retired 'v1'.
    expect(draft.vehicleId, _camryId);
    expect(find.byType(LocationScreen), findsOneWidget);
  });
}

/// A no-latency stand-in for [CarsRepository] so the vehicle picker resolves
/// instantly — same rationale as booking_screen_harness.dart's own copy.
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
