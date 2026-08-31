import 'models/booking.dart';

/// The single authoritative Booking status state machine — both
/// [BookingStatusController] (client-side, for a fast/clear error before
/// ever touching Firestore) and `FirestoreBookingRepository.updateBookingStatus`
/// (server-side, the actual enforcement boundary, mirrored in
/// firestore.rules) check transitions against this exact map, so the rule
/// can never silently diverge from the app's own understanding of what's
/// allowed.
///
/// The happy path is strict and linear:
///   upcoming -> technicianOnTheWay -> inProgress -> completed
/// Cancellation is a separate, one-way branch reachable only from
/// [BookingStatus.upcoming] — once a technician is already on the way, the
/// existing project has no "cancel" affordance for that state, so no edge
/// is defined for it here. [BookingStatus.completed] and
/// [BookingStatus.cancelled] are both terminal: no outgoing edges at all.
const Map<BookingStatus, Set<BookingStatus>> bookingStatusTransitions = {
  BookingStatus.upcoming: {BookingStatus.technicianOnTheWay, BookingStatus.cancelled},
  BookingStatus.technicianOnTheWay: {BookingStatus.inProgress},
  BookingStatus.inProgress: {BookingStatus.completed},
  BookingStatus.completed: {},
  BookingStatus.cancelled: {},
};

bool isValidBookingStatusTransition({required BookingStatus from, required BookingStatus to}) {
  return bookingStatusTransitions[from]?.contains(to) ?? false;
}

/// Thrown when a requested status change isn't a legal edge in
/// [bookingStatusTransitions] — e.g. skipping a step, moving backward, or
/// acting on a terminal booking.
class InvalidBookingStatusTransitionException implements Exception {
  const InvalidBookingStatusTransitionException({required this.from, required this.to});

  final BookingStatus from;
  final BookingStatus to;

  @override
  String toString() => 'InvalidBookingStatusTransitionException: $from -> $to is not an allowed transition';
}
