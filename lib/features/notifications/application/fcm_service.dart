import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/device_token_repository.dart';
import '../data/firestore_device_token_repository.dart';
import 'notification_providers.dart';

/// A human-readable platform label for the device-token document — never
/// the full platform/OS-version string (nothing here needs it, and keeping
/// this minimal matches Phase 3's "lightweight document" requirement).
String currentPlatformLabel() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}

/// The two `FirebaseMessaging.instance` calls [FcmDeviceTokenSync] actually
/// needs, pulled behind an interface — the FCM plugin talks to a real
/// platform channel with no in-memory fake of its own, so without this seam
/// none of [FcmDeviceTokenSync]'s branching (permission denied, no token
/// available, a genuine token change) could be unit-tested at all (Phase
/// 13 explicitly requires "token update handling" coverage). Kept
/// deliberately this thin — not a general-purpose FCM wrapper, just the two
/// calls this one class makes.
abstract class FcmTokenSource {
  /// `true` only when the user granted permission — every denial variant
  /// (denied, or not-yet-determined on a platform that doesn't prompt)
  /// collapses to the same "don't register a token" outcome, matching how
  /// [FcmDeviceTokenSync] actually uses this.
  Future<bool> requestPermissionGranted();
  Future<String?> getToken();
}

class FirebaseFcmTokenSource implements FcmTokenSource {
  @override
  Future<bool> requestPermissionGranted() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus != AuthorizationStatus.denied;
  }

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();
}

/// Registers/refreshes this device's FCM token for the currently
/// authenticated user, and keeps it in sync as auth state changes.
///
/// Deliberately a plain class driven by a `ref.listen` set up once at the
/// app root (see `AnaayaPlusApp`) rather than an [AsyncNotifier] — there is
/// no meaningful "state" to expose to any screen (tokens are never shown in
/// UI, per Phase 4), only a side effect to perform whenever the signed-in
/// user changes. Every method is best-effort — matches
/// `NotificationEventService`'s own reasoning: a permission denial or a
/// transient Firestore/FCM error must never block sign-in or crash the app.
class FcmDeviceTokenSync {
  FcmDeviceTokenSync(this._ref, {FcmTokenSource? tokenSource, DeviceTokenRepository Function(String uid)? repositoryForUid})
    : _tokenSource = tokenSource ?? FirebaseFcmTokenSource(),
      _repositoryForUid = repositoryForUid ?? ((uid) => FirestoreDeviceTokenRepository(uid: uid));

  final Ref _ref;
  final FcmTokenSource _tokenSource;

  /// Deliberately NOT via [deviceTokenRepositoryProvider] for the
  /// sign-out-cleanup path — that provider resolves against the CURRENTLY
  /// authenticated uid, which is already null/different by the time
  /// sign-out finishes, not the uid a token was originally registered
  /// under. An explicitly-scoped repository instance is required there,
  /// the same reason `_ensureUserDocument` never trusts a provider that
  /// could have already rebuilt. Injectable so tests never touch real
  /// Firestore.
  final DeviceTokenRepository Function(String uid) _repositoryForUid;

  /// The token last registered under the previously signed-in user, if
  /// any — used to clean it up on sign-out ("not persist a token under
  /// another user's UID" — Phase 4). Deliberately in-memory only, scoped to
  /// this single app session: there is no reliable way to know, days later,
  /// which token a long-since-signed-out session last registered, and nothing
  /// in this milestone's requirements needs that — an orphaned old token
  /// simply stops being useful the same way any rotated/expired token does
  /// (see `FirestoreDeviceTokenRepository`'s own doc comment).
  String? _lastRegisteredToken;
  String? _lastRegisteredUid;

  @visibleForTesting
  String? get debugLastRegisteredToken => _lastRegisteredToken;
  @visibleForTesting
  String? get debugLastRegisteredUid => _lastRegisteredUid;

  /// Called once, reactively, whenever [authStateChangesProvider]'s uid
  /// changes — a fresh sign-in AND a returning already-signed-in user on a
  /// cold start both flow through here, which a one-shot call from inside
  /// the OTP flow (like `_ensureUserDocument`) could never cover for the
  /// second case.
  Future<void> syncForUid(String? uid) async {
    if (uid == null) {
      await _unregisterLastKnownToken();
      return;
    }
    if (uid != _lastRegisteredUid) {
      // A different user than whoever this session last registered for —
      // release that token from the old account first, matching Phase 4's
      // "not persist a token under another user's UID" requirement even
      // when sign-out and sign-in happen back-to-back on the same device
      // without this class ever observing a genuine `null` in between.
      await _unregisterLastKnownToken();
    }

    try {
      final granted = await _tokenSource.requestPermissionGranted();
      if (!granted) return;

      final token = await _tokenSource.getToken();
      if (token == null) return;

      await _ref.read(deviceTokenRepositoryProvider).registerToken(token: token, platform: currentPlatformLabel());
      _lastRegisteredToken = token;
      _lastRegisteredUid = uid;
    } catch (_) {
      // Best-effort — see this class's own doc comment.
    }
  }

  /// Called whenever FCM itself rotates the token (a genuine new value, not
  /// a repeat of the current one) — registers the new token under whichever
  /// user is currently signed in, if any.
  Future<void> handleTokenRefresh(String newToken) async {
    final uid = _ref.read(authStateChangesProvider).value;
    if (uid == null) return;
    try {
      await _ref.read(deviceTokenRepositoryProvider).registerToken(token: newToken, platform: currentPlatformLabel());
      _lastRegisteredToken = newToken;
      _lastRegisteredUid = uid;
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _unregisterLastKnownToken() async {
    final token = _lastRegisteredToken;
    final uid = _lastRegisteredUid;
    if (token == null || uid == null) return;
    _lastRegisteredToken = null;
    _lastRegisteredUid = null;
    try {
      await _repositoryForUid(uid).deleteToken(token);
    } catch (_) {
      // Best-effort.
    }
  }
}

final fcmDeviceTokenSyncProvider = Provider((ref) => FcmDeviceTokenSync(ref));
