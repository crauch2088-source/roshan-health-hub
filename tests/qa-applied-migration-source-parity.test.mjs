import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";

const manifest = JSON.parse(
  readFileSync(new URL("../db/qa-applied-migration-source-parity.json", import.meta.url), "utf8"),
);

function normalize(sql) {
  return sql
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/--[^\n]*/g, " ")
    .replace(/\s+/g, "")
    .toLowerCase()
    .replace(/^(begin;|begintransaction;|starttransaction;)+/, "")
    .replace(/(commit;|end;)+$/, "");
}

test("QA-applied pharmacy migration sources match the recorded SQL hashes", () => {
  assert.equal(manifest.environment, "QA");
  assert.equal(manifest.entries.length, 5);

  for (const entry of manifest.entries) {
    const source = readFileSync(new URL(`../${entry.source_path}`, import.meta.url), "utf8");
    const actual = createHash("sha256").update(normalize(source), "utf8").digest("hex");
    assert.equal(actual, entry.normalized_sha256, `${entry.version} ${entry.name} source drift`);
    assert.equal(entry.qa_applied, true);
    assert.equal(entry.production_applied, false);
  }
});

test("Phase 61 keeps historical permission checks; Phase 61B owns role-boundary logic", () => {
  const phase61Source = readFileSync(
    new URL("../db/roshan_phase61_prescription_item_correction_workflow.sql", import.meta.url),
    "utf8",
  );
  const phase61bSource = readFileSync(
    new URL("../db/roshan_phase61b_clinical_role_boundary.sql", import.meta.url),
    "utf8",
  );

  assert.doesNotMatch(phase61Source, /CREATE OR REPLACE FUNCTION private\.app_has_role_permission/);
  assert.match(phase61Source, /public\.app_has_perm\('pharmacy\.correction\.request'\)/);
  assert.match(phase61Source, /public\.app_has_perm\('prescriptions\.correction\.resolve'\)/);
  assert.match(phase61bSource, /CREATE OR REPLACE FUNCTION private\.app_has_role_permission/);
});
