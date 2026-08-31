import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/cars/application/cars_providers.dart';
import 'package:anaaya_plus/features/cars/data/cars_repository.dart';
import 'package:anaaya_plus/features/cars/data/mock_cars_repository.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/domain/vehicle_association.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/cars_screen.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/vehicle_form_screen.dart';
import 'package:anaaya_plus/features/cars/presentation/widgets/vehicle_card.dart';

import '../../support/auth_fixtures.dart';
import '../../support/instant_home_overrides.dart';

const _camry = Vehicle(
  id: 'v1',
  make: 'Toyota',
  model: 'Camry',
  year: 2023,
  plateNumber: 'ABC 1234',
  imageAsset: 'vehicle_sedan',
  isDefault: true,
);
const _tucson = Vehicle(
  id: 'v2',
  make: 'Hyundai',
  model: 'Tucson',
  year: 2024,
  plateNumber: 'XYZ 5678',
  imageAsset: 'vehicle_suv',
  isDefault: false,
);

/// getVehicles() fails on the first call, succeeds afterwards — lets a test
/// exercise both the error state and a real Retry recovery.
class _FlakyCarsRepository implements CarsRepository {
  _FlakyCarsRepository(this._inner);
  final CarsRepository _inner;
  var _attempt = 0;

  @override
  Future<List<Vehicle>> getVehicles() {
    _attempt++;
    if (_attempt == 1) throw Exception('mock failure');
    return _inner.getVehicles();
  }

  @override
  Future<Vehicle> addVehicle({required String make, required String model, required int year, required String plateNumber}) =>
      _inner.addVehicle(make: make, model: model, year: year, plateNumber: plateNumber);

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) => _inner.updateVehicle(vehicle);

  @override
  Future<void> deleteVehicle(String id) => _inner.deleteVehicle(id);

  @override
  Future<void> setDefaultVehicle(String id) => _inner.setDefaultVehicle(id);

  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) => _inner.fetchAssociationStatus(vehicleId);
}

Future<ProviderContainer> _pumpCars(WidgetTester tester, {CarsRepository? repository}) async {
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
      carsRepositoryProvider.overrideWithValue(
        repository ??
            MockCarsRepository(
              seedVehicles: const [_camry, _tucson],
              seedAssociations: const {'v1': VehicleAssociationStatus.none, 'v2': VehicleAssociationStatus.upcomingBooking},
            ),
      ),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = createAppRouter(authRepository: fakeAuth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  router.go(AppRoutes.cars);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(CarsScreen)));

/// Opens the overflow menu on the card showing [vehicleName].
Future<void> _openCardMenu(WidgetTester tester, String vehicleName) async {
  final card = find.ancestor(of: find.text(vehicleName), matching: find.byType(VehicleCard));
  final menuButton = find.descendant(of: card, matching: find.byIcon(Icons.more_vert));
  await tester.tap(menuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    // A Completer that's resolved before the test ends (see below) — an
    // indefinitely-pending future here would leak into later tests in this
    // file, since nothing would ever clean it up.
    final completer = Completer<List<Vehicle>>();
    final fakeAuth = FakeAuthRepository(uid: testUid);
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        ...instantHomeOverrides(),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        carsRepositoryProvider.overrideWithValue(_PendingCarsRepository(completer)),
      ],
    );
    addTearDown(container.dispose);
    final router = createAppRouter(authRepository: fakeAuth);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
    await tester.pump();
    router.go(AppRoutes.cars);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('renders the default vehicle and other vehicles', (tester) async {
    await _pumpCars(tester);
    final l10n = _l10n(tester);

    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('Hyundai Tucson'), findsOneWidget);
    expect(find.text(l10n.defaultVehicleBadge), findsOneWidget);
    expect(find.text(l10n.otherVehiclesTitle), findsOneWidget);
  });

  testWidgets('shows a useful empty state when there are no vehicles', (tester) async {
    await _pumpCars(tester, repository: MockCarsRepository(seedVehicles: const []));
    final l10n = _l10n(tester);

    expect(find.text(l10n.noVehiclesTitle), findsOneWidget);
    expect(find.text(l10n.addFirstVehicleCta), findsOneWidget);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    final repository = _FlakyCarsRepository(MockCarsRepository(seedVehicles: const [_camry]));
    await _pumpCars(tester, repository: repository);
    final l10n = _l10n(tester);

    expect(find.text(l10n.unableToLoadVehiclesMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.unableToLoadVehiclesMessage), findsNothing);
    expect(find.text('Toyota Camry'), findsOneWidget);
  });

  testWidgets('Arabic is the default locale and renders RTL', (tester) async {
    await _pumpCars(tester);
    expect(Directionality.of(tester.element(find.byType(CarsScreen))), TextDirection.rtl);
  });

  testWidgets('Add Vehicle navigates to the add form', (tester) async {
    await _pumpCars(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.addVehicleCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(VehicleFormScreen), findsOneWidget);
  });

  testWidgets('Edit navigates to the edit form for that vehicle', (tester) async {
    await _pumpCars(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, l10n.editAction).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(VehicleFormScreen), findsOneWidget);
  });

  testWidgets('Set as Default changes which vehicle is marked default', (tester) async {
    await _pumpCars(tester);
    final l10n = _l10n(tester);

    await _openCardMenu(tester, 'Hyundai Tucson');
    await tester.tap(find.text(l10n.setAsDefaultAction));
    await tester.pump();
    // setDefaultVehicle() awaits two sequential mock calls (mutate, then
    // re-fetch), each with their own latency — one 500ms pump isn't enough.
    await tester.pump(const Duration(milliseconds: 1000));

    // Only one "Default Vehicle" badge exists, and it now belongs to Tucson.
    final defaultCard = find.ancestor(of: find.text(l10n.defaultVehicleBadge), matching: find.byType(VehicleCard));
    expect(find.descendant(of: defaultCard, matching: find.text('Hyundai Tucson')), findsOneWidget);
  });

  testWidgets('Delete on a vehicle with an upcoming booking is blocked, no confirm dialog shown', (tester) async {
    await _pumpCars(tester); // Tucson (v2) has an upcoming booking by default
    final l10n = _l10n(tester);

    await _openCardMenu(tester, 'Hyundai Tucson');
    await tester.tap(find.text(l10n.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.cannotDeleteVehicleTitle), findsOneWidget);
    expect(find.text(l10n.deleteVehicleTitle), findsNothing);
    expect(find.text('Hyundai Tucson'), findsOneWidget); // still there
  });

  testWidgets('Delete confirm dialog: Cancel keeps the vehicle', (tester) async {
    await _pumpCars(tester); // Camry (v1) has no association, so it's deletable
    final l10n = _l10n(tester);

    await _openCardMenu(tester, 'Toyota Camry');
    await tester.tap(find.text(l10n.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.deleteVehicleTitle), findsOneWidget);

    await tester.tap(find.text(l10n.cancelAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Toyota Camry'), findsOneWidget);
  });

  testWidgets('Delete confirm removes the vehicle, shows feedback, and promotes a new default', (tester) async {
    await _pumpCars(tester); // Camry (v1) is default and deletable
    final l10n = _l10n(tester);

    await _openCardMenu(tester, 'Toyota Camry');
    await tester.tap(find.text(l10n.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(l10n.deleteAction)); // confirm in the dialog
    await tester.pump();
    // deleteVehicle() awaits two sequential mock calls (delete, then
    // re-fetch), each with their own latency — one 500ms pump isn't enough.
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Toyota Camry'), findsNothing);
    expect(find.text(l10n.vehicleDeletedMessage), findsOneWidget);
    // Tucson is now the only vehicle left, promoted to default.
    final defaultCard = find.ancestor(of: find.text(l10n.defaultVehicleBadge), matching: find.byType(VehicleCard));
    expect(find.descendant(of: defaultCard, matching: find.text('Hyundai Tucson')), findsOneWidget);
  });
}

/// getVehicles() stays pending until [completer] is resolved by the test —
/// used to observe the loading state without leaking an unresolved future
/// into later tests.
class _PendingCarsRepository implements CarsRepository {
  _PendingCarsRepository(this.completer);
  final Completer<List<Vehicle>> completer;

  @override
  Future<List<Vehicle>> getVehicles() => completer.future;

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
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) async => VehicleAssociationStatus.none;
}
