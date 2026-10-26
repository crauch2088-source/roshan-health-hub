import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { resolveTabKeyNavigation } from "../src/lib/keyboard-shortcuts.ts";

const source = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("auth cache and nav preferences are isolated per user", () => {
  const auth = source("../src/lib/auth.tsx");
  const nav = source("../src/hooks/use-nav-preferences.tsx");

  assert.match(auth, /queryClient\.clear\(\)/);
  assert.match(auth, /event === "SIGNED_OUT"/);
  assert.match(auth, /previousAuthUserId !== nextAuthUserId/);
  assert.match(nav, /favoritesKey\(userId\)/);
  assert.match(nav, /recentsKey\(userId\)/);
  assert.match(nav, /useAuth\(\)/);
  assert.match(nav, /LEGACY_FAVORITES_KEY/);
  assert.match(nav, /if \(!userId\)/);
});

test("consultation fetches and displays allergy, chronic and blood-group context", () => {
  const consultation = source("../src/features/clinic/consultation/ConsultationPage.tsx");

  assert.match(
    consultation,
    /patients\(id,full_name,mrn,gender,date_of_birth,allergies,chronic_conditions,blood_group\)/,
  );
  assert.match(consultation, /Not recorded|غير مسجل/);
  assert.match(consultation, /border-destructive\/30 bg-destructive\/15/);
  assert.match(consultation, /AlertTriangle/);
  assert.match(consultation, /bloodGroup/);
});

test("consultation uses clinic-local date, explicit direction and unsaved-note guard", () => {
  const consultation = source("../src/features/clinic/consultation/ConsultationPage.tsx");

  assert.match(consultation, /p_invoice_date: todayISO\(\)/);
  assert.doesNotMatch(consultation, /new Date\(\)\.toISOString\(\)\.slice\(0, 10\)/);
  assert.match(consultation, /dir=\{lang === "ar" \? "rtl" : "ltr"\}/);
  assert.match(consultation, /useBlocker\(/);
  assert.match(consultation, /enableBeforeUnload:\s*\(\)\s*=>\s*noteDirty/);
});

test("horizontal tab arrows follow LTR ordering", () => {
  assert.equal(resolveTabKeyNavigation("ArrowRight", 1, 5, "ltr"), 2);
  assert.equal(resolveTabKeyNavigation("ArrowLeft", 1, 5, "ltr"), 0);
  assert.equal(resolveTabKeyNavigation("ArrowLeft", 0, 5, "ltr"), 4);
});

test("horizontal tab arrows follow RTL ordering", () => {
  assert.equal(resolveTabKeyNavigation("ArrowLeft", 1, 5, "rtl"), 2);
  assert.equal(resolveTabKeyNavigation("ArrowRight", 1, 5, "rtl"), 0);
  assert.equal(resolveTabKeyNavigation("ArrowRight", 0, 5, "rtl"), 4);
});

test("tab helper supports Home/End and ignores unrelated keys", () => {
  assert.equal(resolveTabKeyNavigation("Home", 3, 5, "ltr"), 0);
  assert.equal(resolveTabKeyNavigation("End", 1, 5, "rtl"), 4);
  assert.equal(resolveTabKeyNavigation("Escape", 1, 5, "ltr"), -1);
});

test("queue completion uses atomic visit RPC and checks both update errors", () => {
  const queue = source("../src/routes/_authenticated/queue.tsx");

  assert.match(queue, /complete_visit_atomic/);
  assert.match(queue, /if \(visitError\) throw new Error\(visitError\.message\)/);
  assert.match(queue, /if \(ticketError\) throw new Error\(ticketError\.message\)/);
  assert.match(queue, /can\("visits\.read"\) && s\(visit, "id"\)/);
  assert.match(queue, /st === "waiting"/);
  assert.match(queue, /st === "called"/);
});

test("pharmacy and billing Realtime receive loaded branch IDs", () => {
  const pharmacy = source("../src/routes/_authenticated/pharmacy.tsx");
  const billing = source("../src/routes/_authenticated/billing.tsx");

  assert.match(pharmacy, /select\(\s*"id, branch_id, status/);
  assert.match(pharmacy, /useBranchRealtime\(realtimeBranchId\)/);
  assert.match(billing, /select\(\s*"id, branch_id, invoice_number/);
  assert.match(billing, /useBranchRealtime\(realtimeBranchId\)/);
  assert.doesNotMatch(pharmacy, /user as Row.*branch_id/);
  assert.doesNotMatch(billing, /user as Row.*branch_id/);
});

test("patient registration can save and open a visit with permission", () => {
  const patients = source("../src/routes/_authenticated/patients.tsx");
  const i18n = source("../src/lib/i18n.tsx");

  assert.match(patients, /rpc<string>\("create_patient_atomic"/);
  assert.match(patients, /openVisit: true/);
  assert.match(patients, /can\("visits\.create"\)/);
  assert.match(patients, /to: "\/visits", search: \{ patient: outcome\.patientId \}/);
  assert.match(i18n, /save_and_new_visit: \{ ar: "حفظ وفتح زيارة", en: "Save & create visit" \}/);
});

test("lab results warn before unload and display identifiers and numeric fields LTR", () => {
  const lab = source("../src/routes/_authenticated/lab_.$orderId.tsx");

  assert.match(lab, /hasUnsavedResultEdits/);
  assert.match(lab, /beforeunload/);
  assert.match(lab, /<bdi dir="ltr">\{s\(patient, "mrn"\)\}<\/bdi>/);
  assert.match(lab, /<TableCell className="w-40" dir="ltr">/);
  assert.match(lab, /<TableCell dir="ltr">/);
});
