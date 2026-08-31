// SMS-03 Phase 8 — resolves the Firebase UID for a verified phone number:
// reuse an existing user's uid if one already has this phone number
// attached, or create a new Firebase Auth user (with the phone number set)
// otherwise. This is what makes "existing user -> same account,
// new user -> exactly one new account" possible at all, since a
// custom-token sign-in is keyed purely by whatever uid we pass it — there
// is no Firebase-native "look up by phone" for custom-token-created users
// unless their phoneNumber is explicitly set on the account, which this
// module does at creation time specifically so this lookup works on every
// later sign-in.
//
// Uses the SAME `FIREBASE_SERVICE_ACCOUNT_KEY` as `firestoreAdmin.ts` (via
// the shared `loadServiceAccountKey`) — no second credential — but mints
// its own access token under the Identity Platform scope, since Firestore
// and Identity Platform are different Google APIs with different scopes
// and a token minted for one is not valid for the other.
import { importPKCS8, SignJWT } from "npm:jose@^5";
import { loadServiceAccountKey } from "./firestoreAdmin.ts";

const FIREBASE_PROJECT_ID = "anaaya-plus";
const IDENTITY_TOOLKIT_BASE = `https://identitytoolkit.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/accounts`;
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const IDENTITY_TOOLKIT_SCOPE = "https://www.googleapis.com/auth/identitytoolkit";

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getIdentityPlatformAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.token;

  const key = loadServiceAccountKey();
  const privateKey = await importPKCS8(key.private_key, "RS256");
  const assertion = await new SignJWT({ scope: IDENTITY_TOOLKIT_SCOPE })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(key.client_email)
    .setSubject(key.client_email)
    .setAudience(TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!response.ok) throw new Error("failed to mint Identity Platform access token");
  const body = (await response.json()) as { access_token: string; expires_in: number };
  cachedToken = { token: body.access_token, expiresAt: now + body.expires_in };
  return body.access_token;
}

/** Looks up an existing Firebase Auth user by E.164 phone number. Returns
 * `null` if no user has this phone number attached — never throws for
 * "not found", only for a genuine transport/auth failure. */
export async function findUidByPhoneNumber(phoneE164: string): Promise<string | null> {
  const token = await getIdentityPlatformAccessToken();
  const response = await fetch(`${IDENTITY_TOOLKIT_BASE}:lookup`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ phoneNumber: [phoneE164] }),
  });
  if (!response.ok) throw new Error(`Identity Platform lookup failed with status ${response.status}`);
  const body = (await response.json()) as { users?: Array<{ localId: string }> };
  return body.users?.[0]?.localId ?? null;
}

/** Creates a new Firebase Auth user with `phoneE164` already attached, so
 * every future `findUidByPhoneNumber` call for this same number resolves
 * back to this exact uid — this is the entire mechanism preventing
 * duplicate accounts across sign-ins. Returns the newly assigned uid. */
export async function createUserWithPhoneNumber(phoneE164: string): Promise<string> {
  const token = await getIdentityPlatformAccessToken();
  const response = await fetch(IDENTITY_TOOLKIT_BASE, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ phoneNumber: phoneE164 }),
  });
  if (!response.ok) throw new Error(`Identity Platform user creation failed with status ${response.status}`);
  const body = (await response.json()) as { localId: string };
  return body.localId;
}

export interface ResolvedFirebaseUser {
  uid: string;
  isNewUser: boolean;
}

/**
 * The single entry point `verify-otp` calls after a successful OTP check:
 * resolves to the existing uid for a returning phone number, or creates
 * exactly one new Firebase Auth user for a phone number seen for the
 * first time. Never creates a second user for a phone that already has
 * one — the create path only runs when the lookup above found nothing.
 */
export async function resolveFirebaseUidForPhone(phoneE164: string): Promise<ResolvedFirebaseUser> {
  const existingUid = await findUidByPhoneNumber(phoneE164);
  if (existingUid) return { uid: existingUid, isNewUser: false };

  const newUid = await createUserWithPhoneNumber(phoneE164);
  return { uid: newUid, isNewUser: true };
}
