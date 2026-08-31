import 'dart:async';

import 'package:anaaya_plus/features/auth/data/auth_repository.dart';
import 'package:anaaya_plus/features/auth/data/user_repository.dart';
import 'package:anaaya_plus/features/auth/domain/phone_auth_failure.dart';

/// A signed-in-by-default UID — most tests that boot the full app aren't
/// about auth at all, and need to land past the auth gate without caring
/// what the UID actually is.
const testUid = 'test-uid';

/// A no-Firebase, fully controllable [AuthRepository]. [uid] is exposed as
/// [currentUserUid]/[authStateChanges] purely as a plain string — Firebase's
/// own `User` type can't be constructed in a pure Dart test without a real
/// platform, which is exactly why [AuthRepository] never exposes it.
class FakeAuthRepository implements AuthRepository {
  // `uid` is kept as the public parameter name — `this._uid` would force
  // external callers to use the private field name instead.
  // ignore: prefer_initializing_formals
  FakeAuthRepository({String? uid, this.phoneNumber, this.onSendCode, this.onVerifyOtp}) : _uid = uid {
    _controller = StreamController<String?>.broadcast();
  }

  String? _uid;
  late final StreamController<String?> _controller;

  /// Returned by [currentUserPhoneNumber] — controllable so tests can
  /// assert what gets passed to [UserRepository.ensureUserDocument].
  String? phoneNumber;

  /// Called for [sendOtp]. Return normally for success, or throw a
  /// [PhoneAuthFailureException] (or any other exception) to simulate a
  /// send failure.
  Future<void> Function(String phoneNumber)? onSendCode;

  /// Called for [verifyOtp]. Return the UID to "sign in" as on success, or
  /// throw a [PhoneAuthFailureException] (or any other exception) for
  /// failure.
  Future<String> Function(String phoneNumber, String otp)? onVerifyOtp;

  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;

  /// Constructed with a uid (the "already signed in" case almost every
  /// full-app test harness uses): replays that uid to *every* new
  /// subscriber immediately on listen, mirroring how a real, already-signed
  /// -in Firebase session eventually reports itself to any new listener,
  /// regardless of exactly when that listener attaches — a plain broadcast
  /// stream can't do this, since it drops events for anyone not already
  /// listening at emission time, which is exactly the ordering a widget
  /// test can't reliably control.
  ///
  /// Constructed with no uid (auth-flow tests that drive sign-in
  /// themselves, and this file's own auth-state-gating tests): returns the
  /// plain, unreplayed stream, so it stays genuinely unresolved — no value
  /// at all — until [verifyOtp]/[debugSignIn]/[signOut] is explicitly
  /// called, exactly like a real not-yet-restored session.
  @override
  Stream<String?> authStateChanges() {
    final initialUid = _uid;
    if (initialUid == null) return _controller.stream;

    return Stream.multi((emitController) {
      emitController.add(initialUid);
      final subscription = _controller.stream.listen(
        emitController.add,
        onError: emitController.addError,
        onDone: emitController.close,
      );
      emitController.onCancel = subscription.cancel;
    });
  }

  @override
  String? get currentUserUid => _uid;

  @override
  String? get currentUserPhoneNumber => phoneNumber;

  /// Controllable fake ID token — defaults to a recognizably-fake string
  /// derived from the current uid (never a real JWT), so a test can assert
  /// on it without this fixture actually depending on Firebase.
  String? idToken;

  @override
  Future<String?> getIdToken() async => _uid == null ? null : (idToken ?? 'fake-id-token-for-$_uid');

  @override
  Future<void> sendOtp(String phoneNumber) async {
    sendOtpCallCount++;
    if (onSendCode != null) await onSendCode!(phoneNumber);
  }

  @override
  Future<String> verifyOtp({required String phoneNumber, required String otp}) async {
    verifyOtpCallCount++;
    final uid = onVerifyOtp != null ? await onVerifyOtp!(phoneNumber, otp) : 'signed-in-uid';
    _uid = uid;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();

  /// Test-only convenience for feature tests that just need *a* signed-in
  /// transition and don't care about the OTP flow itself (e.g. cars/profile
  /// provider auth-gating tests) — not part of [AuthRepository].
  Future<void> debugSignIn(String uid) async {
    _uid = uid;
    _controller.add(uid);
  }
}

/// An in-memory [UserRepository] mirroring [FirestoreUserRepository]'s
/// documented behavior — a uid that already has a document is left
/// untouched — without needing a real (or emulated) Firestore backend.
class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.onEnsureUserDocument});

  /// Override to simulate a Firestore-side failure (throw) instead of the
  /// default successful in-memory write.
  Future<void> Function(String uid, String? phoneNumber)? onEnsureUserDocument;

  final Map<String, Map<String, Object?>> documents = {};
  int ensureUserDocumentCallCount = 0;

  @override
  Future<void> ensureUserDocument({required String uid, String? phoneNumber}) async {
    ensureUserDocumentCallCount++;
    if (onEnsureUserDocument != null) {
      await onEnsureUserDocument!(uid, phoneNumber);
      return;
    }
    if (documents.containsKey(uid)) return; // already provisioned — never overwritten
    documents[uid] = {'uid': uid, 'phoneNumber': phoneNumber, 'name': null, 'email': null, 'createdAt': DateTime.now()};
  }
}
