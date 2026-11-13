import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  "db/roshan_phase61_prescription_item_correction_workflow.sql",
  "utf8",
);
const roleBoundaryMigration = readFileSync("db/roshan_phase61b_clinical_role_boundary.sql", "utf8");
const integration = readFileSync(
  "db/tests/phase61_prescription_correction_integration.sql",
  "utf8",
);
const fixture = readFileSync("db/tests/phase61_prescription_correction_fixture.sql", "utf8");
const workflow = readFileSync(".github/workflows/ci-phase61-prescription-correction.yml", "utf8");
const concurrency = readFileSync("db/tests/phase61_prescription_correction_concurrency.sh", "utf8");

test("Phase 61 exposes only dedicated correction and clinical-prescription permissions", () => {
  assert.match(migration, /pharmacy\.correction\.request/);
  assert.match(migration, /prescriptions\.correction\.resolve/);
  assert.match(migration, /prescriptions\.create/);
  assert.match(migration, /WHERE r\.code = 'pharmacist'/);
  assert.match(migration, /WHERE r\.code = 'doctor'/);
  assert.doesNotMatch(migration, /WHERE r\.code IN \('admin', 'doctor'\)/);
});

test("Phase 61 request and event storage is RLS-protected and direct-write-free", () => {
  assert.match(migration, /ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /FORCE ROW LEVEL SECURITY/);
  assert.match(migration, /REVOKE ALL ON TABLE public\.prescription_item_correction_requests/);
  assert.match(migration, /REVOKE ALL ON TABLE public\.prescription_item_correction_events/);
  assert.match(migration, /BEFORE UPDATE OR DELETE/);
  assert.match(migration, /BEFORE TRUNCATE/);
});

test("Phase 61 RPCs enforce lock order, snapshot validation and explicit actions", () => {
  assert.match(migration, /request_prescription_item_correction/);
  assert.match(migration, /resolve_prescription_item_correction/);
  assert.match(migration, /FOR UPDATE OF p, v, pt/);
  assert.match(migration, /FOR UPDATE/);
  assert.match(migration, /item_snapshot/);
  assert.match(migration, /replace_item/);
  assert.match(migration, /cancel_and_reissue/);
  assert.match(migration, /reject/);
  assert.match(migration, /create_prescription_atomic/);
  assert.match(migration, /app_can_resolve_prescription_item_correction/);
  assert.match(migration, /app_has_role_permission/);
  assert.match(migration, /catalog_medicine_price_invalid/);
  const resolver = migration.slice(
    migration.indexOf("CREATE OR REPLACE FUNCTION public.resolve_prescription_item_correction"),
    migration.indexOf("REVOKE ALL ON FUNCTION public.request_prescription_item_correction"),
  );
  assert.doesNotMatch(resolver, /COALESCE\\(m\\.selling_price,\\s*0\\)/);
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION private\.app_can_resolve_prescription_item_correction/,
  );
});

test("Phase 61 integration covers authorization, no-side-effects and state transitions", () => {
  const assertions = [
    "duplicate request retry did not return the existing request",
    "wrong-branch pharmacist created a correction request",
    "ordinary Admin created a correction request",
    "ordinary Admin created a clinical prescription through the SECURITY DEFINER RPC",
    "invalid item state unexpectedly accepted",
    "partial correction silently removed or linked another unrequested item",
    "request rejection",
    "cancel-and-reissue",
    "Super Admin cannot inherit clinical write authority",
    "correction workflow changed inventory, stock movement or financial tables",
  ];

  for (const assertion of assertions) {
    assert.ok(integration.includes(assertion), `missing regression: ${assertion}`);
  }
});

test("Phase 61 integration fixture uses canonical UUID literals", () => {
  const uuidCandidates = integration.match(/\b[0-9a-f]{8}-[0-9a-f-]{12,}\b/gi) ?? [];

  for (const candidate of uuidCandidates) {
    assert.match(
      candidate,
      /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i,
      `malformed UUID literal in integration fixture: ${candidate}`,
    );
  }
});

test("Phase 61 denies unassigned and wrong-branch doctors", () => {
  assert.ok(integration.includes("unassigned doctor resolved a correction request"));
  assert.ok(integration.includes("wrong-branch doctor resolved a correction request"));
});

test("Phase 61 keeps clinical prescription authoring out of pharmacy.create", () => {
  assert.match(migration, /p_is_external IS NULL/);
  assert.match(migration, /private\.app_has_role_permission/);
  assert.doesNotMatch(
    migration,
    /public\.app_has_perm\('pharmacy\.create'\) OR public\.app_has_perm\('emr\.create'\)/,
  );
  assert.doesNotMatch(migration, /public\.app_has_perm\('emr\.create'\)/);
  assert.ok(integration.includes("pharmacist created an internal prescription"));
  assert.ok(integration.includes("ordinary Admin created a clinical prescription"));
  assert.ok(
    integration.includes("pharmacist created a prescription through the clinical authoring RPC"),
  );
});

test("Phase 61 runs a real two-session concurrent resolution regression", () => {
  assert.ok(workflow.includes("phase61_prescription_correction_concurrency.sh"));
  assert.ok(concurrency.includes("pg_sleep"));
  assert.ok(concurrency.includes("prescription_correction_request_already_resolved"));
  assert.ok(concurrency.includes("stock_movements"));
  assert.ok(concurrency.includes("cashbox_transactions"));
});

test("Phase 61 revokes inherited authenticator table-write privileges", () => {
  for (const table of [
    "prescription_item_correction_requests",
    "prescription_item_correction_events",
  ]) {
    assert.ok(
      migration.includes(
        `REVOKE ALL ON TABLE public.${table}\n  FROM PUBLIC, anon, authenticated, service_role, authenticator;`,
      ),
      `missing authenticator privilege revocation for ${table}`,
    );
  }
  assert.equal(
    integration.split("has_table_privilege('authenticator'").length - 1,
    8,
    "integration must check INSERT/UPDATE/DELETE/TRUNCATE on both tables",
  );
});

test("Phase 61 integration proves the migration itself grants prescription authoring", () => {
  assert.equal(
    fixture.includes("VALUES ('prescriptions.create', 'Create clinical prescriptions'"),
    false,
    "the fixture must not pre-seed the permission that Phase 61 is supposed to create",
  );
  assert.ok(
    integration.includes("doctor is missing the dedicated prescription-authoring permission"),
  );
});


test("Phase 61B wraps unchecked RPCs and denies clinical writes to Super Admin", () => {
  assert.match(
    roleBoundaryMigration,
    /ALTER FUNCTION public\.request_prescription_item_correction/,
  );
  assert.match(roleBoundaryMigration, /request_prescription_item_correction_unchecked/);
  assert.match(roleBoundaryMigration, /resolve_prescription_item_correction_unchecked/);
  assert.match(roleBoundaryMigration, /create_prescription_atomic_unchecked/);
  assert.match(roleBoundaryMigration, /app_has_role_permission/);
  assert.match(
    roleBoundaryMigration,
    /GRANT EXECUTE ON FUNCTION public\.create_prescription_atomic/,
  );
  assert.match(
    roleBoundaryMigration,
    /REVOKE ALL ON FUNCTION private\.create_prescription_atomic_unchecked/,
  );
});
