// SMS-03 Phase 2 tests — an in-memory `OtpStore` fake exercises every
// decision path (creation, correct verification, wrong OTP, expiry, max
// attempts, replay, resend cooldown, rate limit) with no real Postgres
// involved. Run with:
//   deno test supabase/functions/_shared/otpStore.test.ts
import { assertEquals, assertNotEquals } from "jsr:@std/assert@^1";
import {
  generateOtp,
  hashOtp,
  MAX_ATTEMPTS,
  type OtpChallengeRow,
  type OtpStore,
  RATE_LIMIT_MAX_SENDS,
  requestOtp,
  RESEND_COOLDOWN_MS,
  verifyOtpChallenge,
} from "./otpStore.ts";

/** A plain in-memory implementation of `OtpStore` — every method mirrors
 * exactly what the real Postgres-backed store must guarantee (in
 * particular, `findActiveByPhone` never returns a consumed row). */
class FakeOtpStore implements OtpStore {
  rows: OtpChallengeRow[] = [];
  private nextId = 1;

  findActiveByPhone(phone: string): Promise<OtpChallengeRow | null> {
    const candidates = this.rows
      .filter((r) => r.phone === phone && r.consumedAt === null)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    return Promise.resolve(candidates[0] ?? null);
  }

  countCreatedSince(phone: string, sinceIso: string): Promise<number> {
    const since = new Date(sinceIso).getTime();
    return Promise.resolve(
      this.rows.filter((r) => r.phone === phone && new Date(r.createdAt).getTime() >= since).length,
    );
  }

  insert(row: Omit<OtpChallengeRow, "id">): Promise<OtpChallengeRow> {
    const full: OtpChallengeRow = { ...row, id: String(this.nextId++) };
    this.rows.push(full);
    return Promise.resolve(full);
  }

  incrementAttempts(id: string): Promise<void> {
    const row = this.rows.find((r) => r.id === id);
    if (row) row.attempts += 1;
    return Promise.resolve();
  }

  consume(id: string): Promise<void> {
    const row = this.rows.find((r) => r.id === id);
    if (row) row.consumedAt = new Date().toISOString();
    return Promise.resolve();
  }
}

const PHONE = "+966512345678";

// --- generateOtp / hashOtp (pure) ---

Deno.test("generateOtp: always 6 digits, zero-padded", () => {
  for (let i = 0; i < 50; i++) {
    const otp = generateOtp();
    assertEquals(otp.length, 6);
    assertEquals(/^[0-9]{6}$/.test(otp), true);
  }
});
Deno.test("hashOtp: same otp+salt always hashes identically", async () => {
  const a = await hashOtp("123456", "salt");
  const b = await hashOtp("123456", "salt");
  assertEquals(a, b);
});
Deno.test("hashOtp: different salts produce different hashes for the same otp", async () => {
  const a = await hashOtp("123456", "salt-a");
  const b = await hashOtp("123456", "salt-b");
  assertNotEquals(a, b);
});

// --- requestOtp (creation, cooldown, rate limit) ---

Deno.test("requestOtp: creation succeeds and stores only a hash, never the plaintext OTP", async () => {
  const store = new FakeOtpStore();
  const result = await requestOtp(store, PHONE, new Date("2026-01-01T00:00:00Z"));
  if (!result.ok) throw new Error("expected success");
  assertEquals(result.otp.length, 6);
  assertEquals(store.rows.length, 1);
  assertNotEquals(store.rows[0].otpHash, result.otp);
});

Deno.test("requestOtp: a resend before the cooldown elapses is rejected", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  await requestOtp(store, PHONE, t0);
  const result = await requestOtp(store, PHONE, new Date(t0.getTime() + RESEND_COOLDOWN_MS - 1));
  assertEquals(result, { ok: false, reason: "resend_cooldown", retryAfterMs: 1 });
});

Deno.test("requestOtp: a resend exactly at/after the cooldown succeeds", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  await requestOtp(store, PHONE, t0);
  const result = await requestOtp(store, PHONE, new Date(t0.getTime() + RESEND_COOLDOWN_MS));
  assertEquals(result.ok, true);
});

Deno.test(`requestOtp: the ${RATE_LIMIT_MAX_SENDS + 1}th send within an hour is rate-limited`, async () => {
  const store = new FakeOtpStore();
  let t = new Date("2026-01-01T00:00:00Z").getTime();
  for (let i = 0; i < RATE_LIMIT_MAX_SENDS; i++) {
    const result = await requestOtp(store, PHONE, new Date(t));
    assertEquals(result.ok, true, `send #${i + 1} should have succeeded`);
    t += RESEND_COOLDOWN_MS; // clear cooldown each time, only rate limit should trigger
  }
  const result = await requestOtp(store, PHONE, new Date(t));
  assertEquals(result, { ok: false, reason: "rate_limited" });
});

Deno.test("requestOtp: rate limit is scoped per phone number", async () => {
  const store = new FakeOtpStore();
  let t = new Date("2026-01-01T00:00:00Z").getTime();
  for (let i = 0; i < RATE_LIMIT_MAX_SENDS; i++) {
    await requestOtp(store, PHONE, new Date(t));
    t += RESEND_COOLDOWN_MS;
  }
  const otherPhone = await requestOtp(store, "+966599999999", new Date(t));
  assertEquals(otherPhone.ok, true);
});

// --- verifyOtpChallenge (correct/wrong/expiry/attempts/replay) ---

Deno.test("verifyOtpChallenge: correct OTP verifies successfully", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  const created = await requestOtp(store, PHONE, t0);
  if (!created.ok) throw new Error("setup failed");
  const result = await verifyOtpChallenge(store, PHONE, created.otp, t0);
  assertEquals(result, { ok: true });
});

Deno.test("verifyOtpChallenge: wrong OTP is rejected and increments attempts", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  await requestOtp(store, PHONE, t0);
  const result = await verifyOtpChallenge(store, PHONE, "000000", t0);
  assertEquals(result, { ok: false, reason: "invalid_otp" });
  assertEquals(store.rows[0].attempts, 1);
});

Deno.test("verifyOtpChallenge: no challenge at all is rejected as not_found", async () => {
  const store = new FakeOtpStore();
  const result = await verifyOtpChallenge(store, PHONE, "123456", new Date());
  assertEquals(result, { ok: false, reason: "not_found" });
});

Deno.test("verifyOtpChallenge: an expired challenge is rejected even with the correct OTP", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  const created = await requestOtp(store, PHONE, t0);
  if (!created.ok) throw new Error("setup failed");
  const result = await verifyOtpChallenge(store, PHONE, created.otp, new Date(t0.getTime() + 5 * 60 * 1000 + 1));
  assertEquals(result, { ok: false, reason: "expired" });
});

Deno.test("verifyOtpChallenge: exhausting max attempts blocks further tries, even with the correct OTP", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  const created = await requestOtp(store, PHONE, t0);
  if (!created.ok) throw new Error("setup failed");

  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    const result = await verifyOtpChallenge(store, PHONE, "000000", t0);
    assertEquals(result, { ok: false, reason: "invalid_otp" });
  }
  // The challenge now has MAX_ATTEMPTS recorded — even the real OTP must
  // now be rejected outright.
  const finalTry = await verifyOtpChallenge(store, PHONE, created.otp, t0);
  assertEquals(finalTry, { ok: false, reason: "too_many_attempts" });
});

Deno.test("verifyOtpChallenge: a verified OTP cannot be replayed (one-time use)", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  const created = await requestOtp(store, PHONE, t0);
  if (!created.ok) throw new Error("setup failed");

  const first = await verifyOtpChallenge(store, PHONE, created.otp, t0);
  assertEquals(first, { ok: true });

  const replay = await verifyOtpChallenge(store, PHONE, created.otp, t0);
  assertEquals(replay, { ok: false, reason: "not_found" });
});

Deno.test("verifyOtpChallenge: verification is scoped per phone number", async () => {
  const store = new FakeOtpStore();
  const t0 = new Date("2026-01-01T00:00:00Z");
  const created = await requestOtp(store, PHONE, t0);
  if (!created.ok) throw new Error("setup failed");

  const wrongPhone = await verifyOtpChallenge(store, "+966599999999", created.otp, t0);
  assertEquals(wrongPhone, { ok: false, reason: "not_found" });
});
