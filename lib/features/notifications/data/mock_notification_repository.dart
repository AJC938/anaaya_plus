import '../domain/models/app_notification.dart';
import '../domain/models/notification_type.dart';
import '../domain/notification_id.dart';
import 'notification_repository.dart';

/// Local/in-memory stand-in for [FirestoreNotificationRepository], matching
/// every other Mock repository in this project — used by widget/unit tests
/// only.
class MockNotificationRepository implements NotificationRepository {
  final Map<String, AppNotification> _notifications = {};
  int _fallbackIdCounter = 0;

  /// A monotonically increasing counter, not wall-clock `DateTime.now()`
  /// directly — two `recordNotification` calls issued back-to-back in a
  /// test (no `await Future.delayed` between them) can land in the same
  /// system-clock millisecond, which would make "newest first" ordering
  /// flaky. Each new (non-duplicate) notification gets a `createdAt`
  /// strictly later than the previous one.
  int _sequence = 0;
  DateTime _nextCreatedAt() => DateTime.fromMillisecondsSinceEpoch(_sequence++);

  @override
  Future<List<AppNotification>> getNotifications() async {
    final list = _notifications.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<AppNotification> recordNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String? bookingReference,
  }) async {
    final id = bookingReference != null
        ? notificationIdFor(bookingReference: bookingReference, type: type)
        : 'fallback-${_fallbackIdCounter++}';

    final existing = _notifications[id];
    final notification = AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      bookingReference: bookingReference,
      // Preserved across a duplicate call — see
      // FirestoreNotificationRepository.recordNotification's identical
      // reasoning.
      isRead: existing?.isRead ?? false,
      createdAt: existing?.createdAt ?? _nextCreatedAt(),
    );
    _notifications[id] = notification;
    return notification;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final existing = _notifications[notificationId];
    if (existing == null) return;
    _notifications[notificationId] = existing.copyWith(isRead: true);
  }
}
