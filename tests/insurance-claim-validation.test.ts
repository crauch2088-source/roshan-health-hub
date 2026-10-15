import assert from "node:assert/strict";
import { test } from "node:test";

import {
  isInsuranceClaimReadyToSubmit,
  validateInsuranceClaimDraft,
} from "../src/lib/insurance-validation.ts";

const validItem = {
  service_type: "consultation",
  reference_id: null,
  description: "Consultation",
  gross_amount: 100,
  covered_amount: 80,
  patient_amount: 20,
  coverage_rule_id: null,
};

test("save readiness requires patient insurance, invoice, items, and no active save", () => {
  assert.equal(
    isInsuranceClaimReadyToSubmit({
      patientInsuranceId: "insurance-1",
      invoiceId: "invoice-1",
      itemCount: 1,
      isSaving: false,
    }),
    true,
  );
  assert.equal(
    isInsuranceClaimReadyToSubmit({
      patientInsuranceId: "insurance-1",
      invoiceId: "",
      itemCount: 1,
      isSaving: false,
    }),
    false,
  );
  assert.equal(
    isInsuranceClaimReadyToSubmit({
      patientInsuranceId: "insurance-1",
      invoiceId: "invoice-1",
      itemCount: 0,
      isSaving: false,
    }),
    false,
  );
  assert.equal(
    isInsuranceClaimReadyToSubmit({
      patientInsuranceId: "insurance-1",
      invoiceId: "invoice-1",
      itemCount: 1,
      isSaving: true,
    }),
    false,
  );
});

test("rejects a claim without an invoice before calling the RPC", () => {
  assert.throws(
    () =>
      validateInsuranceClaimDraft({
        patientInsuranceId: "insurance-1",
        invoiceId: null,
        items: [validItem],
      }),
    /invoice/i,
  );
});

test("rejects a claim without patient insurance or line items", () => {
  assert.throws(
    () =>
      validateInsuranceClaimDraft({
        patientInsuranceId: "",
        invoiceId: "invoice-1",
        items: [validItem],
      }),
    /insurance/i,
  );
  assert.throws(
    () =>
      validateInsuranceClaimDraft({
        patientInsuranceId: "insurance-1",
        invoiceId: "invoice-1",
        items: [],
      }),
    /item/i,
  );
});

test("accepts a complete invoice-linked claim draft", () => {
  assert.doesNotThrow(() =>
    validateInsuranceClaimDraft({
      patientInsuranceId: "insurance-1",
      invoiceId: "invoice-1",
      items: [validItem],
    }),
  );
});
