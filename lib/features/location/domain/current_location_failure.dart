/// The distinct, user-actionable ways resolving the device's current
/// location can fail — thrown by [LocationService] and surfaced through
/// [CurrentLocationController]'s [AsyncError] state so the UI can show a
/// tailored message and, where relevant, a real recovery action (open
/// settings) instead of one generic "something went wrong."
library;

/// The OS permission dialog was shown (or could still be shown) and the
/// user said no.
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();

  @override
  String toString() => 'Location permission was denied.';
}

/// The user denied permission permanently — the OS will not show its own
/// dialog again; recovery requires the app's system settings page.
class LocationPermissionDeniedForeverException implements Exception {
  const LocationPermissionDeniedForeverException();

  @override
  String toString() => 'Location permission was permanently denied.';
}

/// Permission is fine, but the device's location services (GPS/network
/// location) are switched off entirely.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();

  @override
  String toString() => 'Location services are disabled on this device.';
}

/// Permission and services are both fine, but a GPS fix could not be
/// obtained (timeout, no signal, or a platform-reported failure).
class PositionUnavailableException implements Exception {
  const PositionUnavailableException();

  @override
  String toString() => 'The device position could not be determined.';
}

/// A GPS fix was obtained, but turning it into an address failed (network
/// failure, timeout, or no geocoder backend present on the device).
class ReverseGeocodeFailedException implements Exception {
  const ReverseGeocodeFailedException();

  @override
  String toString() => 'The coordinates could not be resolved into an address.';
}
