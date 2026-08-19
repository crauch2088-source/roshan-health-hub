/** Shared types for the consultation workspace. */

export type QuickOption = {
  en: string;
  ar: string;
};

export type RxItem = {
  medicine_id?: string;
  medicine_name?: string;

  dosage: string;
  dosage_form: string;
  route: string;
  frequency: string;
  duration: string;
  quantity: string;
  instructions: string;
};

export function emptyRxItem(): RxItem {
  return {
    medicine_id: undefined,
    medicine_name: "",

    dosage: "",
    dosage_form: "",
    route: "",
    frequency: "",
    duration: "",
    quantity: "1",
    instructions: "",
  };
}