import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/notifications/application/notification_providers.dart';
import 'package:anaaya_plus/features/notifications/data/notification_repository.dart';
import 'package:anaaya_plus/features/notifications/domain/models/app_notification.dart';
import 'package:anaaya_plus/features/notifications/domain/models/notification_type.dart';
import 'package:anaaya_plus/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/tracking_screen.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart' show testHomeLocation, testServiceId;
import '../../../support/instant_home_overrides.dart';
import '../../../support/notification_fixtures.dart';

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(NotificationsScreen)));

/// A booking for every notification reference this file's fixtures use, so
/// a tap-to-Tracking test lands on a real, renderable booking instead of
/// hitting the real (unmockable-under-`flutter test`) Firestore repository.
FakeBookingRepository _trackingTargetBookings() {
  final repository = FakeBookingRepository();
  for (final id in ['AN-1', 'AN-2']) {
    repository.bookings[id] = Booking(
      id: id,
      serviceId: testServiceId,
      serviceName: 'Oil Change',
      serviceImageAsset: 'oil_change',
      serviceOptionId: 'opt-mineral',
      serviceOptionName: 'Mineral',
      vehicleId: 'v1',
      vehicleName: 'Toyota Camry',
      vehicleYear: 2023,
      plateNumber: 'ABC 1234',
      location: testHomeLocation,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 25, fees: 10, total: 124),
      status: BookingStatus.upcoming,
      createdAt: DateTime(2026, 1, 1),
    );
  }
  return repository;
}

Future<ProviderContainer> _pumpNotifications(WidgetTester tester, {required NotificationRepository repository}) async {
  final fakeAuth = FakeAuthRepository(uid: testUid);
  final container = ProviderContainer(
    // Matches every other full-app test harness in this project (see
    // `pumpBookingScreen`): without this, a provider that throws (e.g. the
    // error-state test's repository, or the real Firestore-backed
    // `bookingRepositoryProvider` if a test forgets to override it) enters
    // Riverpod's default exponential-backoff auto-retry instead of
    // surfacing `AsyncValue.error` immediately — leaving a pending Timer
    // that fails the test's teardown invariant check.
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      notificationRepositoryProvider.overrideWithValue(repository),
      bookingRepositoryProvider.overrideWithValue(_trackingTargetBookings()),
    ],
  );
  addTearDown(container.dispose);
  final router = createAppRouter(authRepository: fakeAuth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  router.go(AppRoutes.notifications());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

AppNotification _notification({
  required String id,
  required bool isRead,
  String? bookingReference = 'AN-1',
  NotificationType type = NotificationType.technicianOnTheWay,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    type: type,
    title: 'Technician On The Way',
    body: 'Your technician is on the way for booking $bookingReference.',
    bookingReference: bookingReference,
    isRead: isRead,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9),
  );
}

void main() {
  testWidgets('an empty notification list shows the empty state', (tester) async {
    await _pumpNotifications(tester, repository: FakeNotificationRepository());
    final l10n = _l10n(tester);

    expect(find.text(l10n.noNotificationsTitle), findsOneWidget);
  });

  testWidgets('renders every notification with title and body', (tester) async {
    final repository = FakeNotificationRepository()
      ..notifications['n1'] = _notification(id: 'n1', isRead: false)
      ..notifications['n2'] = _notification(id: 'n2', isRead: true, type: NotificationType.paymentSuccessful, bookingReference: 'AN-2');
    await _pumpNotifications(tester, repository: repository);

    expect(find.text('Technician On The Way'), findsNWidgets(2));
    expect(find.textContaining('AN-1'), findsOneWidget);
    expect(find.textContaining('AN-2'), findsOneWidget);
  });

  testWidgets('an unread notification shows an unread indicator dot, a read one does not', (tester) async {
    final repository = FakeNotificationRepository()
      ..notifications['unread'] = _notification(id: 'unread', isRead: false)
      ..notifications['read'] = _notification(id: 'read', isRead: true, bookingReference: 'AN-2');
    await _pumpNotifications(tester, repository: repository);

    // Scoped to NotificationsScreen's own subtree: go_router mounts Home
    // underneath (nested route), and Home's own bell-icon badge is also a
    // non-transparent circular Container whenever there's an unread count
    // — counting the whole tree would double-count that badge alongside
    // this tile's dot.
    final dots = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(NotificationsScreen),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle,
            ),
          ),
        )
        .toList();
    final unreadDots = dots.where((c) => ((c.decoration! as BoxDecoration).color) != Colors.transparent);
    expect(unreadDots.length, 1);
  });

  testWidgets('tapping an unread notification marks it read and navigates to Tracking', (tester) async {
    final repository = FakeNotificationRepository()..notifications['n1'] = _notification(id: 'n1', isRead: false);
    await _pumpNotifications(tester, repository: repository);

    await tester.tap(find.text('Technician On The Way'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TrackingScreen), findsOneWidget);
    expect(repository.notifications['n1']!.isRead, isTrue);
  });

  testWidgets('tapping a notification with no bookingReference marks it read but does not navigate', (tester) async {
    final repository = FakeNotificationRepository()
      ..notifications['n1'] = _notification(id: 'n1', isRead: false, bookingReference: null, type: NotificationType.bookingConfirmed);
    await _pumpNotifications(tester, repository: repository);

    await tester.tap(find.text('Technician On The Way'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(repository.notifications['n1']!.isRead, isTrue);
  });

  testWidgets('an error loading notifications shows the error state with retry', (tester) async {
    var calls = 0;
    final repository = FakeNotificationRepository(
      onGetNotifications: () async {
        calls++;
        throw Exception('Firestore unavailable');
      },
    );
    await _pumpNotifications(tester, repository: repository);
    final l10n = _l10n(tester);

    expect(find.text(l10n.unableToLoadNotificationsMessage), findsOneWidget);
    expect(calls, greaterThanOrEqualTo(1));

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, greaterThanOrEqualTo(2));
  });

  testWidgets('shows a loading placeholder while notifications are being fetched', (tester) async {
    final repository = FakeNotificationRepository(onGetNotifications: () => Completer<List<AppNotification>>().future);

    await _pumpNotifications(tester, repository: repository);

    expect(find.byType(LoadingPlaceholder), findsWidgets);
  });
}
