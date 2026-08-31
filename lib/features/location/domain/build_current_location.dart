import 'gps_coordinates.dart';
import 'models/booking_location.dart';
import 'reverse_geocode_result.dart';

/// The fixed id every resolved current-location result carries. Never
/// persisted (a real GPS fix is never a saved Firestore document — see
/// `FirestoreLocationRepository`'s own doc comment) — it only exists so the
/// Location screen can compare `draft.location?.id` against it to know the
/// current-location card is the one currently selected, exactly like a
/// saved location's Firestore document id serves the same comparison.
const currentLocationId = 'current-location';

/// Turns a raw GPS fix plus whatever reverse-geocoding managed to resolve
/// into a [BookingLocation] — pure, synchronous, and independent of
/// [LocationService], so it's unit-testable without touching GPS or
/// network at all.
///
/// [geocode] is nullable for two independent reasons, both legitimate:
/// reverse geocoding wasn't attempted, or it succeeded with an empty
/// result (a real coordinate with no resolvable address, e.g. open desert
/// or water — not a failure). Either way this never crashes; every city/
/// district/addressLine field falls back to an honest empty value rather
/// than a fabricated one, and the label falls back to the raw coordinates
/// themselves so the user is never shown a place name nobody actually
/// found.
BookingLocation buildCurrentLocation({required GpsCoordinates coordinates, ReverseGeocodeResult? geocode}) {
  final cityAr = geocode?.cityAr;
  final cityEn = geocode?.cityEn;
  final districtAr = geocode?.districtAr;
  final districtEn = geocode?.districtEn;

  return BookingLocation(
    id: currentLocationId,
    labelAr: suggestedLocationLabel(district: districtAr, city: cityAr, coordinates: coordinates),
    labelEn: suggestedLocationLabel(district: districtEn, city: cityEn, coordinates: coordinates),
    cityAr: cityAr ?? '',
    cityEn: cityEn ?? '',
    districtAr: districtAr ?? '',
    districtEn: districtEn ?? '',
    addressLineAr: geocode?.addressLineAr,
    addressLineEn: geocode?.addressLineEn,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    // A real GPS fix is never the old mock entry — see BookingLocation's
    // own doc comment on this field.
    isSimulatedCurrentLocation: false,
  );
}

/// A reasonable default label for a resolved point that has no user-given
/// name yet — "district, city" when both resolved, falling back to
/// whichever one did, and finally to the raw coordinates themselves so the
/// user is never shown a fabricated place name. Shared by
/// [buildCurrentLocation] and the map picker's own suggested-label field
/// (`buildPickedLocation`) — the exact same fallback rule either way.
String suggestedLocationLabel({required String? district, required String? city, required GpsCoordinates coordinates}) {
  final hasDistrict = district != null && district.isNotEmpty;
  final hasCity = city != null && city.isNotEmpty;
  if (hasDistrict && hasCity) return '$district, $city';
  if (hasCity) return city;
  if (hasDistrict) return district;
  return '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
}
