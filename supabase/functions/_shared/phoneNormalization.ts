// SMS-03 Phase 1 — a direct TypeScript port of
// lib/features/auth/domain/phone_number_validation.dart, kept deliberately
// in lockstep with that file rather than reinventing the rules server-side
// (the same "one map, both sides validated against it" discipline already
// used for payment_status_transition.dart / paymentLogic.ts). The Dart
// implementation is NOT modified by this phase.
//
// Saudi mobile numbers only — 9 digits, starting with 5 (e.g.
// "512345678"). A leading domestic "0" is tolerated and stripped, since
// users commonly type "0512345678".
export const SAUDI_COUNTRY_CODE = "+966";

export function normalizeSaudiLocalNumber(input: string): string {
  const digitsOnly = input.replace(/[^0-9]/g, "");
  return digitsOnly.startsWith("0") ? digitsOnly.slice(1) : digitsOnly;
}

export function isValidSaudiLocalNumber(input: string): boolean {
  return /^5[0-9]{8}$/.test(normalizeSaudiLocalNumber(input));
}

/** The full E.164 number this backend stores/keys OTP challenges by. */
export function toSaudiE164(input: string): string {
  return `${SAUDI_COUNTRY_CODE}${normalizeSaudiLocalNumber(input)}`;
}

/**
 * Accepts either a raw local number (any of the tolerated input shapes) or
 * an already-E.164 `+9665XXXXXXXX` string (e.g. a client that already
 * normalized it) and returns the canonical E.164 form, or `null` if the
 * input is not a valid Saudi mobile number in either shape. This is the
 * single entry point `send-otp`/`verify-otp` should call rather than
 * assuming which shape a given request body will carry.
 */
export function parseSaudiPhoneNumber(input: string): string | null {
  const trimmed = input.trim();
  if (trimmed.startsWith(SAUDI_COUNTRY_CODE)) {
    const local = trimmed.slice(SAUDI_COUNTRY_CODE.length);
    return isValidSaudiLocalNumber(local) ? toSaudiE164(local) : null;
  }
  return isValidSaudiLocalNumber(trimmed) ? toSaudiE164(trimmed) : null;
}
