// Shared by verify-firebase-auth (SPG-08) and verify-moyasar-payment
// (SPG-09) — the exact same Firebase ID token verification, used by both
// rather than duplicated, per SPG-09 Phase 3's explicit "reuse the exact
// JWT verification approach from SPG-08" instruction. Firebase
// Authentication remains the application's only user-identity system; this
// module never creates, stores, or trusts any identity of its own — it
// verifies Firebase ID tokens against Google's own PUBLIC signing keys, the
// same mechanism `firebase-admin`'s `verifyIdToken` uses internally. No
// secret is involved in this half of authentication at all.
import { createRemoteJWKSet, type JWTVerifyGetKey, jwtVerify } from "npm:jose@^5";

const FIREBASE_PROJECT_ID = "anaaya-plus";
const ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;

// `createRemoteJWKSet` handles fetching, caching, and re-fetching on key
// rotation (a new `kid` it hasn't seen) automatically — deliberately not a
// hardcoded key list, so Google rotating its signing keys never breaks
// this.
const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

export const FIREBASE_TOKEN_HEADER = "X-Firebase-Auth-Token";

/**
 * The actual verification logic, parameterised over the JWKS source so
 * tests can supply a local test keypair instead of Google's real one
 * (there is no way to mint a validly-signed "real" token in a test without
 * Google's private key). `verifyFirebaseIdToken` below is the only
 * production entry point and always uses the real remote JWKS — this
 * export exists purely for `firebaseAuth.test.ts`.
 */
export async function verifyFirebaseIdTokenWithJwks(
  token: string | null,
  jwks: JWTVerifyGetKey,
): Promise<string | null> {
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, jwks, {
      issuer: ISSUER,
      audience: FIREBASE_PROJECT_ID,
      algorithms: ["RS256"],
    });
    const uid = typeof payload.sub === "string" ? payload.sub : "";
    return uid || null;
  } catch {
    return null;
  }
}

/**
 * Verifies a Firebase ID token's signature, issuer, audience, and
 * expiration against Google's public JWKS, returning the verified uid (the
 * token's `sub` claim) on success. Returns `null` for every failure mode
 * uniformly — missing, malformed, expired, wrong issuer, wrong audience,
 * bad signature, unknown `kid`, or a JWKS fetch failure — deliberately
 * never revealing which, so callers can never use this to probe token
 * validity. The verified uid is the ONLY identity a caller may use; no
 * client-supplied uid is ever accepted anywhere in this backend.
 */
export function verifyFirebaseIdToken(token: string | null): Promise<string | null> {
  return verifyFirebaseIdTokenWithJwks(token, firebaseJwks);
}
