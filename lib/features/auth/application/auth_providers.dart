import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_user_repository.dart';
import '../data/user_repository.dart';
import '../domain/phone_auth_failure.dart';
import '../domain/phone_auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());

/// Provisions `users/{uid}` on sign-in — see [UserRepository]. Kept separate
/// from [authRepositoryProvider] since it's a distinct concern (Firestore,
/// not Firebase Authentication).
final userRepositoryProvider = Provider<UserRepository>((ref) => FirestoreUserRepository());

/// The single source of truth for whether the app is authenticated — the
/// router's redirect and any screen that cares about sign-in state watch
/// this, never a locally-tracked boolean. Backed directly by
/// `FirebaseAuth.authStateChanges()`, exposed as just the UID since that's
/// all this app currently needs.
final authStateChangesProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Owns the Phone Number -> OTP flow's local state. Does not itself decide
/// whether the app is "authenticated" — on a successful [verifyOtp],
/// [authStateChangesProvider] emits the new user and the router redirects
/// on its own; this controller has nothing further to do.
class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  Future<void> sendCode(String phoneNumber, {bool isResend = false}) async {
    if (state.isSending) return; // guards against duplicate submissions
    state = state.copyWith(isSending: true, phoneNumber: phoneNumber, clearFailure: true);

    final repository = ref.read(authRepositoryProvider);
    try {
      await repository.sendOtp(phoneNumber);
      state = state.copyWith(isSending: false, codeSent: true, codeSentAt: DateTime.now(), clearFailure: true);
    } on PhoneAuthFailureException catch (e) {
      state = state.copyWith(isSending: false, failure: e.failure);
    } catch (_) {
      state = state.copyWith(isSending: false, failure: PhoneAuthFailure.unknown);
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    final phoneNumber = state.phoneNumber;
    if (phoneNumber == null || !state.codeSent || state.isVerifying) return; // guards against duplicate submissions
    state = state.copyWith(isVerifying: true, clearFailure: true);

    final authRepository = ref.read(authRepositoryProvider);
    try {
      await authRepository.verifyOtp(phoneNumber: phoneNumber, otp: smsCode);
      await _ensureUserDocument(authRepository);
    } on PhoneAuthFailureException catch (e) {
      state = state.copyWith(isVerifying: false, failure: e.failure);
    } catch (_) {
      state = state.copyWith(isVerifying: false, failure: PhoneAuthFailure.unknown);
    }
  }

  /// Provisions this user's Firestore document right after a successful
  /// sign-in. Deliberately swallows every failure here: Firestore being
  /// unreachable must never undo — or even be reported as — a Firebase
  /// Authentication sign-in that already succeeded (requirement: handle
  /// Firestore failures cleanly without breaking successful auth).
  Future<void> _ensureUserDocument(AuthRepository authRepository) async {
    final uid = authRepository.currentUserUid;
    if (uid == null) return;
    try {
      await ref.read(userRepositoryProvider).ensureUserDocument(uid: uid, phoneNumber: authRepository.currentUserPhoneNumber);
    } catch (_) {
      // Best-effort — see the doc comment above.
    }
  }

  /// Resets the flow — used when the user goes back to change their number.
  void clear() => state = const PhoneAuthState();
}

final phoneAuthControllerProvider = NotifierProvider<PhoneAuthController, PhoneAuthState>(PhoneAuthController.new);
