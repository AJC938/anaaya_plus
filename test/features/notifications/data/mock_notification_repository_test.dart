import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/notifications/data/mock_notification_repository.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';

void main() {
  group('getNotifications', () {
    test('starts empty', () async {
      final repository = MockNotificationRepository();

      final result = await repository.getNotifications();

      expect(result, isEmpty);
    });

    test('returns notifications newest first', () async {
      final repository = MockNotificationRepository();
      await repository.recordNotification(
        type: NotificationType.bookingConfirmed,
        title: 'First',
        body: 'body',
        bookingReference: 'AN-1',
      );
      await repository.recordNotification(
        type: NotificationType.paymentSuccessful,
        title: 'Second',
        body: 'body',
        bookingReference: 'AN-1',
      );

      final result = await repository.getNotifications();

      expect(result.first.title, 'Second');
      expect(result.last.title, 'First');
    });
  });

  group('recordNotification — idempotency (duplicate protection)', () {
    test('recording the same (bookingReference, type) twice never creates a second entry', () async {
      final repository = MockNotificationRepository();

      await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'الفني في الطريق',
        body: 'body',
        bookingReference: 'AN-1',
      );
      await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'الفني في الطريق',
        body: 'body',
        bookingReference: 'AN-1',
      );

      final result = await repository.getNotifications();
      expect(result, hasLength(1));
    });

    test('a duplicate record call never resets isRead back to false', () async {
      final repository = MockNotificationRepository();
      final first = await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );
      await repository.markAsRead(first.id);

      final second = await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );

      expect(second.isRead, isTrue);
    });

    test('a duplicate record call preserves the original createdAt', () async {
      final repository = MockNotificationRepository();
      final first = await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );

      final second = await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );

      expect(second.createdAt, first.createdAt);
    });

    test('a different type for the same booking creates a genuinely separate entry', () async {
      final repository = MockNotificationRepository();

      await repository.recordNotification(
        type: NotificationType.technicianOnTheWay,
        title: 'a',
        body: 'a',
        bookingReference: 'AN-1',
      );
      await repository.recordNotification(
        type: NotificationType.serviceStarted,
        title: 'b',
        body: 'b',
        bookingReference: 'AN-1',
      );

      final result = await repository.getNotifications();
      expect(result, hasLength(2));
    });
  });

  group('markAsRead', () {
    test('marks the matching notification read', () async {
      final repository = MockNotificationRepository();
      final created = await repository.recordNotification(
        type: NotificationType.bookingConfirmed,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );
      expect(created.isRead, isFalse);

      await repository.markAsRead(created.id);

      final result = await repository.getNotifications();
      expect(result.single.isRead, isTrue);
    });

    test('marking an unknown id is a safe no-op, not an error', () async {
      final repository = MockNotificationRepository();

      await expectLater(repository.markAsRead('not-a-real-id'), completes);
    });
  });
}
