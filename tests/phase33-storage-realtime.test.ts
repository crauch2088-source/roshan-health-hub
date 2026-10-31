import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = read("../db/roshan_phase34_consolidated_storage_realtime_and_lab_verify.sql");
const fixture = read("../db/tests/phase33_storage_realtime_fixture.sql");
const integration = read("../db/tests/phase33_storage_realtime_assertions.sql");
const ci = read("../.github/workflows/ci.yml");
const consultation = read("../src/features/clinic/consultation/ConsultationPage.tsx");
const history = read("../src/features/clinic/consultation/components/HistoryTab.tsx");
const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
const mapper = read("../src/lib/lab-workflow.ts");

test("consultation query failures are visible and retryable and visit state resets", () => {
  assert.match(consultation, /visitQ\.error/);
  assert.match(consultation, /visitQ\.refetch\(\)/);
  assert.match(consultation, /invoiceQ\.refetch\(\)/);
  assert.match(
    consultation,
    /setReviewChecks\(\{ identity: false, history: false, vitals: false, plan: false \}\)/,
  );
  assert.match(consultation, /<section\s+key=\{visitId\}/);
  assert.match(consultation, /<HistoryTab visitId=\{visitId\}/);
  assert.match(history, /visits\.error/);
  assert.match(history, /visits\.refetch\(\)/);
  assert.match(
    read("../src/features/clinic/consultation/components/ClinicalNoteTab.tsx"),
    /noteQ\.refetch\(\)/,
  );
  assert.match(
    read("../src/features/clinic/consultation/components/PrescriptionTab.tsx"),
    /medsQ\.refetch\(\)/,
  );
  assert.match(
    read("../src/features/clinic/consultation/components/LaboratoryTab.tsx"),
    /testsQ\.refetch\(\)/,
  );
  assert.match(lab, /setValues\(v\)/);
  assert.match(lab, /setComments\(c\)/);
});

test("typed mapper and server verification contract stay aligned", () => {
  assert.match(mapper, /kind: "empty"/);
  assert.match(mapper, /kind: "numeric"/);
  assert.match(mapper, /kind: "coded"/);
  assert.match(mapper, /kind: "text"/);
  assert.match(mapper, /critical-high/);
  assert.match(mapper, /verifyLabOrder/);
  assert.match(lab, /supabase\.rpc\("verify_lab_order"/);
  assert.doesNotMatch(lab, /\.from\("lab_orders"\)\s*\.update\(\{\s*status:\s*"verified"/);
});

test("Phase 34 consolidates Storage, Realtime, verification and audit boundaries", () => {
  assert.match(migration, /public\s*=\s*false/i);
  assert.match(migration, /private\.app_has_branch_access/);
  assert.match(migration, /public\.app_has_perm/);
  assert.match(migration, /storage\.objects/);
  assert.match(migration, /DO \$storage_policies\$[\s\S]*EXCEPTION WHEN insufficient_privilege/);
  assert.match(
    migration,
    /DO \$storage_boundary_guard\$[\s\S]*EXCEPTION WHEN insufficient_privilege/,
  );
  assert.match(
    migration,
    /DO \$realtime_policy_guard\$[\s\S]*EXCEPTION WHEN insufficient_privilege/,
  );
  assert.doesNotMatch(migration, /ALTER TABLE storage\.objects ENABLE ROW LEVEL SECURITY/i);
  assert.match(migration, /realtime\.messages/);
  assert.match(migration, /public\.visits/);
  assert.match(migration, /supabase_realtime/);
  assert.match(migration, /public\.verify_lab_order/);
  assert.match(migration, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(migration, /audit_logs is append-only/);
  assert.match(migration, /phase34_lab_results_no_mutation_after_verify_update/);
  assert.doesNotMatch(migration, /jewzonxplxhogqrnhosl|service_role_key|SUPABASE_URL/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS storage/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS realtime/i);
  assert.match(integration, /cross-branch storage object leaked/i);
  assert.match(integration, /verify_lab_order/);
  assert.match(integration, /audit log UPDATE was not blocked/);
  assert.match(ci, /phase33-storage-realtime/);
  assert.match(ci, /roshan_phase34_consolidated_storage_realtime_and_lab_verify\.sql/);
  assert.match(consultation, /useBranchRealtime\(s\(visit, "branch_id"\)/);
  assert.match(
    read("../src/routes/_authenticated/queue.tsx"),
    /useBranchRealtime\(realtimeBranchId\)/,
  );
  assert.match(
    read("../src/routes/_authenticated/lab.tsx"),
    /useBranchRealtime\(realtimeBranchId\)/,
  );
  assert.match(
    read("../src/routes/_authenticated/certificates.tsx"),
    /useBranchRealtime\(realtimeBranchId\)/,
  );
});

test("Phase 48 Storage policies bind lab orders and certificates while generic attachments remain fail-closed", () => {
  const binding = read("../db/roshan_phase48_storage_entity_branch_binding.sql");
  const assertions = read("../db/tests/phase48_storage_entity_branch_binding_assertions.sql");
  const workflow = read("../.github/workflows/ci-phase48-storage-entity-branch-binding.yml");
  const storagePath = read("../src/lib/storage-path.ts");

  assert.ok(
    binding.includes("CREATE OR REPLACE FUNCTION private.phase48_storage_entity_branch_matches"),
  );
  assert.ok(binding.includes("SECURITY DEFINER\nSET search_path TO ''"));
  assert.ok(binding.includes("private.phase48_storage_entity_branch_matches(_bucket_id, _path)"));
  assert.ok(
    binding.includes("public.lab_orders") && binding.includes("lo.branch_id = v_branch_id"),
  );
  assert.ok(
    binding.includes("public.medical_certificates") && binding.includes("c.id = v_certificate_id"),
  );
  assert.ok(
    binding.includes(
      "WHEN 'roshan-clinical-attachments' THEN\n      -- No approved uploader/entity contract exists for this bucket yet.\n      -- Keep every operation fail-closed until a real call site is reviewed.\n      RETURN false;",
    ),
  );
  assert.doesNotMatch(binding, /FROM public\.attachments/);
  assert.doesNotMatch(storagePath, /roshan-clinical-attachments|clinical-attachments/);
  assert.ok(
    binding.includes(
      "REVOKE ALL ON FUNCTION private.phase48_storage_entity_branch_matches(text, text)",
    ) && binding.includes("FROM PUBLIC, anon, authenticated, service_role"),
  );

  assert.ok(
    assertions.includes("branch-A writer cannot place a branch-B entity under a branch-A prefix"),
  );
  assert.ok(assertions.includes("Well-formed paths that reference missing rows fail closed."));
  assert.ok(assertions.includes("generic clinical-attachments bucket remains fail-closed"));
  assert.ok(
    assertions.includes("branch-A reader must not see pre-existing generic clinical-attachments objects"),
  );
  assert.ok(assertions.includes("Storage UPDATE rebound"));
  assert.ok(workflow.includes("image: postgres:17"));
  assert.ok(workflow.includes("phase48_storage_entity_branch_binding_assertions.sql"));
  assert.ok(workflow.includes("node --test --experimental-strip-types"));
});
