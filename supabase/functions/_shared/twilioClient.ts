// SMS-03 Phase 4 — calls ONLY Twilio's TEST Messaging API (magic
// From/To numbers, zero cost, no real delivery — confirmed against
// Twilio's own "Test Credentials" documentation during SMS-02). Reads
// `TWILIO_TEST_ACCOUNT_SID`/`TWILIO_TEST_AUTH_TOKEN` fresh from the
// environment on every call — never logged, never included in any response
// or error. There is deliberately no "live" code path in this file at all;
// switching to a real provider later is a new module, not a flag here.
const TWILIO_API_BASE = "https://api.twilio.com/2010-04-01";
const REQUEST_TIMEOUT_MS = 10_000;

/** Twilio's own documented magic "From" number that always passes
 * validation under test credentials — never a real, reachable number. */
export const TWILIO_TEST_FROM_NUMBER = "+15005550006";

export type SendTestSmsResult =
  | { ok: true; sid: string; status: string }
  | {
      ok: false;
      reason: "not_configured" | "invalid_recipient" | "gateway_error" | "network_error" | "timeout" | "malformed_response";
    };

/**
 * Sends a message via Twilio's Messages API using TEST credentials only.
 * Under test credentials this never reaches a real phone and is never
 * billed (see SMS-02's verified findings) — it only exercises request
 * construction, authentication, and Twilio's own response handling, which
 * is this function's entire purpose. `to` should be the real destination
 * phone number being tested (Twilio's test mode validates its shape but
 * never delivers to it).
 */
export async function sendTestSms(params: { to: string; body: string }): Promise<SendTestSmsResult> {
  const accountSid = Deno.env.get("TWILIO_TEST_ACCOUNT_SID");
  const authToken = Deno.env.get("TWILIO_TEST_AUTH_TOKEN");
  if (!accountSid || !authToken) return { ok: false, reason: "not_configured" };

  const basicAuth = btoa(`${accountSid}:${authToken}`);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(`${TWILIO_API_BASE}/Accounts/${accountSid}/Messages.json`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${basicAuth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ From: TWILIO_TEST_FROM_NUMBER, To: params.to, Body: params.body }),
      signal: controller.signal,
    });
  } catch (error) {
    const isAbort = error instanceof DOMException && error.name === "AbortError";
    return { ok: false, reason: isAbort ? "timeout" : "network_error" };
  } finally {
    clearTimeout(timeoutId);
  }

  if (response.status === 400) return { ok: false, reason: "invalid_recipient" };
  if (response.status >= 400) return { ok: false, reason: "gateway_error" };

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { ok: false, reason: "malformed_response" };
  }

  if (typeof body !== "object" || body === null) return { ok: false, reason: "malformed_response" };
  const record = body as Record<string, unknown>;
  if (typeof record.sid !== "string" || typeof record.status !== "string") {
    return { ok: false, reason: "malformed_response" };
  }

  return { ok: true, sid: record.sid, status: record.status };
}
