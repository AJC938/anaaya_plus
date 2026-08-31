/// The structured result of resolving a [GpsCoordinates] fix into a
/// human-readable address. Every field is nullable and independently
/// optional — a real geocoder backend routinely returns partial data (e.g.
/// a city with no district, or a district with no street), and this must
/// never be treated as a failure on its own; only the complete absence of
/// any result is (see [LocationService.reverseGeocode]).
///
/// Carries both language variants where the backend actually returned them
/// (this app asks for Arabic and English separately — see
/// `GeolocatorLocationService`). When the backend only ever returns one
/// language for a given field, the *Ar and *En variants of that field are
/// intentionally left holding the same string rather than one being
/// fabricated as a "translation" — see [buildCurrentLocation]'s own doc
/// comment for where that gets resolved into a [BookingLocation].
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.cityAr,
    this.cityEn,
    this.districtAr,
    this.districtEn,
    this.addressLineAr,
    this.addressLineEn,
  });

  final String? cityAr;
  final String? cityEn;
  final String? districtAr;
  final String? districtEn;
  final String? addressLineAr;
  final String? addressLineEn;
}
