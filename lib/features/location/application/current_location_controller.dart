import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geolocator_location_service.dart';
import '../data/location_service.dart';
import '../domain/build_current_location.dart';
import '../domain/current_location_failure.dart';
import '../domain/location_permission_status.dart';
import '../domain/models/booking_location.dart';

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

/// Drives the real "Use Current Location" flow: permission → GPS fix →
/// reverse geocoding, exposed as one [AsyncValue] the Location screen can
/// render directly (idle/loading/error/resolved) without owning any of
/// that sequencing itself.
///
/// Starts as `AsyncData(null)` — "not attempted yet" — never `AsyncLoading`
/// on its own; nothing runs until [fetchCurrentLocation] is explicitly
/// called (the user tapping "Use Current Location"), unlike every other
/// `Async*Provider` in this app that fetches eagerly on first watch.
class CurrentLocationController extends AsyncNotifier<BookingLocation?> {
  @override
  BookingLocation? build() => null;

  Future<void> fetchCurrentLocation() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(locationServiceProvider);

      var status = await service.getPermissionStatus();
      if (status == LocationPermissionStatus.denied) {
        // Only actually prompts the OS dialog when it hasn't been decided
        // yet — a no-op if the user already granted or permanently denied
        // it, which getPermissionStatus() already told us.
        status = await service.requestPermission();
      }

      switch (status) {
        case LocationPermissionStatus.deniedForever:
          throw const LocationPermissionDeniedForeverException();
        case LocationPermissionStatus.denied:
          throw const LocationPermissionDeniedException();
        case LocationPermissionStatus.serviceDisabled:
          throw const LocationServiceDisabledException();
        case LocationPermissionStatus.granted:
          break;
      }

      final coordinates = await service.getCurrentPosition();
      final geocode = await service.reverseGeocode(latitude: coordinates.latitude, longitude: coordinates.longitude);
      return buildCurrentLocation(coordinates: coordinates, geocode: geocode);
    });
  }
}

final currentLocationControllerProvider = AsyncNotifierProvider<CurrentLocationController, BookingLocation?>(
  CurrentLocationController.new,
);
