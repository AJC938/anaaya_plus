import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/data/booking_repository.dart';
import 'package:anaaya_plus/features/booking/data/mock_booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/booking_status_transition.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/cars/data/mock_cars_repository.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/scheduling/data/mock_scheduling_repository.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';
import 'package:anaaya_plus/features/services/data/mock_services_repository.dart';

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

MockBookingRepository _repository() {
  return MockBookingRepository(
    servicesRepository: MockServicesRepository(),
    carsRepository: MockCarsRepository(),
    schedulingRepository: MockSchedulingRepository(),
  );
}

Future<TimeSlot> _firstAvailableSlot(MockSchedulingRepository scheduling, String serviceId) async {
  final dates = await scheduling.fetchAvailableDates(serviceId: serviceId);
  final availableDay = dates.firstWhere((d) => d.hasAvailability);
  final slots = await scheduling.fetchTimeSlots(serviceId: serviceId, date: availableDay.date);
  return slots.firstWhere((s) => s.isAvailable);
}

void main() {
  test('createBooking resolves real service, option, and vehicle snapshots', () async {
    final scheduling = MockSchedulingRepository();
    final repository = MockBookingRepository(
      servicesRepository: MockServicesRepository(),
      carsRepository: MockCarsRepository(),
      schedulingRepository: scheduling,
    );
    final slot = await _firstAvailableSlot(scheduling, 's1');

    final draft = BookingDraft(
      serviceId: 's1',
      serviceOptionId: 'opt-oil-mineral',
      vehicleId: 'v1',
      location: _location,
      date: DateTime(slot.start.year, slot.start.month, slot.start.day),
      timeSlot: slot,
    );

    final booking = await repository.createBooking(draft, const Locale('en'));

    expect(booking.id, matches(RegExp(r'^AN-\d{5}-\d{4}$')));
    expect(booking.serviceId, 's1');
    expect(booking.serviceName, 'Oil Change');
    expect(booking.serviceOptionName, 'Mineral');
    expect(booking.vehicleId, 'v1');
    expect(booking.vehicleName, 'Toyota Camry');
    expect(booking.vehicleYear, 2023);
    expect(booking.plateNumber, 'ABC 1234');
    expect(booking.price.basePrice, 89);
    expect(booking.price.optionPrice, 25);
    expect(booking.status, BookingStatus.upcoming);
  });

  test('a booking with no option leaves serviceOptionName null and adds no option price', () async {
    final scheduling = MockSchedulingRepository();
    final repository = MockBookingRepository(
      servicesRepository: MockServicesRepository(),
      carsRepository: MockCarsRepository(),
      schedulingRepository: scheduling,
    );
    final slot = await _firstAvailableSlot(scheduling, 's2');

    final draft = BookingDraft(
      serviceId: 's2', // Full Inspection — does not require a product
      vehicleId: 'v1',
      location: _location,
      date: DateTime(slot.start.year, slot.start.month, slot.start.day),
      timeSlot: slot,
    );

    final booking = await repository.createBooking(draft, const Locale('en'));

    expect(booking.serviceOptionId, isNull);
    expect(booking.serviceOptionName, isNull);
    expect(booking.price.optionPrice, 0);
  });

  test('createBooking throws BookingSlotUnavailableException for a stale/unknown slot id', () async {
    final repository = _repository();
    final draft = BookingDraft(
      serviceId: 's1',
      vehicleId: 'v1',
      location: _location,
      date: DateTime(2020, 1, 1),
      timeSlot: TimeSlot(id: 'not-a-real-slot', start: DateTime(2020, 1, 1, 9), isAvailable: true),
    );

    await expectLater(repository.createBooking(draft, const Locale('en')), throwsA(isA<BookingSlotUnavailableException>()));
  });

  test('a booking created in this session is retrievable by its reference', () async {
    final scheduling = MockSchedulingRepository();
    final repository = MockBookingRepository(
      servicesRepository: MockServicesRepository(),
      carsRepository: MockCarsRepository(),
      schedulingRepository: scheduling,
    );
    final slot = await _firstAvailableSlot(scheduling, 's1');
    final draft = BookingDraft(
      serviceId: 's1',
      vehicleId: 'v1',
      location: _location,
      date: DateTime(slot.start.year, slot.start.month, slot.start.day),
      timeSlot: slot,
    );

    final created = await repository.createBooking(draft, const Locale('en'));
    final fetched = await repository.fetchBookingById(created.id, const Locale('en'));

    expect(fetched, isNotNull);
    expect(fetched!.id, created.id);
    expect(fetched.serviceName, created.serviceName);
  });

  test('fetchBookingById returns null for an unknown id', () async {
    final repository = _repository();
    final result = await repository.fetchBookingById('not-a-real-id', const Locale('en'));
    expect(result, isNull);
  });

  group('demo bookings exercise every BookingStatus', () {
    final cases = {
      'demo-upcoming': BookingStatus.upcoming,
      'demo-on-the-way': BookingStatus.technicianOnTheWay,
      'demo-in-progress': BookingStatus.inProgress,
      'demo-completed': BookingStatus.completed,
      'demo-cancelled': BookingStatus.cancelled,
    };

    for (final entry in cases.entries) {
      test('${entry.key} has status ${entry.value}', () async {
        final repository = _repository();
        final booking = await repository.fetchBookingById(entry.key, const Locale('en'));
        expect(booking, isNotNull);
        expect(booking!.status, entry.value);
      });
    }

    test('the technician-on-the-way demo booking has an ETA', () async {
      final repository = _repository();
      final booking = await repository.fetchBookingById('demo-on-the-way', const Locale('en'));
      expect(booking!.estimatedArrival, isNotNull);
    });

    test('demo bookings respect the requested locale', () async {
      final repository = _repository();
      final ar = await repository.fetchBookingById('demo-upcoming', const Locale('ar'));
      final en = await repository.fetchBookingById('demo-upcoming', const Locale('en'));
      expect(en!.serviceName, 'Oil Change');
      expect(ar!.serviceName, 'تغيير الزيت');
    });
  });

  group('getBookings', () {
    test('includes every demo booking by default', () async {
      final repository = _repository();
      final bookings = await repository.getBookings(const Locale('en'));
      expect(bookings.map((b) => b.id).toSet(), {'AN-20481', 'AN-20482', 'AN-20483', 'AN-20470', 'AN-20465'});
    });

    test('a booking created this session is included alongside the demo set', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final slot = await _firstAvailableSlot(scheduling, 's1');
      final draft = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(slot.start.year, slot.start.month, slot.start.day),
        timeSlot: slot,
      );

      final created = await repository.createBooking(draft, const Locale('en'));
      final bookings = await repository.getBookings(const Locale('en'));

      expect(bookings.map((b) => b.id), contains(created.id));
      expect(bookings, hasLength(6)); // 5 demo bookings + the one just created
    });
  });

  group('updateBookingStatus', () {
    Future<Booking> createRealBooking(MockBookingRepository repository, MockSchedulingRepository scheduling) async {
      final slot = await _firstAvailableSlot(scheduling, 's1');
      final draft = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(slot.start.year, slot.start.month, slot.start.day),
        timeSlot: slot,
      );
      return repository.createBooking(draft, const Locale('en'));
    }

    test('a valid transition (upcoming -> technicianOnTheWay) updates the stored booking', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);

      final updated = await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.technicianOnTheWay);

      expect(updated.status, BookingStatus.technicianOnTheWay);
      expect(updated.estimatedArrival, isNotNull);
      final refetched = await repository.fetchBookingById(created.id, const Locale('en'));
      expect(refetched!.status, BookingStatus.technicianOnTheWay);
    });

    test('an invalid transition (upcoming -> completed) throws and never mutates the stored booking', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);

      await expectLater(
        repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.completed),
        throwsA(isA<InvalidBookingStatusTransitionException>()),
      );

      final refetched = await repository.fetchBookingById(created.id, const Locale('en'));
      expect(refetched!.status, BookingStatus.upcoming);
    });

    test('a fixed demo booking id cannot be advanced — there is nothing persistent to mutate', () async {
      final repository = _repository();

      await expectLater(
        repository.updateBookingStatus(bookingReference: 'demo-upcoming', newStatus: BookingStatus.technicianOnTheWay),
        throwsStateError,
      );
    });
  });

  group('cancelBooking', () {
    Future<Booking> createRealBooking(MockBookingRepository repository, MockSchedulingRepository scheduling) async {
      final slot = await _firstAvailableSlot(scheduling, 's1');
      final draft = BookingDraft(
        serviceId: 's1',
        vehicleId: 'v1',
        location: _location,
        date: DateTime(slot.start.year, slot.start.month, slot.start.day),
        timeSlot: slot,
      );
      return repository.createBooking(draft, const Locale('en'));
    }

    test('cancels an upcoming booking', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);

      final cancelled = await repository.cancelBooking(bookingReference: created.id);

      expect(cancelled.status, BookingStatus.cancelled);
      final refetched = await repository.fetchBookingById(created.id, const Locale('en'));
      expect(refetched!.status, BookingStatus.cancelled);
    });

    test('preserves every other field — only status changes', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);

      final cancelled = await repository.cancelBooking(bookingReference: created.id);

      expect(cancelled.id, created.id);
      expect(cancelled.serviceId, created.serviceId);
      expect(cancelled.vehicleId, created.vehicleId);
      expect(cancelled.scheduledAt, created.scheduledAt);
      expect(cancelled.price.total, created.price.total);
      expect(cancelled.createdAt, created.createdAt);
    });

    test('an already-cancelled booking rejects a second cancellation', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);
      await repository.cancelBooking(bookingReference: created.id);

      await expectLater(
        repository.cancelBooking(bookingReference: created.id),
        throwsA(isA<InvalidBookingStatusTransitionException>()),
      );
    });

    test('technicianOnTheWay can no longer be cancelled', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);
      await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.technicianOnTheWay);

      await expectLater(
        repository.cancelBooking(bookingReference: created.id),
        throwsA(isA<InvalidBookingStatusTransitionException>()),
      );
      final refetched = await repository.fetchBookingById(created.id, const Locale('en'));
      expect(refetched!.status, BookingStatus.technicianOnTheWay);
    });

    test('completed can no longer be cancelled', () async {
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);
      await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.technicianOnTheWay);
      await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.inProgress);
      await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.completed);

      await expectLater(
        repository.cancelBooking(bookingReference: created.id),
        throwsA(isA<InvalidBookingStatusTransitionException>()),
      );
    });

    test('a fixed demo booking id cannot be cancelled — there is nothing persistent to mutate', () async {
      final repository = _repository();

      await expectLater(repository.cancelBooking(bookingReference: 'demo-upcoming'), throwsStateError);
    });

    test('an unknown booking reference throws', () async {
      final repository = _repository();

      await expectLater(repository.cancelBooking(bookingReference: 'not-a-real-booking'), throwsStateError);
    });

    test('a concurrent lifecycle change is never overwritten by a stale cancellation', () async {
      // Simulates the exact race BE-06 must guard against: Device A loads
      // the booking while it is still upcoming, Device B (or another
      // process) advances it to technicianOnTheWay in the meantime, and
      // only then does Device A's cancel request actually reach the
      // repository. cancelBooking must validate against the CURRENT stored
      // status — never a status captured earlier by the caller — the same
      // guarantee a Firestore transaction's re-read-on-retry provides.
      final scheduling = MockSchedulingRepository();
      final repository = MockBookingRepository(
        servicesRepository: MockServicesRepository(),
        carsRepository: MockCarsRepository(),
        schedulingRepository: scheduling,
      );
      final created = await createRealBooking(repository, scheduling);
      // "Device A" would have captured status: upcoming here, but never
      // passes it to cancelBooking — only the reference.
      await repository.updateBookingStatus(bookingReference: created.id, newStatus: BookingStatus.technicianOnTheWay);

      await expectLater(
        repository.cancelBooking(bookingReference: created.id),
        throwsA(isA<InvalidBookingStatusTransitionException>()),
      );

      final refetched = await repository.fetchBookingById(created.id, const Locale('en'));
      expect(refetched!.status, BookingStatus.technicianOnTheWay, reason: 'the newer lifecycle state must survive the stale cancellation attempt');
    });
  });
}
