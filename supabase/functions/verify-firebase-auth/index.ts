// SPG-08 — identity verification only. Firebase Authentication remains the
// application's only user-identity system; this function never creates,
// stores, or trusts any identity of its own. It exists solely to let a
// Supabase Edge Function confirm which Firebase-authenticated user is
// calling, without ever holding a Firebase secret.
//
// SPG-09: the actual JWT verification now lives in `_shared/firebaseAuth.ts`
// so `verify-moyasar-payment` can reuse the exact same logic rather than a
// second copy of it — this file's own behavior is unchanged (still 401 for
// missing/invalid/expired/wrong-project tokens, 200 + uid for a valid one).
//
// Deliberately does NOT touch Firestore, Moyasar, or any Supabase secret —
// see this project's SPG-08 task scope. Deliberately does NOT use the
// Supabase `Authorization`/`apikey` header for the Firebase token — that
// header is reserved for Supabase's own platform-level gateway auth, kept
// fully separate from the caller's Firebase identity (a dedicated
// `X-Firebase-Auth-Token` header carries that instead).
import { FIREBASE_TOKEN_HEADER, verifyFirebaseIdToken } from "../_shared/firebaseAuth.ts";

function unauthenticated(): Response {
  // Deliberately generic — never reveals *which* check failed.
  return Response.json({ ok: false, authenticated: false }, { status: 401 });
}

Deno.serve(async (req) => {
  const token = req.headers.get(FIREBASE_TOKEN_HEADER);
  const uid = await verifyFirebaseIdToken(token);
  if (!uid) return unauthenticated();
  return Response.json({ ok: true, authenticated: true, uid });
});
