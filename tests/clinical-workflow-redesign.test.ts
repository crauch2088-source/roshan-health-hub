import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import {
  createEmptyPrescriptionDraft,
  validatePrescriptionDrafts,
} from "../src/lib/prescription-draft.ts";
import { labWorkflowStage } from "../src/lib/lab-workflow.ts";
import { shouldBlockUnsavedClinicalNoteNavigation } from "../src/lib/clinical-navigation-guard.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("prescription completeness guard rejects empty and incomplete regimens", () => {
  assert.equal(validatePrescriptionDrafts([]), "empty");
  const draft = createEmptyPrescriptionDraft();
  draft.name = "Example medicine";
  assert.equal(validatePrescriptionDrafts([draft]), "missing-dose");
  draft.dose = "500 mg";
  assert.equal(validatePrescriptionDrafts([draft]), "missing-frequency");
  draft.frequency = "twice daily";
  assert.equal(validatePrescriptionDrafts([draft]), "missing-duration");
  draft.duration = "5 days";
  draft.quantity = "0";
  assert.equal(validatePrescriptionDrafts([draft]), "invalid-quantity");
  draft.quantity = "10";
  assert.equal(validatePrescriptionDrafts([draft]), null);
});

test("consultation tabs expose accessible tab semantics, bilingual labels and arrow navigation", () => {
  const ui = read("../src/features/clinic/consultation/ConsultationPage.tsx");
  assert.match(ui, /role="tablist"/);
  assert.match(ui, /role="tab"/);
  assert.match(ui, /aria-selected=\{tab === item\.key\}/);
  assert.match(ui, /role="tabpanel"/);
  assert.match(ui, /resolveTabKeyNavigation/);
  assert.match(ui, /lang === "ar" \? "rtl" : "ltr"/);
  assert.match(ui, /lang === "ar" \? item\.ar : item\.en/);
});

test("unsaved clinical notes block route changes and share one unload guard", () => {
  let confirmations = 0;
  const decline = () => {
    confirmations += 1;
    return false;
  };

  assert.equal(shouldBlockUnsavedClinicalNoteNavigation(false, "/clinic/visit-1", "/patients", decline), false);
  assert.equal(confirmations, 0);
  assert.equal(shouldBlockUnsavedClinicalNoteNavigation(true, "/clinic/visit-1?{}", "/clinic/visit-1?{}", decline), false);
  assert.equal(confirmations, 0);
  assert.equal(shouldBlockUnsavedClinicalNoteNavigation(true, "/clinic/visit-1?{}", "/patients?{}", decline), true);
  assert.equal(
    shouldBlockUnsavedClinicalNoteNavigation(true, "/clinic/visit-1?{}", "/patients?{}", () => {
      confirmations += 1;
      return true;
    }),
    false,
  );
  assert.equal(confirmations, 2);

  const page = read("../src/features/clinic/consultation/ConsultationPage.tsx");
  const note = read("../src/features/clinic/consultation/components/ClinicalNoteTab.tsx");
  assert.match(page, /useBlocker\(/);
  assert.match(page, /enableBeforeUnload:\s*\(\)\s*=>\s*noteDirty/);
  assert.match(page, /shouldBlockUnsavedClinicalNoteNavigation/);
  assert.doesNotMatch(page, /window\.addEventListener\(["']beforeunload["']/);
  assert.doesNotMatch(note, /window\.addEventListener\(["']beforeunload["']/);
});

test("lab ordering debounces and sanitizes catalogue search and explains loading/error states", () => {
  const ui = read("../src/features/clinic/consultation/components/LaboratoryTab.tsx");
  assert.match(ui, /useDebounced\(search, 280\)/);
  assert.match(ui, /sanitizeTerm\(debouncedSearch\)/);
  assert.match(ui, /testsQ\.error/);
  assert.match(ui, /aria-pressed=\{chosen\}/);
  assert.match(ui, /Estimated selected-test subtotal/);
  assert.match(ui, /create\.isPending \|\| !selected\.length \|\| !s\(patient, "id"\)/);
});

test("prescription UI states that doses are clinician-entered and validates completeness", () => {
  const ui = read("../src/features/clinic/consultation/components/PrescriptionTab.tsx");
  assert.match(ui, /does not auto-prescribe doses/);
  assert.match(ui, /validatePrescriptionDrafts\(items\)/);
  assert.match(ui, /missing-duration/);
});

test("shell and navigation use the refreshed Roshan surface and mobile-safe layout", () => {
  const css = read("../src/styles.css");
  const shell = read("../src/components/app-shell.tsx");
  const nav = read("../src/components/mobile-bottom-nav.tsx");
  assert.match(css, /--primary: oklch\(0\.535 0\.115 178\)/);
  assert.match(css, /\.roshan-patient-context/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(shell, /roshan-app-background/);
  assert.match(shell, /max-w-\[1680px\]/);
  assert.match(nav, /env\(safe-area-inset-bottom\)/);
});

test("laboratory workflow timeline follows persisted states and treats unknown states conservatively", () => {
  assert.equal(labWorkflowStage("ordered"), 0);
  assert.equal(labWorkflowStage("sample_collected"), 1);
  assert.equal(labWorkflowStage("in_progress"), 2);
  assert.equal(labWorkflowStage("completed"), 3);
  assert.equal(labWorkflowStage("verified"), 4);
  assert.equal(labWorkflowStage("unexpected"), 0);
  const ui = read("../src/routes/_authenticated/lab.tsx");
  assert.match(ui, /Laboratory workflow stage/);
  assert.match(ui, /مرحلة سير المختبر/);
});

test("lab result verification blocks unsaved edits and asks for review of abnormal values", () => {
  const ui = read("../src/routes/_authenticated/lab_.$orderId.tsx");
  assert.match(ui, /hasUnsavedResultEdits/);
  assert.match(ui, /Save result changes before verification/);
  assert.match(ui, /outside the reference range/);
  assert.match(ui, /not a critical-value classifier/);
});

test("consultation quick review is optional, local-only and non-blocking", () => {
  const ui = read("../src/features/clinic/consultation/ConsultationPage.tsx");
  assert.match(ui, /Quick clinical review \(optional\)/);
  assert.match(ui, /these checks are not saved/);
  assert.match(ui, /never block visit completion or emergency care/);
  assert.match(ui, /reviewChecks\[item\.key\]/);
});

test("pediatric prescriptions prompt for weight-based review without calculating a dose", () => {
  const ui = read("../src/features/clinic/consultation/components/PrescriptionTab.tsx");
  assert.match(ui, /patients\(id,full_name,date_of_birth\)/);
  assert.match(ui, /clinic-vitals-weight/);
  assert.match(ui, /Pediatric safety: no current visit weight is recorded/);
  assert.match(ui, /Could not verify the recorded weight/);
  assert.match(ui, /system does not calculate pediatric doses/);
});

test("responsive, focus, dark-mode and print guardrails are present in source", () => {
  const css = read("../src/styles.css");
  assert.match(css, /max-width: 639px/);
  assert.match(css, /safe-area-inset-bottom/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.dark/);
  assert.match(css, /@media print/);
  assert.match(css, /:focus-visible/);
});

test("blank or nonnumeric lab values are not classified as out of range", async () => {
  const { isAbnormalLabResult } = await import("../src/lib/lab-workflow.ts");
  assert.equal(isAbnormalLabResult("", 3.5, 5.5), false);
  assert.equal(isAbnormalLabResult("   ", 3.5, 5.5), false);
  assert.equal(isAbnormalLabResult("not numeric", 3.5, 5.5), false);
  assert.equal(isAbnormalLabResult("3.4", 3.5, 5.5), true);
  assert.equal(isAbnormalLabResult("5.6", 3.5, 5.5), true);
  assert.equal(isAbnormalLabResult("4.5", 3.5, 5.5), false);
});
