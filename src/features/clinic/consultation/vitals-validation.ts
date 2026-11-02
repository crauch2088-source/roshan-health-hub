export const NUMERIC_VITAL_FIELDS = [
  "bp_systolic",
  "bp_diastolic",
  "pulse",
  "respiratory_rate",
  "temperature",
  "spo2",
  "weight",
  "height",
] as const;

export type NumericVitalField = (typeof NUMERIC_VITAL_FIELDS)[number];

export type VitalValidationCode =
  | "invalid-number"
  | "negative"
  | "must-be-positive"
  | "above-maximum";

export type VitalValidationIssue = {
  field: NumericVitalField;
  code: VitalValidationCode;
};

const STRICTLY_POSITIVE_FIELDS = new Set<NumericVitalField>(["weight", "height"]);

/**
 * Validate data integrity without rejecting clinically critical observations.
 *
 * Zero remains recordable for blood pressure, pulse, respiratory rate,
 * temperature and SpO2 (for example, an arrest/apnea or absent reading).
 * Negative values are never meaningful measurements. SpO2 is bounded at
 * 100%, while a supplied weight or height must be greater than zero.
 * No upper clinical cutoffs are imposed on other vital signs.
 */
export function validateVitals(fields: Record<string, string>): VitalValidationIssue[] {
  const issues: VitalValidationIssue[] = [];

  for (const field of NUMERIC_VITAL_FIELDS) {
    const raw = fields[field] ?? "";
    if (!raw.trim()) continue;

    const value = Number(raw);
    if (!Number.isFinite(value)) {
      issues.push({ field, code: "invalid-number" });
      continue;
    }

    if (value < 0) {
      issues.push({ field, code: "negative" });
      continue;
    }

    if (STRICTLY_POSITIVE_FIELDS.has(field) && value === 0) {
      issues.push({ field, code: "must-be-positive" });
      continue;
    }

    if (field === "spo2" && value > 100) {
      issues.push({ field, code: "above-maximum" });
    }
  }

  return issues;
}
