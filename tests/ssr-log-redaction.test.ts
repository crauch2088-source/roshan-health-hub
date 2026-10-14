import assert from "node:assert/strict";
import { test } from "node:test";
import { describeError } from "../src/lib/error-capture.ts";
import { redactSensitive, safeRequestTarget, sanitizeLogValue } from "../src/lib/redact.ts";

const b64 = (value: string) => Buffer.from(value).toString("base64url");
const fakeJwt = [
  b64('{"alg":"HS256"}'),
  b64('{"role":"service_role"}'),
  b64("fake-signature"),
].join(".");
const fakeSecret = "sb_secret_" + "a1B2c3D4".repeat(5);

test("redacts JWTs, Supabase keys, emails, UUIDs and phone-like values in strings", () => {
  const output = redactSensitive(
    "failure " +
      fakeJwt +
      " " +
      fakeSecret +
      " user@example.test 123e4567-e89b-42d3-a456-426614174000 +249 912 345 678",
  );
  for (const value of [fakeJwt, "eyJ", fakeSecret, "user@example.test", "123e4567", "912 345 678"])
    assert.ok(!output.includes(value), "leaked " + value);
});

test("recursively redacts sensitive keys in nested object arguments", () => {
  const input = {
    event: "request failed",
    authorization: "Bearer " + fakeJwt,
    context: {
      apiKey: fakeSecret,
      patient: {
        name: "Example Person",
        email: "person@example.test",
        phone: "+249 912 345 678",
        notes: "routine follow-up",
      },
      nested: [{ access_token: fakeJwt, message: "safe diagnostic detail" }],
    },
  };
  const output = JSON.stringify(sanitizeLogValue(input));
  for (const value of [fakeJwt, fakeSecret, "person@example.test", "912 345 678", "Example Person"])
    assert.ok(!output.includes(value), "leaked " + value);
  assert.ok(output.includes("request failed"));
  assert.ok(output.includes("safe diagnostic detail"));
});

test("handles arrays, circular references, Error causes and excessive depth", () => {
  const circular: Record<string, unknown> = { message: "safe" };
  circular.self = circular;
  const output = JSON.stringify(
    sanitizeLogValue([{ token: fakeJwt }, circular, new Error("safe")]),
  );
  assert.ok(!output.includes(fakeJwt));
  assert.ok(output.includes("[Circular]"));
  assert.doesNotThrow(() => JSON.parse(output));
});

test("redacts sensitive Error messages while preserving stack and cause context", () => {
  const error = new TypeError("failure " + fakeSecret, {
    cause: new Error("email person@example.test"),
  });
  const output = describeError(error);
  assert.ok(output.includes("TypeError"));
  assert.ok(output.includes("at "));
  assert.ok(output.includes("caused by:"));
  assert.ok(!output.includes(fakeSecret));
  assert.ok(!output.includes("person@example.test"));
});

test("request target excludes query strings and masks UUIDs", () => {
  assert.equal(
    safeRequestTarget(
      "https://example.test/patients/123e4567-e89b-42d3-a456-426614174000?token=abc&email=a@b.com",
      "get",
    ),
    "GET /patients/[UUID]",
  );
});
