import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';

import '../../../support/auth_fixtures.dart';

void main() {
  group('auth-state gating (regression coverage for the startup race)', () {
    test('bookingsListProvider stays in AsyncLoading while auth is still resolving, not AsyncError', () async {
      // No uid passed, and its stream never emits until sign-in/sign-out is
      // called — this stands in for "Firebase Auth hasn't restored the
      // session yet", the exact state a fresh app launch briefly passes
      // through. Mirrors carsControllerProvider's own regression test.
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          // bookingRepositoryProvider deliberately NOT overridden — this
          // exercises its real uid==null throw, which must never fire while
          // auth is merely unresolved.
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      // A keep-alive listener is required: without one, the provider isn't
      // kept actively subscribed to authStateChangesProvider's stream, so
      // its pending `await ... .future` never even observes signOut()'s
      // emission below.
      container.listen(bookingsListProvider, (previous, next) {});
      final state = container.read(bookingsListProvider);
      expect(state, isA<AsyncLoading<List<Booking>>>());

      // Resolve auth before the test ends so the pending await doesn't
      // dangle past the container's disposal.
      await fakeAuth.signOut();
    });

    test('bookingsListProvider becomes AsyncError once auth resolves to signed-out, not stuck loading forever', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(bookingsListProvider, (previous, next) {});
      expect(container.read(bookingsListProvider), isA<AsyncLoading<List<Booking>>>());

      await fakeAuth.signOut(); // emits null — a genuine, resolved sign-out

      // Riverpod wraps the thrown error in its own (not publicly exported)
      // ProviderException, so this matches on the message rather than the
      // original error's type.
      await expectLater(
        container.read(bookingsListProvider.future),
        throwsA(predicate((e) => e.toString().contains('bookingRepositoryProvider requires an authenticated user'))),
      );
      expect(container.read(bookingsListProvider).hasError, isTrue);
    });

    test('bookingByIdProvider stays in AsyncLoading while auth is still resolving, not AsyncError', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      addTearDown(fakeAuth.dispose);

      container.listen(bookingByIdProvider('AN-1'), (previous, next) {});
      expect(container.read(bookingByIdProvider('AN-1')), isA<AsyncLoading<Booking?>>());

      await fakeAuth.signOut();
    });
  });
}
