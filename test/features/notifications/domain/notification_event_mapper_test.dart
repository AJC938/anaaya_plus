import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart' show BookingStatus;
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';
import 'package:anaaya_plus/features/notifications/domain/notification_event_mapper.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart' show PaymentStatus;

const _ref = 'AN-20481';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  group('notificationForBookingCreated', () {
    test('maps to bookingConfirmed with the reference in the body', () {
      final content = notificationForBookingCreated(l10n: en, bookingReference: _ref);

      expect(content.type, NotificationType.bookingConfirmed);
      expect(content.title, isNotEmpty);
      expect(content.body, contains(_ref));
    });

    test('resolves Arabic text for the Arabic locale', () {
      final content = notificationForBookingCreated(l10n: ar, bookingReference: _ref);

      expect(content.title, 'تم تأكيد الحجز');
    });
  });

  group('notificationForBookingStatusChange', () {
    test('technicianOnTheWay maps to NotificationType.technicianOnTheWay', () {
      final content = notificationForBookingStatusChange(to: BookingStatus.technicianOnTheWay, l10n: en, bookingReference: _ref);

      expect(content.type, NotificationType.technicianOnTheWay);
      expect(content.body, contains(_ref));
    });

    test('inProgress maps to NotificationType.serviceStarted', () {
      final content = notificationForBookingStatusChange(to: BookingStatus.inProgress, l10n: en, bookingReference: _ref);

      expect(content.type, NotificationType.serviceStarted);
    });

    test('completed maps to NotificationType.serviceCompleted', () {
      final content = notificationForBookingStatusChange(to: BookingStatus.completed, l10n: en, bookingReference: _ref);

      expect(content.type, NotificationType.serviceCompleted);
    });

    test('cancelled maps to NotificationType.bookingCancelled', () {
      final content = notificationForBookingStatusChange(to: BookingStatus.cancelled, l10n: en, bookingReference: _ref);

      expect(content.type, NotificationType.bookingCancelled);
    });

    test('the exact Arabic copy for the booking lifecycle notifications matches the product spec', () {
      expect(
        notificationForBookingStatusChange(to: BookingStatus.technicianOnTheWay, l10n: ar, bookingReference: _ref).title,
        'الفني في الطريق',
      );
      expect(
        notificationForBookingStatusChange(to: BookingStatus.inProgress, l10n: ar, bookingReference: _ref).title,
        'بدأت الخدمة',
      );
      expect(
        notificationForBookingStatusChange(to: BookingStatus.completed, l10n: ar, bookingReference: _ref).title,
        'اكتملت الخدمة',
      );
      expect(
        notificationForBookingStatusChange(to: BookingStatus.cancelled, l10n: ar, bookingReference: _ref).title,
        'تم إلغاء الحجز',
      );
    });

    test('upcoming is never a valid transition target — throws rather than silently mapping to nothing', () {
      expect(
        () => notificationForBookingStatusChange(to: BookingStatus.upcoming, l10n: en, bookingReference: _ref),
        throwsArgumentError,
      );
    });
  });

  group('notificationForPaymentStatus', () {
    test('paid maps to NotificationType.paymentSuccessful', () {
      final content = notificationForPaymentStatus(status: PaymentStatus.paid, l10n: en, bookingReference: _ref);

      expect(content!.type, NotificationType.paymentSuccessful);
      expect(content.body, contains(_ref));
    });

    test('failed maps to NotificationType.paymentFailed', () {
      final content = notificationForPaymentStatus(status: PaymentStatus.failed, l10n: en, bookingReference: _ref);

      expect(content!.type, NotificationType.paymentFailed);
    });

    test('pending maps to null — no notification for a transient/absent state', () {
      final content = notificationForPaymentStatus(status: PaymentStatus.pending, l10n: en, bookingReference: _ref);

      expect(content, isNull);
    });
  });
}
