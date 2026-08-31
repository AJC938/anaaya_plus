// SMS-03 Phase 1 tests — mirrors the exact cases the Dart original's own
// test suite covers, so the two implementations can be visually diffed for
// drift. Run with:
//   deno test supabase/functions/_shared/phoneNormalization.test.ts
import { assertEquals } from "jsr:@std/assert@^1";
import {
  isValidSaudiLocalNumber,
  normalizeSaudiLocalNumber,
  parseSaudiPhoneNumber,
  toSaudiE164,
} from "./phoneNormalization.ts";

Deno.test("normalizeSaudiLocalNumber: strips a leading domestic 0", () => {
  assertEquals(normalizeSaudiLocalNumber("0512345678"), "512345678");
});
Deno.test("normalizeSaudiLocalNumber: leaves a number with no leading 0 unchanged", () => {
  assertEquals(normalizeSaudiLocalNumber("512345678"), "512345678");
});
Deno.test("normalizeSaudiLocalNumber: strips non-digit characters (spaces, dashes)", () => {
  assertEquals(normalizeSaudiLocalNumber("05 123 45-678"), "512345678");
});

Deno.test("isValidSaudiLocalNumber: a valid 9-digit number starting with 5", () => {
  assertEquals(isValidSaudiLocalNumber("512345678"), true);
});
Deno.test("isValidSaudiLocalNumber: valid with a leading 0 tolerated", () => {
  assertEquals(isValidSaudiLocalNumber("0512345678"), true);
});
Deno.test("isValidSaudiLocalNumber: rejects a number not starting with 5", () => {
  assertEquals(isValidSaudiLocalNumber("412345678"), false);
});
Deno.test("isValidSaudiLocalNumber: rejects too few digits", () => {
  assertEquals(isValidSaudiLocalNumber("51234567"), false);
});
Deno.test("isValidSaudiLocalNumber: rejects too many digits", () => {
  assertEquals(isValidSaudiLocalNumber("5123456789"), false);
});
Deno.test("isValidSaudiLocalNumber: rejects empty input", () => {
  assertEquals(isValidSaudiLocalNumber(""), false);
});
Deno.test("isValidSaudiLocalNumber: rejects non-numeric input", () => {
  assertEquals(isValidSaudiLocalNumber("abcdefghi"), false);
});

Deno.test("toSaudiE164: produces the canonical +9665XXXXXXXX form", () => {
  assertEquals(toSaudiE164("512345678"), "+966512345678");
});
Deno.test("toSaudiE164: normalizes a leading-0 input first", () => {
  assertEquals(toSaudiE164("0512345678"), "+966512345678");
});

Deno.test("parseSaudiPhoneNumber: accepts a raw local number", () => {
  assertEquals(parseSaudiPhoneNumber("512345678"), "+966512345678");
});
Deno.test("parseSaudiPhoneNumber: accepts a leading-0 local number", () => {
  assertEquals(parseSaudiPhoneNumber("0512345678"), "+966512345678");
});
Deno.test("parseSaudiPhoneNumber: accepts an already-E.164 number", () => {
  assertEquals(parseSaudiPhoneNumber("+966512345678"), "+966512345678");
});
Deno.test("parseSaudiPhoneNumber: rejects an invalid E.164-shaped number", () => {
  assertEquals(parseSaudiPhoneNumber("+966412345678"), null);
});
Deno.test("parseSaudiPhoneNumber: rejects a non-Saudi E.164 number", () => {
  assertEquals(parseSaudiPhoneNumber("+15005550006"), null);
});
Deno.test("parseSaudiPhoneNumber: rejects garbage input", () => {
  assertEquals(parseSaudiPhoneNumber("not a phone number"), null);
});
Deno.test("parseSaudiPhoneNumber: rejects empty input", () => {
  assertEquals(parseSaudiPhoneNumber(""), null);
});
