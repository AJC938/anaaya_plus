import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/location/application/location_providers.dart';
import 'package:anaaya_plus/features/location/data/location_repository.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';

import '../../../support/auth_fixtures.dart';

const _home = BookingLocation(
  id: 'loc-home',
  labelAr: 'المنزل',
  labelEn: 'Home',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الزهراء',
  districtEn: 'Al Zahra District',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

const _newLocationPick = BookingLocation(
  id: '',
  labelAr: 'صديق',
  labelEn: "Friend's House",
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الروضة',
  districtEn: 'Al Rawdah District',
  latitude: 21.55,
  longitude: 39.17,
  isSimulatedCurrentLocation: false,
);

/// A fully in-memory, mutable [LocationRepository] fake — mirrors
/// `MockLocationRepository`'s own shape closely enough to exercise real
/// add/update/delete behavior without touching Firestore.
class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository({List<BookingLocation>? seed, this.failNextMutation = false}) : _locations = List.of(seed ?? const [_home]);

  final List<BookingLocation> _locations;
  bool failNextMutation;
  int _nextId = 1;

  @override
  Future<List<BookingLocation>> fetchSavedLocations() async => List.unmodifiable(_locations);

  @override
  Future<BookingLocation> addLocation(BookingLocation location) async {
    if (failNextMutation) throw Exception('mock add failure');
    final created = BookingLocation(
      id: 'loc-new-${_nextId++}',
      labelAr: location.labelAr,
      labelEn: location.labelEn,
      cityAr: location.cityAr,
      cityEn: location.cityEn,
      districtAr: location.districtAr,
      districtEn: location.districtEn,
      addressLineAr: location.addressLineAr,
      addressLineEn: location.addressLineEn,
      latitude: location.latitude,
      longitude: location.longitude,
      isSimulatedCurrentLocation: false,
    );
    _locations.add(created);
    return created;
  }

  @override
  Future<BookingLocation> updateLocation(BookingLocation location) async {
    if (failNextMutation) throw Exception('mock update failure');
    final index = _locations.indexWhere((existing) => existing.id == location.id);
    if (index == -1) throw StateError('Location ${location.id} not found');
    _locations[index] = location;
    return location;
  }

  @override
  Future<void> deleteLocation(String id) async {
    if (failNextMutation) throw Exception('mock delete failure');
    _locations.removeWhere((location) => location.id == id);
  }
}

ProviderContainer _container({List<BookingLocation>? seed, bool failNextMutation = false}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      locationRepositoryProvider.overrideWithValue(_FakeLocationRepository(seed: seed, failNextMutation: failNextMutation)),
    ],
  );
  // A keep-alive listener is required: without one, savedLocationsControllerProvider
  // isn't kept actively subscribed to authStateChangesProvider's stream, so
  // build()'s `await ref.watch(authStateChangesProvider.future)` never
  // observes FakeAuthRepository's emission and hangs — see
  // FakeAuthRepository's own doc comment.
  container.listen(savedLocationsControllerProvider, (previous, next) {});
  return container;
}

void main() {
  group('savedLocationsControllerProvider — real saved locations only', () {
    test('an empty saved-locations repository returns an empty list', () async {
      final container = _container(seed: const []);
      addTearDown(container.dispose);

      final locations = await container.read(savedLocationsControllerProvider.future);

      expect(locations, isEmpty);
    });

    test('real saved locations pass through unchanged', () async {
      final container = _container(seed: const [_home]);
      addTearDown(container.dispose);

      final locations = await container.read(savedLocationsControllerProvider.future);

      expect(locations, [_home]);
    });
  });

  group('mutations', () {
    test('addLocation returns the created location with a real assigned id, and it appears in the list', () async {
      final container = _container(seed: const []);
      addTearDown(container.dispose);
      await container.read(savedLocationsControllerProvider.future);

      final created = await container.read(savedLocationsControllerProvider.notifier).addLocation(_newLocationPick);

      expect(created.id, isNotEmpty);
      expect(created.labelEn, "Friend's House");
      final locations = container.read(savedLocationsControllerProvider).value!;
      expect(locations.map((l) => l.id), contains(created.id));
    });

    test('updateLocation updates the existing entry in place — no duplicate created', () async {
      final container = _container(seed: const [_home]);
      addTearDown(container.dispose);
      await container.read(savedLocationsControllerProvider.future);

      final updated = BookingLocation(
        id: _home.id,
        labelAr: 'منزل جديد',
        labelEn: 'New Home',
        cityAr: _home.cityAr,
        cityEn: _home.cityEn,
        districtAr: _home.districtAr,
        districtEn: _home.districtEn,
        latitude: _home.latitude,
        longitude: _home.longitude,
        isSimulatedCurrentLocation: false,
      );
      await container.read(savedLocationsControllerProvider.notifier).updateLocation(updated);

      final locations = container.read(savedLocationsControllerProvider).value!;
      expect(locations, hasLength(1)); // no duplicate created
      expect(locations.single.id, _home.id);
      expect(locations.single.labelEn, 'New Home');
    });

    test('deleteLocation removes exactly the targeted location', () async {
      final container = _container(seed: const [_home]);
      addTearDown(container.dispose);
      await container.read(savedLocationsControllerProvider.future);

      await container.read(savedLocationsControllerProvider.notifier).deleteLocation(_home.id);

      expect(container.read(savedLocationsControllerProvider).value, isEmpty);
    });

    test('an addLocation/updateLocation failure surfaces as an AsyncError and rethrows to the caller', () async {
      final container = _container(seed: const [_home], failNextMutation: true);
      addTearDown(container.dispose);
      await container.read(savedLocationsControllerProvider.future);

      // Rethrows so callers like the map picker (which rely on try/catch)
      // can tell a save failed, not just observers watching the state.
      await expectLater(
        container.read(savedLocationsControllerProvider.notifier).addLocation(_newLocationPick),
        throwsException,
      );
      expect(container.read(savedLocationsControllerProvider).hasError, isTrue);
    });

    // deleteLocation is deliberately NOT symmetric with add/update here:
    // the repository call happens *outside* AsyncValue.guard (see the
    // controller's own doc comment), so a failed delete rethrows without
    // ever touching state — the previously loaded list, including the item
    // that just failed to delete, must stay fully visible rather than being
    // replaced by a generic error. Matches CarsController.deleteVehicle's
    // exact same reasoning.
    test('a deleteLocation failure rethrows but leaves the previous list visible, not an AsyncError', () async {
      final container = _container(seed: const [_home], failNextMutation: true);
      addTearDown(container.dispose);
      await container.read(savedLocationsControllerProvider.future);

      await expectLater(
        container.read(savedLocationsControllerProvider.notifier).deleteLocation(_home.id),
        throwsException,
      );

      final state = container.read(savedLocationsControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value, [_home]);
    });
  });

  group('auth-state gating (regression coverage for the startup race)', () {
    test('stays in AsyncLoading while auth is still resolving, not AsyncError', () async {
      // No uid passed, and its stream never emits until sign-in/sign-out is
      // called — this stands in for "Firebase Auth hasn't restored the
      // session yet", the exact state a fresh app launch briefly passes
      // through. Mirrors carsControllerProvider's own regression test.
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          // locationRepositoryProvider deliberately NOT overridden — this
          // exercises its real uid==null throw, which must never fire while
          // auth is merely unresolved.
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(savedLocationsControllerProvider, (previous, next) {});
      final state = container.read(savedLocationsControllerProvider);
      expect(state, isA<AsyncLoading<List<BookingLocation>>>());

      // Resolve auth before the test ends so the pending await doesn't
      // dangle past the container's disposal.
      await fakeAuth.signOut();
    });

    test('becomes AsyncError once auth resolves to signed-out, not stuck loading forever', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(savedLocationsControllerProvider, (previous, next) {});
      expect(container.read(savedLocationsControllerProvider), isA<AsyncLoading<List<BookingLocation>>>());

      await fakeAuth.signOut(); // emits null — a genuine, resolved sign-out

      // Riverpod wraps the thrown error in its own (not publicly exported)
      // ProviderException, so this matches on the message rather than the
      // original error's type.
      await expectLater(
        container.read(savedLocationsControllerProvider.future),
        throwsA(predicate((e) => e.toString().contains('locationRepositoryProvider requires an authenticated user'))),
      );
      expect(container.read(savedLocationsControllerProvider).hasError, isTrue);
    });
  });
}
