/// Saudi mobile numbers only, matching Anaaya Plus's Saudi service area —
/// 9 digits, starting with 5 (e.g. "512345678"). A leading domestic "0" is
/// tolerated and stripped, since users commonly type "0512345678".
const String saudiCountryCode = '+966';

String normalizeSaudiLocalNumber(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digitsOnly.startsWith('0') ? digitsOnly.substring(1) : digitsOnly;
}

bool isValidSaudiLocalNumber(String input) {
  return RegExp(r'^5[0-9]{8}$').hasMatch(normalizeSaudiLocalNumber(input));
}

/// The full E.164 number Firebase's `verifyPhoneNumber` expects.
String toSaudiE164(String input) => '$saudiCountryCode${normalizeSaudiLocalNumber(input)}';
