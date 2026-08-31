import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/application/notification_event_service.dart';
import '../../scheduling/application/scheduling_providers.dart';
import '../domain/booking_validation.dart';
import '../domain/models/booking.dart';
import 'booking_draft_controller.dart';
import 'booking_providers.dart';

/// Owns the "Confirm Booking" action's in-flight state — the single,
/// authoritative guard against duplicate submissions (a rapid double-tap,
/// network latency prompting a second tap, or any other accidental
/// duplicate invocation), matching the app's established AsyncNotifier
/// mutation pattern (see `CarsController`/`SavedLocationsController`)
/// rather than tracking "is a request in flight" as local widget state.
///
/// [submit] always reads the CURRENT [bookingDraftControllerProvider] value
/// itself — never a draft handed in by the caller — so a draft that
/// changed (or was cleared) between when Review was built and when the
/// user actually tapped Confirm is never blindly trusted.
class BookingSubmissionController extends Notifier<AsyncValue<Booking?>> {
  @override
  AsyncValue<Booking?> build() => const AsyncData(null);

  Future<void> submit(Locale locale) async {
    // Authoritative re-entrancy guard: state flips to AsyncLoading below
    // synchronously, before the first `await` — so a second call arriving
    // while one is already in flight always observes isLoading == true and
    // returns immediately as a no-op. A duplicate booking can never be
    // created this way, regardless of whether the caller's own UI managed
    // to disable itself in time.
    if (state.isLoading) return;

    final draft = ref.read(bookingDraftControllerProvider);
    if (draft == null || !isDraftComplete(draft)) {
      state = AsyncError(const IncompleteBookingDraftException(), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    final repository = ref.read(bookingRepositoryProvider);
    state = await AsyncValue.guard(() => repository.createBooking(draft, locale));

    if (state.value != null) {
      ref.read(bookingDraftControllerProvider.notifier).clear();
      // So the Bookings tab reflects this booking immediately instead of
      // showing whatever list it last fetched.
      ref.invalidate(bookingsListProvider);
      // The slot this booking just claimed is real, persisted state in
      // Firestore now — but availableDatesProvider/timeSlotsProvider are
      // cached `FutureProvider.family` entries keyed by (serviceId, date)
      // that were already resolved once when Date & Time was first
      // browsed. Without this, a user who immediately starts a second
      // booking for the same service in the same app session would see
      // the just-claimed slot rendered as available again — the atomic
      // claim itself is unaffected (a second real attempt still correctly
      // fails), but the UI would misleadingly let them try.
      ref.invalidate(availableDatesProvider(draft.serviceId));
      ref.invalidate(timeSlotsProvider((serviceId: draft.serviceId, date: draft.date!)));
      // BE-08: best-effort, fire-and-forget — see NotificationEventService's
      // own doc comment for why a notification failure must never surface
      // as a booking-submission failure.
      unawaited(ref.read(notificationEventServiceProvider).recordBookingCreated(bookingReference: state.value!.id));
    }
  }
}

final bookingSubmissionControllerProvider = NotifierProvider<BookingSubmissionController, AsyncValue<Booking?>>(
  BookingSubmissionController.new,
);
