import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const pharmacy = readFileSync("src/routes/_authenticated/pharmacy.tsx", "utf8");
const clinic = readFileSync("src/routes/_authenticated/clinic.tsx", "utf8");
const correctionUi = readFileSync("src/components/prescription-correction.tsx", "utf8");

test("pharmacist can request correction only for a specific unlinked prescription item", () => {
  assert.match(pharmacy, /pharmacy\.correction\.request/);
  assert.match(pharmacy, /canRequestCorrection/);
  assert.match(pharmacy, /user\?\.role_code/);
  assert.match(pharmacy, /PharmacyCorrectionRequest/);
  assert.match(correctionUi, /request_prescription_item_correction/);
  assert.match(correctionUi, /prescription_item_id/);
  assert.match(correctionUi, /p_reason/);
  assert.match(correctionUi, /length >= 10/);
});

test("pharmacy correction request UI is bilingual and does not dispense or bill", () => {
  assert.match(correctionUi, /طلب تصحيح الوصفة/);
  assert.match(correctionUi, /Request prescription correction/);
  assert.match(correctionUi, /لا يؤدي طلب التصحيح إلى صرف الدواء أو إنشاء فاتورة/);
  assert.match(
    correctionUi,
    /Requesting clarification does not dispense medicines, create invoices/,
  );
  assert.match(pharmacy, /medicine_id/);
});

test("responsible prescriber inbox is permission-gated and reads only pending RLS-scoped requests", () => {
  assert.match(clinic, /PrescriberCorrectionInbox/);
  assert.match(correctionUi, /prescriptions\.correction\.resolve/);
  assert.match(correctionUi, /isClinicalPrescriber/);
  assert.match(correctionUi, /prescription_item_correction_requests/);
  assert.match(correctionUi, /eq\("status", "pending"\)/);
  assert.match(correctionUi, /resolve_prescription_item_correction/);
});

test("prescriber replacement requires explicit catalogue selection and complete clinician-entered regimen", () => {
  for (const field of [
    "medicine_id",
    "dose",
    "frequency",
    "duration",
    "quantity",
    "dosage_form",
    "route",
  ]) {
    assert.ok(correctionUi.includes(field), `missing explicit replacement field: ${field}`);
  }
  assert.match(correctionUi, /replace_item/);
  assert.match(correctionUi, /instructions/);
  assert.doesNotMatch(correctionUi, /fuzzy|similarity\s*search|auto.?match/i);
});

test("correction UI writes only through dedicated RPCs and refreshes the pharmacy queue", () => {
  assert.match(correctionUi, /supabase\.rpc\(["']request_prescription_item_correction/);
  assert.match(correctionUi, /supabase\.rpc\(["']resolve_prescription_item_correction/);
  assert.doesNotMatch(
    correctionUi,
    /\.from\(["']prescription_item_correction_requests["']\)\s*\.insert/,
  );
  assert.doesNotMatch(
    correctionUi,
    /\.from\(["']prescription_item_correction_requests["']\)\s*\.(insert|update|delete)/,
  );
  assert.match(correctionUi, /prescription-corrections/);
  assert.match(correctionUi, /pharmacy-queue/);
});

test("cancel-and-reissue is exposed only to prescribers allowed to create prescriptions", () => {
  assert.match(correctionUi, /can\("prescriptions\.create"\)/);
  assert.match(correctionUi, /cancel_and_reissue/);
  assert.match(correctionUi, /openResolution\(request, "cancel_and_reissue"\)/);
});

test("cancel-and-reissue editor supports a complete multi-item replacement order", () => {
  assert.match(correctionUi, /replacementOrderItems/);
  assert.match(correctionUi, /addReplacementOrderItem/);
  assert.match(correctionUi, /removeReplacementOrderItem/);
  for (const field of [
    "medicine_id",
    "dose",
    "frequency",
    "duration",
    "quantity",
    "dosage_form",
    "route",
    "instructions",
  ]) {
    assert.ok(correctionUi.includes(field), `missing replacement-order field: ${field}`);
  }
  assert.match(correctionUi, /p_replacement/);
});

test("cancel-and-reissue refuses incomplete or empty replacement orders without inferring regimens", () => {
  assert.match(correctionUi, /replacementOrderItems\.length/);
  assert.match(correctionUi, /Number\.isSafeInteger/);
  assert.match(correctionUi, /every\(/);
  assert.doesNotMatch(correctionUi, /auto.?dose|dose.?inference|infer.*route/i);
});

test("both correction dialogs support Arabic RTL, English LTR and small-screen vertical scrolling", () => {
  assert.equal((correctionUi.match(/dir=\{lang === "ar" \? "rtl" : "ltr"\}/g) ?? []).length, 2);
  assert.equal((correctionUi.match(/max-h-\[90dvh\].*overflow-y-auto/g) ?? []).length, 2);
  assert.match(correctionUi, /sm:grid-cols-2/);
  assert.match(correctionUi, /flex-col-reverse gap-2 sm:flex-row/);
});

test("existing prescription composer requires the dedicated prescriber permission", () => {
  const prescriptionTab = readFileSync(
    "src/features/clinic/consultation/components/PrescriptionTab.tsx",
    "utf8",
  );
  assert.match(prescriptionTab, /useAuth/);
  assert.match(prescriptionTab, /user\?\.role_code/);
  assert.match(prescriptionTab, /isClinicalPrescriber/);
  assert.match(prescriptionTab, /can\("prescriptions\.create"\)/);
  assert.match(prescriptionTab, /Only authorized prescribers can create prescriptions/);
  assert.match(prescriptionTab, /فقط مقدمو الرعاية المخولون يمكنهم إصدار الوصفات/);
  assert.doesNotMatch(prescriptionTab, /pharmacy\.create|emr\.create/);
});
