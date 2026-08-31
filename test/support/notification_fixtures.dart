import 'package:anaaya_plus/features/notifications/data/notification_repository.dart';
import 'package:anaaya_plus/features/notifications/domain/models/app_notification.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';
import 'package:anaaya_plus/features/notifications/domain/notification_id.dart';

/// A [NotificationRepository] with no artificial latency and controllable
/// outcomes — matches [FakeBookingRepository]/[FakePaymentRepository]'s
/// exact role.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({this.onRecord, this.onMarkAsRead, this.onGetNotifications});

  /// Overrides [recordNotification] entirely — a throwing closure for a
  /// repository-failure test. Defaults to a real in-memory mutation that
  /// enforces the same (bookingReference, type) idempotency the real
  /// repositories do.
  Future<AppNotification> Function(NotificationType type, String title, String body, String? bookingReference)? onRecord;

  /// Overrides [markAsRead] entirely — a throwing closure for a
  /// repository-failure test.
  Future<void> Function(String notificationId)? onMarkAsRead;

  /// Overrides [getNotifications] entirely — a throwing closure for a
  /// loading-error test.
  Future<List<AppNotification>> Function()? onGetNotifications;

  final Map<String, AppNotification> notifications = {};
  int recordCalls = 0;
  int _sequence = 0;

  @override
  Future<List<AppNotification>> getNotifications() {
    if (onGetNotifications != null) return onGetNotifications!();
    return _defaultGetNotifications();
  }

  Future<List<AppNotification>> _defaultGetNotifications() async {
    final list = notifications.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<AppNotification> recordNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String? bookingReference,
  }) {
    recordCalls++;
    if (onRecord != null) return onRecord!(type, title, body, bookingReference);
    return _defaultRecord(type, title, body, bookingReference);
  }

  Future<AppNotification> _defaultRecord(NotificationType type, String title, String body, String? bookingReference) async {
    final id = bookingReference != null ? notificationIdFor(bookingReference: bookingReference, type: type) : 'fallback-$recordCalls';
    final existing = notifications[id];
    final notification = AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      bookingReference: bookingReference,
      isRead: existing?.isRead ?? false,
      createdAt: existing?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(_sequence++),
    );
    notifications[id] = notification;
    return notification;
  }

  @override
  Future<void> markAsRead(String notificationId) {
    if (onMarkAsRead != null) return onMarkAsRead!(notificationId);
    return _defaultMarkAsRead(notificationId);
  }

  Future<void> _defaultMarkAsRead(String notificationId) async {
    final existing = notifications[notificationId];
    if (existing == null) return;
    notifications[notificationId] = existing.copyWith(isRead: true);
  }
}
