import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  createEmptyPrescriptionDraft,
  createPrescriptionDraftForMedicine,
  editPrescriptionName,
} from "../src/lib/prescription-draft.ts";

const sql = readFileSync(
  new URL("../db/roshan_phase7_atomic_prescription.sql", import.meta.url),
  "utf8",
);
const ui = readFileSync(
  new URL("../src/features/clinic/consultation/components/PrescriptionTab.tsx", import.meta.url),
  "utf8",
);
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  scripts?: Record<string, string>;
};

test("prescription RPC contains permission, branch, and least-privilege guards", () => {
  assert.match(sql, /app_has_perm\('pharmacy\.create'\)[\s\S]*app_has_perm\('emr\.create'\)/);
  assert.match(sql, /cross-branch prescription access denied/);
  assert.match(sql, /m\\.is_active IS TRUE/);
  assert.match(sql, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(sql, /REVOKE ALL ON FUNCTION[\s\S]*FROM anon/);
  assert.match(sql, /GRANT EXECUTE ON FUNCTION[\s\S]*TO authenticated/);
});

test("prescription save uses a single atomic RPC", () => {
  const start = ui.indexOf("const save = useSave(");
  const end = ui.indexOf("\n\n  return (", start);
  assert.ok(start >= 0 && end > start);
  const handler = ui.slice(start, end);
  assert.match(handler, /rpc\("create_prescription_atomic"/);
  assert.doesNotMatch(handler, /\.from\("prescriptions"\)\.insert/);
  assert.doesNotMatch(handler, /\.from\("prescription_items"\)\.insert/);
});

test("prescription regression test is included in the guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /prescription-atomicity\.test\.ts/);
});

test("new medicine selection starts with a clean regimen", () => {
  assert.deepEqual(
    createPrescriptionDraftForMedicine({
      id: "medicine-1",
      name: "",
      generic_name: "Amoxicillin",
      dosage_form: "Capsule",
    }),
    {
      medicine_id: "medicine-1",
      name: "Amoxicillin",
      dose: "",
      frequency: "",
      duration: "",
      quantity: "1",
      instructions: "",
      dosage_form: "Capsule",
      route: "Oral",
    },
  );
});

test("adding an item can reset every regimen field for the next medicine", () => {
  assert.deepEqual(createEmptyPrescriptionDraft(), {
    medicine_id: "",
    name: "",
    dose: "",
    frequency: "",
    duration: "",
    quantity: "1",
    instructions: "",
    dosage_form: "",
    route: "",
  });
});

test("prescription medicine lookup is debounced, sanitized, and server-side", () => {
  assert.match(ui, /useDebounced\(search, 300\)/);
  assert.match(ui, /sanitizeTerm\(debouncedSearch\)/);
  assert.match(ui, /\.limit\(30\)/);
  assert.doesNotMatch(ui, /\.limit\(500\)/);
  assert.match(ui, /brand_name\.ilike/);
  assert.match(ui, /Could not load medicines/);
  assert.match(ui, /No matching medicines/);
});

test("successful prescription save clears the draft to prevent accidental duplicate submission", () => {
  assert.match(
    ui,
    /onDone:\s*\(\)\s*=>\s*\{[\s\S]*?setItems\(\[\]\)[\s\S]*?setForm\(createEmptyPrescriptionDraft\(\)\)[\s\S]*?setSearch\(""\)/,
  );
});

test("editing a selected medicine name clears its catalog link and old regimen", () => {
  const selected = createPrescriptionDraftForMedicine({
    id: "medicine-1",
    name: "Amoxicillin",
    dosage_form: "Capsule",
  });
  const edited = editPrescriptionName(
    {
      ...selected,
      dose: "500 mg",
      frequency: "twice daily",
      duration: "5 days",
      instructions: "after food",
    },
    "Custom medicine",
  );
  assert.equal(edited.medicine_id, "");
  assert.equal(edited.name, "Custom medicine");
  assert.equal(edited.dose, "");
  assert.equal(edited.frequency, "");
  assert.equal(edited.duration, "");
  assert.equal(edited.instructions, "");
});
