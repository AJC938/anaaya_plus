// SPG-07 foundation — proves Supabase Edge Functions deployment works
// end-to-end (project link, deploy, and a remote authenticated call) before
// any Moyasar/payment-verification logic is added. Deliberately does
// nothing else: no Firebase/Firestore access, no Moyasar access, no
// secrets read. Invocation still requires Supabase's own platform-level
// apikey header (the public anon key) — that gate is enforced by the
// Supabase runtime itself, not by any logic in this file.
Deno.serve(() => {
  return Response.json({ ok: true, service: "anaaya-backend" });
});
