// SMS-03 Phase 4 tests — mocks `globalThis.fetch` so no real Twilio call is
// ever made. Run with:
//   deno test --allow-env supabase/functions/_shared/twilioClient.test.ts
import { assertEquals } from "jsr:@std/assert@^1";
import { sendTestSms, TWILIO_TEST_FROM_NUMBER } from "./twilioClient.ts";

const ORIGINAL_FETCH = globalThis.fetch;

function withMockFetch<T>(handler: typeof fetch, run: () => Promise<T>): Promise<T> {
  globalThis.fetch = handler as typeof fetch;
  Deno.env.set("TWILIO_TEST_ACCOUNT_SID", "ACtestFakeSidForTestsOnly");
  Deno.env.set("TWILIO_TEST_AUTH_TOKEN", "fake_test_auth_token_for_tests_only");
  return run().finally(() => {
    globalThis.fetch = ORIGINAL_FETCH;
    Deno.env.delete("TWILIO_TEST_ACCOUNT_SID");
    Deno.env.delete("TWILIO_TEST_AUTH_TOKEN");
  });
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.test("sendTestSms: sends the magic test From number, never a real one", async () => {
  const captured: { from: string | null } = { from: null };
  await withMockFetch(
    (_input, init) => {
      const params = new URLSearchParams(init?.body as string);
      captured.from = params.get("From");
      return Promise.resolve(jsonResponse({ sid: "SMtest123", status: "queued" }));
    },
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(captured.from, TWILIO_TEST_FROM_NUMBER);
});

Deno.test("sendTestSms: uses Basic auth built from the TEST credentials only", async () => {
  const captured: { auth: string | null } = { auth: null };
  await withMockFetch(
    (_input, init) => {
      captured.auth = (init?.headers as Record<string, string>)?.Authorization ?? null;
      return Promise.resolve(jsonResponse({ sid: "SMtest123", status: "queued" }));
    },
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(captured.auth, `Basic ${btoa("ACtestFakeSidForTestsOnly:fake_test_auth_token_for_tests_only")}`);
});

Deno.test("sendTestSms: a well-formed 2xx response returns ok with sid/status", async () => {
  const result = await withMockFetch(
    () => Promise.resolve(jsonResponse({ sid: "SMabc", status: "queued" })),
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(result, { ok: true, sid: "SMabc", status: "queued" });
});

Deno.test("sendTestSms: a 400 response maps to invalid_recipient", async () => {
  const result = await withMockFetch(
    () => Promise.resolve(jsonResponse({ message: "invalid" }, 400)),
    () => sendTestSms({ to: "bad-number", body: "test" }),
  );
  assertEquals(result, { ok: false, reason: "invalid_recipient" });
});

Deno.test("sendTestSms: a 5xx response maps to gateway_error", async () => {
  const result = await withMockFetch(
    () => Promise.resolve(jsonResponse({ message: "server error" }, 500)),
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(result, { ok: false, reason: "gateway_error" });
});

Deno.test("sendTestSms: a network failure maps to network_error", async () => {
  const result = await withMockFetch(
    () => Promise.reject(new TypeError("network down")),
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(result, { ok: false, reason: "network_error" });
});

Deno.test("sendTestSms: an abort maps to timeout", async () => {
  const result = await withMockFetch(
    () => Promise.reject(new DOMException("The signal has been aborted", "AbortError")),
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(result, { ok: false, reason: "timeout" });
});

Deno.test("sendTestSms: malformed JSON body maps to malformed_response", async () => {
  const result = await withMockFetch(
    () => Promise.resolve(new Response("not json", { status: 200 })),
    () => sendTestSms({ to: "+966512345678", body: "test" }),
  );
  assertEquals(result, { ok: false, reason: "malformed_response" });
});

Deno.test("sendTestSms: missing credentials maps to not_configured without making a request", async () => {
  let fetchCalled = false;
  globalThis.fetch = (() => {
    fetchCalled = true;
    return Promise.resolve(jsonResponse({ sid: "x", status: "queued" }));
  }) as typeof fetch;
  Deno.env.delete("TWILIO_TEST_ACCOUNT_SID");
  Deno.env.delete("TWILIO_TEST_AUTH_TOKEN");
  try {
    const result = await sendTestSms({ to: "+966512345678", body: "test" });
    assertEquals(result, { ok: false, reason: "not_configured" });
    assertEquals(fetchCalled, false);
  } finally {
    globalThis.fetch = ORIGINAL_FETCH;
  }
});
