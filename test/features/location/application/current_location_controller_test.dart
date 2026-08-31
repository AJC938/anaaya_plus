import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/location/application/current_location_controller.dart';
import 'package:anaaya_plus/features/location/data/location_service.dart';
import 'package:anaaya_plus/features/location/domain/current_location_failure.dart';
import 'package:anaaya_plus/features/location/domain/gps_coordinates.dart';
import 'package:anaaya_plus/features/location/domain/location_permission_status.dart';
import 'package:anaaya_plus/features/location/domain/reverse_geocode_result.dart';

const _coordinates = GpsCoordinates(latitude: 21.5433, longitude: 39.1728);
const _geocode = ReverseGeocodeResult(cityEn: 'Jeddah', districtEn: 'Al Rawdah');

/// A fully controllable [LocationService] fake — no platform channel, no
/// real GPS/network involved, matching the "use fakes for the location and
/// geocoding layers" requirement directly.
class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.permissionStatus = LocationPermissionStatus.granted,
    LocationPermissionStatus? requestResult,
    this.positionError,
    this.geocode = _geocode,
    this.geocodeError,
  }) : requestResult = requestResult ?? permissionStatus;

  final LocationPermissionStatus permissionStatus;
  final LocationPermissionStatus requestResult;
  final Object? positionError;
  final ReverseGeocodeResult? geocode;
  final Object? geocodeError;

  int getPermissionStatusCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async {
    getPermissionStatusCalls++;
    return permissionStatus;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCalls++;
    return requestResult;
  }

  @override
  Future<GpsCoordinates> getCurrentPosition() async {
    final error = positionError;
    if (error != null) throw error;
    return _coordinates;
  }

  @override
  Future<ReverseGeocodeResult?> reverseGeocode({required double latitude, required double longitude}) async {
    final error = geocodeError;
    if (error != null) throw error;
    return geocode;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

ProviderContainer _container(_FakeLocationService fake) {
  final container = ProviderContainer(overrides: [locationServiceProvider.overrideWithValue(fake)]);
  return container;
}

void main() {
  test('starts as AsyncData(null) — nothing is attempted until fetchCurrentLocation is called', () {
    final container = _container(_FakeLocationService());
    addTearDown(container.dispose);

    final state = container.read(currentLocationControllerProvider);

    expect(state.hasValue, isTrue);
    expect(state.value, isNull);
    expect(state.isLoading, isFalse);
  });

  test('1. permission already granted resolves without ever calling requestPermission', () async {
    final fake = _FakeLocationService(permissionStatus: LocationPermissionStatus.granted);
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).hasValue, isTrue);
    expect(fake.requestPermissionCalls, 0);
  });

  test('2. permission denied (after being asked) surfaces LocationPermissionDeniedException', () async {
    final fake = _FakeLocationService(permissionStatus: LocationPermissionStatus.denied, requestResult: LocationPermissionStatus.denied);
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    final state = container.read(currentLocationControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<LocationPermissionDeniedException>());
    // Denied (not yet decided) must actually prompt the OS dialog.
    expect(fake.requestPermissionCalls, 1);
  });

  test('3. permission permanently denied surfaces LocationPermissionDeniedForeverException', () async {
    final fake = _FakeLocationService(
      permissionStatus: LocationPermissionStatus.denied,
      requestResult: LocationPermissionStatus.deniedForever,
    );
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).error, isA<LocationPermissionDeniedForeverException>());
  });

  test('a permission already permanently denied on the first check never prompts again', () async {
    final fake = _FakeLocationService(permissionStatus: LocationPermissionStatus.deniedForever);
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).error, isA<LocationPermissionDeniedForeverException>());
    // The OS won't show its own dialog again once permanently denied — the
    // service contract says getPermissionStatus() already tells us this,
    // so requestPermission() (which only ever gets called for the plain
    // "denied" case) must never fire here.
    expect(fake.requestPermissionCalls, 0);
  });

  test('4. disabled location services surfaces LocationServiceDisabledException', () async {
    final fake = _FakeLocationService(permissionStatus: LocationPermissionStatus.serviceDisabled);
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).error, isA<LocationServiceDisabledException>());
  });

  test('5. a successful GPS position proceeds to reverse geocoding and resolves', () async {
    final container = _container(_FakeLocationService());
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    final state = container.read(currentLocationControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value, isNotNull);
    expect(state.value!.latitude, 21.5433);
    expect(state.value!.longitude, 39.1728);
  });

  test('6. a GPS failure/exception surfaces PositionUnavailableException, without crashing', () async {
    final fake = _FakeLocationService(positionError: const PositionUnavailableException());
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).error, isA<PositionUnavailableException>());
  });

  test('7. successful reverse geocoding is reflected in the resolved BookingLocation', () async {
    final container = _container(_FakeLocationService());
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    final location = container.read(currentLocationControllerProvider).value;
    expect(location!.cityEn, 'Jeddah');
    expect(location.districtEn, 'Al Rawdah');
  });

  test('8. a reverse-geocoding failure surfaces ReverseGeocodeFailedException, without crashing', () async {
    final fake = _FakeLocationService(geocodeError: const ReverseGeocodeFailedException());
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    expect(container.read(currentLocationControllerProvider).error, isA<ReverseGeocodeFailedException>());
  });

  test('9./10. a full successful run converts into a real, non-simulated BookingLocation', () async {
    final container = _container(_FakeLocationService());
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    final location = container.read(currentLocationControllerProvider).value!;
    expect(location.latitude, 21.5433);
    expect(location.longitude, 39.1728);
    expect(location.cityEn, 'Jeddah');
    expect(location.districtEn, 'Al Rawdah');
    expect(location.isSimulatedCurrentLocation, isFalse);
  });

  test('a null reverse-geocoding result (no address found for a real coordinate) still resolves, not an error', () async {
    final fake = _FakeLocationService(geocode: null);
    final container = _container(fake);
    addTearDown(container.dispose);

    await container.read(currentLocationControllerProvider.notifier).fetchCurrentLocation();

    final state = container.read(currentLocationControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value, isNotNull);
    expect(state.value!.isSimulatedCurrentLocation, isFalse);
  });
}
