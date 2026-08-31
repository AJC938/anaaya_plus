import '../domain/models/app_notification.dart';
import '../domain/models/notification_type.dart';

/// Data seam for the Notifications feature — mirrors every other
/// repository in this project (an interface, a Firestore implementation, a
/// Mock implementation for tests).
abstract class NotificationRepository {
  /// Every notification for the signed-in user, newest first.
  Future<List<AppNotification>> getNotifications();

  /// Idempotently records [title]/[body] under the deterministic id for
  /// (bookingReference, type) — see `notificationIdFor`. Calling this again
  /// for the same (bookingReference, type) pair is always safe: it
  /// overwrites the same document rather than creating a second one (see
  /// `notification_id.dart`'s own doc comment for why this is BE-08's
  /// entire duplicate-protection mechanism, not merely a UI-level guard).
  Future<AppNotification> recordNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String? bookingReference,
  });

  /// Marks a single notification read — a no-op (not an error) if it's
  /// already read, matching this project's established idempotent-mutation
  /// philosophy (see `FirestorePaymentRepository.submitPayment`'s own
  /// already-paid short-circuit).
  Future<void> markAsRead(String notificationId);
}
