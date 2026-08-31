import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_status_controller.dart';
import 'package:anaaya_plus/features/booking/domain/booking_status_transition.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/booking_fixtures.dart';

const _bookingRef = 'AN-00001';

Booking _bookingWith(BookingStatus status) => Booking(
  id: _bookingRef,
  serviceId: 's1',
  serviceName: 'Oil Change',
  serviceImageAsset: 'oil_change',
  vehicleId: 'v1',
  vehicleName: 'Toyota Camry',
  vehicleYear: 2023,
  plateNumber: 'ABC 1234',
  location: testLocation,
  scheduledAt: DateTime(2026, 1, 5, 9),
  price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 0, fees: 10, total: 99),
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

/// Waits for the controller's initial `build()` (its `fetchBookingById`
/// load) to settle before a test starts calling `advance()` — otherwise a
/// call could race the still-pending initial load.
Future<ProviderContainer> _containerLoaded({required FakeBookingRepository repository}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      bookingRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  // Required keep-alive: without an active listener, a bare
  // ProviderContainer can tear down the provider's underlying
  // authStateChangesProvider subscription before it ever delivers its
  // first event, leaving the pending `.future` await below hanging
  // forever — the same pattern used throughout this project's other
  // auth-restoration-dependent provider tests.
  container.listen(bookingStatusControllerProvider(_bookingRef), (previous, next) {});
  await container.read(bookingStatusControllerProvider(_bookingRef).future);
  return container;
}

void main() {
  group('advance — valid transitions', () {
    test('upcoming -> technicianOnTheWay succeeds and updates state', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).advance(BookingStatus.technicianOnTheWay);

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.value?.status, BookingStatus.technicianOnTheWay);
    });

    test('a successful advance invalidates bookingsListProvider so the Bookings tab refreshes', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      var listCalls = 0;
      repository.onGetBookings = () async {
        listCalls++;
        return repository.bookings.values.toList();
      };
      // Prime the cache once so invalidation has something to actually mark stale.
      await container.read(bookingsListProvider.future);
      final callsBeforeAdvance = listCalls;

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).advance(BookingStatus.technicianOnTheWay);
      await container.read(bookingsListProvider.future);

      expect(listCalls, greaterThan(callsBeforeAdvance));
    });
  });

  group('advance — rejected transitions', () {
    test('an invalid transition (upcoming -> completed) is rejected and the booking status is left unchanged', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).advance(BookingStatus.completed);

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.error, isA<InvalidBookingStatusTransitionException>());
      expect(repository.bookings[_bookingRef]!.status, BookingStatus.upcoming);
    });

    test('a rejected advance still leaves the last-known booking retrievable — a later valid advance still works', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(bookingStatusControllerProvider(_bookingRef).notifier);

      await notifier.advance(BookingStatus.completed); // rejected
      await notifier.advance(BookingStatus.technicianOnTheWay); // valid, should still work

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.value?.status, BookingStatus.technicianOnTheWay);
    });
  });

  group('advance — double-submission protection', () {
    test('a second call while the first is still in flight never reaches the repository a second time', () async {
      final completer = Completer<Booking>();
      var updateCalls = 0;
      final repository = FakeBookingRepository(
        onUpdateStatus: (bookingReference, newStatus) {
          updateCalls++;
          return completer.future;
        },
      )..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(bookingStatusControllerProvider(_bookingRef).notifier);

      final first = notifier.advance(BookingStatus.technicianOnTheWay);
      final second = notifier.advance(BookingStatus.technicianOnTheWay);

      expect(updateCalls, 1);
      expect(container.read(bookingStatusControllerProvider(_bookingRef)).isLoading, isTrue);

      completer.complete(_bookingWith(BookingStatus.technicianOnTheWay));
      await first;
      await second;

      expect(updateCalls, 1);
    });
  });

  group('advance — repository failure', () {
    test('a generic repository failure surfaces as an error without corrupting the stored booking', () async {
      final repository = FakeBookingRepository(onUpdateStatus: (bookingReference, newStatus) async => throw Exception('Firestore unavailable'))
        ..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).advance(BookingStatus.technicianOnTheWay);

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.hasError, isTrue);
      expect(state.error, isNot(isA<InvalidBookingStatusTransitionException>()));
    });
  });

  group('cancel — success', () {
    test('cancels an upcoming booking and updates state', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).cancel();

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.value?.status, BookingStatus.cancelled);
    });

    test('a successful cancel invalidates bookingsListProvider so the Bookings tab refreshes', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      var listCalls = 0;
      repository.onGetBookings = () async {
        listCalls++;
        return repository.bookings.values.toList();
      };
      await container.read(bookingsListProvider.future);
      final callsBeforeCancel = listCalls;

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).cancel();
      await container.read(bookingsListProvider.future);

      expect(listCalls, greaterThan(callsBeforeCancel));
    });
  });

  group('cancel — rejected', () {
    test('a booking that is no longer upcoming is rejected and left unchanged', () async {
      final repository = FakeBookingRepository()..bookings[_bookingRef] = _bookingWith(BookingStatus.technicianOnTheWay);
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).cancel();

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.error, isA<InvalidBookingStatusTransitionException>());
      expect(repository.bookings[_bookingRef]!.status, BookingStatus.technicianOnTheWay);
    });
  });

  group('cancel — no booking loaded', () {
    test('calling cancel when no booking was ever found is a no-op, not a crash', () async {
      var cancelCalls = 0;
      // No entry seeded under _bookingRef — the initial load resolves
      // cleanly to null (a genuine "booking not found"), matching
      // FakeBookingRepository.fetchBookingById's own behavior.
      final repository = FakeBookingRepository(onCancel: (bookingReference) {
        cancelCalls++;
        return Future.value(_bookingWith(BookingStatus.cancelled));
      });
      final container = await _containerLoaded(repository: repository);

      await container.read(bookingStatusControllerProvider(_bookingRef).notifier).cancel();

      expect(cancelCalls, 0, reason: 'cancel() must never reach the repository when _lastKnown is null');
      expect(container.read(bookingStatusControllerProvider(_bookingRef)).hasError, isFalse);
    });
  });

  group('cancel — double-submission protection', () {
    test('a second call while the first is still in flight never reaches the repository a second time', () async {
      final completer = Completer<Booking>();
      var cancelCalls = 0;
      final repository = FakeBookingRepository(
        onCancel: (bookingReference) {
          cancelCalls++;
          return completer.future;
        },
      )..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(bookingStatusControllerProvider(_bookingRef).notifier);

      final first = notifier.cancel();
      final second = notifier.cancel();

      expect(cancelCalls, 1);
      expect(container.read(bookingStatusControllerProvider(_bookingRef)).isLoading, isTrue);

      completer.complete(_bookingWith(BookingStatus.cancelled));
      await first;
      await second;

      expect(cancelCalls, 1);
    });

    test('a simulate advance and a cancel can never both be in flight at once', () async {
      final completer = Completer<Booking>();
      var totalCalls = 0;
      final repository = FakeBookingRepository(
        onUpdateStatus: (bookingReference, newStatus) {
          totalCalls++;
          return completer.future;
        },
        onCancel: (bookingReference) {
          totalCalls++;
          return completer.future;
        },
      )..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(bookingStatusControllerProvider(_bookingRef).notifier);

      final advanceCall = notifier.advance(BookingStatus.technicianOnTheWay);
      final cancelCall = notifier.cancel();

      expect(totalCalls, 1);

      completer.complete(_bookingWith(BookingStatus.technicianOnTheWay));
      await advanceCall;
      await cancelCall;

      expect(totalCalls, 1);
    });
  });

  group('cancel — repository failure', () {
    test('a generic repository failure surfaces as an error and preserves the booking for retry', () async {
      final repository = FakeBookingRepository(onCancel: (bookingReference) async => throw Exception('Firestore unavailable'))
        ..bookings[_bookingRef] = _bookingWith(BookingStatus.upcoming);
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(bookingStatusControllerProvider(_bookingRef).notifier);

      await notifier.cancel();

      final state = container.read(bookingStatusControllerProvider(_bookingRef));
      expect(state.hasError, isTrue);
      expect(state.error, isNot(isA<InvalidBookingStatusTransitionException>()));

      // The booking is still retrievable for a retry, not permanently lost.
      repository.onCancel = null;
      await notifier.cancel();
      expect(container.read(bookingStatusControllerProvider(_bookingRef)).value?.status, BookingStatus.cancelled);
    });
  });
}
