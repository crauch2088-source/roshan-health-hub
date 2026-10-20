import assert from "node:assert/strict";
import { test } from "node:test";
import { mapLabResult, preserveCriticalLabFlag } from "../src/lib/lab-workflow.ts";

test("blank is empty but numeric zero remains a real result", () => {
  assert.equal(mapLabResult({ value: null, dataType: "numeric" }).kind, "empty");
  const result = mapLabResult({ value: "0", dataType: "numeric", lower: 0, upper: 10 });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.value, 0);
    assert.equal(result.abnormal, false);
  }
});

test("reference bounds flag low values but accept inclusive bounds", () => {
  const result = mapLabResult({ value: "3.2", dataType: "numeric", lower: 4, upper: 10 });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.flag, "low");
    assert.equal(result.abnormal, true);
  }
  assert.equal(mapLabResult({ value: "10", dataType: "numeric", lower: 4, upper: 10 }).kind, "numeric");
});

test("critical thresholds and unchanged persisted critical flags are retained", () => {
  const result = mapLabResult({ value: "1", dataType: "numeric", lower: 4, criticalLower: 2 });
  assert.equal(result.kind, "numeric");
  if (result.kind === "numeric") {
    assert.equal(result.flag, "critical-low");
    assert.equal(result.critical, true);
  }
  const mapped = mapLabResult({ value: "5", dataType: "numeric", lower: 4, upper: 10 });
  const saved = preserveCriticalLabFlag(mapped, "5", "5", "critical-high");
  assert.equal(saved.kind, "numeric");
  if (saved.kind === "numeric") assert.equal(saved.critical, true);
});

test("text and coded values are not coerced to numbers", () => {
  const text = mapLabResult({ value: "0", dataType: "text" });
  assert.equal(text.kind, "text");
  if (text.kind === "text") assert.equal(text.value, "0");
  assert.equal(mapLabResult({ value: "NEG", dataType: "coded", code: "NEG" }).kind, "coded");
});

test("unknown legacy data types preserve numeric strings and nonnumeric text", () => {
  assert.equal(mapLabResult({ value: "12.5", dataType: "legacy_custom_type" }).kind, "numeric");
  assert.equal(mapLabResult({ value: "Detected", dataType: "legacy_custom_type" }).kind, "text");
});
