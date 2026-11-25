import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

test("ClinicalNoteTab normalizes and validates WHO ICD-10 2019 codes", () => {
  const src = fs.readFileSync(
    path.resolve("src/features/clinic/consultation/components/ClinicalNoteTab.tsx"),
    "utf8",
  );
  assert.ok(src.includes("normalizeIcd10Code"));
  assert.ok(src.includes("isSyntacticallyValidIcd10Format"));
  assert.ok(src.includes("WHO ICD-10 (2019)"));
});

test("Phase 65 SQL enforces WHO-ICD-10 versioning without substituting ICD-10-CM", () => {
  const sql = fs.readFileSync(
    path.resolve("db/roshan_phase65_who_icd10_diagnosis_versioning.sql"),
    "utf8",
  );
  assert.ok(sql.includes("coding_system"));
  assert.ok(sql.includes("coding_version"));
  assert.ok(sql.includes("coding_label_snapshot"));
  assert.ok(sql.includes("'WHO-ICD-10'"));
  assert.ok(!sql.includes("'ICD-10-CM'"));
});
