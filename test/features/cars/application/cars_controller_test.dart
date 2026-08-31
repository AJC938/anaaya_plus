import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/cars/application/cars_providers.dart';
import 'package:anaaya_plus/features/cars/data/cars_repository.dart';
import 'package:anaaya_plus/features/cars/data/mock_cars_repository.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/domain/vehicle_association.dart';

import '../../../support/auth_fixtures.dart';

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

/// A repository whose mutations always fail, to test the controller's error
/// propagation without touching the real mock's happy-path implementation.
class _ThrowingCarsRepository implements CarsRepository {
  @override
  Future<List<Vehicle>> getVehicles() async => const [_camry];

  @override
  Future<Vehicle> addVehicle({required String make, required String model, required int year, required String plateNumber}) {
    throw Exception('mutation failed');
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) => throw Exception('mutation failed');

  @override
  Future<void> deleteVehicle(String id) => throw Exception('mutation failed');

  @override
  Future<void> setDefaultVehicle(String id) => throw Exception('mutation failed');

  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) async => VehicleAssociationStatus.none;
}

ProviderContainer _container({List<Vehicle>? seedVehicles, Map<String, VehicleAssociationStatus>? seedAssociations, CarsRepository? repository}) {
  final container = ProviderContainer(
    overrides: [
      // carsControllerProvider.build() now waits for authStateChangesProvider
      // to resolve before ever touching carsRepositoryProvider (see its own
      // doc comment) — a working auth fake is required even though these
      // tests don't otherwise care about auth.
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      carsRepositoryProvider.overrideWithValue(
        repository ?? MockCarsRepository(seedVehicles: seedVehicles, seedAssociations: seedAssociations),
      ),
    ],
  );
  // A keep-alive listener is required: without one, carsControllerProvider
  // isn't kept actively subscribed to authStateChangesProvider's stream, so
  // build()'s `await ref.watch(authStateChangesProvider.future)` never
  // observes FakeAuthRepository's emission and hangs — every test using
  // this helper reads carsControllerProvider.future directly, which alone
  // doesn't keep that subscription alive the way a real widget's ref.watch
  // would.
  container.listen(carsControllerProvider, (previous, next) {});
  return container;
}

void main() {
  test('getVehicles returns the seeded vehicles', () async {
    final container = _container();
    addTearDown(container.dispose);

    final vehicles = await container.read(carsControllerProvider.future);
    expect(vehicles.map((v) => v.id), ['v1', 'v2']);
  });

  test('the first vehicle added to an empty list becomes the default', () async {
    final container = _container(seedVehicles: const []);
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).addVehicle(make: 'Toyota', model: 'Camry', year: 2023, plateNumber: 'ABC 1234');

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles, hasLength(1));
    expect(vehicles.single.isDefault, isTrue);
  });

  test('an additional vehicle does not replace the current default', () async {
    final container = _container();
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).addVehicle(make: 'Kia', model: 'Sportage', year: 2022, plateNumber: 'KIA 999');

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles.where((v) => v.isDefault).single.id, 'v1');
  });

  test('setDefaultVehicle flips exactly one default', () async {
    final container = _container();
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).setDefaultVehicle('v2');

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles.firstWhere((v) => v.id == 'v1').isDefault, isFalse);
    expect(vehicles.firstWhere((v) => v.id == 'v2').isDefault, isTrue);
  });

  test('updateVehicle preserves the id and default status', () async {
    final container = _container();
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).updateVehicle(_camry.copyWith(model: 'Corolla'));

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles, hasLength(2)); // no duplicate created
    final updated = vehicles.firstWhere((v) => v.id == 'v1');
    expect(updated.model, 'Corolla');
    expect(updated.isDefault, isTrue);
  });

  test('deleting a non-default vehicle leaves the default unchanged', () async {
    final container = _container(
      seedVehicles: const [_camry, _tucson],
      seedAssociations: const {'v1': VehicleAssociationStatus.none, 'v2': VehicleAssociationStatus.none},
    );
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).deleteVehicle('v2');

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles, hasLength(1));
    expect(vehicles.single.id, 'v1');
    expect(vehicles.single.isDefault, isTrue);
  });

  test('deleting the default vehicle promotes the first remaining one', () async {
    final container = _container(
      seedVehicles: const [_camry, _tucson],
      seedAssociations: const {'v1': VehicleAssociationStatus.none, 'v2': VehicleAssociationStatus.none},
    );
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).deleteVehicle('v1');

    final vehicles = container.read(carsControllerProvider).value!;
    expect(vehicles.single.id, 'v2');
    expect(vehicles.single.isDefault, isTrue);
  });

  test('deleting the last vehicle produces an empty list', () async {
    final container = _container(
      seedVehicles: const [_camry],
      seedAssociations: const {'v1': VehicleAssociationStatus.none},
    );
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).deleteVehicle('v1');

    expect(container.read(carsControllerProvider).value, isEmpty);
  });

  test('deleting a vehicle with an upcoming booking throws and leaves the list unchanged', () async {
    final container = _container(); // v2 has an upcoming booking by default
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await expectLater(
      container.read(carsControllerProvider.notifier).deleteVehicle('v2'),
      throwsA(isA<VehicleDeleteBlockedException>()),
    );

    expect(container.read(carsControllerProvider).value, hasLength(2));
  });

  test('a vehicle with only historical activity can be deleted', () async {
    final container = _container(
      seedVehicles: const [_camry, _tucson],
      seedAssociations: const {'v1': VehicleAssociationStatus.none, 'v2': VehicleAssociationStatus.historicalOnly},
    );
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    await container.read(carsControllerProvider.notifier).deleteVehicle('v2');

    expect(container.read(carsControllerProvider).value!.map((v) => v.id), ['v1']);
  });

  test('a mutation failure surfaces as an AsyncError and rethrows to the caller', () async {
    final container = _container(repository: _ThrowingCarsRepository());
    addTearDown(container.dispose);
    await container.read(carsControllerProvider.future);

    // Rethrows so callers like the vehicle form (which rely on try/catch)
    // can tell a save failed, not just observers watching the state.
    await expectLater(
      container.read(carsControllerProvider.notifier).addVehicle(make: 'Toyota', model: 'Camry', year: 2023, plateNumber: 'ABC 1234'),
      throwsException,
    );

    expect(container.read(carsControllerProvider).hasError, isTrue);
  });

  group('auth-state gating (regression coverage for the startup race)', () {
    test('stays in AsyncLoading while auth is still resolving, not AsyncError', () async {
      // No uid passed, and its stream never emits until sign-in/sign-out is
      // called — this stands in for "Firebase Auth hasn't restored the
      // session yet", the exact state a fresh app launch briefly passes
      // through.
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          // carsRepositoryProvider deliberately NOT overridden — this
          // exercises its real uid==null throw, which must never fire
          // while auth is merely unresolved.
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      // A keep-alive listener is required here, not just container.read():
      // without one, the provider isn't kept actively subscribed to the
      // auth stream, so it never even observes signOut()'s emission below.
      container.listen(carsControllerProvider, (previous, next) {});
      final state = container.read(carsControllerProvider);
      expect(state, isA<AsyncLoading<List<Vehicle>>>());

      // Resolve auth before the test ends so build()'s pending await
      // doesn't dangle past the container's disposal.
      await fakeAuth.signOut();
    });

    test('becomes AsyncError once auth resolves to signed-out, not stuck loading forever', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(carsControllerProvider, (previous, next) {});
      expect(container.read(carsControllerProvider), isA<AsyncLoading<List<Vehicle>>>());

      await fakeAuth.signOut(); // emits null — a genuine, resolved sign-out

      // Riverpod wraps the thrown error in its own (not publicly exported)
      // ProviderException, so this matches on the message rather than the
      // original error's type.
      await expectLater(
        container.read(carsControllerProvider.future),
        throwsA(predicate((e) => e.toString().contains('carsRepositoryProvider requires an authenticated user'))),
      );
      expect(container.read(carsControllerProvider).hasError, isTrue);
    });

    test('proceeds to load data once auth resolves to an authenticated uid', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          carsRepositoryProvider.overrideWithValue(MockCarsRepository(seedVehicles: const [_camry])),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(carsControllerProvider, (previous, next) {});
      expect(container.read(carsControllerProvider), isA<AsyncLoading<List<Vehicle>>>());

      await fakeAuth.debugSignIn('signed-in-uid');

      final vehicles = await container.read(carsControllerProvider.future);
      expect(vehicles.map((v) => v.id), ['v1']);
    });
  });
}
