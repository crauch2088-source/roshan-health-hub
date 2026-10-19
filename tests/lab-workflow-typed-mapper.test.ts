import assert from "node:assert/strict";
import { test } from "node:test";

import { mapLabResult } from "../src/lib/lab-workflow.ts";

test("blank is pending but numeric zero is a real result", () => {
  assert.equal(mapLabResult(null, "numeric").kind, "empty");
  const result = mapLabResult("0", "numeric", {
    lower_limit: 0,
    upper_limit: 10,
  });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.numericValue, 0);
    assert.equal(result.abnormal, false);
  }
});

test("reference ranges set low flags without flagging inclusive bounds", () => {
  const result = mapLabResult("3.2", "numeric", {
    lower_limit: 4,
    upper_limit: 10,
  });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.flag, "low");
    assert.equal(result.abnormal, true);
  }
  assert.equal(
    mapLabResult("10", "numeric", { lower_limit: 4, upper_limit: 10 }).kind,
    "numeric",
  );
});

test("critical thresholds and persisted critical flags are retained", () => {
  const result = mapLabResult("1", "numeric", {
    lower_limit: 4,
    critical_lower_limit: 2,
  });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.flag, "critical_low");
    assert.equal(result.critical, true);
  }
  const saved = mapLabResult("5", "numeric", undefined, "critical_high");
  assert.equal(saved.kind, "numeric");
  if (saved.kind === "numeric") assert.equal(saved.critical, true);
});

test("text and coded values are not coerced", () => {
  assert.equal(mapLabResult("0", "text").numericValue, null);
  assert.equal(mapLabResult("NEG", "coded").kind, "coded");
});

test("unknown legacy data types keep numeric strings compatible", () => {
  assert.equal(mapLabResult("12.5", "legacy_custom_type").kind, "numeric");
  assert.equal(mapLabResult("Detected", "legacy_custom_type").kind, "text");
});
