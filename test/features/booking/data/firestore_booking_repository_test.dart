import 'package:anaaya_plus/features/booking/data/firestore_booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final scheduledAtUtc = DateTime.utc(2026, 3, 5, 14, 30);
final createdAtUtc = DateTime.utc(2026, 3, 5, 12, 0);

Map<String, dynamic> _fullyPopulatedData({
  String bookingReference = 'AN-20481',
  Map<String, dynamic>? serviceOptionSnapshot,
  String? serviceOptionId,
  Timestamp? estimatedArrival,
  String status = 'upcoming',
  Object? addressLine = 'Prince Sultan Street',
}) {
  return <String, dynamic>{
    'bookingReference': bookingReference,
    'serviceId': 's1',
    'serviceOptionId': serviceOptionId,
    'serviceSnapshot': {'name': 'Oil Change', 'imageAsset': 'oil_change'},
    'serviceOptionSnapshot': serviceOptionSnapshot,
    'vehicleId': 'v1',
    'vehicleSnapshot': {'name': 'Toyota Camry', 'year': 2023, 'plateNumber': 'ABC 1234'},
    'location': <String, dynamic>{
      'label': 'Home',
      'city': 'Jeddah',
      'district': 'Al Zahra District',
      'addressLine': addressLine,
      'coordinates': const GeoPoint(21.5896, 39.1547),
      'isSimulatedCurrentLocation': false,
    },
    'scheduledAt': Timestamp.fromDate(scheduledAtUtc),
    'estimatedArrival': estimatedArrival,
    'price': {'basePrice': 89.0, 'optionPrice': 60.0, 'fees': 10.0, 'total': 159.0},
    'status': status,
    'createdAt': Timestamp.fromDate(createdAtUtc),
  };
}

void main() {
  group('bookingFromFirestoreData', () {
    test('maps a fully populated document', () {
      final booking = bookingFromFirestoreData(
        _fullyPopulatedData(serviceOptionId: 'opt-oil-full', serviceOptionSnapshot: {'name': 'Full Synthetic', 'imageAsset': 'oil_full'}),
      );

      expect(booking.id, 'AN-20481');
      expect(booking.serviceId, 's1');
      expect(booking.serviceName, 'Oil Change');
      expect(booking.serviceImageAsset, 'oil_change');
      expect(booking.serviceOptionId, 'opt-oil-full');
      expect(booking.serviceOptionName, 'Full Synthetic');
      expect(booking.vehicleId, 'v1');
      expect(booking.vehicleName, 'Toyota Camry');
      expect(booking.vehicleYear, 2023);
      expect(booking.plateNumber, 'ABC 1234');
      expect(booking.status, BookingStatus.upcoming);
      // Timestamp.toDate() returns local time — compare the instant via
      // toUtc() rather than assuming a particular local timezone.
      expect(booking.scheduledAt.toUtc(), scheduledAtUtc);
      expect(booking.createdAt.toUtc(), createdAtUtc);
    });

    test('a null serviceOption (no option chosen) maps to null id and name', () {
      final booking = bookingFromFirestoreData(_fullyPopulatedData());

      expect(booking.serviceOptionId, isNull);
      expect(booking.serviceOptionName, isNull);
    });

    test('a null estimatedArrival maps to null, not a crash', () {
      final booking = bookingFromFirestoreData(_fullyPopulatedData());

      expect(booking.estimatedArrival, isNull);
    });

    test('a present estimatedArrival maps to the correct DateTime', () {
      final estimatedArrivalUtc = DateTime.utc(2026, 3, 5, 14, 48);
      final booking = bookingFromFirestoreData(
        _fullyPopulatedData(estimatedArrival: Timestamp.fromDate(estimatedArrivalUtc), status: 'technicianOnTheWay'),
      );

      expect(booking.estimatedArrival?.toUtc(), estimatedArrivalUtc);
      expect(booking.status, BookingStatus.technicianOnTheWay);
    });

    test('maps the location snapshot, including a null addressLine', () {
      final data = _fullyPopulatedData(addressLine: null);

      final booking = bookingFromFirestoreData(data);

      // Only one locale's text is stored (see the mapping function's own
      // doc comment) — both language slots on BookingLocation are filled
      // with the same stored string, since the other language was never
      // captured.
      expect(booking.location.labelAr, 'Home');
      expect(booking.location.labelEn, 'Home');
      expect(booking.location.cityAr, 'Jeddah');
      expect(booking.location.districtEn, 'Al Zahra District');
      expect(booking.location.addressLineAr, isNull);
      expect(booking.location.addressLineEn, isNull);
      expect(booking.location.isSimulatedCurrentLocation, isFalse);
    });

    test('maps the GeoPoint coordinates onto latitude/longitude', () {
      final booking = bookingFromFirestoreData(_fullyPopulatedData());

      expect(booking.location.latitude, 21.5896);
      expect(booking.location.longitude, 39.1547);
    });

    test('a missing/malformed GeoPoint falls back safely, without crashing', () {
      final data = _fullyPopulatedData();
      (data['location'] as Map<String, dynamic>).remove('coordinates');

      final booking = bookingFromFirestoreData(data);

      expect(booking.location.latitude, 0);
      expect(booking.location.longitude, 0);
    });

    test('maps the full price breakdown', () {
      final booking = bookingFromFirestoreData(_fullyPopulatedData());

      expect(booking.price.basePrice, 89.0);
      expect(booking.price.optionPrice, 60.0);
      expect(booking.price.fees, 10.0);
      expect(booking.price.total, 159.0);
    });

    test('maps every known status string to its BookingStatus', () {
      for (final status in BookingStatus.values) {
        final booking = bookingFromFirestoreData(_fullyPopulatedData(status: status.name));
        expect(booking.status, status);
      }
    });

    test('an unrecognized status string falls back to upcoming, without crashing', () {
      final booking = bookingFromFirestoreData(_fullyPopulatedData(status: 'some-future-status'));

      expect(booking.status, BookingStatus.upcoming);
    });

    test('bookingReference comes only from the document data — there is no separate id parameter to confuse it with', () {
      // The function signature itself (Map<String, dynamic>? data) has no
      // id/documentId parameter at all — this test just pins the one place
      // bookingReference can come from: the field inside the data.
      final booking = bookingFromFirestoreData(_fullyPopulatedData(bookingReference: 'AN-99999'));

      expect(booking.id, 'AN-99999');
    });

    test('missing document data (null map) does not crash', () {
      final booking = bookingFromFirestoreData(null);

      expect(booking.id, '');
      expect(booking.serviceId, '');
      expect(booking.serviceOptionId, isNull);
      expect(booking.vehicleId, '');
      expect(booking.status, BookingStatus.upcoming);
      expect(booking.location.labelAr, '');
      expect(booking.price.total, 0);
    });
  });

  group('bookingStatusUpdateFields', () {
    test('a transition to technicianOnTheWay sets status and a simulated estimatedArrival', () {
      final now = DateTime(2026, 1, 5, 9);
      final fields = bookingStatusUpdateFields(BookingStatus.technicianOnTheWay, now: now);

      expect(fields['status'], 'technicianOnTheWay');
      expect(fields['estimatedArrival'], isA<Timestamp>());
      expect((fields['estimatedArrival'] as Timestamp).toDate(), now.add(const Duration(minutes: 15)));
    });

    test('every other transition sets only status — no estimatedArrival field at all', () {
      for (final status in [BookingStatus.upcoming, BookingStatus.inProgress, BookingStatus.completed, BookingStatus.cancelled]) {
        final fields = bookingStatusUpdateFields(status);

        expect(fields['status'], status.name);
        expect(fields.containsKey('estimatedArrival'), isFalse, reason: '$status must not include estimatedArrival');
      }
    });

    test('never includes statusUpdatedAt — the caller stamps that separately with a server timestamp', () {
      final fields = bookingStatusUpdateFields(BookingStatus.inProgress);

      expect(fields.containsKey('statusUpdatedAt'), isFalse);
    });

    test('never includes an id field or any snapshot/price field — only lifecycle fields are ever touched', () {
      final fields = bookingStatusUpdateFields(BookingStatus.technicianOnTheWay);

      expect(fields.keys, containsAll(['status', 'estimatedArrival']));
      expect(fields.keys, hasLength(2));
    });
  });

  group('FirestoreBookingRepository.shouldReleaseSlot', () {
    test('releases when the claim exists and belongs to this exact booking', () {
      final result = FirestoreBookingRepository.shouldReleaseSlot(
        bookingReference: 'AN-20481',
        slotExists: true,
        slotBookingReference: 'AN-20481',
      );

      expect(result, isTrue);
    });

    test('never releases a claim that belongs to a different booking', () {
      final result = FirestoreBookingRepository.shouldReleaseSlot(
        bookingReference: 'AN-20481',
        slotExists: true,
        slotBookingReference: 'AN-99999',
      );

      expect(result, isFalse);
    });

    test('never releases when no claim document was found at all', () {
      final result = FirestoreBookingRepository.shouldReleaseSlot(
        bookingReference: 'AN-20481',
        slotExists: false,
        slotBookingReference: null,
      );

      expect(result, isFalse);
    });

    test('a claim that exists but carries no bookingReference field is never released', () {
      final result = FirestoreBookingRepository.shouldReleaseSlot(
        bookingReference: 'AN-20481',
        slotExists: true,
        slotBookingReference: null,
      );

      expect(result, isFalse);
    });
  });
}
