import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/notifications/data/mock_device_token_repository.dart';

void main() {
  group('registerToken', () {
    test('registers a token with its platform', () async {
      final repository = MockDeviceTokenRepository();

      await repository.registerToken(token: 'token-1', platform: 'android');

      expect(repository.registeredTokens['token-1'], 'android');
    });

    test('re-registering the same token updates rather than duplicating', () async {
      final repository = MockDeviceTokenRepository();
      await repository.registerToken(token: 'token-1', platform: 'android');

      await repository.registerToken(token: 'token-1', platform: 'android');

      expect(repository.registeredTokens, hasLength(1));
    });

    test('two distinct tokens are both registered independently', () async {
      final repository = MockDeviceTokenRepository();

      await repository.registerToken(token: 'token-1', platform: 'android');
      await repository.registerToken(token: 'token-2', platform: 'android');

      expect(repository.registeredTokens, hasLength(2));
    });
  });

  group('deleteToken', () {
    test('removes a registered token', () async {
      final repository = MockDeviceTokenRepository();
      await repository.registerToken(token: 'token-1', platform: 'android');

      await repository.deleteToken('token-1');

      expect(repository.registeredTokens, isEmpty);
    });

    test('deleting an unknown token is a safe no-op', () async {
      final repository = MockDeviceTokenRepository();

      await expectLater(repository.deleteToken('not-registered'), completes);
    });
  });
}
