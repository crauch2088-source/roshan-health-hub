import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

test("PrescriptionTab wires PediatricSafetyPanel with explicit confirmation gate", () => {
  const tabSrc = fs.readFileSync(
    path.resolve("src/features/clinic/consultation/components/PrescriptionTab.tsx"),
    "utf8",
  );
  assert.ok(tabSrc.includes("PediatricSafetyPanel"));
  assert.ok(tabSrc.includes("pediatricSafetyConfirmed"));
});

test("PediatricSafetyPanel uses pediatric-safety engine and keeps protocol activation gated", () => {
  const panelSrc = fs.readFileSync(
    path.resolve("src/features/clinic/consultation/components/PediatricSafetyPanel.tsx"),
    "utf8",
  );
  for (const symbol of [
    "validatePatientWeight",
    "convertMgToMl",
    "isRouteConsistentWithFormulation",
    "evaluateMedicationDecisionSupport",
    "canFinalizeClinicianOrder",
    "protocol: null",
    "mg_per_kg_per_dose",
    "mg_per_kg_per_day",
  ]) {
    assert.ok(panelSrc.includes(symbol), `Expected PediatricSafetyPanel to contain ${symbol}`);
  }
});
