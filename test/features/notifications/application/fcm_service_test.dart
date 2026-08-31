import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/notifications/application/fcm_service.dart';
import 'package:anaaya_plus/features/notifications/application/notification_providers.dart';
import 'package:anaaya_plus/features/notifications/data/device_token_repository.dart';
import 'package:anaaya_plus/features/notifications/data/mock_device_token_repository.dart';

import '../../../support/auth_fixtures.dart';

/// `FcmDeviceTokenSync` takes a [Ref], not a [ProviderContainer] — this is
/// the standard, minimal way to obtain a real, container-bound [Ref] in a
/// test without introducing a widget/ConsumerWidget just to get one.
final _refProvider = Provider<Ref>((ref) => ref);
Ref _refFrom(ProviderContainer container) => container.read(_refProvider);

class _FakeTokenSource implements FcmTokenSource {
  _FakeTokenSource({this.granted = true, this.token = 'token-1'});

  bool granted;
  String? token;
  int requestPermissionCalls = 0;
  int getTokenCalls = 0;

  @override
  Future<bool> requestPermissionGranted() async {
    requestPermissionCalls++;
    return granted;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }
}

void main() {
  group('syncForUid — success', () {
    test('registers the current token under the signed-in user', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final source = _FakeTokenSource();
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: source);

      await sync.syncForUid(testUid);

      expect(tokenRepo.registeredTokens['token-1'], isNotNull);
      expect(sync.debugLastRegisteredToken, 'token-1');
      expect(sync.debugLastRegisteredUid, testUid);
    });
  });

  group('syncForUid — permission denied', () {
    test('never registers a token when permission is denied', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final source = _FakeTokenSource(granted: false);
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: source);

      await sync.syncForUid(testUid);

      expect(tokenRepo.registeredTokens, isEmpty);
      expect(source.getTokenCalls, 0, reason: 'no point fetching a token once permission is denied');
    });
  });

  group('syncForUid — no token available', () {
    test('never registers when getToken returns null', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final source = _FakeTokenSource(token: null);
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: source);

      await sync.syncForUid(testUid);

      expect(tokenRepo.registeredTokens, isEmpty);
    });
  });

  group('syncForUid — sign-out', () {
    test('a null uid unregisters the previously-registered token', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final source = _FakeTokenSource();
      final unregisterCalls = <(String uid, String token)>[];
      final sync = FcmDeviceTokenSync(
        _refFrom(container),
        tokenSource: source,
        repositoryForUid: (uid) => _RecordingRepository(unregisterCalls, uid),
      );
      await sync.syncForUid(testUid);

      await sync.syncForUid(null);

      expect(unregisterCalls, [(testUid, 'token-1')]);
      expect(sync.debugLastRegisteredToken, isNull);
      expect(sync.debugLastRegisteredUid, isNull);
    });

    test('never persists a token under a different user than who it was registered for — switching users releases the old one first', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final source = _FakeTokenSource();
      final unregisterCalls = <(String uid, String token)>[];
      final sync = FcmDeviceTokenSync(
        _refFrom(container),
        tokenSource: source,
        repositoryForUid: (uid) => _RecordingRepository(unregisterCalls, uid),
      );
      await sync.syncForUid('user-a');

      await sync.syncForUid('user-b');

      expect(unregisterCalls, [('user-a', 'token-1')]);
      expect(sync.debugLastRegisteredUid, 'user-b');
    });
  });

  group('handleTokenRefresh', () {
    test('registers the new token under the currently signed-in user', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: _FakeTokenSource());
      container.listen(authStateChangesProvider, (previous, next) {});
      await container.read(authStateChangesProvider.future);

      await sync.handleTokenRefresh('rotated-token');

      expect(tokenRepo.registeredTokens['rotated-token'], isNotNull);
      expect(sync.debugLastRegisteredToken, 'rotated-token');
    });

    test('does nothing when nobody is signed in', () async {
      final tokenRepo = MockDeviceTokenRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: null)),
          deviceTokenRepositoryProvider.overrideWithValue(tokenRepo),
        ],
      );
      addTearDown(container.dispose);
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: _FakeTokenSource());
      // Deliberately never awaited to resolution: FakeAuthRepository(uid:
      // null) never emits at all until an explicit sign-in/out call (see
      // its own doc comment) — genuinely unresolved is exactly what "not
      // signed in yet" looks like, and `.value` on a still-loading
      // AsyncValue is already null, the same condition a real signed-out
      // session would produce.

      await sync.handleTokenRefresh('rotated-token');

      expect(tokenRepo.registeredTokens, isEmpty);
    });
  });

  group('error handling', () {
    test('a repository failure during registration is swallowed, never thrown', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
          deviceTokenRepositoryProvider.overrideWithValue(_ThrowingDeviceTokenRepository()),
        ],
      );
      addTearDown(container.dispose);
      final sync = FcmDeviceTokenSync(_refFrom(container), tokenSource: _FakeTokenSource());

      await expectLater(sync.syncForUid(testUid), completes);
    });
  });
}

class _RecordingRepository implements DeviceTokenRepository {
  _RecordingRepository(this._calls, this._uid);
  final List<(String uid, String token)> _calls;
  final String _uid;

  @override
  Future<void> deleteToken(String token) async => _calls.add((_uid, token));

  @override
  Future<void> registerToken({required String token, required String platform}) async {}
}

class _ThrowingDeviceTokenRepository implements DeviceTokenRepository {
  @override
  Future<void> registerToken({required String token, required String platform}) async => throw Exception('Firestore unavailable');

  @override
  Future<void> deleteToken(String token) async {}
}
