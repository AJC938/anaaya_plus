import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/features/auth/presentation/screens/phone_number_screen.dart';
import 'package:anaaya_plus/features/home/presentation/screens/home_screen.dart';

import '../../support/auth_fixtures.dart';
import '../../support/instant_home_overrides.dart';

Future<(ProviderContainer, GoRouter)> _pump(WidgetTester tester, {required FakeAuthRepository auth}) async {
  // BE-08: Home's header now watches `unreadNotificationCountProvider`
  // (see `home_header.dart`), which reads `notificationsListProvider` ->
  // the real `notificationRepositoryProvider` when unmocked. That's
  // harmless by design (the badge just silently stays hidden on a fetch
  // failure — see that provider's own doc comment) as long as retry is
  // disabled, matching every other full-app test harness in this project
  // (e.g. `pumpBookingScreen`, `services_screen_test.dart`) — without it,
  // Riverpod's default auto-retry leaves a pending backoff Timer that
  // fails this test's teardown invariant the moment an authenticated user
  // reaches Home.
  final container = ProviderContainer(retry: (retryCount, error) => null, overrides: [...instantHomeOverrides()]);
  final router = createAppRouter(authRepository: auth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return (container, router);
}

void main() {
  testWidgets('an unauthenticated user is redirected to the phone screen, not Home', (tester) async {
    final (container, _) = await _pump(tester, auth: FakeAuthRepository());
    addTearDown(container.dispose);

    expect(find.byType(PhoneNumberScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('an already-authenticated user lands on Home directly', (tester) async {
    final (container, _) = await _pump(tester, auth: FakeAuthRepository(uid: testUid));
    addTearDown(container.dispose);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneNumberScreen), findsNothing);
  });

  testWidgets('an authenticated user visiting the phone screen is redirected back to Home', (tester) async {
    final (container, router) = await _pump(tester, auth: FakeAuthRepository(uid: testUid));
    addTearDown(container.dispose);

    router.go(AppRoutes.authPhone);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneNumberScreen), findsNothing);
  });

  testWidgets('signing out reactively redirects the app back to the phone screen', (tester) async {
    final auth = FakeAuthRepository(uid: testUid);
    final (container, _) = await _pump(tester, auth: auth);
    addTearDown(container.dispose);
    expect(find.byType(HomeScreen), findsOneWidget);

    await auth.signOut();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PhoneNumberScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
