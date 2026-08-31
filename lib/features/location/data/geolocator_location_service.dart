import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart' show Geocoding, Placemark;
import 'package:geolocator/geolocator.dart' as geo;

import '../domain/current_location_failure.dart';
import '../domain/gps_coordinates.dart';
import '../domain/location_permission_status.dart';
import '../domain/reverse_geocode_result.dart';
import 'location_service.dart';

/// Real implementation wrapping the `geolocator` (GPS/permission) and
/// `geocoding` (reverse geocoding) plugins. This is the only file in the
/// app that imports either plugin — everything else, including the whole
/// UI layer, only ever sees [LocationService]'s plugin-free types.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({Geocoding? geocoding}) : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async {
    return _resolveStatus(await geo.Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    return _resolveStatus(await geo.Geolocator.requestPermission());
  }

  /// Service-enabled is only meaningful once permission is otherwise
  /// granted — matches the real-world order a user actually resolves these
  /// in (grant permission, then possibly still need to turn GPS on).
  Future<LocationPermissionStatus> _resolveStatus(geo.LocationPermission permission) async {
    switch (permission) {
      case geo.LocationPermission.denied:
      case geo.LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
      case geo.LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case geo.LocationPermission.whileInUse:
      case geo.LocationPermission.always:
        final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        return serviceEnabled ? LocationPermissionStatus.granted : LocationPermissionStatus.serviceDisabled;
    }
  }

  @override
  Future<GpsCoordinates> getCurrentPosition() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return GpsCoordinates(latitude: position.latitude, longitude: position.longitude);
    } on geo.LocationServiceDisabledException {
      // Can still be thrown here even after getPermissionStatus() checked
      // it — services can be switched off in the gap between the check and
      // this call.
      throw const LocationServiceDisabledException();
    } catch (_) {
      throw const PositionUnavailableException();
    }
  }

  @override
  Future<ReverseGeocodeResult?> reverseGeocode({required double latitude, required double longitude}) async {
    // Android-only, and best-effort: if this itself throws, that's not
    // reliable enough signal on its own to fail the whole lookup — the
    // actual placemark call below is the real test.
    var backendPresent = true;
    try {
      backendPresent = await _geocoding.isPresent();
    } catch (_) {
      backendPresent = true;
    }
    if (!backendPresent) {
      throw const ReverseGeocodeFailedException();
    }

    // The primary (Arabic — the app's default locale) call is what
    // determines success/failure/no-result for the whole operation. The
    // English call is a best-effort enhancement layered on top: if it
    // fails or returns nothing, the Arabic result is reused for the
    // English slot too — honest duplication (see ReverseGeocodeResult's
    // own doc comment), never a fabricated translation.
    final List<Placemark> primary;
    try {
      primary = await _geocoding.placemarkFromCoordinates(latitude, longitude, locale: const Locale('ar'));
    } catch (_) {
      throw const ReverseGeocodeFailedException();
    }
    if (primary.isEmpty) return null;

    final ar = primary.first;
    final en = await _placemarkOrNull(latitude, longitude, const Locale('en')) ?? ar;

    return ReverseGeocodeResult(
      cityAr: ar.locality,
      cityEn: en.locality,
      districtAr: ar.subLocality,
      districtEn: en.subLocality,
      addressLineAr: _addressLine(ar),
      addressLineEn: _addressLine(en),
    );
  }

  Future<Placemark?> _placemarkOrNull(double latitude, double longitude, Locale locale) async {
    try {
      final results = await _geocoding.placemarkFromCoordinates(latitude, longitude, locale: locale);
      return results.isEmpty ? null : results.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await geo.Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  String? _addressLine(Placemark placemark) {
    if (placemark.thoroughfare?.isNotEmpty == true) return placemark.thoroughfare;
    if (placemark.street?.isNotEmpty == true) return placemark.street;
    if (placemark.name?.isNotEmpty == true) return placemark.name;
    return null;
  }
}
