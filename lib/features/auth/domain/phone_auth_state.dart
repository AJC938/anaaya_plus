import 'phone_auth_failure.dart';

/// State for the Phone Number -> OTP flow. Deliberately not the app's
/// authenticated-user state — that lives entirely in
/// `authStateChangesProvider`, sourced from Firebase itself. This is only
/// the local, transient state of *getting through* the flow.
class PhoneAuthState {
  const PhoneAuthState({
    this.isSending = false,
    this.isVerifying = false,
    this.phoneNumber,
    this.codeSent = false,
    this.codeSentAt,
    this.failure,
  });

  final bool isSending;
  final bool isVerifying;

  /// The full E.164 number the code was sent to — set as soon as sending
  /// starts, so it's available for both the request and the OTP screen's
  /// "code sent to ..." display.
  final String? phoneNumber;

  /// Whether `send-otp` has succeeded for the current [phoneNumber] — the
  /// backend has no session-id concept (unlike Firebase's native phone
  /// auth), so this is a plain flag rather than a derived
  /// verification-id-is-non-null check.
  final bool codeSent;

  /// When the current code was sent — drives the resend cooldown.
  final DateTime? codeSentAt;

  final PhoneAuthFailure? failure;

  PhoneAuthState copyWith({
    bool? isSending,
    bool? isVerifying,
    String? phoneNumber,
    bool? codeSent,
    DateTime? codeSentAt,
    PhoneAuthFailure? failure,
    bool clearFailure = false,
  }) {
    return PhoneAuthState(
      isSending: isSending ?? this.isSending,
      isVerifying: isVerifying ?? this.isVerifying,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      codeSent: codeSent ?? this.codeSent,
      codeSentAt: codeSentAt ?? this.codeSentAt,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
