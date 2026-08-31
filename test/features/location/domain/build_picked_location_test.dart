import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/location/domain/build_picked_location.dart';
import 'package:anaaya_plus/features/location/domain/gps_coordinates.dart';
import 'package:anaaya_plus/features/location/domain/reverse_geocode_result.dart';

const _coordinates = GpsCoordinates(latitude: 21.5433, longitude: 39.1728);

void main() {
  test('a successful conversion carries the real coordinates, geocoded fields, and the user label through', () {
    const geocode = ReverseGeocodeResult(
      cityAr: 'جدة',
      cityEn: 'Jeddah',
      districtAr: 'الروضة',
      districtEn: 'Al Rawdah',
      addressLineAr: 'شارع الأمير سعود الفيصل',
      addressLineEn: 'Prince Saud Al Faisal St.',
    );

    final location = buildPickedLocation(id: '', coordinates: _coordinates, geocode: geocode, label: "Friend's House");

    expect(location.id, '');
    expect(location.latitude, 21.5433);
    expect(location.longitude, 39.1728);
    expect(location.cityAr, 'جدة');
    expect(location.cityEn, 'Jeddah');
    expect(location.districtAr, 'الروضة');
    expect(location.districtEn, 'Al Rawdah');
    expect(location.addressLineAr, 'شارع الأمير سعود الفيصل');
    expect(location.addressLineEn, 'Prince Saud Al Faisal St.');
  });

  test('the same user-typed label is stored verbatim in both language slots — never a fabricated translation', () {
    final location = buildPickedLocation(id: '', coordinates: _coordinates, geocode: null, label: 'المنزل الثاني');

    expect(location.labelAr, 'المنزل الثاني');
    expect(location.labelEn, 'المنزل الثاني');
  });

  test('an existing document id is preserved for an edit-mode rebuild', () {
    final location = buildPickedLocation(id: 'loc-existing', coordinates: _coordinates, geocode: null, label: 'Home');

    expect(location.id, 'loc-existing');
  });

  test('a null geocode result falls back to honest empty city/district/address, never fabricated', () {
    final location = buildPickedLocation(id: '', coordinates: _coordinates, geocode: null, label: 'Somewhere');

    expect(location.cityAr, '');
    expect(location.cityEn, '');
    expect(location.districtAr, '');
    expect(location.districtEn, '');
    expect(location.addressLineAr, isNull);
    expect(location.addressLineEn, isNull);
  });

  test('a map-picked point is never flagged as the old mock simulated current-location entry', () {
    final location = buildPickedLocation(id: '', coordinates: _coordinates, geocode: null, label: 'Somewhere');

    expect(location.isSimulatedCurrentLocation, isFalse);
  });
}
