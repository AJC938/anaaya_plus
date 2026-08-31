import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';
import 'package:anaaya_plus/features/notifications/domain/notification_id.dart';

void main() {
  group('notificationIdFor', () {
    test('the same bookingReference and type always produces the same id', () {
      final first = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.technicianOnTheWay);
      final second = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.technicianOnTheWay);

      expect(first, second);
    });

    test('a different type for the same booking produces a different id', () {
      final onTheWay = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.technicianOnTheWay);
      final completed = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.serviceCompleted);

      expect(onTheWay, isNot(completed));
    });

    test('the same type for a different booking produces a different id', () {
      final first = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.paymentSuccessful);
      final second = notificationIdFor(bookingReference: 'AN-99999', type: NotificationType.paymentSuccessful);

      expect(first, isNot(second));
    });

    test('the id contains the booking reference and the type name', () {
      final id = notificationIdFor(bookingReference: 'AN-20481', type: NotificationType.bookingCancelled);

      expect(id, contains('AN-20481'));
      expect(id, contains('bookingCancelled'));
    });

    test('every NotificationType produces a distinct id for the same booking', () {
      final ids = {for (final type in NotificationType.values) notificationIdFor(bookingReference: 'AN-1', type: type)};

      expect(ids.length, NotificationType.values.length);
    });
  });
}
