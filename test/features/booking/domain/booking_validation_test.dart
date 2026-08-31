import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/domain/booking_validation.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';

const _location = BookingLocation(
  id: 'loc-home',
  labelAr: 'المنزل',
  labelEn: 'Home',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الزهراء',
  districtEn: 'Al Zahra District',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

final _timeSlot = TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true);

void main() {
  group('resolveReachableStep', () {
    test('a fresh draft with no location can only reach Location', () {
      const draft = BookingDraft(serviceId: 's1', vehicleId: 'v1');
      expect(resolveReachableStep(draft), BookingStep.location);
    });

    test('a draft with a location but no date can reach Date & Time', () {
      const draft = BookingDraft(serviceId: 's1', vehicleId: 'v1', location: _location);
      expect(resolveReachableStep(draft), BookingStep.dateTime);
    });

    test('a draft with a location and date but no time slot still needs Date & Time', () {
      final draft = BookingDraft(serviceId: 's1', vehicleId: 'v1', location: _location, date: DateTime(2026, 1, 5));
      expect(resolveReachableStep(draft), BookingStep.dateTime);
    });

    test('a draft with location, date, and time slot can reach Review', () {
      final draft = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(2026, 1, 5),
        timeSlot: _timeSlot,
      );
      expect(resolveReachableStep(draft), BookingStep.review);
    });
  });

  group('isDraftComplete', () {
    test('is false until location, date, and time slot are all set', () {
      expect(isDraftComplete(const BookingDraft(serviceId: 's1', vehicleId: 'v1')), isFalse);
      expect(isDraftComplete(const BookingDraft(serviceId: 's1', vehicleId: 'v1', location: _location)), isFalse);
    });

    test('is true once the draft is fully filled in', () {
      final draft = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(2026, 1, 5),
        timeSlot: _timeSlot,
      );
      expect(isDraftComplete(draft), isTrue);
    });
  });

  group('BookingDraft.copyWith', () {
    test('changing the vehicle preserves location, date, and time slot', () {
      final original = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(2026, 1, 5),
        timeSlot: _timeSlot,
      );

      final updated = original.copyWith(vehicleId: 'v2');

      expect(updated.vehicleId, 'v2');
      expect(updated.location, _location);
      expect(updated.date, original.date);
      expect(updated.timeSlot, _timeSlot);
    });
  });
}
