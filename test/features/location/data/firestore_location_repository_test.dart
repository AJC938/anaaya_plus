import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/location/data/firestore_location_repository.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';

const _sampleLocation = BookingLocation(
  id: 'loc-existing', // deliberately non-empty, to prove it's never written into the field map
  labelAr: 'المنزل',
  labelEn: 'Home',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الزهراء',
  districtEn: 'Al Zahra District',
  addressLineAr: 'شارع الأمير سلطان',
  addressLineEn: 'Prince Sultan Street',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

void main() {
  group('locationToFirestoreFields', () {
    test('writes every user-editable field with the correct value', () {
      final fields = locationToFirestoreFields(_sampleLocation);

      expect(fields['labelAr'], 'المنزل');
      expect(fields['labelEn'], 'Home');
      expect(fields['cityAr'], 'جدة');
      expect(fields['cityEn'], 'Jeddah');
      expect(fields['districtAr'], 'حي الزهراء');
      expect(fields['districtEn'], 'Al Zahra District');
      expect(fields['addressLineAr'], 'شارع الأمير سلطان');
      expect(fields['addressLineEn'], 'Prince Sultan Street');
    });

    test('coordinates is a real Firestore GeoPoint, not a separate lat/lng representation', () {
      final fields = locationToFirestoreFields(_sampleLocation);

      expect(fields['coordinates'], isA<GeoPoint>());
      final geoPoint = fields['coordinates'] as GeoPoint;
      expect(geoPoint.latitude, 21.5896);
      expect(geoPoint.longitude, 39.1547);
      expect(fields.containsKey('latitude'), isFalse);
      expect(fields.containsKey('longitude'), isFalse);
    });

    test('the document id is never duplicated into the field map', () {
      final fields = locationToFirestoreFields(_sampleLocation);

      expect(fields.containsKey('id'), isFalse);
    });

    test('createdAt is never included — each call site in FirestoreLocationRepository decides that separately', () {
      final fields = locationToFirestoreFields(_sampleLocation);

      expect(fields.containsKey('createdAt'), isFalse);
    });
  });

  group('locationFromFirestoreData', () {
    const id = 'loc-123';

    test('maps a fully populated document', () {
      final location = locationFromFirestoreData({
        'labelAr': 'المنزل',
        'labelEn': 'Home',
        'cityAr': 'جدة',
        'cityEn': 'Jeddah',
        'districtAr': 'حي الزهراء',
        'districtEn': 'Al Zahra District',
        'addressLineAr': 'شارع الأمير سلطان',
        'addressLineEn': 'Prince Sultan Street',
        'coordinates': const GeoPoint(21.5896, 39.1547),
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, id: id);

      expect(location.id, id);
      expect(location.labelAr, 'المنزل');
      expect(location.labelEn, 'Home');
      expect(location.cityAr, 'جدة');
      expect(location.cityEn, 'Jeddah');
      expect(location.districtAr, 'حي الزهراء');
      expect(location.districtEn, 'Al Zahra District');
      expect(location.addressLineAr, 'شارع الأمير سلطان');
      expect(location.addressLineEn, 'Prince Sultan Street');
      expect(location.latitude, 21.5896);
      expect(location.longitude, 39.1547);
      // A saved Firestore document is never the mock "Current Location"
      // entry — that concept stays entirely local (see
      // FirestoreLocationRepository's own doc comment).
      expect(location.isSimulatedCurrentLocation, isFalse);
    });

    test('null addressLine values map safely to null, not an empty string', () {
      final location = locationFromFirestoreData({
        'labelAr': 'المنزل',
        'labelEn': 'Home',
        'cityAr': 'جدة',
        'cityEn': 'Jeddah',
        'districtAr': 'حي الزهراء',
        'districtEn': 'Al Zahra District',
        'addressLineAr': null,
        'addressLineEn': null,
        'coordinates': const GeoPoint(21.5896, 39.1547),
      }, id: id);

      expect(location.addressLineAr, isNull);
      expect(location.addressLineEn, isNull);
    });

    test('the Firestore document id becomes BookingLocation.id', () {
      final location = locationFromFirestoreData({'labelAr': 'العمل', 'labelEn': 'Work'}, id: id);

      expect(location.id, id);
    });

    test('a stray "id" field in the document data cannot override the document id', () {
      final location = locationFromFirestoreData({'id': 'someone-elses-id', 'labelAr': 'العمل', 'labelEn': 'Work'}, id: id);

      expect(location.id, id);
      expect(location.id, isNot('someone-elses-id'));
    });

    test('a GeoPoint maps correctly to latitude/longitude', () {
      final location = locationFromFirestoreData({'coordinates': const GeoPoint(24.7136, 46.6753)}, id: id);

      expect(location.latitude, 24.7136);
      expect(location.longitude, 46.6753);
    });

    // Matches bookingFromFirestoreData's own established contract: a
    // *missing* field falls back safely, but a wrong-type non-null value
    // is a genuine data-corruption case that isn't expected to survive a
    // silent cast — same as every other `as T?` field in this mapping.
    test('a missing coordinates field falls back safely to 0/0, without crashing', () {
      final location = locationFromFirestoreData({'labelAr': 'العمل', 'labelEn': 'Work'}, id: id);

      expect(location.latitude, 0);
      expect(location.longitude, 0);
    });

    test('createdAt is present in the document but has no domain field to map onto — it is safely ignored', () {
      // BookingLocation carries no createdAt field (see the mapping
      // function's own doc comment) — it exists in the stored document
      // purely as record-keeping. Confirms its presence never leaks into
      // (or crashes) any mapped field.
      final location = locationFromFirestoreData({
        'labelAr': 'المنزل',
        'labelEn': 'Home',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, id: id);

      expect(location.labelAr, 'المنزل');
      expect(location.labelEn, 'Home');
    });

    test('missing document data (null map) does not crash', () {
      final location = locationFromFirestoreData(null, id: id);

      expect(location.id, id);
      expect(location.labelAr, '');
      expect(location.labelEn, '');
      expect(location.cityAr, '');
      expect(location.cityEn, '');
      expect(location.districtAr, '');
      expect(location.districtEn, '');
      expect(location.addressLineAr, isNull);
      expect(location.addressLineEn, isNull);
      expect(location.latitude, 0);
      expect(location.longitude, 0);
      expect(location.isSimulatedCurrentLocation, isFalse);
    });
  });
}
