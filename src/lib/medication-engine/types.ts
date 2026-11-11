export type DoseRounding = {
  incrementMg: number;
  mode: "nearest" | "down" | "up";
};

export type DoseBasis =
  | { kind: "fixed"; amountMg: number; dosesPerDay: number; maxPerDoseMg?: number; maxPerDayMg?: number }
  | { kind: "mg_per_kg_per_dose"; amountMgPerKg: number; dosesPerDay: number; maxPerDoseMg?: number; maxPerDayMg?: number }
  | { kind: "mg_per_kg_per_day"; amountMgPerKgPerDay: number; dosesPerDay: number; maxPerDoseMg?: number; maxPerDayMg?: number };

export type DoseCalculationInput = {
  basis: DoseBasis;
  /** Encounter-linked measured weight only; never a patient-master fallback. */
  weightKg?: number | null;
  /** Must be defined by an approved protocol; the engine never infers frequency. */
  rounding?: DoseRounding;
};

export type DoseCalculationResult =
  | { status: "calculated"; doseMg: number; dailyDoseMg: number; uncappedDoseMg: number; appliedCaps: Array<"max_per_dose" | "max_per_day">; rounded: boolean }
  | { status: "needs_data"; missing: ["weight_kg"] }
  | { status: "invalid"; reason: "invalid_rule_parameters" | "invalid_weight" | "calculation_out_of_range" | "rounding_exceeds_safety_cap" | "rounding_not_positive" };
