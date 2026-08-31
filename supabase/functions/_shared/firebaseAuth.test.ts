// SPG-09 Phase 16 category A — Firebase ID token verification.
//
// A real "valid token" test can't be built against Google's own JWKS
// without Google's private signing key (which nobody but Google has), so
// this suite generates its OWN RSA test keypair and exercises
// `verifyFirebaseIdTokenWithJwks` directly against a local JWKS built from
// it — this is the exact same `jwtVerify` call path production code uses
// (`verifyFirebaseIdToken`), just pointed at a key this test controls
// instead of the real remote one. Run with:
//   deno test --allow-net supabase/functions/_shared/firebaseAuth.test.ts
// (`--allow-net` is required only because `jose`'s JWKS type loads via a
// dynamic import the first time; no network call is actually made for a
// local JWK.)
import { assertEquals } from "jsr:@std/assert@^1";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from "npm:jose@^5";
import { verifyFirebaseIdTokenWithJwks } from "./firebaseAuth.ts";

const FIREBASE_PROJECT_ID = "anaaya-plus";
const ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const KID = "test-key-1";

type TestPrivateKey = Awaited<ReturnType<typeof generateKeyPair>>["privateKey"];

async function buildTestJwks() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const publicJwk = await exportJWK(publicKey);
  publicJwk.kid = KID;
  publicJwk.alg = "RS256";
  const jwks = createLocalJWKSet({ keys: [publicJwk] });
  return { privateKey, jwks };
}

interface TokenOverrides {
  issuer?: string;
  audience?: string;
  subject?: string;
  expiresInSeconds?: number;
  privateKey?: TestPrivateKey;
}

async function signTestToken(
  privateKey: TestPrivateKey,
  overrides: TokenOverrides = {},
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: KID })
    .setIssuer(overrides.issuer ?? ISSUER)
    .setAudience(overrides.audience ?? FIREBASE_PROJECT_ID)
    .setSubject(overrides.subject ?? "test-uid-123")
    .setIssuedAt(now)
    .setExpirationTime(now + (overrides.expiresInSeconds ?? 3600))
    .sign(overrides.privateKey ?? privateKey);
}

Deno.test("firebaseAuth: valid token returns the uid", async () => {
  const { privateKey, jwks } = await buildTestJwks();
  const token = await signTestToken(privateKey);
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, "test-uid-123");
});

Deno.test("firebaseAuth: missing token returns null", async () => {
  const { jwks } = await buildTestJwks();
  const uid = await verifyFirebaseIdTokenWithJwks(null, jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: malformed token returns null", async () => {
  const { jwks } = await buildTestJwks();
  const uid = await verifyFirebaseIdTokenWithJwks("not-a-real-jwt", jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: wrong issuer is rejected", async () => {
  const { privateKey, jwks } = await buildTestJwks();
  const token = await signTestToken(privateKey, { issuer: "https://securetoken.google.com/some-other-project" });
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: wrong audience is rejected", async () => {
  const { privateKey, jwks } = await buildTestJwks();
  const token = await signTestToken(privateKey, { audience: "some-other-project" });
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: expired token is rejected", async () => {
  const { privateKey, jwks } = await buildTestJwks();
  const token = await signTestToken(privateKey, { expiresInSeconds: -60 });
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: token signed by a different key is rejected (bad signature)", async () => {
  const { jwks } = await buildTestJwks();
  const { privateKey: otherPrivateKey } = await generateKeyPair("RS256");
  const token = await signTestToken(otherPrivateKey);
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, null);
});

Deno.test("firebaseAuth: missing subject claim is rejected", async () => {
  const { privateKey, jwks } = await buildTestJwks();
  const now = Math.floor(Date.now() / 1000);
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: KID })
    .setIssuer(ISSUER)
    .setAudience(FIREBASE_PROJECT_ID)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);
  const uid = await verifyFirebaseIdTokenWithJwks(token, jwks);
  assertEquals(uid, null);
});
