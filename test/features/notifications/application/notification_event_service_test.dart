import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart' show BookingStatus;
import 'package:anaaya_plus/features/notifications/application/notification_event_service.dart';
import 'package:anaaya_plus/features/notifications/application/notification_providers.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart' show PaymentStatus;

import '../../../support/auth_fixtures.dart';
import '../../../support/notification_fixtures.dart';

ProviderContainer _container(FakeNotificationRepository repository, {Locale locale = const Locale('en')}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      notificationRepositoryProvider.overrideWithValue(repository),
      localeProvider.overrideWith(() => _FixedLocale(locale)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FixedLocale extends LocaleController {
  _FixedLocale(this._locale);
  final Locale _locale;
  @override
  Locale build() => _locale;
}

void main() {
  group('recordBookingCreated', () {
    test('records a bookingConfirmed notification containing the reference', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository);

      await container.read(notificationEventServiceProvider).recordBookingCreated(bookingReference: 'AN-1');

      final notifications = await repository.getNotifications();
      expect(notifications.single.type, NotificationType.bookingConfirmed);
      expect(notifications.single.body, contains('AN-1'));
      expect(notifications.single.bookingReference, 'AN-1');
    });
  });

  group('recordBookingStatusChange', () {
    for (final entry in {
      BookingStatus.technicianOnTheWay: NotificationType.technicianOnTheWay,
      BookingStatus.inProgress: NotificationType.serviceStarted,
      BookingStatus.completed: NotificationType.serviceCompleted,
      BookingStatus.cancelled: NotificationType.bookingCancelled,
    }.entries) {
      test('${entry.key} records a ${entry.value} notification', () async {
        final repository = FakeNotificationRepository();
        final container = _container(repository);

        await container.read(notificationEventServiceProvider).recordBookingStatusChange(to: entry.key, bookingReference: 'AN-1');

        final notifications = await repository.getNotifications();
        expect(notifications.single.type, entry.value);
      });
    }
  });

  group('recordPaymentStatus', () {
    test('paid records a paymentSuccessful notification', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository);

      await container.read(notificationEventServiceProvider).recordPaymentStatus(status: PaymentStatus.paid, bookingReference: 'AN-1');

      final notifications = await repository.getNotifications();
      expect(notifications.single.type, NotificationType.paymentSuccessful);
    });

    test('failed records a paymentFailed notification', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository);

      await container
          .read(notificationEventServiceProvider)
          .recordPaymentStatus(status: PaymentStatus.failed, bookingReference: 'AN-1');

      final notifications = await repository.getNotifications();
      expect(notifications.single.type, NotificationType.paymentFailed);
    });

    test('pending never records anything at all — the repository is never even called', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository);

      await container
          .read(notificationEventServiceProvider)
          .recordPaymentStatus(status: PaymentStatus.pending, bookingReference: 'AN-1');

      expect(repository.recordCalls, 0);
    });
  });

  group('idempotency through the service', () {
    test('the same event recorded twice through the service never creates a duplicate', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository);
      final service = container.read(notificationEventServiceProvider);

      await service.recordBookingStatusChange(to: BookingStatus.technicianOnTheWay, bookingReference: 'AN-1');
      await service.recordBookingStatusChange(to: BookingStatus.technicianOnTheWay, bookingReference: 'AN-1');

      final notifications = await repository.getNotifications();
      expect(notifications, hasLength(1));
    });
  });

  group('best-effort error handling', () {
    test('a repository failure never throws out of the service — it is swallowed', () async {
      final repository = FakeNotificationRepository(onRecord: (type, title, body, ref) async => throw Exception('offline'));
      final container = _container(repository);

      await expectLater(
        container.read(notificationEventServiceProvider).recordBookingCreated(bookingReference: 'AN-1'),
        completes,
      );
    });
  });

  group('localization', () {
    test('resolves Arabic text when the current locale is Arabic', () async {
      final repository = FakeNotificationRepository();
      final container = _container(repository, locale: const Locale('ar'));

      await container.read(notificationEventServiceProvider).recordBookingCreated(bookingReference: 'AN-1');

      final notifications = await repository.getNotifications();
      expect(notifications.single.title, 'تم تأكيد الحجز');
    });
  });
}
