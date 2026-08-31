import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/domain/booking_status_transition.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';

void main() {
  group('isValidBookingStatusTransition — the happy path', () {
    test('upcoming -> technicianOnTheWay is allowed', () {
      expect(isValidBookingStatusTransition(from: BookingStatus.upcoming, to: BookingStatus.technicianOnTheWay), isTrue);
    });

    test('technicianOnTheWay -> inProgress is allowed', () {
      expect(isValidBookingStatusTransition(from: BookingStatus.technicianOnTheWay, to: BookingStatus.inProgress), isTrue);
    });

    test('inProgress -> completed is allowed', () {
      expect(isValidBookingStatusTransition(from: BookingStatus.inProgress, to: BookingStatus.completed), isTrue);
    });

    test('upcoming -> cancelled is allowed', () {
      expect(isValidBookingStatusTransition(from: BookingStatus.upcoming, to: BookingStatus.cancelled), isTrue);
    });
  });

  group('isValidBookingStatusTransition — rejected transitions', () {
    const invalidPairs = [
      (BookingStatus.upcoming, BookingStatus.completed),
      (BookingStatus.upcoming, BookingStatus.inProgress),
      (BookingStatus.completed, BookingStatus.upcoming),
      (BookingStatus.completed, BookingStatus.inProgress),
      (BookingStatus.completed, BookingStatus.cancelled),
      (BookingStatus.completed, BookingStatus.technicianOnTheWay),
      (BookingStatus.cancelled, BookingStatus.upcoming),
      (BookingStatus.cancelled, BookingStatus.completed),
      (BookingStatus.cancelled, BookingStatus.technicianOnTheWay),
      (BookingStatus.cancelled, BookingStatus.inProgress),
      (BookingStatus.inProgress, BookingStatus.technicianOnTheWay),
      (BookingStatus.inProgress, BookingStatus.upcoming),
      (BookingStatus.inProgress, BookingStatus.cancelled),
      (BookingStatus.technicianOnTheWay, BookingStatus.completed),
      (BookingStatus.technicianOnTheWay, BookingStatus.upcoming),
      (BookingStatus.technicianOnTheWay, BookingStatus.cancelled),
    ];

    for (final (from, to) in invalidPairs) {
      test('$from -> $to is rejected', () {
        expect(isValidBookingStatusTransition(from: from, to: to), isFalse);
      });
    }

    test('a status can never transition to itself', () {
      for (final status in BookingStatus.values) {
        expect(isValidBookingStatusTransition(from: status, to: status), isFalse, reason: '$status -> $status must be rejected');
      }
    });
  });

  group('terminal statuses', () {
    test('completed has no outgoing edges at all', () {
      expect(bookingStatusTransitions[BookingStatus.completed], isEmpty);
    });

    test('cancelled has no outgoing edges at all', () {
      expect(bookingStatusTransitions[BookingStatus.cancelled], isEmpty);
    });
  });

  group('InvalidBookingStatusTransitionException', () {
    test('carries the exact from/to that was rejected', () {
      const exception = InvalidBookingStatusTransitionException(from: BookingStatus.upcoming, to: BookingStatus.completed);

      expect(exception.from, BookingStatus.upcoming);
      expect(exception.to, BookingStatus.completed);
      expect(exception.toString(), contains('upcoming'));
      expect(exception.toString(), contains('completed'));
    });
  });
}
