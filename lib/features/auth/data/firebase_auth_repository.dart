import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/supabase/supabase_otp_client.dart';
import '../domain/phone_auth_failure.dart';
import 'auth_repository.dart';

/// Real implementation. Firebase Auth remains the only source of the app's
/// signed-in session (`authStateChanges`, `currentUserUid`, `getIdToken`,
/// `signOut`) — but as of SMS-05, the phone-login flow itself no longer
/// uses Firebase's native `verifyPhoneNumber`/`signInWithCredential`. It
/// goes through the SMS-01–04 backend instead: `send-otp` (Supabase +
/// Twilio TEST credentials) and `verify-otp` (Supabase, returns a Firebase
/// Custom Token), then `FirebaseAuth.signInWithCustomToken` to actually
/// establish the session. See `supabase_otp_client.dart` for the HTTP
/// layer this class delegates to.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<String?> authStateChanges() => _firebaseAuth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserUid => _firebaseAuth.currentUser?.uid;

  @override
  String? get currentUserPhoneNumber => _firebaseAuth.currentUser?.phoneNumber;

  /// Delegates entirely to the Firebase SDK's own token management — never
  /// logged, never persisted, never exposes the refresh token (the public
  /// `User` API has no accessor for that at all). Returns `null` for a
  /// signed-out user rather than throwing, matching every other getter on
  /// this class.
  @override
  Future<String?> getIdToken() => _firebaseAuth.currentUser?.getIdToken() ?? Future.value(null);

  @override
  Future<void> sendOtp(String phoneNumber) async {
    OtpSendResult result;
    try {
      result = await sendOtpWithSupabase(phone: phoneNumber);
    } on OtpRequestException catch (e) {
      throw PhoneAuthFailureException(mapOtpBackendErrorCode(e.error));
    }

    // Only ever non-null when the backend's own `OTP_TEST_MODE` secret is
    // "true" — `send-otp` decides this server-side, never this client (see
    // `supabase_otp_client.dart`'s doc comment). Logging it here is exactly
    // as safe as the backend already made it by choosing to return it at
    // all; it is NEVER the customToken, the Firebase ID token, or any
    // credential/secret.
    if (result.testMode && result.otp != null) {
      debugPrint('ANAAYA_OTP_TEST_MODE otp=${result.otp}');
    }
  }

  @override
  Future<String> verifyOtp({required String phoneNumber, required String otp}) async {
    OtpVerificationResult result;
    try {
      result = await verifyOtpWithSupabase(phone: phoneNumber, otp: otp);
    } on OtpVerificationException catch (e) {
      throw PhoneAuthFailureException(mapOtpBackendErrorCode(e.error));
    }

    final UserCredential credential;
    try {
      credential = await _firebaseAuth.signInWithCustomToken(result.customToken);
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthFailureException(mapFirebaseAuthErrorCode(e.code));
    }

    final uid = credential.user?.uid;
    if (uid == null) throw const PhoneAuthFailureException(PhoneAuthFailure.unknown);

    // Safe to log — a uid and a boolean, never a token or secret.
    debugPrint('ANAAYA_AUTH_RESULT uid=$uid isNewUser=${result.isNewUser}');
    return uid;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}
