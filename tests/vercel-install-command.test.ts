import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

type VercelConfig = {
  installCommand?: string;
  ignoreCommand?: string;
};

const vercelConfig = JSON.parse(
  readFileSync(new URL("../vercel.json", import.meta.url), "utf8"),
) as VercelConfig;
const ciWorkflow = readFileSync(
  new URL("../.github/workflows/ci.yml", import.meta.url),
  "utf8",
);

test("Vercel installs from the lockfile with a clean npm ci", () => {
  assert.equal(vercelConfig.installCommand, "npm ci");
});

test("Vercel's ignore guard rebuilds when vercel.json changes", () => {
  const trackedPaths = vercelConfig.ignoreCommand?.split(/\s+/) ?? [];
  assert.ok(
    trackedPaths.includes("vercel.json"),
    "vercel.json must be in the ignore-command path list so install changes trigger a preview",
  );
});

test("clinical E2E remains manually gated until QA readiness is explicitly enabled", () => {
  assert.match(
    ciWorkflow,
    /workflow_dispatch:\s*inputs:\s*run_clinical_e2e_acceptance:[\s\S]*?default:\s*false/,
  );
  assert.match(
    ciWorkflow,
    /clinical-e2e-acceptance:\s*\n\s+name:[^\n]*\n\s+if:\s*github\.event_name == 'workflow_dispatch' && inputs\.run_clinical_e2e_acceptance == true && vars\.CLINICAL_E2E_QA_READY == 'true'/,
  );
});
