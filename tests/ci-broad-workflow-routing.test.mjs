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
    pushBranch: "fix/insurance-claim-amount-integrity",
    workflowDispatch: false,
  },
  {
    workflow: ".github/workflows/ci-prescription-atomicity.yml",
    required: [
      "db/roshan_phase7_atomic_prescription.sql",
      "db/tests/prescription_rpc_fixture.sql",
      "db/tests/prescription_rpc_integration.sql",
      "tests/prescription-atomicity.test.ts",
      "src/lib/prescription-draft.ts",
      "src/features/clinic/consultation/components/PrescriptionTab.tsx",
      "package.json",
    ],
    pushBranch: "fix/prescription-atomicity",
    workflowDispatch: false,
  },
  {
    workflow: ".github/workflows/ci-privileged-role-guard.yml",
    required: [
      "db/roshan_security_privileged_role_guard.sql",
      "db/tests/privileged_role_guard_fixture.sql",
      "db/tests/privileged_role_guard_integration.sql",
      "tests/privileged-role-guard-sql.test.ts",
      "package.json",
    ],
    pushBranch: "test/privileged-role-guard-integration",
    workflowDispatch: false,
  },
  {
    workflow: ".github/workflows/ci-insurance-claim-validation.yml",
    required: [
      "src/lib/insurance-validation.ts",
      "tests/insurance-claim-validation.test.ts",
      "package.json",
      "package-lock.json",
    ],
    pushBranch: "fix/insurance-claim-invoice-link",
    workflowDispatch: true,
  },
];

for (const contract of contracts) {
  test(contract.workflow + " routes every consumed input and preserves event semantics", () => {
    const workflow = readFileSync(contract.workflow, "utf8");
    const pullRequestStart = workflow.indexOf("  pull_request:");
    assert.notEqual(pullRequestStart, -1, "pull_request trigger must exist");
    const nextEvent = workflow.slice(pullRequestStart + 1).search(/\n  [a-z_]+:/);
    assert.notEqual(nextEvent, -1, "next top-level event must exist");
    const pullRequest = workflow.slice(pullRequestStart, pullRequestStart + 1 + nextEvent);
    assert.match(pullRequest, /paths:/);
    for (const path of contract.required) {
      assert.ok(pullRequest.includes(path), "missing scoped path: " + path);
    }
    assert.ok(pullRequest.includes(contract.workflow), "workflow must trigger its own validation");
    assert.doesNotMatch(pullRequest, /['"](?:db|tests)\/\*\*['"]/);

    const expectedPush = "  push:\n    branches:\n      - '" + contract.pushBranch + "'";
    assert.ok(workflow.includes(expectedPush), "push branch changed: " + contract.pushBranch);
    assert.equal(
      workflow.includes("  workflow_dispatch:"),
      contract.workflowDispatch,
      "workflow_dispatch behavior changed",
    );
  });
}

test("Node TypeScript test workflows are triggered when package module metadata changes", () => {
  const packageJson = JSON.parse(readFileSync("package.json", "utf8"));
  assert.equal(packageJson.type, "module");
  for (const path of [
    ".github/workflows/ci-prescription-atomicity.yml",
    ".github/workflows/ci-privileged-role-guard.yml",
  ]) {
    const workflow = readFileSync(path, "utf8");
    const pullRequestStart = workflow.indexOf("  pull_request:");
    const pushStart = workflow.indexOf("\n  push:", pullRequestStart);
    assert.ok(
      workflow.slice(pullRequestStart, pushStart).includes("package.json"),
      path + " must rerun when package.json changes",
    );
  }
});
