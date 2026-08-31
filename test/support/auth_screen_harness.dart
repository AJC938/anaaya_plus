import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';

import 'auth_fixtures.dart';
import 'instant_home_overrides.dart';

/// Builds a fresh app + router + container starting unauthenticated (so the
/// redirect lands on the Phone Number screen), with [auth] wired into both
/// the router's gate and the Riverpod provider the screens/controller
/// actually read from — one fake identity for both. [user] defaults to a
/// fresh [FakeUserRepository] so a successful sign-in's Firestore
/// provisioning step never touches the real (uninitialized-in-tests)
/// Firebase — the real repository's constructor throws immediately, which
/// Riverpod retries on a timer that can outlive a short test.
Future<ProviderContainer> pumpAuthScreen(WidgetTester tester, {required FakeAuthRepository auth, FakeUserRepository? user}) async {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(user ?? FakeUserRepository()),
    ],
  );
  addTearDown(container.dispose);

  final router = createAppRouter(authRepository: auth);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  return container;
}
