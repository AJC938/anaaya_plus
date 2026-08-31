import '../../../core/localization/app_localizations.dart';
import '../../booking/domain/models/booking.dart' show BookingStatus;
import '../../payment/domain/models/payment.dart' show PaymentStatus;
import 'models/notification_type.dart';

/// The not-yet-persisted content of a notification — everything
/// [notificationIdFor]/the repository still need to add (id, isRead,
/// createdAt) is intentionally absent here, since those aren't the
/// mapper's concern.
class NotificationContent {
  const NotificationContent({required this.type, required this.title, required this.body});

  final NotificationType type;
  final String title;
  final String body;
}

/// Pure mapping from "a booking was just created" to its notification —
/// kept separate from [notificationForBookingStatusChange] because creation
/// isn't a transition (there's no "from" status): [BookingStatus.upcoming]
/// is never itself reached via `bookingStatusTransitions`, only ever set at
/// creation time.
NotificationContent notificationForBookingCreated({required AppLocalizations l10n, required String bookingReference}) {
  return NotificationContent(
    type: NotificationType.bookingConfirmed,
    title: l10n.bookingConfirmedNotificationTitle,
    body: l10n.bookingConfirmedNotificationBody(bookingReference),
  );
}

/// Pure mapping from a booking's new status to its notification. Every
/// status [BookingStatus.upcoming] can actually transition to already has
/// exactly one notification (see `booking_status_transition.dart`'s
/// `bookingStatusTransitions` map: technicianOnTheWay, inProgress,
/// completed, cancelled) — there is deliberately no "no notification" case
/// to represent here, since every real transition this app supports is
/// meaningful enough to notify about (Phase 5's explicit list). Never
/// called with [BookingStatus.upcoming] itself, which is only ever an
/// initial value, never a transition target.
NotificationContent notificationForBookingStatusChange({
  required BookingStatus to,
  required AppLocalizations l10n,
  required String bookingReference,
}) {
  return switch (to) {
    BookingStatus.technicianOnTheWay => NotificationContent(
      type: NotificationType.technicianOnTheWay,
      title: l10n.technicianOnTheWayNotificationTitle,
      body: l10n.technicianOnTheWayNotificationBody(bookingReference),
    ),
    BookingStatus.inProgress => NotificationContent(
      type: NotificationType.serviceStarted,
      title: l10n.serviceStartedNotificationTitle,
      body: l10n.serviceStartedNotificationBody(bookingReference),
    ),
    BookingStatus.completed => NotificationContent(
      type: NotificationType.serviceCompleted,
      title: l10n.serviceCompletedNotificationTitle,
      body: l10n.serviceCompletedNotificationBody(bookingReference),
    ),
    BookingStatus.cancelled => NotificationContent(
      type: NotificationType.bookingCancelled,
      title: l10n.bookingCancelledNotificationTitle,
      body: l10n.bookingCancelledNotificationBody(bookingReference),
    ),
    BookingStatus.upcoming => throw ArgumentError('upcoming is never a transition target — there is no notification for it'),
  };
}

/// Pure mapping from a payment result to its notification. Unlike booking
/// status, [PaymentStatus.pending] deliberately maps to `null` — matching
/// Phase 6's "do not create notifications for every internal state update":
/// pending is a transient/absent state (see
/// `payment_status_transition.dart`'s own doc comment on why this mock
/// never even persists it), never something worth notifying the user about.
NotificationContent? notificationForPaymentStatus({
  required PaymentStatus status,
  required AppLocalizations l10n,
  required String bookingReference,
}) {
  return switch (status) {
    PaymentStatus.paid => NotificationContent(
      type: NotificationType.paymentSuccessful,
      title: l10n.paymentSuccessfulNotificationTitle,
      body: l10n.paymentSuccessfulNotificationBody(bookingReference),
    ),
    PaymentStatus.failed => NotificationContent(
      type: NotificationType.paymentFailed,
      title: l10n.paymentFailedNotificationTitle,
      body: l10n.paymentFailedNotificationBody(bookingReference),
    ),
    PaymentStatus.pending => null,
  };
}
