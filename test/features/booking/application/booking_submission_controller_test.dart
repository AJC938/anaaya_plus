import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_submission_controller.dart';
import 'package:anaaya_plus/features/booking/data/booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/booking_validation.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';

import '../../../support/booking_fixtures.dart';

const _locale = Locale('en');

final _completeDraft = BookingDraft(
  serviceId: 's1',
  serviceOptionId: 'opt-mineral',
  vehicleId: 'v1',
  location: testLocation,
  date: DateTime(2026, 1, 5),
  timeSlot: TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true),
);

Booking _bookingFor(BookingDraft draft) => Booking(
  id: 'AN-00001',
  serviceId: draft.serviceId,
  serviceName: 'Oil Change',
  serviceImageAsset: 'oil_change',
  serviceOptionId: draft.serviceOptionId,
  serviceOptionName: draft.serviceOptionId != null ? 'Mineral' : null,
  vehicleId: draft.vehicleId,
  vehicleName: 'Toyota Camry',
  vehicleYear: 2023,
  plateNumber: 'ABC 1234',
  location: draft.location!,
  scheduledAt: draft.timeSlot!.start,
  price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 25, fees: 10, total: 124),
  status: BookingStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

/// Seeds [bookingDraftControllerProvider] the same way the real Booking
/// flow does (via its own mutation methods), not by injecting a draft
/// value directly — so these tests exercise exactly what
/// [BookingSubmissionController.submit] actually reads.
ProviderContainer _container({required BookingRepository repository, BookingDraft? draft}) {
  final container = ProviderContainer(overrides: [bookingRepositoryProvider.overrideWithValue(repository)]);
  addTearDown(container.dispose);

  if (draft != null) {
    final notifier = container.read(bookingDraftControllerProvider.notifier);
    notifier.startOrUpdateDraft(serviceId: draft.serviceId, serviceOptionId: draft.serviceOptionId, vehicleId: draft.vehicleId);
    if (draft.location != null) notifier.setLocation(draft.location!);
    if (draft.date != null) notifier.setDate(draft.date!);
    if (draft.timeSlot != null) notifier.setTimeSlot(draft.timeSlot!);
  }

  return container;
}

void main() {
  group('submit — valid creation', () {
    test('a complete draft creates a booking, clears the draft, and refreshes the bookings list', () async {
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => _bookingFor(draft));
      final container = _container(repository: repository, draft: _completeDraft);

      await container.read(bookingSubmissionControllerProvider.notifier).submit(_locale);

      final state = container.read(bookingSubmissionControllerProvider);
      expect(state.value, isNotNull);
      expect(state.value!.id, 'AN-00001');
      expect(container.read(bookingDraftControllerProvider), isNull);
      expect(repository.bookings, hasLength(1));
    });
  });

  group('submit — incomplete/missing draft', () {
    test('no draft at all is rejected before ever reaching the repository', () async {
      var createCalls = 0;
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw StateError('must not be called'));
      final container = _container(repository: repository); // no draft seeded

      await container.read(bookingSubmissionControllerProvider.notifier).submit(_locale);

      expect(createCalls, 0);
      final state = container.read(bookingSubmissionControllerProvider);
      expect(state.error, isA<IncompleteBookingDraftException>());
    });

    test('a draft missing location/date/time is rejected before ever reaching the repository', () async {
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw StateError('must not be called'));
      final container = _container(repository: repository, draft: const BookingDraft(serviceId: 's1', vehicleId: 'v1'));

      await container.read(bookingSubmissionControllerProvider.notifier).submit(_locale);

      final state = container.read(bookingSubmissionControllerProvider);
      expect(state.error, isA<IncompleteBookingDraftException>());
      // The draft itself is left alone — an incomplete draft is not the
      // same failure mode as a repository error, and there is nothing to
      // roll back since nothing was ever written.
      expect(container.read(bookingDraftControllerProvider), isNotNull);
    });
  });

  group('submit — double-submission protection', () {
    test('a second call while the first is still in flight never reaches the repository a second time', () async {
      final completer = Completer<Booking>();
      var createCalls = 0;
      final repository = FakeBookingRepository(
        onCreate: (draft, locale) {
          createCalls++;
          return completer.future;
        },
      );
      final container = _container(repository: repository, draft: _completeDraft);
      final notifier = container.read(bookingSubmissionControllerProvider.notifier);

      final firstCall = notifier.submit(_locale);
      // Fired synchronously, before the first call has had any chance to
      // resolve — this is the exact "rapid double-tap" / "accidental
      // duplicate invocation" scenario the guard exists for.
      final secondCall = notifier.submit(_locale);

      expect(createCalls, 1);
      expect(container.read(bookingSubmissionControllerProvider).isLoading, isTrue);

      completer.complete(_bookingFor(_completeDraft));
      await firstCall;
      await secondCall;

      expect(createCalls, 1);
      expect(container.read(bookingSubmissionControllerProvider).value, isNotNull);
      expect(repository.bookings, hasLength(1));
    });

    test('a call that arrives after a successful submission is a genuinely new, separate booking', () async {
      var createCalls = 0;
      final repository = FakeBookingRepository(
        onCreate: (draft, locale) async {
          createCalls++;
          return _bookingFor(draft);
        },
      );
      final container = _container(repository: repository, draft: _completeDraft);
      final notifier = container.read(bookingSubmissionControllerProvider.notifier);

      await notifier.submit(_locale);
      expect(createCalls, 1);

      // The draft was cleared by the first successful submission, so a
      // second call — sequential, not concurrent — correctly finds nothing
      // to submit rather than silently recreating the same booking.
      await notifier.submit(_locale);
      expect(createCalls, 1);
      expect(container.read(bookingSubmissionControllerProvider).error, isA<IncompleteBookingDraftException>());
    });
  });

  group('submit — failure handling', () {
    test('a BookingSlotUnavailableException surfaces distinctly and preserves the draft', () async {
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw const BookingSlotUnavailableException());
      final container = _container(repository: repository, draft: _completeDraft);

      await container.read(bookingSubmissionControllerProvider.notifier).submit(_locale);

      final state = container.read(bookingSubmissionControllerProvider);
      expect(state.error, isA<BookingSlotUnavailableException>());
      expect(container.read(bookingDraftControllerProvider), isNotNull);
    });

    test('a generic repository failure surfaces as an error and preserves the draft, without a partial booking', () async {
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw Exception('Firestore unavailable'));
      final container = _container(repository: repository, draft: _completeDraft);

      await container.read(bookingSubmissionControllerProvider.notifier).submit(_locale);

      final state = container.read(bookingSubmissionControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isNot(isA<BookingSlotUnavailableException>()));
      expect(container.read(bookingDraftControllerProvider), isNotNull);
      expect(repository.bookings, isEmpty);
    });
  });
}
