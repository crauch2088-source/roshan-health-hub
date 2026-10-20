import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const routes = {
  queue: read("../src/routes/_authenticated/queue.tsx"),
  consultation: read("../src/features/clinic/consultation/ConsultationPage.tsx"),
  lab: read("../src/routes/_authenticated/lab_.$orderId.tsx"),
  certificates: read("../src/routes/_authenticated/certificates.tsx"),
  pharmacy: read("../src/routes/_authenticated/pharmacy.tsx"),
  billing: read("../src/routes/_authenticated/billing.tsx"),
};
const acceptance = read("../db/tests/clinical_e2e_acceptance_workflow.sql");
const securityFixture = read("../db/tests/clinical_security_hardening_fixture.sql");
const clinicalRls = read("../tests/clinical-rls.test.ts");

test("synthetic PostgreSQL acceptance includes the five operational role identities", () => {
  for (const role of ["receptionist", "doctor", "lab_technician", "pharmacist", "billing"]) {
    assert.match(
      acceptance + securityFixture,
      new RegExp(role),
      `missing synthetic role fixture: ${role}`,
    );
  }
  assert.match(acceptance, /request\.jwt\.claim\.sub/);
  assert.match(acceptance, /ROLLBACK;/);
  assert.match(acceptance, /billing\.create/);
  assert.doesNotMatch(
    acceptance,
    /jewzonxplxhogqrnhosl|supabase\.co|roshan-health-hub\.vercel\.app/i,
  );
});

test("role gates and branch-aware subscriptions remain present on clinical workflow routes", () => {
  assert.match(routes.queue, /PermissionGate perm="queue\.read"/);
  assert.match(routes.lab, /PermissionGate perm="lab\.read"/);
  assert.match(routes.certificates, /PermissionGate perm="certificates\.read"/);
  assert.match(routes.pharmacy, /PermissionGate perm="pharmacy\.read"/);
  assert.match(routes.billing, /PermissionGate perm="billing\.read"/);
  for (const [name, source] of Object.entries(routes)) {
    assert.match(source, /useBranchRealtime\(/, `${name} lost branch-aware realtime scoping`);
  }
  assert.match(routes.queue, /can\("visits\.update"\)/);
  assert.match(routes.lab, /can\("lab\.update"\)/);
  assert.match(routes.certificates, /can\("certificates\.create"\)/);
  assert.match(routes.pharmacy, /can\("pharmacy\.update"\)/);
  assert.match(routes.billing, /can\("billing\.create"\)/);
  assert.match(clinicalRls, /branch_id|branch/i);
});

test("workflow contracts cover visit, lab verification, certificate print, dispensing, billing and attachments", () => {
  assert.match(routes.consultation, /complete_visit_atomic/);
  assert.match(routes.lab, /verifyLabOrder/);
  assert.match(routes.certificates, /create_medical_certificate/);
  assert.match(routes.certificates, /window\.print\(\)/);
  assert.match(routes.pharmacy, /dispensePrescriptionFefo/);
  assert.match(routes.billing, /billing\.create/);
  assert.match(routes.lab, /ClinicalAttachmentUploader/);
  assert.match(routes.certificates, /ClinicalAttachmentUploader/);
  assert.match(acceptance, /public\.complete_visit_atomic/);
  assert.match(acceptance, /public\.complete_lab_order_item/);
  assert.match(acceptance, /certificate serial was not generated/);
  assert.match(acceptance, /pharmacist certificate issuance unexpectedly succeeded/);
});

test("language, mobile viewport and runtime error checks are explicit in the manual browser checklist", () => {
  const guide = read("../docs/PRODUCTION_BROWSER_SMOKE_CHECKLIST.md");
  assert.match(guide, /Arabic.*English|Arabic.*→ English/i);
  assert.match(guide, /RTL/i);
  assert.match(guide, /LTR/i);
  assert.match(guide, /390 × 844/);
  assert.match(guide, /console\.error/);
  assert.match(guide, /unhandledrejection/);
  assert.match(guide, /signed URL/i);
});
