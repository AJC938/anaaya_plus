/// Pure failure categories for the phone auth flow — no `firebase_auth`
/// import here. Every [AuthRepository] implementation maps its own
/// backend's error codes onto these, so the application layer (and its
/// tests) never has to know which backend produced a given failure.
enum PhoneAuthFailure { invalidPhoneNumber, invalidOtp, otpExpired, tooManyRequests, network, unknown }

/// Thrown by an [AuthRepository] implementation to signal a categorized,
/// user-facing phone-auth failure — the single exception type
/// `PhoneAuthController` needs to catch, regardless of which backend
/// (Firebase-native, Supabase OTP) produced it.
class PhoneAuthFailureException implements Exception {
  const PhoneAuthFailureException(this.failure);
  final PhoneAuthFailure failure;
  @override
  String toString() => 'PhoneAuthFailureException: $failure';
}

/// Maps a `FirebaseAuthException.code` string onto [PhoneAuthFailure] —
/// still relevant post-SMS-05 since `signInWithCustomToken` itself can
/// throw Firebase-side codes (`invalid-custom-token`,
/// `custom-token-mismatch`, `user-disabled`, ...). Takes a plain string
/// (not the exception itself) so this is testable without constructing a
/// real Firebase exception.
PhoneAuthFailure mapFirebaseAuthErrorCode(String code) {
  switch (code) {
    case 'invalid-phone-number':
      return PhoneAuthFailure.invalidPhoneNumber;
    case 'invalid-verification-code':
      return PhoneAuthFailure.invalidOtp;
    case 'session-expired':
    case 'invalid-verification-id':
      return PhoneAuthFailure.otpExpired;
    case 'too-many-requests':
      return PhoneAuthFailure.tooManyRequests;
    case 'network-request-failed':
      return PhoneAuthFailure.network;
    default:
      return PhoneAuthFailure.unknown;
  }
}

/// Maps a `send-otp`/`verify-otp` Edge Function safe error code (see
/// `supabase_otp_client.dart`) onto [PhoneAuthFailure].
PhoneAuthFailure mapOtpBackendErrorCode(String code) {
  switch (code) {
    case 'invalid_phone_number':
      return PhoneAuthFailure.invalidPhoneNumber;
    case 'invalid_otp':
      return PhoneAuthFailure.invalidOtp;
    case 'not_found':
    case 'expired':
      return PhoneAuthFailure.otpExpired;
    case 'too_many_attempts':
    case 'rate_limited':
    case 'resend_cooldown':
      return PhoneAuthFailure.tooManyRequests;
    case 'network_error':
      return PhoneAuthFailure.network;
    default:
      return PhoneAuthFailure.unknown;
  }
}
