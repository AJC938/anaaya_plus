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

/// A repository whose add/update mutations always fail, to test the form's
/// error handling without touching the real mock's happy path.
class _ThrowingMutationRepository implements CarsRepository {
  _ThrowingMutationRepository(this._inner);
  final CarsRepository _inner;

  @override
  Future<List<Vehicle>> getVehicles() => _inner.getVehicles();

  @override
  Future<Vehicle> addVehicle({required String make, required String model, required int year, required String plateNumber}) {
    throw Exception('mock save failure');
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) => throw Exception('mock save failure');

  @override
  Future<void> deleteVehicle(String id) => _inner.deleteVehicle(id);

  @override
  Future<void> setDefaultVehicle(String id) => _inner.setDefaultVehicle(id);

  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) => _inner.fetchAssociationStatus(vehicleId);
}

Future<ProviderContainer> _pumpForm(
  WidgetTester tester, {
  String? vehicleId,
  List<Vehicle> seedVehicles = const [_camry, _tucson],
  CarsRepository? repository,
}) async {
  final fakeAuth = FakeAuthRepository(uid: testUid);
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      carsRepositoryProvider.overrideWithValue(repository ?? MockCarsRepository(seedVehicles: seedVehicles)),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = createAppRouter(authRepository: fakeAuth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  // Load the vehicle list first (Edit mode reads it synchronously from the
  // provider's current value, exactly like the real navigation flow does).
  router.go(AppRoutes.cars);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  // Pushed (not `.go()`), matching real navigation from My Cars — the form
  // screen calls context.pop() on save, which needs an actual back entry.
  router.push(vehicleId == null ? AppRoutes.addVehicle() : AppRoutes.editVehicle(vehicleId));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(VehicleFormScreen)));

Future<void> _selectDropdownOption(WidgetTester tester, {required int dropdownIndex, required String optionText}) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(dropdownIndex));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(optionText).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Add Vehicle', () {
    testWidgets('renders the form fields and Save Vehicle CTA', (tester) async {
      await _pumpForm(tester);
      final l10n = _l10n(tester);

      expect(find.text(l10n.makeLabel), findsOneWidget);
      expect(find.text(l10n.modelLabel), findsOneWidget);
      expect(find.text(l10n.yearLabel), findsOneWidget);
      expect(find.text(l10n.licensePlateLabel), findsOneWidget);
      expect(find.text(l10n.saveVehicleCta), findsOneWidget);
    });

    testWidgets('shows required-field errors when saving an empty form', (tester) async {
      await _pumpForm(tester);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();

      expect(find.text(l10n.fieldRequiredError), findsWidgets);
    });

    testWidgets('shows an invalid-year error', (tester) async {
      await _pumpForm(tester);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Toyota');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Camry');
      await tester.enterText(find.byType(TextFormField).at(0), '1899');
      await tester.enterText(find.byType(TextFormField).at(1), 'ABC 1234');
      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();

      expect(find.text(l10n.invalidYearError), findsOneWidget);
    });

    testWidgets('shows an invalid-plate error', (tester) async {
      await _pumpForm(tester);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Toyota');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Camry');
      await tester.enterText(find.byType(TextFormField).at(0), '2023');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();

      expect(find.text(l10n.invalidPlateError), findsOneWidget);
    });

    testWidgets('a valid save returns to My Cars, shows feedback, and adds the vehicle', (tester) async {
      final container = await _pumpForm(tester);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Kia');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Sportage');
      await tester.enterText(find.byType(TextFormField).at(0), '2022');
      await tester.enterText(find.byType(TextFormField).at(1), 'KIA 999');

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();
      // addVehicle() awaits two sequential mock calls (add, then re-fetch).
      await tester.pump(const Duration(milliseconds: 1000));
      // Lets the pop's page-transition animation finish, so the outgoing
      // form screen is actually gone, not just mid-transition.
      await tester.pumpAndSettle();

      expect(find.byType(CarsScreen), findsOneWidget);
      expect(find.byType(VehicleFormScreen), findsNothing);
      expect(find.text(l10n.vehicleSavedMessage), findsOneWidget);
      expect(container.read(carsControllerProvider).value, hasLength(3));
    });

    testWidgets('the first vehicle added becomes the default', (tester) async {
      final container = await _pumpForm(tester, seedVehicles: const []);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Toyota');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Camry');
      await tester.enterText(find.byType(TextFormField).at(0), '2023');
      await tester.enterText(find.byType(TextFormField).at(1), 'ABC 1234');

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      final vehicles = container.read(carsControllerProvider).value!;
      expect(vehicles, hasLength(1));
      expect(vehicles.single.isDefault, isTrue);
    });

    testWidgets('a rapid double-tap on Save only submits once', (tester) async {
      final container = await _pumpForm(tester);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Kia');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Sportage');
      await tester.enterText(find.byType(TextFormField).at(0), '2022');
      await tester.enterText(find.byType(TextFormField).at(1), 'KIA 999');

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.tap(find.text(l10n.saveVehicleCta)); // guarded no-op
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(container.read(carsControllerProvider).value, hasLength(3));
    });

    testWidgets('shows the Saving state while a save is in flight', (tester) async {
      await _pumpForm(tester);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Kia');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Sportage');
      await tester.enterText(find.byType(TextFormField).at(0), '2022');
      await tester.enterText(find.byType(TextFormField).at(1), 'KIA 999');

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();

      expect(find.text(l10n.savingLabel), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('a save error keeps the form open with values preserved', (tester) async {
      final repository = _ThrowingMutationRepository(MockCarsRepository(seedVehicles: const [_camry, _tucson]));
      await _pumpForm(tester, repository: repository);
      final l10n = _l10n(tester);

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Kia');
      await _selectDropdownOption(tester, dropdownIndex: 1, optionText: 'Sportage');
      await tester.enterText(find.byType(TextFormField).at(0), '2022');
      await tester.enterText(find.byType(TextFormField).at(1), 'KIA 999');

      await tester.tap(find.text(l10n.saveVehicleCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(l10n.saveVehicleErrorMessage), findsOneWidget);
      expect(find.byType(VehicleFormScreen), findsOneWidget);
      expect(find.text('KIA 999'), findsOneWidget); // preserved
      expect(find.text(l10n.saveVehicleCta), findsOneWidget); // re-enabled
    });
  });

  group('Edit Vehicle', () {
    testWidgets('pre-fills the existing vehicle values', (tester) async {
      await _pumpForm(tester, vehicleId: 'v1');
      final l10n = _l10n(tester);

      expect(find.text(l10n.editVehicleTitle), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Camry'), findsOneWidget);
      expect(find.text('2023'), findsOneWidget);
      expect(find.text('ABC 1234'), findsOneWidget);
      expect(find.text(l10n.saveChangesCta), findsOneWidget);
    });

    testWidgets('a valid update preserves the vehicle id and creates no duplicate', (tester) async {
      final container = await _pumpForm(tester, vehicleId: 'v1');
      final l10n = _l10n(tester);

      await tester.enterText(find.byType(TextFormField).at(1), 'NEW 4321');
      await tester.tap(find.text(l10n.saveChangesCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      final vehicles = container.read(carsControllerProvider).value!;
      expect(vehicles, hasLength(2)); // no duplicate
      final updated = vehicles.firstWhere((v) => v.id == 'v1');
      expect(updated.plateNumber, 'NEW 4321');
      expect(updated.isDefault, isTrue); // preserved
    });

    testWidgets('shows validation errors on an invalid update', (tester) async {
      await _pumpForm(tester, vehicleId: 'v1');
      final l10n = _l10n(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '1');
      await tester.tap(find.text(l10n.saveChangesCta));
      await tester.pump();

      expect(find.text(l10n.invalidPlateError), findsOneWidget);
      expect(find.byType(VehicleFormScreen), findsOneWidget);
    });

    testWidgets('an update error keeps the form open', (tester) async {
      final repository = _ThrowingMutationRepository(MockCarsRepository(seedVehicles: const [_camry, _tucson]));
      await _pumpForm(tester, vehicleId: 'v1', repository: repository);
      final l10n = _l10n(tester);

      await tester.enterText(find.byType(TextFormField).at(1), 'NEW 4321');
      await tester.tap(find.text(l10n.saveChangesCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(l10n.saveVehicleErrorMessage), findsOneWidget);
      expect(find.byType(VehicleFormScreen), findsOneWidget);
    });

    testWidgets('changing Make resets Model when it is no longer valid', (tester) async {
      await _pumpForm(tester, vehicleId: 'v1'); // Toyota Camry

      await _selectDropdownOption(tester, dropdownIndex: 0, optionText: 'Hyundai');

      // Camry isn't a Hyundai model, so it must no longer be shown selected.
      expect(find.text('Camry'), findsNothing);
    });
  });
}
