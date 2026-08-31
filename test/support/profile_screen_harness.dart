import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/profile/application/profile_providers.dart';
import 'package:anaaya_plus/features/profile/data/profile_repository.dart';

import 'auth_fixtures.dart';
import 'instant_home_overrides.dart';
import 'profile_fixtures.dart';

/// Builds a fresh app + router + container and navigates to [route] — used
/// by every Profile screen test. Defaults [repository] to a no-latency
/// [FakeProfileRepository] so tests are deterministic; pass one with
/// controlled behavior (a Completer, a throwing callback, ...) to exercise
/// loading/error/success paths.
///
/// All four bottom-nav branches mount immediately on the first frame
/// ([IndexedStack] builds every child, not just the active one — see
/// `widget_test.dart`'s branch-preservation tests) — so Home's own
/// providers need harmless instant data too, exactly like every other
/// screen harness in this app already establishes.
Future<ProviderContainer> pumpProfileScreen(
  WidgetTester tester, {
  String route = AppRoutes.profile,
  ProfileRepository? repository,
}) async {
  // Shared between the router (constructor-injected) and the Riverpod
  // provider screens read from (e.g. Profile's real Sign Out call) — one
  // fake identity, so signing out through the UI is reflected in both.
  final fakeAuth = FakeAuthRepository(uid: testUid);
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      profileRepositoryProvider.overrideWithValue(repository ?? FakeProfileRepository()),
      authRepositoryProvider.overrideWithValue(fakeAuth),
    ],
  );
  addTearDown(container.dispose);
  await _useTallViewport(tester);

  final router = createAppRouter(authRepository: fakeAuth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();

  // Land on Profile itself first and let its async data resolve before
  // going anywhere deeper — a sub-route like Edit Profile reads the
  // already-loaded profile synchronously (see EditProfileScreen), so
  // jumping straight there before that first fetch settles would hit it
  // mid-[AsyncLoading], matching a scenario that never happens in real
  // navigation (Edit Profile is only ever reached from an already-loaded
  // Profile screen).
  router.go(AppRoutes.profile);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();

  if (route != AppRoutes.profile) {
    router.go(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  return container;
}

Future<void> _useTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
