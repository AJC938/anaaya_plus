// SMS-03 Phase 6 — requests a one-time code for a Saudi phone number.
// Public (no Firebase ID token — there is no identity yet, this IS the
// authentication step), gated only by Supabase's own platform-level
// `apikey` header like every other function in this project.
//
// Input:  { phone: string }
// Output: { ok: true, testMode: boolean, otp?: string } | { ok: false, error: string }
//
// OTP_TEST_MODE — READ THIS BEFORE TOUCHING THIS FILE:
// When the Supabase secret/env var `OTP_TEST_MODE` is exactly the string
// "true", the response includes the freshly generated plaintext OTP. This
// is intentional, zero-cost-portfolio-demo-only behavior (no real SMS
// provider is configured for this project — see SMS-02) and MUST NEVER be
// enabled in a real production deployment: it defeats the entire purpose
// of sending the code over SMS at all. The OTP is still hashed, stored,
// rate-limited, expired, and attempt-limited exactly as it would be for a
// real user — only the transport (SMS vs. direct response) differs.
import { parseSaudiPhoneNumber } from "../_shared/phoneNormalization.ts";
import { requestOtp } from "../_shared/otpStore.ts";
import { SupabaseOtpStore } from "../_shared/supabaseOtpStore.ts";
import { sendTestSms } from "../_shared/twilioClient.ts";

function fail(status: number, error: string): Response {
  return Response.json({ ok: false, error }, { status });
}

function isTestMode(): boolean {
  return Deno.env.get("OTP_TEST_MODE") === "true";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_request");
  }
  if (typeof body !== "object" || body === null) return fail(400, "invalid_request");

  const { phone } = body as Record<string, unknown>;
  if (typeof phone !== "string" || !phone) return fail(400, "invalid_request");

  const normalizedPhone = parseSaudiPhoneNumber(phone);
  if (!normalizedPhone) return fail(400, "invalid_phone_number");

  const store = new SupabaseOtpStore();
  let result;
  try {
    result = await requestOtp(store, normalizedPhone, new Date());
  } catch {
    return fail(500, "internal_error");
  }

  if (!result.ok) {
    if (result.reason === "resend_cooldown") return fail(429, "resend_cooldown");
    return fail(429, "rate_limited");
  }

  const testMode = isTestMode();

  // Best-effort: this is the real integration exercise Phase 6 asks for
  // (request construction, TEST-credential auth, response handling), but a
  // Twilio-side hiccup must never block the test-mode demo path, whose
  // whole point is proving the OTP flow works even with no real SMS
  // transport configured. Outside test mode a genuine send failure IS
  // fatal — a real user with no test-mode fallback has no other way to
  // receive the code.
  const smsResult = await sendTestSms({
    to: normalizedPhone,
    body: `Your Anaaya Plus verification code is ${result.otp}`,
  });
  if (!smsResult.ok && !testMode) {
    return fail(502, "sms_send_failed");
  }

  return Response.json(testMode ? { ok: true, testMode: true, otp: result.otp } : { ok: true, testMode: false });
});
