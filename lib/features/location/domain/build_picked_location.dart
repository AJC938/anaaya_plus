import 'build_current_location.dart';
import 'gps_coordinates.dart';
import 'models/booking_location.dart';
import 'reverse_geocode_result.dart';

/// Turns a map-picked coordinate plus whatever reverse-geocoding resolved
/// into a [BookingLocation] the user can review, name, and save — pure and
/// synchronous, exactly like [buildCurrentLocation], just parameterized by
/// [id] (empty string for a brand-new pick; an existing saved location's
/// document id when re-picking a point during edit) and a user-supplied
/// [label] rather than a fixed one.
///
/// [label] is stored in both language slots verbatim — a user typing "Home"
/// gets exactly that back, never a fabricated translation into the other
/// language (matches [ReverseGeocodeResult]'s own documented convention).
BookingLocation buildPickedLocation({
  required String id,
  required GpsCoordinates coordinates,
  required ReverseGeocodeResult? geocode,
  required String label,
}) {
  final cityAr = geocode?.cityAr;
  final cityEn = geocode?.cityEn;
  final districtAr = geocode?.districtAr;
  final districtEn = geocode?.districtEn;

  return BookingLocation(
    id: id,
    labelAr: label,
    labelEn: label,
    cityAr: cityAr ?? '',
    cityEn: cityEn ?? '',
    districtAr: districtAr ?? '',
    districtEn: districtEn ?? '',
    addressLineAr: geocode?.addressLineAr,
    addressLineEn: geocode?.addressLineEn,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    // A map-picked point is never the old mock current-location entry —
    // see BookingLocation's own doc comment on this field.
    isSimulatedCurrentLocation: false,
  );
}
