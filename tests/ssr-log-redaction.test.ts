import assert from "node:assert/strict";
import { test } from "node:test";
import { describeError } from "../src/lib/error-capture.ts";
import { redactSensitive, safeRequestTarget, sanitizeLogValue } from "../src/lib/redact.ts";
import { buildLivenessResponse, buildReadinessResponse } from "../src/lib/health-probes.ts";
import {
  buildAllowlistedTelemetryEnvelope,
  dispatchTelemetryFailOpen,
} from "../src/lib/telemetry.ts";

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
test("buildLivenessResponse returns 200 alive payload with no-store cache header", async () => {
  const res = buildLivenessResponse({ commitSha: "abc1234" });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("cache-control"), "no-store");
  const body = (await res.json()) as Record<string, unknown>;
  assert.equal(body.status, "alive");
  assert.equal(body.service, "roshan-health-hub");
  assert.equal(body.commitSha, "abc1234");
});

test("buildReadinessResponse handles unconfigured, failing, and healthy probes without leaking secrets", async () => {
  const secretUrl = "https://example.test/secret-supabase";
  const secretKey = "sb_secret_readiness_key_12345";

  const unconfigured = await buildReadinessResponse({ commitSha: "abc1234" });
  assert.equal(unconfigured.status, 503);
  const unconfiguredBody = (await unconfigured.json()) as {
    status: string;
    checks: { supabase: string };
   ;
  assert.equal(unconfiguredBody.status, "not_ready");
  assert.equal(unconfiguredBody.checks.supabase, "unconfigured");

  const failing = await buildReadinessResponse(
    { supabaseUrl: secretUrl, supabaseAnonKey: secretKey, commitSha: "abc1234" },
    async () => false,
  );
  assert.equal(failing.status, 503);
  const failingText = await failing.text();
  assert.equal("supabaseUrl" in JSON.parse(failingText), false);
  assert.ok(!failingText.includes(secretKey));
  assert.equal(JSON.parse(failingText).checks.supabase, "unavailable");

  const healthy = await buildReadinessResponse(
    { supabaseUrl: secretUrl, supabaseAnonKey: secretKey, commitSha: "abc1234" },
    async () => true,
  );
  assert.equal(healthy.status, 200);
  const healthyText = await healthy.text();
  assert.equal("supabaseUrl" in JSON.parse(healthyText), false);
  assert.ok(!healthyText.includes(secretKey));
  assert.equal(JSON.parse(healthyText).status, "ready");
  assert.equal(JSON.parse(healthyText).checks.supabase, "ok");
});

test("buildAllowlistedTelemetryEnvelope drops extra PHI keys and redacts Arabic/English names, phones, JWTs and secrets", () => {
  const envelope = buildAllowlistedTelemetryEnvelope({
    environment: "production",
    commitSha: "79d81f0",
    route: "https://example.test/patients/123e4567-e89b-42d3-a456-426614174000?token=abc",
    method: "POST",
    rpcName: "create_visit",
    sqlState: "23505",
    errorCategory: "db_conflict",
    message: `name=Jane Doe, full_name=أحمد محمد, phone=+249 912 345 678, jwt=${fakeJwt}, secret=${fakeSecret}`,
    patientName: "Should Be Dropped",
    diagnosis: "Sensitive PHI",
  });

  const serialized = JSON.stringify(envelope);
  assert.equal("patientName" in envelope, false);
  assert.equal("diagnosis" in envelope, false);
  assert.equal(envelope.route, "POST /patients/[UUID]");
  assert.equal(envelope.rpcName, "create_visit");
  assert.equal(envelope.sqlState, "23505");
  for (const sensitive of [
    "Jane Doe",
    "أحمد محمد",
    "912 345 678",
    fakeJwt,
    fakeSecret,
    "Should Be Dropped",
    "Sensitive PHI",
  ]) {
    assert.ok(!serialized.includes(sensitive), "leaked " + sensitive);
  }
});

test("dispatchTelemetryFailOpen fails open on unconfigured, HTTP errors, rejections, and timeouts", async () => {
  const envelope = buildAllowlistedTelemetryEnvelope({ message: "safe error" });

  const unconfigured = await dispatchTelemetryFailOpen(envelope, undefined);
  assert.deepEqual(unconfigured, { sent: false, reason: "unconfigured" });

  const okRes = await dispatchTelemetryFailOpen(
    envelope,
    "https://example.test/telemetry",
    async () => ({ ok: true }),
  );
  assert.deepEqual(okRes, { sent: true });

  const httpErr = await dispatchTelemetryFailOpen(
    envelope,
    "https://example.test/telemetry",
    async () => ({ ok: false }),
  );
  assert.deepEqual(httpErr, { sent: false, reason: "http_error" });

  const rejected = await dispatchTelemetryFailOpen(
    envelope,
    "https://example.test/telemetry",
    async () => {
      throw new Error("network down");
    },
  );
  assert.deepEqual(rejected, { sent: false, reason: "network_or_timeout" });

  const timedOut = await dispatchTelemetryFailOpen(
    envelope,
    "https://example.test/telemetry",
    (_url, init) =>
      new Promise((_resolve, reject) => {
        init.signal.addEventListener("abort", () => reject(new Error("aborted")));
      }),
    10,
  );
  assert.deepEqual(timedOut, { sent: false, reason: "network_or_timeout" });
});
