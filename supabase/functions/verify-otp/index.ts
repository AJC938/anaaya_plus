// SMS-03 Phase 7 — verifies a one-time code and, on success, mints a
// Firebase Custom Token for the resolved uid. Public (no Firebase ID
// token — same reasoning as send-otp: this IS the authentication step).
//
// Input:  { phone: string, otp: string }
// Output: { ok: true, customToken: string, isNewUser: boolean } | { ok: false, error: string }
//
// Never returns any Firebase credential other than the one-shot custom
// token the caller explicitly asked for by submitting a correct OTP —
// never the service-account key, never a raw access token, never logs the
// custom token itself.
import { parseSaudiPhoneNumber } from "../_shared/phoneNormalization.ts";
import { verifyOtpChallenge } from "../_shared/otpStore.ts";
import { SupabaseOtpStore } from "../_shared/supabaseOtpStore.ts";
import { resolveFirebaseUidForPhone } from "../_shared/firebaseUserLookup.ts";
import { createFirebaseCustomToken } from "../_shared/firebaseCustomToken.ts";

function fail(status: number, error: string): Response {
  return Response.json({ ok: false, error }, { status });
}

const VERIFY_FAILURE_STATUS: Record<string, number> = {
  not_found: 404,
  expired: 410,
  too_many_attempts: 429,
  invalid_otp: 401,
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_request");
  }
  if (typeof body !== "object" || body === null) return fail(400, "invalid_request");

  const { phone, otp } = body as Record<string, unknown>;
  if (typeof phone !== "string" || !phone || typeof otp !== "string" || !otp) {
    return fail(400, "invalid_request");
  }

  const normalizedPhone = parseSaudiPhoneNumber(phone);
  if (!normalizedPhone) return fail(400, "invalid_phone_number");

  const store = new SupabaseOtpStore();
  let verifyResult;
  try {
    verifyResult = await verifyOtpChallenge(store, normalizedPhone, otp, new Date());
  } catch {
    return fail(500, "internal_error");
  }

  if (!verifyResult.ok) {
    return fail(VERIFY_FAILURE_STATUS[verifyResult.reason] ?? 400, verifyResult.reason);
  }

  // The OTP is now consumed (one-time use) regardless of what happens
  // below — a Firebase-side failure past this point must never allow a
  // second attempt to replay the same already-verified code.
  let uid: string;
  let isNewUser: boolean;
  try {
    const resolved = await resolveFirebaseUidForPhone(normalizedPhone);
    uid = resolved.uid;
    isNewUser = resolved.isNewUser;
  } catch {
    return fail(502, "firebase_lookup_failed");
  }

  let customToken: string;
  try {
    customToken = await createFirebaseCustomToken({ uid });
  } catch {
    return fail(500, "internal_error");
  }

  return Response.json({ ok: true, customToken, isNewUser });
});
