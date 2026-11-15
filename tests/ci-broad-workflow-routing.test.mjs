import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const contracts = [
  {
    workflow: ".github/workflows/ci-insurance-claim-integrity.yml",
    required: [
      "db/roshan_phase5_insurance_claim_amount_integrity.sql",
      "db/roshan_phase5_insurance_coverage_validity.sql",
      "db/tests/insurance_claim_rpc_fixture.sql",
      "db/tests/insurance_claim_rpc_integration.sql",
      "db/tests/insurance_coverage_validity.sql",
      "db/tests/roshan_insurance_claim_amount_integrity_test.sql",
    ],
  },
  {
    workflow: ".github/workflows/ci-prescription-atomicity.yml",
    required: [
      "db/roshan_phase7_atomic_prescription.sql",
      "db/tests/prescription_rpc_fixture.sql",
      "db/tests/prescription_rpc_integration.sql",
      "tests/prescription-atomicity.test.ts",
    ],
  },
  {
    workflow: ".github/workflows/ci-privileged-role-guard.yml",
    required: [
      "db/roshan_security_privileged_role_guard.sql",
      "db/tests/privileged_role_guard_fixture.sql",
      "db/tests/privileged_role_guard_integration.sql",
      "tests/privileged-role-guard-sql.test.ts",
    ],
  },
  {
    workflow: ".github/workflows/ci-insurance-claim-validation.yml",
    required: [
      "src/lib/insurance-validation.ts",
      "tests/insurance-claim-validation.test.ts",
      "package.json",
      "package-lock.json",
    ],
  },
];

for (const contract of contracts) {
  test(`${contract.workflow} runs only for its own regression inputs`, () => {
    const workflow = readFileSync(contract.workflow, "utf8");
    const pullRequestStart = workflow.indexOf("  pull_request:");
    const pushStart = workflow.indexOf("\n  push:", pullRequestStart);
    assert.notEqual(pullRequestStart, -1, "pull_request trigger must exist");
    assert.notEqual(pushStart, -1, "branch-specific push trigger must remain");
    const pullRequest = workflow.slice(pullRequestStart, pushStart);

    assert.match(pullRequest, /paths:/);
    for (const path of contract.required) {
      assert.ok(pullRequest.includes(path), `missing scoped path: ${path}`);
    }
    assert.ok(
      pullRequest.includes(contract.workflow),
      "workflow changes must validate their own routing",
    );
    assert.doesNotMatch(pullRequest, /['"](?:db|tests)\/\*\*['"]/);
  });
}
