import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/domain/phone_auth_failure.dart';

void main() {
  group('mapFirebaseAuthErrorCode', () {
    test('invalid-phone-number maps to invalidPhoneNumber', () {
      expect(mapFirebaseAuthErrorCode('invalid-phone-number'), PhoneAuthFailure.invalidPhoneNumber);
    });

    test('invalid-verification-code maps to invalidOtp', () {
      expect(mapFirebaseAuthErrorCode('invalid-verification-code'), PhoneAuthFailure.invalidOtp);
    });

    test('session-expired maps to otpExpired', () {
      expect(mapFirebaseAuthErrorCode('session-expired'), PhoneAuthFailure.otpExpired);
    });

    test('invalid-verification-id also maps to otpExpired', () {
      expect(mapFirebaseAuthErrorCode('invalid-verification-id'), PhoneAuthFailure.otpExpired);
    });

    test('too-many-requests maps to tooManyRequests', () {
      expect(mapFirebaseAuthErrorCode('too-many-requests'), PhoneAuthFailure.tooManyRequests);
    });

    test('network-request-failed maps to network', () {
      expect(mapFirebaseAuthErrorCode('network-request-failed'), PhoneAuthFailure.network);
    });

    test('an unrecognized code falls back to unknown', () {
      expect(mapFirebaseAuthErrorCode('quota-exceeded'), PhoneAuthFailure.unknown);
    });
  });

  group('mapOtpBackendErrorCode', () {
    test('invalid_phone_number maps to invalidPhoneNumber', () {
      expect(mapOtpBackendErrorCode('invalid_phone_number'), PhoneAuthFailure.invalidPhoneNumber);
    });

    test('invalid_otp maps to invalidOtp', () {
      expect(mapOtpBackendErrorCode('invalid_otp'), PhoneAuthFailure.invalidOtp);
    });

    test('not_found maps to otpExpired', () {
      expect(mapOtpBackendErrorCode('not_found'), PhoneAuthFailure.otpExpired);
    });

    test('expired maps to otpExpired', () {
      expect(mapOtpBackendErrorCode('expired'), PhoneAuthFailure.otpExpired);
    });

    test('too_many_attempts maps to tooManyRequests', () {
      expect(mapOtpBackendErrorCode('too_many_attempts'), PhoneAuthFailure.tooManyRequests);
    });

    test('rate_limited maps to tooManyRequests', () {
      expect(mapOtpBackendErrorCode('rate_limited'), PhoneAuthFailure.tooManyRequests);
    });

    test('resend_cooldown maps to tooManyRequests', () {
      expect(mapOtpBackendErrorCode('resend_cooldown'), PhoneAuthFailure.tooManyRequests);
    });

    test('network_error maps to network', () {
      expect(mapOtpBackendErrorCode('network_error'), PhoneAuthFailure.network);
    });

    test('an unrecognized code falls back to unknown', () {
      expect(mapOtpBackendErrorCode('firebase_lookup_failed'), PhoneAuthFailure.unknown);
    });
  });
}
