import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const rootPath = decodeURIComponent(new URL("../", import.meta.url).pathname);
const migration = readFileSync(
  join(rootPath, "db/roshan_phase51_public_setup_required_anon.sql"),
  "utf8",
);
const assertions = readFileSync(
  join(rootPath, "db/tests/phase51_setup_required_anon_assertions.sql"),
  "utf8",
);
const workflow = readFileSync(join(rootPath, ".github/workflows/ci.yml"), "utf8");
const packageJson = JSON.parse(readFileSync(join(rootPath, "package.json"), "utf8"));

test("Phase 51 exposes only the boolean setup status to anonymous bootstrap clients", () => {
  assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION public\.setup_required\(\)[\s\S]*?RETURNS boolean[\s\S]*?LANGUAGE sql[\s\S]*?STABLE[\s\S]*?SECURITY DEFINER[\s\S]*?SET search_path TO ''[\s\S]*?SELECT private\.setup_required\(\)/i,
  );
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.setup_required\(\)[\s\S]*?FROM PUBLIC, anon, authenticated, service_role, authenticator, supabase_auth_admin/i,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION public\.setup_required\(\) TO anon, authenticated/i,
  );
  assert.doesNotMatch(
    migration,
    /CREATE OR REPLACE FUNCTION private\.setup_required/i,
    "the existing private helper must not be replaced or exposed",
  );

  assert.match(assertions, /has_function_privilege\('anon', 'public\.setup_required\(\)', 'EXECUTE'\)/i);
  assert.match(assertions, /has_function_privilege\('anon', 'private\.setup_required\(\)', 'EXECUTE'\)/i);
  assert.match(assertions, /phase51@example\.invalid/);
  assert.match(assertions, /v_required IS DISTINCT FROM true/);
  assert.match(assertions, /v_required IS DISTINCT FROM false/);
  assert.match(assertions, /anon unexpectedly executed private\.setup_required/);
  assert.match(assertions, /ROLLBACK;/);

  const fingerprintCheck = workflow.indexOf(
    "Require exact live-v115 versus replayed catalog match (7/7 SHA-256)",
  );
  const phase51Step = workflow.indexOf(
    "Phase 51 anonymous setup status RPC (PostgreSQL 17)",
  );
  assert.ok(fingerprintCheck >= 0 && phase51Step > fingerprintCheck);
  assert.ok(
    packageJson.scripts["test:guard"].includes("tests/phase51-setup-required-anon.test.ts"),
  );
});

