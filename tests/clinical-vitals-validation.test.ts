import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { validateVitals } from "../src/features/clinic/consultation/vitals-validation.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("blank optional vital fields are allowed", () => {
  assert.deepEqual(validateVitals({}), []);
  assert.deepEqual(validateVitals({ pulse: " ", spo2: "" }), []);
});

test("negative measurements are rejected for every numeric vital field", () => {
  const fields = [
    "bp_systolic",
    "bp_diastolic",
    "pulse",
    "respiratory_rate",
    "temperature",
    "spo2",
    "weight",
    "height",
  ];
  const issues = validateVitals(Object.fromEntries(fields.map((field) => [field, "-1"])));
  assert.deepEqual(
    issues.map((issue) => issue.field),
    fields,
  );
  assert.ok(issues.every((issue) => issue.code === "negative"));
});

test("zero remains recordable for vital signs that may be absent in an emergency", () => {
  assert.deepEqual(
    validateVitals({
      bp_systolic: "0",
      bp_diastolic: "0",
      pulse: "0",
      respiratory_rate: "0",
      temperature: "0",
      spo2: "0",
    }),
    [],
  );
});

test("zero weight and height are rejected when explicitly entered", () => {
  assert.deepEqual(validateVitals({ weight: "0", height: "0" }), [
    { field: "weight", code: "must-be-positive" },
    { field: "height", code: "must-be-positive" },
  ]);
});

test("SpO2 is bounded to 100 percent while 100 remains valid", () => {
  assert.deepEqual(validateVitals({ spo2: "100" }), []);
  assert.deepEqual(validateVitals({ spo2: "100.1" }), [
    { field: "spo2", code: "above-maximum" },
  ]);
});

test("non-finite numeric input is rejected", () => {
  assert.deepEqual(validateVitals({ pulse: "Infinity", temperature: "1e309" }), [
    { field: "pulse", code: "invalid-number" },
    { field: "temperature", code: "invalid-number" },
  ]);
});

test("clinically extreme positive values remain recordable for clinician review", () => {
  assert.deepEqual(
    validateVitals({
      bp_systolic: "250",
      bp_diastolic: "150",
      pulse: "240",
      respiratory_rate: "80",
      temperature: "43",
      spo2: "100",
      weight: "0.5",
      height: "35",
    }),
    [],
  );
});

test("vitals UI validates before writes, exposes field errors, and flags zero danger readings", () => {
  const ui = read("../src/features/clinic/consultation/components/VitalsTab.tsx");
  const saveStart = ui.indexOf("const save = useSave(");
  const validation = ui.indexOf("validateVitals(f)", saveStart);
  const payload = ui.indexOf("const payload = {", saveStart);

  assert.ok(saveStart >= 0 && validation > saveStart && payload > validation);
  assert.match(ui, /aria-invalid=\{Boolean\(validationError\)\}/);
  assert.match(ui, /role="alert"/);
  assert.match(ui, /disabled=\{save\.isPending \|\| validationErrors\.length > 0\}/);
  assert.match(ui, /return Number\.isFinite\(value\) && rule\(value\);/);
  assert.doesNotMatch(ui, /Number\.isFinite\(value\) && value > 0 && rule\(value\)/);
});
