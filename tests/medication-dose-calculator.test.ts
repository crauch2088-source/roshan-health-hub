import assert from "node:assert/strict";
import { test } from "node:test";

import { calculateDose } from "../src/lib/medication-engine/dose-calculator.ts";

test("calculates an explicitly supplied mg/kg/dose rule", () => {
  assert.deepEqual(
    calculateDose({
      basis: { kind: "mg_per_kg_per_dose", amountMgPerKg: 2, dosesPerDay: 2 },
      weightKg: 10,
    }),
    {
      status: "calculated",
      doseMg: 20,
      dailyDoseMg: 40,
      uncappedDoseMg: 20,
      appliedCaps: [],
      rounded: false,
    },
  );
});

test("calculates mg/kg/day using only the explicit doses-per-day input", () => {
  const result = calculateDose({
    basis: { kind: "mg_per_kg_per_day", amountMgPerKgPerDay: 30, dosesPerDay: 3 },
    weightKg: 12,
  });
  assert.equal(result.status, "calculated");
  if (result.status === "calculated") {
    assert.equal(result.dailyDoseMg, 360);
    assert.equal(result.doseMg, 120);
  }
});

test("records both active ceilings when both constrain the uncapped dose", () => {
  const result = calculateDose({
    basis: {
      kind: "mg_per_kg_per_dose",
      amountMgPerKg: 10,
      dosesPerDay: 3,
      maxPerDoseMg: 80,
      maxPerDayMg: 180,
    },
    weightKg: 10,
  });
  assert.equal(result.status, "calculated");
  if (result.status === "calculated") {
    assert.equal(result.doseMg, 60);
    assert.equal(result.dailyDoseMg, 180);
    assert.deepEqual(result.appliedCaps, ["max_per_dose", "max_per_day"]);
  }
});

test("fixed-dose calculations do not require weight", () => {
  const result = calculateDose({
    basis: { kind: "fixed", amountMg: 250, dosesPerDay: 2 },
  });
  assert.equal(result.status, "calculated");
  if (result.status === "calculated") {
    assert.equal(result.doseMg, 250);
    assert.equal(result.dailyDoseMg, 500);
  }
});

test("missing weight returns needs_data and never falls back to a previous weight", () => {
  assert.deepEqual(
    calculateDose({
      basis: { kind: "mg_per_kg_per_dose", amountMgPerKg: 5, dosesPerDay: 2 },
      weightKg: null,
    }),
    { status: "needs_data", missing: ["weight_kg"] },
  );
});

test("rejects non-finite, zero, or negative weight and dose parameters", () => {
  for (const weightKg of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.equal(
      calculateDose({
        basis: { kind: "mg_per_kg_per_dose", amountMgPerKg: 1, dosesPerDay: 1 },
        weightKg,
      }).status,
      "invalid",
    );
  }
  assert.equal(
    calculateDose({
      basis: { kind: "fixed", amountMg: -1, dosesPerDay: 1 },
    }).status,
    "invalid",
  );
});

test("rejects invalid frequency and safety ceilings", () => {
  assert.equal(
    calculateDose({
      basis: { kind: "fixed", amountMg: 10, dosesPerDay: 0 },
    }).status,
    "invalid",
  );
  assert.equal(
    calculateDose({
      basis: {
        kind: "mg_per_kg_per_day",
        amountMgPerKgPerDay: 10,
        dosesPerDay: 2,
        maxPerDoseMg: -1,
      },
      weightKg: 10,
    }).status,
    "invalid",
  );
});

test("rounding cannot silently exceed a configured safety ceiling", () => {
  assert.deepEqual(
    calculateDose({
      basis: {
        kind: "mg_per_kg_per_dose",
        amountMgPerKg: 1.26,
        dosesPerDay: 1,
        maxPerDoseMg: 1.25,
      },
      weightKg: 1,
      rounding: { incrementMg: 0.1, mode: "nearest" },
    }),
    { status: "invalid", reason: "rounding_exceeds_safety_cap" },
  );
});

test("daily ceilings are not mistaken for per-dose ceilings", () => {
  const result = calculateDose({
    basis: {
      kind: "mg_per_kg_per_dose",
      amountMgPerKg: 50,
      dosesPerDay: 4,
      maxPerDayMg: 100,
    },
    weightKg: 2,
  });
  assert.equal(result.status, "calculated");
  if (result.status === "calculated") {
    assert.equal(result.doseMg, 25);
    assert.equal(result.dailyDoseMg, 100);
  }
});

test("allows source-defined upward rounding when no safety ceiling is exceeded", () => {
  const result = calculateDose({
    basis: { kind: "fixed", amountMg: 1.21, dosesPerDay: 1 },
    rounding: { incrementMg: 0.1, mode: "up" },
  });
  assert.equal(result.status, "calculated");
  if (result.status === "calculated") {
    assert.equal(result.doseMg, 1.3);
    assert.equal(result.dailyDoseMg, 1.3);
    assert.equal(result.rounded, true);
  }
});
