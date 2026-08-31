import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/location/domain/build_current_location.dart';
import 'package:anaaya_plus/features/location/domain/gps_coordinates.dart';
import 'package:anaaya_plus/features/location/domain/reverse_geocode_result.dart';

const _coordinates = GpsCoordinates(latitude: 21.5433, longitude: 39.1728);

void main() {
  test('a successful conversion carries the real coordinates and resolved address through', () {
    const geocode = ReverseGeocodeResult(
      cityAr: 'جدة',
      cityEn: 'Jeddah',
      districtAr: 'الروضة',
      districtEn: 'Al Rawdah',
      addressLineAr: 'شارع الأمير سعود الفيصل',
      addressLineEn: 'Prince Saud Al Faisal St.',
    );

    final location = buildCurrentLocation(coordinates: _coordinates, geocode: geocode);

    expect(location.id, currentLocationId);
    expect(location.latitude, 21.5433);
    expect(location.longitude, 39.1728);
    expect(location.cityAr, 'جدة');
    expect(location.cityEn, 'Jeddah');
    expect(location.districtAr, 'الروضة');
    expect(location.districtEn, 'Al Rawdah');
    expect(location.addressLineAr, 'شارع الأمير سعود الفيصل');
    expect(location.addressLineEn, 'Prince Saud Al Faisal St.');
    expect(location.labelAr, 'الروضة, جدة');
    expect(location.labelEn, 'Al Rawdah, Jeddah');
  });

  test('a real GPS result is never flagged as the old mock simulated entry', () {
    const geocode = ReverseGeocodeResult(cityEn: 'Jeddah', districtEn: 'Al Rawdah');

    final location = buildCurrentLocation(coordinates: _coordinates, geocode: geocode);

    expect(location.isSimulatedCurrentLocation, isFalse);
  });

  test('a null geocode result (reverse geocoding not attempted or found nothing) falls back to the raw coordinates', () {
    final location = buildCurrentLocation(coordinates: _coordinates, geocode: null);

    expect(location.cityAr, '');
    expect(location.cityEn, '');
    expect(location.districtAr, '');
    expect(location.districtEn, '');
    expect(location.addressLineAr, isNull);
    expect(location.addressLineEn, isNull);
    // Honest — never a fabricated place name for coordinates nobody
    // actually resolved.
    expect(location.labelAr, '21.5433, 39.1728');
    expect(location.labelEn, '21.5433, 39.1728');
    expect(location.isSimulatedCurrentLocation, isFalse);
  });

  test('a city with no district falls back to the city alone as the label', () {
    const geocode = ReverseGeocodeResult(cityEn: 'Jeddah');

    final location = buildCurrentLocation(coordinates: _coordinates, geocode: geocode);

    expect(location.labelEn, 'Jeddah');
  });

  test('a district with no city falls back to the district alone as the label', () {
    const geocode = ReverseGeocodeResult(districtEn: 'Al Rawdah');

    final location = buildCurrentLocation(coordinates: _coordinates, geocode: geocode);

    expect(location.labelEn, 'Al Rawdah');
  });
}
