import 'notification_type.dart';

/// A single notification history entry — lightweight by design (see
/// `notification_id.dart` and `firestore_notification_repository.dart`'s own
/// doc comments): never a copy of the booking document, only what's needed
/// to display the entry and route a tap.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.bookingReference,
    required this.isRead,
    required this.createdAt,
  });

  /// The deterministic id this notification was written under — see
  /// `notificationIdFor`. Never a Firestore auto-id.
  final String id;

  final NotificationType type;

  /// Already-localized display text, resolved once at creation time (the
  /// same "snapshot text captured in the active locale" pattern
  /// `FirestoreBookingRepository.createBooking` already uses for
  /// service/vehicle names) — never re-derived from [type] at render time,
  /// so a later locale switch can't retroactively change history text the
  /// user already saw.
  final String title;
  final String body;

  /// Null for a notification that isn't about a specific booking — no such
  /// type exists yet in this milestone, but the field stays nullable rather
  /// than assuming every future notification type will be booking-scoped.
  final String? bookingReference;

  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      bookingReference: bookingReference,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
