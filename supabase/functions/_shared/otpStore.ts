// SMS-03 Phase 2 — OTP challenge state: generation, hashing, expiry,
// attempt-limiting, resend cooldown, and per-phone rate limiting. This
// module is a Supabase Postgres TABLE (see supabase/migrations for the
// schema) used ONLY as an ephemeral authentication-challenge store — never
// the application's user/vehicle/booking/payment database, which stays
// entirely in Firestore per this project's architecture.
//
// Deliberately split into (a) pure functions with zero I/O — generation,
// hashing, and the pending/verify decision logic — and (b) an `OtpStore`
// interface the orchestration functions depend on, so every decision path
// is unit-testable with an in-memory fake store, the same
// dependency-injection discipline `firestoreAdmin.ts` already established
// for this backend (there, via a mockable `fetch`; here, via a mockable
// store interface, since there's no single HTTP call to intercept).

export interface OtpChallengeRow {
  id: string;
  phone: string;
  otpHash: string;
  salt: string;
  attempts: number;
  maxAttempts: number;
  expiresAt: string; // ISO 8601
  createdAt: string; // ISO 8601
  consumedAt: string | null;
}

export interface OtpStore {
  /** The most recent NOT-YET-CONSUMED challenge for this phone, if any —
   * used both for verification and for the resend-cooldown check. A
   * consumed (already-used) challenge must never be returned here, which is
   * what makes replay of an already-verified OTP impossible even before
   * expiry. */
  findActiveByPhone(phone: string): Promise<OtpChallengeRow | null>;
  /** Count of challenges (consumed or not) created for this phone since
   * `sinceIso` — the per-phone send-rate-limit input. */
  countCreatedSince(phone: string, sinceIso: string): Promise<number>;
  insert(row: Omit<OtpChallengeRow, "id">): Promise<OtpChallengeRow>;
  incrementAttempts(id: string): Promise<void>;
  /** Marks the challenge used — must be called the instant verification
   * succeeds, before returning success to the caller, so a second request
   * with the same OTP can never succeed (one-time use / replay
   * protection). */
  consume(id: string): Promise<void>;
}

export const OTP_LENGTH = 6;
export const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
export const MAX_ATTEMPTS = 5;
export const RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
export const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
export const RATE_LIMIT_MAX_SENDS = 3;

/** Cryptographically secure, uniformly distributed 6-digit OTP (no modulo
 * bias: rejects and re-draws any value outside the largest multiple of
 * 1_000_000 that fits in a 32-bit unsigned range, rather than accepting the
 * small bias `% 1_000_000` alone would introduce). Returned zero-padded. */
export function generateOtp(): string {
  const max = Math.floor(0xffffffff / 1_000_000) * 1_000_000;
  const buffer = new Uint32Array(1);
  let value: number;
  do {
    crypto.getRandomValues(buffer);
    value = buffer[0];
  } while (value >= max);
  return (value % 1_000_000).toString().padStart(OTP_LENGTH, "0");
}

/** A fresh, cryptographically random per-challenge salt (hex-encoded). */
export function generateSalt(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** SHA-256(otp + salt), hex-encoded. The OTP itself is never stored —
 * only this hash, so a database read (or leak) never reveals a usable
 * code. */
export async function hashOtp(otp: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(`${otp}:${salt}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

export type RequestOtpResult =
  | { ok: true; otp: string; challenge: OtpChallengeRow }
  | { ok: false; reason: "resend_cooldown"; retryAfterMs: number }
  | { ok: false; reason: "rate_limited" };

/**
 * Phase 2's send-side decision: enforces the resend cooldown and the
 * per-phone hourly rate limit, then generates, hashes, and stores a fresh
 * OTP challenge. Returns the plaintext OTP exactly once, to the caller —
 * `send-otp` is the only place that may ever see it outside this function,
 * and only long enough to hand it to Twilio (or, under `OTP_TEST_MODE`,
 * back to the caller — see index.ts).
 */
export async function requestOtp(store: OtpStore, phone: string, now: Date): Promise<RequestOtpResult> {
  const active = await store.findActiveByPhone(phone);
  if (active) {
    const elapsedSinceCreated = now.getTime() - new Date(active.createdAt).getTime();
    if (elapsedSinceCreated < RESEND_COOLDOWN_MS) {
      return { ok: false, reason: "resend_cooldown", retryAfterMs: RESEND_COOLDOWN_MS - elapsedSinceCreated };
    }
  }

  const sinceIso = new Date(now.getTime() - RATE_LIMIT_WINDOW_MS).toISOString();
  const recentCount = await store.countCreatedSince(phone, sinceIso);
  if (recentCount >= RATE_LIMIT_MAX_SENDS) {
    return { ok: false, reason: "rate_limited" };
  }

  const otp = generateOtp();
  const salt = generateSalt();
  const otpHash = await hashOtp(otp, salt);
  const challenge = await store.insert({
    phone,
    otpHash,
    salt,
    attempts: 0,
    maxAttempts: MAX_ATTEMPTS,
    expiresAt: new Date(now.getTime() + OTP_TTL_MS).toISOString(),
    createdAt: now.toISOString(),
    consumedAt: null,
  });

  return { ok: true, otp, challenge };
}

export type VerifyOtpResult =
  | { ok: true }
  | { ok: false; reason: "not_found" | "expired" | "too_many_attempts" | "invalid_otp" };

/**
 * Phase 2's verify-side decision. A missing/expired/exhausted challenge is
 * rejected before ever hashing the submission, so no timing signal
 * distinguishes "no challenge" from "wrong code" beyond what's already
 * unavoidable. On a correct match the challenge is consumed immediately
 * (one-time use) before returning — a second call with the same OTP always
 * lands on `not_found` (the row is gone from `findActiveByPhone`'s view),
 * which is the replay protection.
 */
export async function verifyOtpChallenge(
  store: OtpStore,
  phone: string,
  submittedOtp: string,
  now: Date,
): Promise<VerifyOtpResult> {
  const challenge = await store.findActiveByPhone(phone);
  if (!challenge) return { ok: false, reason: "not_found" };

  if (new Date(challenge.expiresAt).getTime() <= now.getTime()) {
    return { ok: false, reason: "expired" };
  }
  if (challenge.attempts >= challenge.maxAttempts) {
    return { ok: false, reason: "too_many_attempts" };
  }

  const submittedHash = await hashOtp(submittedOtp, challenge.salt);
  if (submittedHash !== challenge.otpHash) {
    await store.incrementAttempts(challenge.id);
    return { ok: false, reason: "invalid_otp" };
  }

  await store.consume(challenge.id);
  return { ok: true };
}
