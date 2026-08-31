// Service-account-backed credential loading — used by the SMS-03/04 Firebase
// Custom Token flow (`firebaseCustomToken.ts`, `firebaseUserLookup.ts`) to
// mint OAuth2 access tokens for Google APIs via the standard service-account
// JWT-bearer flow (the same mechanism the Firebase Admin SDK uses
// internally). There is no `firebase-admin` package available for Deno, so
// this is the standard alternative for a Deno edge runtime.
//
// The service-account key is read via `Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')`
// only, exactly once per isolate (cached in memory), base64-decoded, and
// NEVER logged, returned, or included in any error message or response body.

export interface ServiceAccountKey {
  client_email: string;
  private_key: string;
}

let cachedKey: ServiceAccountKey | null = null;

/**
 * `Deno.env.get` values can carry whitespace (leading/trailing OR embedded
 * — e.g. a line-wrapped base64 blob, or a trailing newline from how the
 * secret was originally captured/piped when it was set) or use the
 * URL-safe base64 alphabet. Browsers' `atob` is "forgiving" and strips
 * whitespace from anywhere in the string per the WHATWG infra spec; Deno's
 * `atob` is stricter and rejects any of that outright with a generic
 * "Failed to decode base64" error. This strips ALL whitespace
 * unconditionally (never a mutation that could corrupt genuine base64 data
 * — real base64 never carries whitespace as meaningful content), then
 * restores the standard alphabet and padding. Never logs or returns the
 * input or output.
 */
export function normalizeBase64(value: string): string {
  const noWhitespace = value.replace(/\s+/g, "");
  const standardAlphabet = noWhitespace.replace(/-/g, "+").replace(/_/g, "/");
  const paddingNeeded = (4 - (standardAlphabet.length % 4)) % 4;
  return standardAlphabet + "=".repeat(paddingNeeded);
}

/**
 * SMS-03: exported so `firebaseCustomToken.ts` and `firebaseUserLookup.ts`
 * can each mint their own scoped OAuth2 access token from the exact same
 * service-account credential — one cached parse, one source of truth for
 * the base64/whitespace handling above.
 */
export function loadServiceAccountKey(): ServiceAccountKey {
  if (cachedKey) return cachedKey;
  const encoded = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
  if (!encoded) throw new Error("FIREBASE_SERVICE_ACCOUNT_KEY is not configured");
  const json = atob(normalizeBase64(encoded));
  const parsed = JSON.parse(json) as ServiceAccountKey;
  cachedKey = parsed;
  return parsed;
}
