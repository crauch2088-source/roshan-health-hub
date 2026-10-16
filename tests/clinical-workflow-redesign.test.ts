import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { createEmptyPrescriptionDraft, validatePrescriptionDrafts } from "../src/lib/prescription-draft.ts";
import { labWorkflowStage } from "../src/lib/lab-workflow.ts";

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
  assert.match(ui, /event\.key === "ArrowLeft"/);
  assert.match(ui, /lang === "ar" \? item\.ar : item\.en/);
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
