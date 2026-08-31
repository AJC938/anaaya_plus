import 'package:flutter/widgets.dart' show Locale;

import '../domain/booking_status_transition.dart' show InvalidBookingStatusTransitionException;
import '../domain/models/booking.dart';
import '../domain/models/booking_draft.dart';

/// Thrown by [BookingRepository.createBooking] when the requested time slot
/// is no longer available by the time the booking is actually submitted —
/// the repository always revalidates, it never trusts the draft's slot was
/// still open.
class BookingSlotUnavailableException implements Exception {
  const BookingSlotUnavailableException();
}

/// Data seam for the Booking feature. [MockBookingRepository] is the only
/// implementation for this milestone; a real backend can replace it later
/// without Booking's screens changing.
abstract class BookingRepository {
  /// Resolves the draft's service/option/vehicle snapshots and price,
  /// revalidates the time slot, and persists the booking. [locale] decides
  /// which language the snapshot text is captured in.
  Future<Booking> createBooking(BookingDraft draft, Locale locale);

  /// [locale] only affects the small set of demo bookings used to exercise
  /// every [BookingStatus] directly — a real, previously-created booking
  /// returns its snapshot exactly as captured at confirmation time.
  Future<Booking?> fetchBookingById(String id, Locale locale);

  /// Every booking for the Bookings screen — bookings created this session
  /// plus the fixed demo set. Ordering/grouping is the caller's job (see
  /// `groupBookingsForList`), not the repository's.
  Future<List<Booking>> getBookings(Locale locale);

  /// Advances [bookingReference] to [newStatus], enforcing
  /// `bookingStatusTransitions` — an illegal edge (skipping a step, moving
  /// backward, acting on a terminal booking) throws
  /// [InvalidBookingStatusTransitionException] rather than silently no-op'ing
  /// or force-setting the field. Returns the booking as it stands after the
  /// update.
  Future<Booking> updateBookingStatus({required String bookingReference, required BookingStatus newStatus});

  /// Cancels [bookingReference] — only ever a legal call when the booking is
  /// still [BookingStatus.upcoming] (the state machine's only edge into
  /// [BookingStatus.cancelled]); any other current status throws
  /// [InvalidBookingStatusTransitionException], exactly like
  /// [updateBookingStatus] would. Kept as its own named operation — rather
  /// than the caller just calling `updateBookingStatus(newStatus:
  /// cancelled)` — because a real cancellation additionally releases the
  /// booking's claimed time slot (see [FirestoreBookingRepository]'s
  /// implementation), a side effect no other transition needs.
  Future<Booking> cancelBooking({required String bookingReference});
}
