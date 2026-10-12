// Regression tests for server-side SSR error logging: the log keeps the error name, message and
// stack (so failures are diagnosable) but never contains secrets, credentials or patient data.
// Fake credentials are assembled at runtime so no secret-looking literal lives in the repo.
import assert from "node:assert/strict";
import { test } from "node:test";

import { describeError } from "../src/lib/error-capture.ts";
import { redactSensitive, safeRequestTarget } from "../src/lib/redact.ts";

const b64 = (s: string) => Buffer.from(s).toString("base64url");
const fakeJwt = [
  b64('{"alg":"HS256"}'),
  b64('{"role":"service_role"}'),
  b64("signature-bytes"),
].join(".");
const fakeSecretKey = "sb_secret_" + "a1B2c3D4".repeat(5);
const fakePublishableKey = "sb_publishable_" + "Z9y8X7w6".repeat(4);

test("JWTs and Supabase keys are redacted", () => {
  const out = redactSensitive(`failed with ${fakeJwt} / ${fakeSecretKey} / ${fakePublishableKey}`);
  assert.ok(!out.includes(fakeJwt) && !out.includes("eyJ"));
  assert.ok(!out.includes(fakeSecretKey) && !out.includes(fakePublishableKey));
});

test("Authorization, cookie and bearer values are redacted", () => {
  const out = redactSensitive(
    `Authorization: Bearer ${fakeJwt}\ncookie: roshan-auth=session-value-123456\napikey=${fakeSecretKey}`,
  );
  assert.ok(!out.includes(fakeJwt) && !out.includes("session-value-123456"));
  assert.ok(!out.includes(fakeSecretKey));
});

test("sensitive key=value pairs are redacted but other text is kept", () => {
  const out = redactSensitive('SUPABASE_SECRET_KEY=abc123xyz password: "hunter2" mode=ssr');
  assert.ok(!out.includes("abc123xyz") && !out.includes("hunter2"));
  assert.ok(out.includes("mode=ssr"));
});

test("patient identifiers (email, uuid, phone/national id, db detail values) are redacted", () => {
  const out = redactSensitive(
    "duplicate key: Key (national_id)=(1234567890) exists; patient a@b.com " +
      "id 123e4567-e89b-42d3-a456-426614174000 phone +249 912 345 678",
  );
  for (const leaked of ["1234567890", "a@b.com", "123e4567", "912 345 678"]) {
    assert.ok(!out.includes(leaked), `leaked ${leaked}`);
  }
  assert.ok(out.includes("national_id"));
});

test("request target keeps method and path only (no query, no ids)", () => {
  const out = safeRequestTarget(
    "https://example.test/patients/123e4567-e89b-42d3-a456-426614174000?token=abc&email=a@b.com",
    "get",
  );
  assert.equal(out, "GET /patients/[UUID]");
});

test("describeError keeps name, message and stack, including the cause chain, redacted", () => {
  const cause = new Error(`upstream rejected ${fakeSecretKey}`);
  const error = new TypeError(`Node.js detected but native WebSocket not found (${fakeJwt})`, {
    cause,
  });
  const out = describeError(error);
  assert.ok(out.includes("TypeError"));
  assert.ok(out.includes("native WebSocket not found"));
  assert.ok(out.includes("caused by:"));
  assert.ok(out.includes("at ")); // stack frames survive
  assert.ok(!out.includes(fakeJwt) && !out.includes(fakeSecretKey));
});
