import '../../../../core/localization/app_localizations.dart';
import '../../domain/phone_auth_failure.dart';

/// Maps a [PhoneAuthFailure] to its localized message — shared by the Phone
/// Number and OTP screens, the two places a Firebase-originated failure is
/// ever shown.
String phoneAuthFailureMessage(PhoneAuthFailure failure, AppLocalizations l10n) {
  return switch (failure) {
    PhoneAuthFailure.invalidPhoneNumber => l10n.invalidPhoneNumberError,
    PhoneAuthFailure.invalidOtp => l10n.invalidOtpError,
    PhoneAuthFailure.otpExpired => l10n.otpExpiredError,
    PhoneAuthFailure.tooManyRequests => l10n.tooManyRequestsError,
    PhoneAuthFailure.network => l10n.authNetworkErrorMessage,
    PhoneAuthFailure.unknown => l10n.authUnknownErrorMessage,
  };
}
