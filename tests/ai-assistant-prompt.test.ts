import assert from "node:assert/strict";
import { test } from "node:test";

import {
  isSensitivePromptColumn,
  sanitizePromptValue,
  withinBudget,
} from "../src/lib/ai/prompt-utils.ts";

test("prompt budget renders row-context objects as text, not object coercions", () => {
  assert.equal(
    withinBudget(
      [
        "Visit: status=in_progress",
        { text: "Vitals:\n[W1] blood_pressure=120/80", legend: ["W1"] },
        "Draft the note.",
      ],
      1000,
    ),
    "Visit: status=in_progress\n\nVitals:\n[W1] blood_pressure=120/80\n\nDraft the note.",
  );
});

test("prompt budget preserves its maximum length and marks truncation", () => {
  assert.equal(withinBudget(["abcdefghij"], 5), "abcde\n(truncated)");
  assert.equal(withinBudget(["", "context"], 100), "context");
});

test("prompt redaction recognizes direct and internal identifiers", () => {
  for (const key of [
    "full_name",
    "patientName",
    "phone",
    "national_id",
    "patient_id",
    "branchId",
    "auth_user_id",
  ]) {
    assert.equal(isSensitivePromptColumn(key), true, `${key} must be redacted`);
  }
  assert.equal(isSensitivePromptColumn("allergies"), false);
  assert.equal(isSensitivePromptColumn("blood_group"), false);
});

test("nested relation data is recursively redacted without removing clinical context", () => {
  assert.deepEqual(
    sanitizePromptValue({
      full_name: "Patient QA-ONLY",
      patient_id: "patient-uuid",
      observations: {
        blood_group: "O+",
        allergies: "penicillin",
        phone: "+000000000",
      },
      lab_tests: [{ id: "test-uuid", name: "CBC", status: "pending" }],
    }),
    {
      observations: { blood_group: "O+", allergies: "penicillin" },
      lab_tests: [{ name: "CBC", status: "pending" }],
    },
  );
});
