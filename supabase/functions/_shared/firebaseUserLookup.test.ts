// SMS-03 Phase 8 tests — mocks `globalThis.fetch` for both the OAuth2
// token endpoint and the Identity Platform REST calls, using a real (test-
// only) RSA keypair so the actual `importPKCS8`/`SignJWT` signing code runs
// unmodified — the same pattern already established in
// `firestoreAdmin.test.ts`. Run with:
//   deno test --allow-env supabase/functions/_shared/firebaseUserLookup.test.ts
import { assertEquals, assertRejects } from "jsr:@std/assert@^1";
import { exportPKCS8, generateKeyPair } from "npm:jose@^5";
import {
  createUserWithPhoneNumber,
  findUidByPhoneNumber,
  resolveFirebaseUidForPhone,
} from "./firebaseUserLookup.ts";

const ORIGINAL_FETCH = globalThis.fetch;

async function setFakeServiceAccount() {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const pem = await exportPKCS8(privateKey);
  Deno.env.set(
    "FIREBASE_SERVICE_ACCOUNT_KEY",
    btoa(JSON.stringify({ client_email: "test@anaaya-plus.iam.gserviceaccount.com", private_key: pem })),
  );
}

type Handler = (req: Request) => Response | Promise<Response>;

function mockFetch(routes: Array<[string, Handler]>): typeof fetch {
  const withToken: Array<[string, Handler]> = [
    ["oauth2.googleapis.com/token", () => jsonResponse({ access_token: "fake-access-token", expires_in: 3600 })],
    ...routes,
  ];
  return ((input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    const req = input instanceof Request ? input : new Request(url, init);
    for (const [pattern, handler] of withToken) {
      if (url.includes(pattern)) return Promise.resolve(handler(req));
    }
    throw new Error(`unmocked fetch: ${url}`);
  }) as typeof fetch;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

async function withMocks<T>(routes: Array<[string, Handler]>, run: () => Promise<T>): Promise<T> {
  await setFakeServiceAccount();
  globalThis.fetch = mockFetch(routes);
  try {
    return await run();
  } finally {
    globalThis.fetch = ORIGINAL_FETCH;
    Deno.env.delete("FIREBASE_SERVICE_ACCOUNT_KEY");
  }
}

const PHONE = "+966512345678";

Deno.test("findUidByPhoneNumber: returns the uid when a user with this phone exists", async () => {
  const result = await withMocks(
    [[":lookup", () => jsonResponse({ users: [{ localId: "uid-existing" }] })]],
    () => findUidByPhoneNumber(PHONE),
  );
  assertEquals(result, "uid-existing");
});

Deno.test("findUidByPhoneNumber: returns null when no user has this phone", async () => {
  const result = await withMocks(
    [[":lookup", () => jsonResponse({})]],
    () => findUidByPhoneNumber(PHONE),
  );
  assertEquals(result, null);
});

Deno.test("findUidByPhoneNumber: throws on a genuine transport failure, distinct from not-found", async () => {
  await assertRejects(() =>
    withMocks([[":lookup", () => new Response(null, { status: 500 })]], () => findUidByPhoneNumber(PHONE))
  );
});

Deno.test("createUserWithPhoneNumber: creates a user and returns the new uid", async () => {
  let capturedPhone: string | null = null;
  const result = await withMocks(
    [
      [
        "identitytoolkit.googleapis.com/v1/projects/anaaya-plus/accounts",
        (req) => {
          if (req.url.includes(":lookup")) throw new Error("should not call lookup here");
          return req.json().then((body) => {
            capturedPhone = body.phoneNumber;
            return jsonResponse({ localId: "uid-new" });
          });
        },
      ],
    ],
    () => createUserWithPhoneNumber(PHONE),
  );
  assertEquals(result, "uid-new");
  assertEquals(capturedPhone, PHONE);
});

Deno.test("resolveFirebaseUidForPhone: existing phone resolves to the existing uid, isNewUser=false", async () => {
  const result = await withMocks(
    [[":lookup", () => jsonResponse({ users: [{ localId: "uid-existing" }] })]],
    () => resolveFirebaseUidForPhone(PHONE),
  );
  assertEquals(result, { uid: "uid-existing", isNewUser: false });
});

Deno.test("resolveFirebaseUidForPhone: unknown phone creates exactly one new user, isNewUser=true", async () => {
  let createCalls = 0;
  const result = await withMocks(
    [
      [":lookup", () => jsonResponse({})],
      [
        "identitytoolkit.googleapis.com/v1/projects/anaaya-plus/accounts",
        (req) => {
          if (req.url.includes(":lookup")) return jsonResponse({});
          createCalls++;
          return jsonResponse({ localId: "uid-brand-new" });
        },
      ],
    ],
    () => resolveFirebaseUidForPhone(PHONE),
  );
  assertEquals(result, { uid: "uid-brand-new", isNewUser: true });
  assertEquals(createCalls, 1);
});
