import '../domain/gps_coordinates.dart';
import '../domain/location_permission_status.dart';
import '../domain/reverse_geocode_result.dart';

/// Data seam for device GPS + reverse geocoding — deliberately separate
/// from [LocationRepository], which only ever knows about saved Firestore
/// locations and has nothing to do with the device's sensors.
/// [GeolocatorLocationService] is the only implementation; the UI layer
/// (`LocationScreen`/`CurrentLocationController`) depends on this
/// abstraction only, never on the `geolocator`/`geocoding` plugin types
/// directly — that keeps them fake-able in tests without any platform
/// channel involved.
///
/// Every method throws one of the typed exceptions in
/// `domain/current_location_failure.dart` on failure — never a bare
/// platform exception — so callers can show a specific, actionable message
/// instead of one generic error.
abstract class LocationService {
  /// The current permission state, without prompting the user.
  Future<LocationPermissionStatus> getPermissionStatus();

  /// Prompts the OS permission dialog (a no-op if already decided) and
  /// returns the resulting state.
  Future<LocationPermissionStatus> requestPermission();

  /// A one-shot GPS fix.
  ///
  /// Throws [LocationServiceDisabledException] if the device's location
  /// services are off, or [PositionUnavailableException] for any other
  /// failure (timeout, no signal, platform error). Never checks permission
  /// itself — callers must have already confirmed
  /// [LocationPermissionStatus.granted].
  Future<GpsCoordinates> getCurrentPosition();

  /// Resolves [latitude]/[longitude] into a human-readable address.
  ///
  /// Returns `null` when the backend has no result for these coordinates
  /// (a legitimate, non-error outcome — e.g. open water or desert), and
  /// throws [ReverseGeocodeFailedException] when the lookup itself fails
  /// (network/timeout/no geocoder backend present).
  Future<ReverseGeocodeResult?> reverseGeocode({required double latitude, required double longitude});

  /// Opens the app's system settings page — the only real recovery once
  /// permission has been permanently denied, since the OS won't show its
  /// own request dialog again. Returns `false` if the platform couldn't
  /// open it; never throws.
  Future<bool> openAppSettings();
}
