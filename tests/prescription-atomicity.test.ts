import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  buildMedicineSearchFilter,
  createEmptyPrescriptionDraft,
  createPrescriptionDraftForMedicine,
  editPrescriptionName,
  validatePrescriptionDrafts,
} from "../src/lib/prescription-draft.ts";
import { getPrescriptionAgeAtEncounter } from "../src/lib/prescription-context.ts";
import { parseDispenseQuantity } from "../src/lib/pharmacy-quantity.ts";

const sql = readFileSync(
  new URL("../db/roshan_phase7_atomic_prescription.sql", import.meta.url),
  "utf8",
);
const ui = readFileSync(
  new URL("../src/features/clinic/consultation/components/PrescriptionTab.tsx", import.meta.url),
  "utf8",
);
const prescriptionDraft = readFileSync(
  new URL("../src/lib/prescription-draft.ts", import.meta.url),
  "utf8",
);
const pharmacy = readFileSync(
  new URL("../src/routes/_authenticated/pharmacy.tsx", import.meta.url),
  "utf8",
);
const workflow = readFileSync(
  new URL("../.github/workflows/ci-prescription-atomicity.yml", import.meta.url),
  "utf8",
);

test("prescription RPC contains permission, branch, and least-privilege guards", () => {
  assert.match(sql, /app_has_perm\('pharmacy\.create'\)[\s\S]*app_has_perm\('emr\.create'\)/);
  assert.match(sql, /cross-branch prescription access denied/);
  assert.ok(sql.includes("m.is_active IS TRUE"));
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

test("prescription regression test is run by its dedicated CI workflow", () => {
  assert.match(workflow, /tests\/prescription-atomicity\.test\.ts/);
  assert.match(workflow, /db\/roshan_phase7_atomic_prescription\.sql/);
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
      quantity: "",
      instructions: "",
      dosage_form: "capsule",
      route: "",
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
    quantity: "",
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
  assert.match(prescriptionDraft, /brand_name\.ilike/);
  assert.match(ui, /Could not load medicines/);
  assert.match(ui, /No matching medicines/);
});

test("medicine search removes SQL LIKE wildcards and PostgREST filter grammar", () => {
  assert.equal(
    buildMedicineSearchFilter("amox%_cillin"),
    "name.ilike.%amox cillin%,generic_name.ilike.%amox cillin%,brand_name.ilike.%amox cillin%,strength.ilike.%amox cillin%,dosage_form.ilike.%amox cillin%",
  );
  assert.equal(
    buildMedicineSearchFilter("amox),status.eq.active,(brand"),
    "name.ilike.%amox status.eq.active brand%,generic_name.ilike.%amox status.eq.active brand%,brand_name.ilike.%amox status.eq.active brand%,strength.ilike.%amox status.eq.active brand%,dosage_form.ilike.%amox status.eq.active brand%",
  );
});

test("short medicine search terms do not query a broad catalog", () => {
  assert.equal(buildMedicineSearchFilter(""), null);
  assert.equal(buildMedicineSearchFilter("a"), null);
  assert.equal(buildMedicineSearchFilter("  a  "), null);
});

test("prescription catalog query uses only the sanitized server-side filter", () => {
  assert.match(ui, /buildMedicineSearchFilter\(debouncedSearch\)/);
  assert.match(ui, /query\.or\(medicineFilter\)/);
  assert.match(ui, /enabled: canCreatePrescription && Boolean\(medicineFilter\)/);
});

test("unknown catalog dosage forms do not masquerade as a supported form", () => {
  assert.deepEqual(
    createPrescriptionDraftForMedicine({
      id: "medicine-2",
      name: "Custom liquid",
      dosage_form: "Oral solution 100 mL",
    }),
    {
      medicine_id: "medicine-2",
      name: "Custom liquid",
      dose: "",
      frequency: "",
      duration: "",
      quantity: "",
      instructions: "",
      dosage_form: "",
      route: "",
    },
  );
});

test("prescription completeness requires explicit dosage form and route", () => {
  const draft = {
    ...createEmptyPrescriptionDraft(),
    name: "Amoxicillin",
    dose: "500 mg",
    frequency: "twice daily",
    duration: "5 days",
    quantity: "10",
  };
  assert.equal(validatePrescriptionDrafts([draft]), "missing-dosage-form");
  draft.dosage_form = "capsule";
  assert.equal(validatePrescriptionDrafts([draft]), "missing-route");
  draft.route = "oral";
  assert.equal(validatePrescriptionDrafts([draft]), null);
});

test("prescription age context uses the clinic-local encounter date, not the current date", () => {
  assert.equal(getPrescriptionAgeAtEncounter("2008-11-17", "2026-11-16T22:00:00.000Z")?.years, 18);
  assert.equal(getPrescriptionAgeAtEncounter("2008-11-17", "2026-11-16T21:59:59.000Z")?.years, 17);
  assert.deepEqual(getPrescriptionAgeAtEncounter("2026-11-01", "2026-11-16T22:00:00.000Z"), {
    years: 0,
    days: 16,
  });
});

test("prescription age context fails closed for missing, malformed, future or invalid dates", () => {
  assert.equal(getPrescriptionAgeAtEncounter(null, "2026-11-16T22:00:00.000Z"), null);
  assert.equal(getPrescriptionAgeAtEncounter("2026-02-30", "2026-11-16T22:00:00.000Z"), null);
  assert.equal(getPrescriptionAgeAtEncounter("2026-11-18", "2026-11-16T22:00:00.000Z"), null);
  assert.equal(getPrescriptionAgeAtEncounter("2026-11-01", "not-a-date"), null);
});

test("prescription composer shows encounter age and only the weight recorded for this visit", () => {
  assert.match(ui, /visit_date,patients\(id,full_name,date_of_birth\)/);
  assert.match(ui, /getPrescriptionAgeAtEncounter/);
  assert.match(ui, /Age at visit/);
  assert.match(ui, /Weight recorded for this visit/);
  assert.match(ui, /patientWeight\.toLocaleString/);
  assert.match(ui, /Pediatric safety: no current visit weight is recorded/);
  assert.match(ui, /Could not verify the recorded weight/);
  assert.match(ui, /system does not calculate pediatric doses/);
});

test("generic form, frequency and duration choices are labelled as non-authoritative", () => {
  assert.match(ui, /Catalogue form data does not independently verify/);
  assert.match(ui, /Frequency shortcuts are for data entry only, not treatment recommendations/);
  assert.match(ui, /Duration shortcuts are for data entry only, not treatment recommendations/);
  assert.match(ui, /Route options are generic/);
  assert.match(ui, /does not auto-prescribe doses/);
});

test("patient instructions and complete prescription details remain visible before saving and in print", () => {
  assert.match(ui, /Additional patient instructions \(optional\)/);
  assert.match(ui, /Textarea/);
  assert.match(ui, /shown on the printed prescription and pharmacy queue/);
  assert.match(ui, /i\.dosage_form/);
  assert.match(ui, /i\.route/);
  assert.match(ui, /i\.instructions/);
  assert.match(ui, /item\.instructions/);
  assert.match(ui, /i\.quantity/);
});

test("pharmacy queue displays persisted formulation, route, dose and patient instructions", () => {
  assert.match(
    pharmacy,
    /prescription_items\(id, quantity, medication_name, dose, dosage, frequency, duration, dosage_form, route, instructions,/,
  );
  assert.match(pharmacy, /s\(i, "dose"\) \|\| s\(i, "dosage"\)/);
  assert.match(pharmacy, /s\(i, "dosage_form"\)/);
  assert.match(pharmacy, /s\(i, "route"\)/);
  assert.match(pharmacy, /s\(i, "instructions"\)/);
  assert.match(pharmacy, /Patient instructions:/);
});

test("dispense quantity parser rejects scientific notation and non-whole quantities", () => {
  assert.equal(parseDispenseQuantity("2"), 2);
  assert.equal(parseDispenseQuantity("2.0"), 2);
  assert.equal(parseDispenseQuantity(3), 3);
  for (const value of ["", "0", "-1", "+2", "1e3", "2.5", "Infinity", "NaN"]) {
    assert.equal(parseDispenseQuantity(value), null, `${value} must be rejected`);
  }
  assert.equal(parseDispenseQuantity("2147483648"), null);
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
