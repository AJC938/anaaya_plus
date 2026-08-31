/// Platform-agnostic view of the device's location-permission state — the
/// seam between [LocationService] and whatever plugin (`geolocator` today)
/// actually reports it, so nothing outside `data/` ever imports a plugin
/// type directly.
enum LocationPermissionStatus {
  /// Granted (either "while in use" or "always" — this app never needs the
  /// distinction, since it only ever takes a single one-shot reading).
  granted,

  /// Not yet granted, but the OS permission dialog can still be shown.
  denied,

  /// Permanently denied — the OS will no longer show its own permission
  /// dialog; the user must re-enable it from the app's system settings.
  deniedForever,

  /// Permission itself may be fine, but the device's location services
  /// (GPS/network location) are turned off entirely.
  serviceDisabled,
}
