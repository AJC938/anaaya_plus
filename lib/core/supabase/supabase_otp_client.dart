import 'dart:convert';

import 'package:http/http.dart' as http;

/// The same Supabase project as `supabase_payment_verification_client.dart`
/// — see that file's own doc comment for why these constants are
/// safe-for-client values, never the `sb_secret_...` key.
const String _supabaseProjectUrl = 'https://ryhfbxgbsznjiutlwhpl.supabase.co';
const String _supabasePublishableKey = 'sb_publishable_C-UUHXrZz7Tr02xgmaIh7Q_XyiB7exW';

/// Thrown when `send-otp` or `verify-otp` reject a request — [error] is the
/// function's own safe error code (`invalid_phone_number`, `rate_limited`,
/// `resend_cooldown`, `not_found`, `expired`, `too_many_attempts`,
/// `invalid_otp`, `firebase_lookup_failed`, `internal_error`, or
/// `network_error` for a transport failure this client detected itself),
/// never a raw message that could leak internal detail.
class OtpRequestException implements Exception {
  const OtpRequestException(this.error);
  final String error;
  @override
  String toString() => 'OtpRequestException: $error';
}

class OtpVerificationException implements Exception {
  const OtpVerificationException(this.error);
  final String error;
  @override
  String toString() => 'OtpVerificationException: $error';
}

/// [otp] is only ever non-null when the backend's `OTP_TEST_MODE` secret is
/// `"true"` (see `send-otp/index.ts`) — this client never assumes or
/// requests that behavior, it only surfaces whatever the server actually
/// returned.
class OtpSendResult {
  const OtpSendResult({required this.testMode, this.otp});
  final bool testMode;
  final String? otp;
}

class OtpVerificationResult {
  const OtpVerificationResult({required this.customToken, required this.isNewUser});
  final String customToken;
  final bool isNewUser;
}

Map<String, dynamic>? _decodeJsonObjectOrNull(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Calls the `send-otp` Supabase Edge Function (SMS-03/04) to request a
/// one-time code for [phone]. Never stores the returned OTP itself — the
/// caller decides what, if anything, to do with a test-mode code.
Future<OtpSendResult> sendOtpWithSupabase({required String phone}) async {
  final uri = Uri.parse('$_supabaseProjectUrl/functions/v1/send-otp');
  http.Response response;
  try {
    response = await http.post(
      uri,
      headers: {'apikey': _supabasePublishableKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
  } catch (_) {
    throw const OtpRequestException('network_error');
  }

  final body = _decodeJsonObjectOrNull(response.body);
  if (response.statusCode == 200 && body?['ok'] == true) {
    return OtpSendResult(testMode: body?['testMode'] == true, otp: body?['otp'] as String?);
  }
  throw OtpRequestException((body?['error'] as String?) ?? 'request_failed');
}

/// Calls the `verify-otp` Supabase Edge Function (SMS-03/04) to submit
/// [otp] for [phone]. On success, returns the one-shot Firebase Custom
/// Token the caller must immediately exchange via
/// `FirebaseAuth.signInWithCustomToken` — this client never logs it.
Future<OtpVerificationResult> verifyOtpWithSupabase({required String phone, required String otp}) async {
  final uri = Uri.parse('$_supabaseProjectUrl/functions/v1/verify-otp');
  http.Response response;
  try {
    response = await http.post(
      uri,
      headers: {'apikey': _supabasePublishableKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
  } catch (_) {
    throw const OtpVerificationException('network_error');
  }

  final body = _decodeJsonObjectOrNull(response.body);
  final customToken = body?['customToken'] as String?;
  if (response.statusCode == 200 && body?['ok'] == true && customToken != null) {
    return OtpVerificationResult(customToken: customToken, isNewUser: body?['isNewUser'] == true);
  }
  throw OtpVerificationException((body?['error'] as String?) ?? 'request_failed');
}
