import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/notifications/application/notification_controller.dart';
import 'package:anaaya_plus/features/notifications/application/notification_providers.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/notification_fixtures.dart';

ProviderContainer _container(FakeNotificationRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      notificationRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('markAsRead — success', () {
    test('marks the notification read and invalidates the list provider', () async {
      final repository = FakeNotificationRepository();
      final created = await repository.recordNotification(
        type: NotificationType.bookingConfirmed,
        title: 'title',
        body: 'body',
        bookingReference: 'AN-1',
      );
      final container = _container(repository);
      // Required keep-alive: notificationsListProvider awaits
      // authStateChangesProvider.future internally — without an active
      // listener a bare ProviderContainer can tear down that subscription
      // before it ever delivers its first event (see every other
      // *_controller_test.dart's identical setup in this project).
      container.listen(notificationsListProvider, (previous, next) {});

      await container.read(notificationControllerProvider.notifier).markAsRead(created.id);

      final refetched = await container.read(notificationsListProvider.future);
      expect(refetched.single.isRead, isTrue);
    });
  });

  group('markAsRead — failure', () {
    test('a repository failure surfaces as an error and never crashes', () async {
      final repository = FakeNotificationRepository(onMarkAsRead: (id) async => throw Exception('Firestore unavailable'));
      final container = _container(repository);

      await container.read(notificationControllerProvider.notifier).markAsRead('any-id');

      final state = container.read(notificationControllerProvider);
      expect(state.hasError, isTrue);
    });
  });
}
