export type PrescriptionDraft = {
  medicine_id: string;
  name: string;
  dose: string;
  frequency: string;
  duration: string;
  quantity: string;
  instructions: string;
  dosage_form: string;
  route: string;
};

export function createEmptyPrescriptionDraft(): PrescriptionDraft {
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
  };
}

/** Select a medicine without carrying a previous medicine's regimen into it. */
export function createPrescriptionDraftForMedicine(medicine: {
  id: string;
  name?: string | null;
  generic_name?: string | null;
  dosage_form?: string | null;
}): PrescriptionDraft {
  const rawForm = medicine.dosage_form?.trim().toLowerCase() ?? "";
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
  const dosageForm = supportedForms.has(rawForm) ? rawForm : "";
  const oralForms = new Set(["tablet", "capsule", "syrup", "suspension"]);
  const route = oralForms.has(dosageForm) ? "oral" : "";

  return {
    ...createEmptyPrescriptionDraft(),
    medicine_id: medicine.id,
    name: medicine.name?.trim() || medicine.generic_name?.trim() || "",
    dosage_form: dosageForm,
    route,
  };
}

/** A manual name edit detaches a catalog medicine and clears its old regimen. */
export function editPrescriptionName(draft: PrescriptionDraft, name: string): PrescriptionDraft {
  if (draft.medicine_id && name.trim() !== draft.name.trim()) {
    return { ...createEmptyPrescriptionDraft(), name };
  }
  return { ...draft, name };
}

/** Build a safe PostgREST OR filter for user-entered medicine catalog text. */
export function buildMedicineSearchFilter(term: string): string | null {
  const clean = term
    .replace(/[(),*%_\\'"]/g, " ")
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

export type PrescriptionValidationError =
  | "empty"
  | "missing-name"
  | "missing-dose"
  | "missing-frequency"
  | "missing-duration"
  | "invalid-quantity";

/** Validates completeness only; deliberately does not recommend a dose or regimen. */
export function validatePrescriptionDrafts(
  items: PrescriptionDraft[],
): PrescriptionValidationError | null {
  if (items.length === 0) return "empty";
  for (const item of items) {
    if (!item.name.trim()) return "missing-name";
    if (!item.dose.trim()) return "missing-dose";
    if (!item.frequency.trim()) return "missing-frequency";
    if (!item.duration.trim()) return "missing-duration";
    const quantity = Number(item.quantity);
    if (!Number.isInteger(quantity) || quantity < 1) return "invalid-quantity";
  }
  return null;
}
