import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/profile/application/profile_providers.dart';
import 'package:anaaya_plus/features/profile/domain/models/customer_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  group('profileRepositoryProvider', () {
    // Constructing a real FirestoreProfileRepository touches
    // FirebaseFirestore.instance, which needs a live Firebase app this
    // suite never initializes — the same limitation FirestoreUserRepository
    // already has no direct test for. Only the new unauthenticated guard
    // (added this step) is exercised here; it never reaches that
    // construction.
    test('throws when there is no authenticated uid (signed out, or auth still resolving)', () {
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authStateChangesProvider.overrideWith((ref) => const Stream<String?>.empty())],
      );
      addTearDown(container.dispose);

      // ProviderContainer.read wraps the thrown error in Riverpod's
      // internal (not publicly exported) ProviderException, so this
      // matches on the wrapper's message rather than the original error's
      // type.
      expect(
        () => container.read(profileRepositoryProvider),
        throwsA(predicate((e) => e.toString().contains('profileRepositoryProvider requires an authenticated user'))),
      );
    });
  });

  group('profileControllerProvider auth-state gating (regression coverage for the startup race)', () {
    // ProfileController.build() now waits for authStateChangesProvider's
    // first emission before ever reading profileRepositoryProvider — these
    // exercise that guard, not profileRepositoryProvider's own throw
    // (covered above), so a fresh app launch (auth still restoring) is no
    // longer indistinguishable from a genuine sign-out.

    test('stays in AsyncLoading while auth is still resolving, not AsyncError', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      // A keep-alive listener is required here, not just container.read():
      // without one, the provider isn't kept actively subscribed to the
      // auth stream, so it never even observes signOut()'s emission below.
      container.listen(profileControllerProvider, (previous, next) {});
      expect(container.read(profileControllerProvider), isA<AsyncLoading<CustomerProfile>>());

      // Resolve auth before the test ends so build()'s pending await
      // doesn't dangle past the container's disposal.
      await fakeAuth.signOut();
    });

    test('becomes AsyncError once auth resolves to signed-out, not stuck loading forever', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(profileControllerProvider, (previous, next) {});
      expect(container.read(profileControllerProvider), isA<AsyncLoading<CustomerProfile>>());

      await fakeAuth.signOut(); // emits null — a genuine, resolved sign-out

      // See the "throws when there is no authenticated uid" test above for
      // why this matches on the message rather than the original error
      // type — Riverpod wraps it in its own (not publicly exported)
      // ProviderException.
      await expectLater(
        container.read(profileControllerProvider.future),
        throwsA(predicate((e) => e.toString().contains('profileRepositoryProvider requires an authenticated user'))),
      );
      expect(container.read(profileControllerProvider).hasError, isTrue);
    });

    test('proceeds to load data once auth resolves to an authenticated uid', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(profileControllerProvider, (previous, next) {});
      expect(container.read(profileControllerProvider), isA<AsyncLoading<CustomerProfile>>());

      await fakeAuth.debugSignIn('signed-in-uid');

      final profile = await container.read(profileControllerProvider.future);
      expect(profile.id, testProfile.id);
    });
  });
}
