import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/cars_screen.dart';
import 'package:anaaya_plus/features/home/application/home_providers.dart';
import 'package:anaaya_plus/features/home/data/mock_home_repository.dart';
import 'package:anaaya_plus/features/home/presentation/screens/home_screen.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_screen.dart';

import 'support/auth_fixtures.dart';

/// Fixes the Home mock scenario so these general navigation/shell tests
/// never render a live countdown (see home_screen_test.dart for that) —
/// `pumpAndSettle` cannot be used on a screen with a real periodic ticker.
class _FixedScenario extends HomeMockScenarioController {
  _FixedScenario(this._value);
  final HomeMockScenario _value;
  @override
  HomeMockScenario build() => _value;
}

ProviderContainer _buildContainer() {
  return ProviderContainer(
    // Profile's branch mounts in the background here too (see
    // profile_screen_harness.dart's comment on IndexedStack), and
    // authRepositoryProvider isn't overridden in this file — so
    // profileRepositoryProvider errors (no Firebase app in tests), and
    // without this, Riverpod's default auto-retry schedules a timer that
    // outlives the test.
    retry: (retryCount, error) => null,
    overrides: [
      homeMockScenarioProvider.overrideWith(() => _FixedScenario(HomeMockScenario.completed)),
    ],
  );
}

/// Pumps the app and lets Home's mock data (400ms artificial latency)
/// resolve, without relying on pumpAndSettle. Also normalizes to the Home
/// tab, and builds a fresh router (signed in, via a fake auth repository —
/// the real one needs Firebase, which isn't initialized in tests) rather
/// than reusing the shared `appRouter` singleton, so no state from a
/// previous test in this file leaks in.
Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  final router = createAppRouter(authRepository: FakeAuthRepository(uid: testUid));
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('الرئيسية'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('defaults to Arabic (RTL) with Arabic tab labels', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الحجوزات'), findsOneWidget);
    expect(find.text('سياراتي'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });

  testWidgets('all four tabs navigate to their own screen and back', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('الحجوزات'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BookingsScreen), findsOneWidget);

    await tester.tap(find.text('سياراتي'));
    // A bare pump first so CarsScreen actually mounts (and its mock
    // repository call starts) before the clock is advanced — otherwise the
    // duration-pump below elapses time before the 400ms timer even exists.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CarsScreen), findsOneWidget);

    await tester.tap(find.text('حسابي'));
    // A bare pump first so ProfileScreen actually mounts (and its mock
    // repository calls start) before the clock is advanced — otherwise the
    // duration-pump below elapses time before the 400ms timers even exist.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Round-tripping back to Home restores its branch correctly.
    await tester.tap(find.text('الرئيسية'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('inactive branches stay mounted offstage instead of being recreated', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await tester.tap(find.text('سياراتي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Home is hidden from the default, onstage-only finder...
    expect(find.byType(HomeScreen), findsNothing);
    // ...but its element is still alive underneath, just offstage: the
    // StatefulShellRoute keeps every visited branch in an IndexedStack
    // instead of disposing it, which is what lets state survive a tab
    // switch.
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a route pushed inside a branch survives switching tabs and back', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    // Stand-in for a future nested route (e.g. a booking detail page)
    // pushed on top of the Home branch's own Navigator via its dedicated
    // navigatorKey.
    AppNavigatorKeys.home.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('nested-probe')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('nested-probe'), findsOneWidget);

    await tester.tap(find.text('سياراتي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('الرئيسية'));
    await tester.pump(const Duration(milliseconds: 400));

    // Returning to Home must show the pushed page again, not reset back to
    // the branch's root location.
    expect(find.text('nested-probe'), findsOneWidget);

    // Clean up the imperative push so it doesn't leak into later tests.
    AppNavigatorKeys.home.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('switching locale flips the app to English (LTR) and back to Arabic', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    // Locale is also watched by Home's content providers (services/offers/
    // active booking return locale-appropriate text), so switching it
    // re-triggers their mock fetch latency too.
    container.read(localeProvider.notifier).set(const Locale('en'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.ltr);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);

    container.read(localeProvider.notifier).set(const Locale('ar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
    expect(find.text('الرئيسية'), findsOneWidget);
  });
}
