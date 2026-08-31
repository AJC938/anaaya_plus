import 'models/booking.dart';

/// Bookings grouped for the Bookings screen — active work first (soonest
/// scheduled time first), then completed/cancelled history (most recent
/// first). Pure and testable: the screen never sorts/filters bookings itself.
class BookingListGroups {
  const BookingListGroups({required this.active, required this.completed, required this.cancelled});

  final List<Booking> active;
  final List<Booking> completed;
  final List<Booking> cancelled;

  bool get isEmpty => active.isEmpty && completed.isEmpty && cancelled.isEmpty;
}

const _activeStatuses = {BookingStatus.upcoming, BookingStatus.technicianOnTheWay, BookingStatus.inProgress};

BookingListGroups groupBookingsForList(List<Booking> bookings) {
  final active = bookings.where((b) => _activeStatuses.contains(b.status)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  final completed = bookings.where((b) => b.status == BookingStatus.completed).toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  final cancelled = bookings.where((b) => b.status == BookingStatus.cancelled).toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  return BookingListGroups(active: active, completed: completed, cancelled: cancelled);
}
