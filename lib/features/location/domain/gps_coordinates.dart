/// A raw device GPS fix — deliberately minimal (no accuracy/heading/speed):
/// nothing downstream of [LocationService] needs anything beyond the
/// coordinate pair itself.
class GpsCoordinates {
  const GpsCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
