import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const readJson = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));

test("Spec Kit is pinned to the official agent-neutral baseline", () => {
  const options = readJson(".specify/init-options.json");
  const integration = readJson(".specify/integration.json");
  assert.equal(options.speckit_version, "1.2.6");
  assert.equal(options.integration, "none");
  assert.equal(options.ai, "none");
  assert.equal(integration.version, "1.2.6");
  assert.equal(integration.integration, "none");
  assert.equal(integration.default_integration, "none");
  assert.deepEqual(integration.installed_integrations, ["none"]);
});

test("official shared files match the Spec Kit managed-file manifest", () => {
  const manifest = readJson(".specify/integrations/speckit.manifest.json");
  assert.equal(manifest.integration, "speckit");
  assert.equal(manifest.version, "1.2.6");
  assert.ok(Object.keys(manifest.files).length >= 10);
  for (const [relativePath, expectedHash] of Object.entries(manifest.files)) {
    const absolutePath = join(root, relativePath);
    assert.ok(existsSync(absolutePath), "missing managed file: " + relativePath);
    const actualHash = createHash("sha256").update(readFileSync(absolutePath)).digest("hex");
    assert.equal(actualHash, expectedHash, "managed file drift: " + relativePath);
  }
});

test("Spec Kit scripts are executable and bundled workflow exists", () => {
  const scripts = [
    ".specify/scripts/bash/check-prerequisites.sh",
    ".specify/scripts/bash/common.sh",
    ".specify/scripts/bash/create-new-feature.sh",
    ".specify/scripts/bash/resolve-template.sh",
    ".specify/scripts/bash/setup-plan.sh",
    ".specify/scripts/bash/setup-tasks.sh",
  ];
  for (const path of scripts) {
    assert.ok(existsSync(join(root, path)), "missing script: " + path);
    assert.ok((statSync(join(root, path)).mode & 0o111) !== 0, "not executable: " + path);
  }
  assert.ok(existsSync(join(root, ".specify/workflows/speckit/workflow.yml")));
  assert.ok(existsSync(join(root, ".specify/workflows/workflow-registry.json")));
});

test("Roshan Constitution and Phase 53 pilot are reviewable but not prematurely planned", () => {
  const constitution = readFileSync(join(root, ".specify/memory/constitution.md"), "utf8");
  const spec = readFileSync(join(root, "specs/001-clinical-document-printing/spec.md"), "utf8");
  assert.match(constitution, /Clinical Safety and Data Fidelity/);
  assert.match(constitution, /Patient Privacy and Least Privilege/);
  assert.match(constitution, /Migration and Production Safety/);
  assert.doesNotMatch(constitution, /\[PROJECT_NAME\]|\[PRINCIPLE_\d/);
  assert.match(spec, /\*\*Status\*\*: Draft/);
  assert.match(spec, /\[NEEDS CLARIFICATION\]/);
  assert.match(spec, /immutable payment ledger/);
  assert.match(spec, /Arabic RTL and English LTR/);
  assert.ok(!existsSync(join(root, "specs/001-clinical-document-printing/plan.md")));
  assert.ok(!existsSync(join(root, "specs/001-clinical-document-printing/tasks.md")));
});
