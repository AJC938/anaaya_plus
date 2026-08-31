// SMS-03 Phase 3 — mints a Firebase Custom Token from the SAME
// FIREBASE_SERVICE_ACCOUNT_KEY already used by `firestoreAdmin.ts` (see
// `loadServiceAccountKey`, imported below rather than duplicated — this
// module introduces no second Firebase credential). A Firebase custom
// token is a self-signed JWT; Firebase Auth's own SDK on the client
// verifies it against the service account's public key it already knows
// about for this project, so minting one requires no network call at all
// — this module never calls Firebase Auth itself (that's Flutter's job,
// via `signInWithCustomToken`).
//
// Reference: https://firebase.google.com/docs/auth/admin/create-custom-tokens
import { importPKCS8, SignJWT } from "npm:jose@^5";
import { loadServiceAccountKey } from "./firestoreAdmin.ts";

/** Firebase's own fixed audience for custom tokens — not a value this
 * project chooses, part of the custom-token contract itself. */
const CUSTOM_TOKEN_AUDIENCE =
  "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit";

/** Firebase rejects a custom token whose `exp` is more than one hour past
 * `iat` — this is the maximum, not a suggestion. Kept short (matching this
 * project's other short-lived credentials, e.g. the Firestore OAuth token
 * in `firestoreAdmin.ts`) since the token is used exactly once, seconds
 * after being minted, to call `signInWithCustomToken`. */
const CUSTOM_TOKEN_TTL_SECONDS = 60 * 60;

export interface CreateCustomTokenOptions {
  /** The target Firebase UID this token authenticates as — an existing
   * uid to restore a returning user's account, or a freshly generated one
   * for a new phone number (see `firebaseUserLookup.ts`). */
  uid: string;
  /** Optional custom claims to embed — kept minimal deliberately; this
   * project's identity model is "uid is the whole story" (see
   * `AuthRepository`'s own doc comment), so no claims are set unless a
   * caller has a real reason to. */
  claims?: Record<string, unknown>;
  /** Injectable for tests; defaults to the real system clock. */
  now?: Date;
}

/**
 * Signs and returns a Firebase custom token for `uid`. Never calls out to
 * any network — signing is entirely local, using the service-account
 * private key already loaded (and cached) by `firestoreAdmin.ts`. Never
 * logs the token, the private key, or any intermediate signing material.
 */
export async function createFirebaseCustomToken(options: CreateCustomTokenOptions): Promise<string> {
  const { uid, claims, now = new Date() } = options;
  if (!uid) throw new Error("createFirebaseCustomToken requires a non-empty uid");

  const key = loadServiceAccountKey();
  const privateKey = await importPKCS8(key.private_key, "RS256");
  const iat = Math.floor(now.getTime() / 1000);

  return await new SignJWT({ uid, ...(claims ? { claims } : {}) })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(key.client_email)
    .setSubject(key.client_email)
    .setAudience(CUSTOM_TOKEN_AUDIENCE)
    .setIssuedAt(iat)
    .setExpirationTime(iat + CUSTOM_TOKEN_TTL_SECONDS)
    .sign(privateKey);
}
