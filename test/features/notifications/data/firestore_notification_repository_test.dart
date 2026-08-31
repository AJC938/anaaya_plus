import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/notifications/data/firestore_notification_repository.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';

final createdAtUtc = DateTime.utc(2026, 3, 5, 12, 0);

Map<String, dynamic> _fullyPopulatedData({
  String type = 'technicianOnTheWay',
  String title = 'الفني في الطريق',
  String body = 'الفني في طريقه إليك الآن لحجزك رقم AN-20481.',
  String? bookingReference = 'AN-20481',
  bool isRead = false,
}) {
  return <String, dynamic>{
    'type': type,
    'title': title,
    'body': body,
    'bookingReference': bookingReference,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAtUtc),
  };
}

void main() {
  group('notificationFromFirestoreData', () {
    test('maps a fully populated document', () {
      final notification = notificationFromFirestoreData('AN-20481_technicianOnTheWay', _fullyPopulatedData());

      expect(notification.id, 'AN-20481_technicianOnTheWay');
      expect(notification.type, NotificationType.technicianOnTheWay);
      expect(notification.title, 'الفني في الطريق');
      expect(notification.body, contains('AN-20481'));
      expect(notification.bookingReference, 'AN-20481');
      expect(notification.isRead, isFalse);
      expect(notification.createdAt.toUtc(), createdAtUtc);
    });

    test('maps every known type string to its NotificationType', () {
      for (final type in NotificationType.values) {
        final notification = notificationFromFirestoreData('id', _fullyPopulatedData(type: type.name));
        expect(notification.type, type);
      }
    });

    test('an unrecognized type string falls back to bookingConfirmed, without crashing', () {
      final notification = notificationFromFirestoreData('id', _fullyPopulatedData(type: 'some-future-type'));

      expect(notification.type, NotificationType.bookingConfirmed);
    });

    test('a null bookingReference is preserved as null, not coerced to empty string', () {
      final notification = notificationFromFirestoreData('id', _fullyPopulatedData(bookingReference: null));

      expect(notification.bookingReference, isNull);
    });

    test('isRead true is mapped correctly', () {
      final notification = notificationFromFirestoreData('id', _fullyPopulatedData(isRead: true));

      expect(notification.isRead, isTrue);
    });

    test('a missing isRead field defaults to false', () {
      final data = _fullyPopulatedData()..remove('isRead');

      final notification = notificationFromFirestoreData('id', data);

      expect(notification.isRead, isFalse);
    });

    test('missing document data (null map) does not crash', () {
      final notification = notificationFromFirestoreData('id', null);

      expect(notification.title, '');
      expect(notification.body, '');
      expect(notification.bookingReference, isNull);
      expect(notification.isRead, isFalse);
      expect(notification.type, NotificationType.bookingConfirmed);
    });
  });
}
