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
  const dosageForm = medicine.dosage_form?.trim() ?? "";
  const form = dosageForm.toLowerCase();
  const route =
    form.includes("tablet") || form.includes("capsule") || form.includes("syrup") ? "Oral" : "";

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
