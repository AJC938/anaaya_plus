import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../notifications/application/notification_event_service.dart';
import '../domain/models/booking.dart';
import 'booking_providers.dart';

/// Owns a single booking's status-lifecycle state for Tracking — the
/// authoritative source Tracking reads from (replacing a plain
/// `bookingByIdProvider` watch there) so a just-applied transition is
/// reflected immediately, with no separate invalidate-then-refetch round
/// trip. One instance per [bookingReference] (see the `.family` provider
/// below), matching `bookingByIdProvider`'s own per-id shape.
///
/// Riverpod's manual (non-codegen) family-notifier API doesn't pass the
/// family argument into [build] — it's instead captured by the notifier's
/// own constructor and read as a plain field (see the factory passed to
/// [AsyncNotifierProvider.family] below).
///
/// Matches [BookingSubmissionController]'s established shape: an
/// `AsyncValue`-typed state that IS the loading/error/data signal, with a
/// synchronous re-entrancy guard set before the first `await` — so a rapid
/// double-tap on a "simulate advance" action can never fire two concurrent
/// transition requests.
class BookingStatusController extends AsyncNotifier<Booking?> {
  BookingStatusController(this.bookingReference);

  final String bookingReference;

  /// The last successfully loaded booking, tracked separately from [state]
  /// itself. [state] transiently loses its value while [advance] is in
  /// flight (or after it fails) — `AsyncValue`'s own previous-value
  /// preservation (`copyWithPrevious`) is a Riverpod-internal API this
  /// milestone deliberately doesn't reach for. Retrying a failed advance
  /// still needs to know which booking to target, and Tracking's UI still
  /// needs something to keep rendering while a request is in flight — this
  /// field is that source, kept in sync on every successful load/advance.
  Booking? _lastKnown;

  @override
  Future<Booking?> build() async {
    // Same startup-race guard as bookingByIdProvider/bookingsListProvider —
    // see their own doc comments.
    await ref.watch(authStateChangesProvider.future);
    final locale = ref.watch(localeProvider);
    final booking = await ref.watch(bookingRepositoryProvider).fetchBookingById(bookingReference, locale);
    _lastKnown = booking;
    return booking;
  }

  Future<void> advance(BookingStatus newStatus) async {
    if (state.isLoading) return;

    final current = _lastKnown;
    if (current == null) return; // nothing loaded yet to advance

    state = const AsyncLoading();
    final repository = ref.read(bookingRepositoryProvider);
    final result = await AsyncValue.guard(() => repository.updateBookingStatus(bookingReference: current.id, newStatus: newStatus));
    state = result;

    if (result.hasValue) {
      _lastKnown = result.value;
      // So the Bookings list reflects the new status immediately instead of
      // showing whatever it last fetched — matches the submission
      // controller's own reasoning for invalidating it on success.
      ref.invalidate(bookingsListProvider);
      unawaited(
        ref
            .read(notificationEventServiceProvider)
            .recordBookingStatusChange(to: newStatus, bookingReference: result.value!.id),
      );
    }
  }

  /// BE-06: cancels the booking. Kept as its own method — rather than
  /// callers just calling `advance(BookingStatus.cancelled)` — because a
  /// real user cancellation goes through [BookingRepository.cancelBooking]
  /// (which additionally releases the claimed time slot), not
  /// [BookingRepository.updateBookingStatus]. Otherwise mirrors [advance]
  /// exactly: the same synchronous re-entrancy guard (so a double-tap can
  /// never fire twice), the same [_lastKnown] preserved on failure so the
  /// booking never disappears from Tracking mid-error, and the same
  /// `bookingsListProvider` invalidation on success.
  Future<void> cancel() async {
    if (state.isLoading) return;

    final current = _lastKnown;
    if (current == null) return;

    state = const AsyncLoading();
    final repository = ref.read(bookingRepositoryProvider);
    final result = await AsyncValue.guard(() => repository.cancelBooking(bookingReference: current.id));
    state = result;

    if (result.hasValue) {
      _lastKnown = result.value;
      ref.invalidate(bookingsListProvider);
      unawaited(
        ref
            .read(notificationEventServiceProvider)
            .recordBookingStatusChange(to: BookingStatus.cancelled, bookingReference: result.value!.id),
      );
    }
  }
}

final bookingStatusControllerProvider = AsyncNotifierProvider.family<BookingStatusController, Booking?, String>(
  BookingStatusController.new,
);
