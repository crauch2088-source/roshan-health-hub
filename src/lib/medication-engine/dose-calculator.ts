import type { DoseBasis, DoseCalculationInput, DoseCalculationResult, DoseRounding } from "./types.ts";

type CapName = "max_per_dose" | "max_per_day";

function positiveFinite(value: number | null | undefined): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}
function normalize(value: number): number {
  return Math.round(value * 1e10) / 1e10;
}
function validRounding(value: DoseRounding | undefined): boolean {
  return value === undefined || (positiveFinite(value.incrementMg) && ["nearest", "down", "up"].includes(value.mode));
}
function roundDose(value: number, rule: DoseRounding): number {
  const units = value / rule.incrementMg;
  if (rule.mode === "down") return normalize(Math.floor(units + 1e-10) * rule.incrementMg);
  if (rule.mode === "up") return normalize(Math.ceil(units - 1e-10) * rule.incrementMg);
  return normalize(Math.round(units) * rule.incrementMg);
}
function validCeiling(value: number | undefined): boolean {
  return value === undefined || positiveFinite(value);
}
function validBasis(basis: DoseBasis): boolean {
  if (!positiveFinite(basis.dosesPerDay) || !validCeiling(basis.maxPerDoseMg) || !validCeiling(basis.maxPerDayMg)) return false;
  if (basis.kind === "fixed") return positiveFinite(basis.amountMg);
  if (basis.kind === "mg_per_kg_per_dose") return positiveFinite(basis.amountMgPerKg);
  return positiveFinite(basis.amountMgPerKgPerDay);
}

/**
 * Pure arithmetic only. It does not select a drug, indication, route,
 * frequency, duration, concentration, volume, or clinical protocol.
 * All quantities are mg and kg. Frequency must be explicitly supplied.
 */
export function calculateDose(input: DoseCalculationInput): DoseCalculationResult {
  if (!validBasis(input.basis) || !validRounding(input.rounding)) {
    return { status: "invalid", reason: "invalid_rule_parameters" };
  }
  const weightBased = input.basis.kind !== "fixed";
  if (weightBased && input.weightKg == null) return { status: "needs_data", missing: ["weight_kg"] };
  if (input.weightKg != null && !positiveFinite(input.weightKg)) {
    return { status: "invalid", reason: "invalid_weight" };
  }

  const basis = input.basis;
  let rawDoseMg: number;
  let rawDailyDoseMg: number;
  if (basis.kind === "fixed") {
    rawDoseMg = basis.amountMg;
    rawDailyDoseMg = rawDoseMg * basis.dosesPerDay;
  } else if (basis.kind === "mg_per_kg_per_dose") {
    rawDoseMg = basis.amountMgPerKg * (input.weightKg as number);
    rawDailyDoseMg = rawDoseMg * basis.dosesPerDay;
  } else {
    rawDailyDoseMg = basis.amountMgPerKgPerDay * (input.weightKg as number);
    rawDoseMg = rawDailyDoseMg / basis.dosesPerDay;
  }
  if (!Number.isFinite(rawDoseMg) || !Number.isFinite(rawDailyDoseMg) || rawDoseMg <= 0 || rawDailyDoseMg <= 0) {
    return { status: "invalid", reason: "calculation_out_of_range" };
  }

  let doseMg = rawDoseMg;
  const appliedCaps: CapName[] = [];
  if (basis.maxPerDoseMg !== undefined && doseMg > basis.maxPerDoseMg) {
    doseMg = basis.maxPerDoseMg;
    appliedCaps.push("max_per_dose");
  }
  if (basis.maxPerDayMg !== undefined) {
    const dailyPerDoseCeiling = basis.maxPerDayMg / basis.dosesPerDay;
    if (doseMg > dailyPerDoseCeiling) {
      doseMg = dailyPerDoseCeiling;
      appliedCaps.push("max_per_day");
    }
  }

  doseMg = normalize(doseMg);
  let rounded = false;
  if (input.rounding) {
    const candidate = roundDose(doseMg, input.rounding);
    if (candidate <= 0) return { status: "invalid", reason: "rounding_not_positive" };
    const configuredCeilings = [
      basis.maxPerDoseMg,
      basis.maxPerDayMg === undefined ? undefined : basis.maxPerDayMg / basis.dosesPerDay,
    ].filter((value): value is number => value !== undefined);
    const safetyCeiling = configuredCeilings.length ? Math.min(...configuredCeilings) : Number.POSITIVE_INFINITY;
    if (candidate > safetyCeiling + 1e-10) {
      return { status: "invalid", reason: "rounding_exceeds_safety_cap" };
    }
    rounded = Math.abs(candidate - doseMg) > 1e-10;
    doseMg = candidate;
  }
  const dailyDoseMg = normalize(doseMg * basis.dosesPerDay);
  if ((basis.maxPerDoseMg !== undefined && doseMg > basis.maxPerDoseMg + 1e-10) ||
      (basis.maxPerDayMg !== undefined && dailyDoseMg > basis.maxPerDayMg + 1e-10)) {
    return { status: "invalid", reason: "rounding_exceeds_safety_cap" };
  }
  return { status: "calculated", doseMg, dailyDoseMg, uncappedDoseMg: normalize(rawDoseMg), appliedCaps, rounded };
}
