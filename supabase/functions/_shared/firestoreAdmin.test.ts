// Regression coverage for `normalizeBase64` — a real deployed SMS-03/04
// function once failed with "Failed to decode base64" because
// `Deno.env.get` returned the secret with a trailing newline (from how it
// was originally captured/piped when set). Run with:
//   deno test --allow-env supabase/functions/_shared/firestoreAdmin.test.ts
import { assertEquals } from "jsr:@std/assert@^1";
import { normalizeBase64 } from "./firestoreAdmin.ts";

Deno.test("normalizeBase64: already-clean base64 decodes unchanged", () => {
  const clean = btoa(JSON.stringify({ a: 1 }));
  assertEquals(JSON.parse(atob(normalizeBase64(clean))), { a: 1 });
});
Deno.test("normalizeBase64: a trailing newline (the real observed bug) is tolerated", () => {
  const clean = btoa(JSON.stringify({ a: 1 }));
  assertEquals(JSON.parse(atob(normalizeBase64(`${clean}\n`))), { a: 1 });
});
Deno.test("normalizeBase64: leading/trailing whitespace is tolerated", () => {
  const clean = btoa(JSON.stringify({ a: 1 }));
  assertEquals(JSON.parse(atob(normalizeBase64(`  ${clean}  `))), { a: 1 });
});
Deno.test("normalizeBase64: URL-safe alphabet (-/_) is converted back to standard (+//)", () => {
  const clean = btoa(JSON.stringify({ needsPlusAndSlash: "??>>" }));
  const urlSafe = clean.replace(/\+/g, "-").replace(/\//g, "_");
  assertEquals(JSON.parse(atob(normalizeBase64(urlSafe))), { needsPlusAndSlash: "??>>" });
});
Deno.test("normalizeBase64: missing padding is restored", () => {
  const clean = btoa(JSON.stringify({ a: 1 }));
  const unpadded = clean.replace(/=+$/, "");
  assertEquals(JSON.parse(atob(normalizeBase64(unpadded))), { a: 1 });
});
// Second root-cause regression: the FIRST normalizeBase64 (edges-only
// .trim()) was deployed and still failed against the real secret with the
// exact same "Failed to decode base64" error. The real value carries
// whitespace embedded *inside* the string (e.g. a line-wrapped blob), not
// just at the edges, which `.trim()` never touches. This is the case that
// actually mattered.
Deno.test("normalizeBase64: embedded/internal whitespace (line wrapping) is stripped, not just the edges", () => {
  const clean = btoa(JSON.stringify({ client_email: "x@y.iam.gserviceaccount.com", note: "long value" }));
  const wrapped = clean.match(/.{1,20}/g)!.join("\n"); // simulate a line-wrapped base64 blob
  assertEquals(
    JSON.parse(atob(normalizeBase64(wrapped))),
    { client_email: "x@y.iam.gserviceaccount.com", note: "long value" },
  );
});
Deno.test("normalizeBase64: all real-world variations combined (whitespace + URL-safe + missing padding)", () => {
  const clean = btoa(JSON.stringify({ client_email: "x@y.iam.gserviceaccount.com" }));
  const urlSafeUnpadded = clean.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const dirty = `${urlSafeUnpadded.slice(0, 10)}\n${urlSafeUnpadded.slice(10)}\n`;
  assertEquals(JSON.parse(atob(normalizeBase64(dirty))), { client_email: "x@y.iam.gserviceaccount.com" });
});
