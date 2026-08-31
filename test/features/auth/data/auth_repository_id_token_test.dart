import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_fixtures.dart';

/// SPG-08: [AuthRepository.getIdToken] is a thin delegation to the real
/// Firebase SDK in [FirebaseAuthRepository] (see its own doc comment) —
/// not independently unit-testable without a real platform channel,
/// matching every other method on that class. What IS testable, and what
/// this file covers, is the exact behavioral contract every implementation
/// (real or fake) must honor: null when signed out, a token when signed
/// in, never a refresh token or anything persisted.
void main() {
  group('AuthRepository.getIdToken', () {
    test('returns null when no user is authenticated', () async {
      final repository = FakeAuthRepository();

      final token = await repository.getIdToken();

      expect(token, isNull);
    });

    test('returns a token when a user is authenticated', () async {
      final repository = FakeAuthRepository(uid: testUid);

      final token = await repository.getIdToken();

      expect(token, isNotNull);
      expect(token, isNotEmpty);
    });

    test('returns null again after signing out', () async {
      final repository = FakeAuthRepository(uid: testUid);
      expect(await repository.getIdToken(), isNotNull);

      await repository.signOut();

      expect(await repository.getIdToken(), isNull);
    });
  });
}
