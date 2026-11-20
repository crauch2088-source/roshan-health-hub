import assert from "node:assert/strict";
import { test } from "node:test";
import {
  canFinalizeClinicianOrder,
  convertMgToMl,
  evaluateMedicationDecisionSupport,
  isRouteConsistentWithFormulation,
  validatePatientWeight,
} from "../src/lib/medication-engine/pediatric-safety.ts";

const syntheticProtocol = {
  protocolId: "SYNTHETIC-TEST-ONLY",
  source: "Synthetic unit-test fixture (not a clinical protocol)",
  version: "1.0.0-test",
  approvedBy: "Synthetic Test Harness",
  effectiveFrom: "2026-01-01T00:00:00Z",
  expiresAt: "2027-01-01T00:00:00Z",
};

test("rejects missing, zero, negative, implausible, and stale pediatric weights", () => {
  const ref = "2026-11-20T12:00:00Z";
  assert.equal(validatePatientWeight(null, ref, ref).reason, "missing");
  assert.equal(validatePatientWeight(0, ref, ref).reason, "non_positive");
  assert.equal(validatePatientWeight(-5, ref, ref).reason, "non_positive");
  assert.equal(validatePatientWeight(0.2, ref, ref).reason, "implausible");
  assert.equal(validatePatientWeight(350, ref, ref).reason, "implausible");
  assert.equal(validatePatientWeight(12, "2026-11-18T00:00:00Z", ref, 24).reason, "stale");
  assert.equal(validatePatientWeight(12, "2026-11-20T10:00:00Z", ref, 24).valid, true);
});

test("distinguishes mg_per_kg_per_dose vs mg_per_kg_per_day and enforces caps", () => {
  const perDose = evaluateMedicationDecisionSupport({
    patientAgeYears: 5,
    weightKg: 20,
    weightRecordedAt: "2026-11-20T11:00:00Z",
    referenceTimeIso: "2026-11-20T12:00:00Z",
    dosageForm: "suspension",
    route: "oral",
    protocol: syntheticProtocol,
    basis: {
      kind: "mg_per_kg_per_dose",
      amountMgPerKg: 10,
      dosesPerDay: 3,
      maxPerDoseMg: 150,
      maxPerDayMg: 500,
    },
    concentration: { mg: 125, perMl: 5 },
  });
  assert.equal(perDose.status, "recommendation_ready");
  assert.equal(perDose.requiresClinicianConfirmation, true);
  assert.equal(perDose.autoPrescribed, false);
  assert.equal(perDose.calculation?.status, "calculated");
  if (perDose.calculation?.status === "calculated") {
    assert.equal(perDose.calculation.doseMg, 150);
    assert.equal(perDose.calculation.dailyDoseMg, 450);
  }
  assert.equal(perDose.volumeMl, 6);

  const perDay = evaluateMedicationDecisionSupport({
    patientAgeYears: 5,
    weightKg: 20,
    weightRecordedAt: "2026-11-20T11:00:00Z",
    referenceTimeIso: "2026-11-20T12:00:00Z",
    dosageForm: "suspension",
    route: "oral",
    protocol: syntheticProtocol,
    basis: {
      kind: "mg_per_kg_per_day",
      amountMgPerKgPerDay: 30,
      dosesPerDay: 3,
      maxPerDayMg: 600,
    },
  });
  assert.equal(perDay.status, "recommendation_ready");
  if (perDay.calculation?.status === "calculated") {
    assert.equal(perDay.calculation.doseMg, 200);
    assert.equal(perDay.calculation.dailyDoseMg, 600);
  }
});

test("validates concentration conversion and route/formulation consistency", () => {
  assert.equal(convertMgToMl(250, 125, 5).volumeMl, 10);
  assert.equal(convertMgToMl(250, 0, 5).valid, false);
  assert.equal(isRouteConsistentWithFormulation("syrup", "oral"), true);
  assert.equal(isRouteConsistentWithFormulation("injection", "oral"), false);
  assert.equal(isRouteConsistentWithFormulation("tablet", "iv"), false);
});

test("fails safely on missing or expired protocol and requires explicit clinician confirmation", () => {
  const missing = evaluateMedicationDecisionSupport({
    patientAgeYears: 6,
    weightKg: 18,
    weightRecordedAt: "2026-11-20T11:00:00Z",
    referenceTimeIso: "2026-11-20T12:00:00Z",
    dosageForm: "syrup",
    route: "oral",
    protocol: null,
    basis: null,
  });
  assert.equal(missing.status, "manual_decision_required");
  assert.equal(missing.reason, "protocol_missing");

  const expired = evaluateMedicationDecisionSupport({
    patientAgeYears: 6,
    weightKg: 18,
    weightRecordedAt: "2026-11-20T11:00:00Z",
    referenceTimeIso: "2028-01-01T00:00:00Z",
    dosageForm: "syrup",
    route: "oral",
    protocol: syntheticProtocol,
    basis: { kind: "fixed", amountMg: 100, dosesPerDay: 2 },
  });
  assert.equal(expired.status, "manual_decision_required");
  assert.equal(expired.reason, "protocol_expired");

  assert.equal(
    canFinalizeClinicianOrder({
      recommendation: missing,
      clinicianEnteredDose: "250 mg",
      clinicianConfirmed: false,
    }),
    false,
  );
  assert.equal(
    canFinalizeClinicianOrder({
      recommendation: missing,
      clinicianEnteredDose: "250 mg",
      clinicianConfirmed: true,
    }),
    true,
  );
});
