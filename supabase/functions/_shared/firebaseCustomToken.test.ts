// SMS-03 Phase 3 tests — verifies the minted token's structure (claims,
// issuer, subject, audience, expiry) AND that it's genuinely
// signature-valid against the test service account's own public key, using
// a real (but freshly generated, test-only) RSA keypair — the same pattern
// `firestoreAdmin.test.ts` already established for exercising the real
// `importPKCS8`/`SignJWT` code path unmodified.
//
// `loadServiceAccountKey` (in firestoreAdmin.ts) caches the parsed key for
// the lifetime of the module, so the FIRST test in this file to trigger a
// real parse fixes which keypair every subsequent test's token is signed
// with — `setFakeServiceAccount` is therefore called once, at module load,
// not per-test, and every test in this file signs against `KEY_PAIR`.
//
// Run with:
//   deno test --allow-env supabase/functions/_shared/firebaseCustomToken.test.ts
import { assertEquals, assertRejects } from "jsr:@std/assert@^1";
import { exportPKCS8, generateKeyPair, jwtVerify } from "npm:jose@^5";
import { createFirebaseCustomToken } from "./firebaseCustomToken.ts";

const TEST_EMAIL = "test-sa@anaaya-plus.iam.gserviceaccount.com";
const KEY_PAIR = await generateKeyPair("RS256", { extractable: true });
Deno.env.set(
  "FIREBASE_SERVICE_ACCOUNT_KEY",
  btoa(JSON.stringify({ client_email: TEST_EMAIL, private_key: await exportPKCS8(KEY_PAIR.privateKey) })),
);

function decodePayload(token: string): Record<string, unknown> {
  return JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
}

Deno.test("createFirebaseCustomToken: mints a structurally valid token with the expected claims", async () => {
  const now = new Date("2026-01-01T00:00:00Z");
  const token = await createFirebaseCustomToken({ uid: "uid-123", now });

  assertEquals(token.split(".").length, 3, "a JWT has three dot-separated parts");

  const payload = decodePayload(token);
  assertEquals(payload.uid, "uid-123");
  assertEquals(payload.iss, TEST_EMAIL);
  assertEquals(payload.sub, TEST_EMAIL);
  assertEquals(payload.aud, "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit");
  assertEquals(payload.iat, Math.floor(now.getTime() / 1000));
  assertEquals(payload.exp, Math.floor(now.getTime() / 1000) + 3600);
});

Deno.test("createFirebaseCustomToken: the signature genuinely verifies against the service account's own public key", async () => {
  const token = await createFirebaseCustomToken({ uid: "uid-verify-me" });
  const { payload } = await jwtVerify(token, KEY_PAIR.publicKey);
  assertEquals(payload.uid, "uid-verify-me");
});

Deno.test("createFirebaseCustomToken: expiry is exactly one hour after issued-at (Firebase's own maximum)", async () => {
  const now = new Date("2026-06-15T12:00:00Z");
  const token = await createFirebaseCustomToken({ uid: "uid-abc", now });
  const payload = decodePayload(token);
  assertEquals((payload.exp as number) - (payload.iat as number), 3600);
});

Deno.test("createFirebaseCustomToken: optional custom claims are embedded under `claims`", async () => {
  const token = await createFirebaseCustomToken({ uid: "uid-xyz", claims: { isNewUser: true } });
  assertEquals(decodePayload(token).claims, { isNewUser: true });
});

Deno.test("createFirebaseCustomToken: omitting claims entirely omits the field, never an empty object", async () => {
  const token = await createFirebaseCustomToken({ uid: "uid-xyz" });
  assertEquals("claims" in decodePayload(token), false);
});

Deno.test("createFirebaseCustomToken: an empty uid is rejected", async () => {
  await assertRejects(() => createFirebaseCustomToken({ uid: "" }));
});
