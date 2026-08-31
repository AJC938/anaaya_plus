/// Every notification this milestone creates maps to exactly one of these —
/// a strongly typed domain enum rather than scattered string literals, per
/// BE-08's own requirement. Deliberately only the events explicitly in
/// scope: one per meaningful Booking/Payment Engine event, never a
/// notification for every internal state update.
enum NotificationType {
  bookingConfirmed,
  paymentSuccessful,
  paymentFailed,
  technicianOnTheWay,
  serviceStarted,
  serviceCompleted,
  bookingCancelled,
}
