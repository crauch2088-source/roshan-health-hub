import type {
  DoseBasis,
  DoseCalculationInput,
  DoseCalculationResult,
  DoseRounding,
} from "./types.ts";

type CapName = "max_per_dose" | "max_per_day";

function positiveFinite(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function normalize(value: number): number {
  return Math.round(value * 1e10) / 1e10;
}

function validRounding(value: unknown): value is DoseRounding | undefined {
  if (value === undefined) return true;
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const candidate = value as Record<string, unknown>;
  return (
    positiveFinite(candidate["incrementMg"]) &&
    ["nearest", "down", "up"].includes(String(candidate["mode"]))
  );
}

function roundDose(value: number, rule: DoseRounding): number {
  const units = value / rule.incrementMg;
  if (rule.mode === "down") {
    return normalize(Math.floor(units + 1e-10) * rule.incrementMg);
  }
  if (rule.mode === "up") {
    return normalize(Math.ceil(units - 1e-10) * rule.incrementMg);
  }
  return normalize(Math.round(units) * rule.incrementMg);
}

function validCeiling(value: unknown): boolean {
  return value === undefined || positiveFinite(value);
}

function validBasis(basis: unknown): basis is DoseBasis {
  if (!basis || typeof basis !== "object" || Array.isArray(basis)) return false;
  const candidate = basis as Record<string, unknown>;
  if (
    !Number.isSafeInteger(candidate["dosesPerDay"]) ||
    (candidate["dosesPerDay"] as number) <= 0 ||
    !validCeiling(candidate["maxPerDoseMg"]) ||
    !validCeiling(candidate["maxPerDayMg"])
  ) {
    return false;
  }
  if (candidate["kind"] === "fixed") return positiveFinite(candidate["amountMg"]);
  if (candidate["kind"] === "mg_per_kg_per_dose") {
    return positiveFinite(candidate["amountMgPerKg"]);
  }
  if (candidate["kind"] === "mg_per_kg_per_day") {
    return positiveFinite(candidate["amountMgPerKgPerDay"]);
  }
  return false;
}

/**
 * Pure arithmetic only. It does not select a drug, indication, route,
 * frequency, duration, concentration, volume, or clinical protocol.
 * All quantities are mg and kg. Frequency must be explicitly supplied.
 */
export function calculateDose(input: DoseCalculationInput): DoseCalculationResult {
  if (
    !input ||
    typeof input !== "object" ||
    !validBasis(input.basis) ||
    !validRounding(input.rounding)
  ) {
    return { status: "invalid", reason: "invalid_rule_parameters" };
  }

  const weightBased = input.basis.kind !== "fixed";
  if (weightBased && input.weightKg == null) {
    return { status: "needs_data", missing: ["weight_kg"] };
  }
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

  if (
    !Number.isFinite(rawDoseMg) ||
    !Number.isFinite(rawDailyDoseMg) ||
    rawDoseMg <= 0 ||
    rawDailyDoseMg <= 0
  ) {
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
  if (!positiveFinite(doseMg)) {
    return { status: "invalid", reason: "calculation_out_of_range" };
  }
  let rounded = false;

  if (input.rounding) {
    const candidate = roundDose(doseMg, input.rounding);
    if (!Number.isFinite(candidate)) {
      return { status: "invalid", reason: "calculation_out_of_range" };
    }
    if (candidate <= 0) {
      return { status: "invalid", reason: "rounding_not_positive" };
    }

    const configuredCeilings = [
      basis.maxPerDoseMg,
      basis.maxPerDayMg === undefined ? undefined : basis.maxPerDayMg / basis.dosesPerDay,
    ].filter((value): value is number => value !== undefined);
    const safetyCeiling = configuredCeilings.length
      ? Math.min(...configuredCeilings)
      : Number.POSITIVE_INFINITY;

    if (candidate > safetyCeiling + 1e-10) {
      return { status: "invalid", reason: "rounding_exceeds_safety_cap" };
    }

    rounded = Math.abs(candidate - doseMg) > 1e-10;
    doseMg = candidate;
  }

  const dailyDoseMg = normalize(doseMg * basis.dosesPerDay);
  const uncappedDoseMg = normalize(rawDoseMg);
  if (!positiveFinite(dailyDoseMg) || !positiveFinite(uncappedDoseMg)) {
    return { status: "invalid", reason: "calculation_out_of_range" };
  }
  if (
    (basis.maxPerDoseMg !== undefined && doseMg > basis.maxPerDoseMg + 1e-10) ||
    (basis.maxPerDayMg !== undefined && dailyDoseMg > basis.maxPerDayMg + 1e-10)
  ) {
    return { status: "invalid", reason: "rounding_exceeds_safety_cap" };
  }

  return {
    status: "calculated",
    doseMg,
    dailyDoseMg,
    uncappedDoseMg,
    appliedCaps,
    rounded,
  };
}
