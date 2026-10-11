/** Shared types for the consultation workspace. */

export type QuickOption = {
  value: string;
  label: string;
  labelAr: string;
};

export type RxItem = {
  medicine_id?: string | undefined;
  medicine_name?: string | undefined;

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