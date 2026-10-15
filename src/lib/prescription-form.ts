export type PrescriptionEntry = {
  medicine_id: string;
  name: string;
  dose: string;
  frequency: string;
  duration: string;
  quantity: string;
  instructions: string;
  dosage_form: string;
  route: string;
  unit_price: number;
};

export type MedicineSearchOption = {
  id: string;
  name?: string | null;
  generic_name?: string | null;
  dosage_form?: string | null;
  selling_price?: number | string | null;
};

export function createEmptyPrescriptionEntry(): PrescriptionEntry {
  return {
    medicine_id: "",
    name: "",
    dose: "",
    frequency: "",
    duration: "",
    quantity: "1",
    instructions: "",
    dosage_form: "",
    route: "",
    unit_price: 0,
  };
}

/** Start a fresh regimen when the selected medicine changes. */
export function preparePrescriptionEntryForMedicine(
  previous: PrescriptionEntry,
  medicine: MedicineSearchOption,
): PrescriptionEntry {
  const dosageForm = (medicine.dosage_form ?? "").trim().toLowerCase();
  const supportedForms = new Set([
    "tablet",
    "capsule",
    "syrup",
    "suspension",
    "drops",
    "injection",
    "cream",
    "ointment",
    "gel",
    "lotion",
    "suppository",
    "inhaler",
    "solution",
    "sachet",
  ]);
  const canonicalForm = supportedForms.has(dosageForm) ? dosageForm : "";
  const oralForms = new Set(["tablet", "capsule", "syrup", "suspension"]);
  const empty = createEmptyPrescriptionEntry();

  // The fresh template intentionally discards the previous medicine's regimen.
  void previous;
  return {
    ...empty,
    medicine_id: medicine.id,
    name: medicine.name?.trim() || medicine.generic_name?.trim() || "",
    dosage_form: canonicalForm,
    route: oralForms.has(canonicalForm) ? "oral" : "",
    unit_price: Number(medicine.selling_price) || 0,
  };
}

/** Detach a manually edited name from the catalog medicine and its price. */
export function updatePrescriptionEntryName(
  previous: PrescriptionEntry,
  name: string,
): PrescriptionEntry {
  if (name === previous.name) return previous;
  return { ...previous, name, medicine_id: "", unit_price: 0 };
}

/** Build a safe PostgREST OR filter from user-entered catalog text. */
export function buildMedicineSearchFilter(term: string): string | null {
  const clean = term
    .replace(/[(),*\\'"]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (clean.length < 2) return null;

  const pattern = "%" + clean + "%";
  return [
    "name.ilike." + pattern,
    "generic_name.ilike." + pattern,
    "brand_name.ilike." + pattern,
    "strength.ilike." + pattern,
  ].join(",");
}
