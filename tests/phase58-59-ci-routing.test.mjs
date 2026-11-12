import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const packageJson = JSON.parse(readFileSync("package.json", "utf8"));
const ci = readFileSync(".github/workflows/ci.yml", "utf8");
const phase58 = readFileSync(".github/workflows/ci-phase58-sdg-currency.yml", "utf8");
const phase59 = readFileSync(".github/workflows/ci-phase59-receipt-currency.yml", "utf8");

test("Phase 58 and 59 PostgreSQL integration is not duplicated in the always-on CI workflow", () => {
  assert.doesNotMatch(ci, /^  phase58-sdg-currency-provenance:/m);
  assert.doesNotMatch(ci, /^  phase59-receipt-currency-provenance:/m);
});

test("Phase 58 PostgreSQL integration runs only when its migration contract changes or manually", () => {
  assert.match(phase58, /workflow_dispatch:/);
  assert.match(phase58, /pull_request:\s*paths:/);
  assert.match(phase58, /db\/roshan_phase58_single_sdg_currency_provenance\.sql/);
  assert.match(phase58, /db\/tests\/phase58_sdg_currency_provenance_integration\.sql/);
  assert.match(phase58, /image: postgres:17/);
  assert.doesNotMatch(phase58, /node --test/);
});

test("Phase 59 PostgreSQL integration remains path-filtered and runs on PostgreSQL 17", () => {
  assert.match(phase59, /pull_request:\s*paths:/);
  assert.match(phase59, /db\/roshan_phase59_receipt_currency_provenance\.sql/);
  assert.match(phase59, /db\/tests\/phase59_receipt_currency_integration\.sql/);
  assert.match(phase59, /image: postgres:17/);
  assert.doesNotMatch(phase59, /node --test/);
});

test("Phase 58 and 59 source-contract tests remain in the normal test guard", () => {
  assert.match(
    packageJson.scripts["test:guard"],
    /tests\\/phase58-sdg-currency-provenance\\.test\\.mjs/,
  );
  assert.match(
    packageJson.scripts["test:guard"],
    /tests\\/phase59-receipt-currency-provenance\\.test\\.mjs/,
  );
  assert.match(packageJson.scripts["test:guard"], /tests\/phase58-59-ci-routing\.test\.mjs/);
});
