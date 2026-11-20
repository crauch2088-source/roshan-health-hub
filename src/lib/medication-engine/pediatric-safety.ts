import { calculateDose } from "./dose-calculator.ts";
import type { DoseBasis, DoseCalculationResult, DoseRounding } from "./types.ts";

export type WeightValidationReason =
  "missing" | "non_positive" | "implausible" | "stale"  | "invalid_timestamp";

export interface WeightValidationResult {
  valid: boolean;
  reason?: WeightValidationReason | undefined;
  ageHours?: number | undefined;
}

export interface ConcentrationConversionResult {
  valid: boolean;
  volumeMl?: number | undefined;
  reason?: "invalid_dose" | "invalid_concentration" | undefined;
}

export interface ApprovedProtocolMetadata {
  protocolId: string;
  source: string;
  version: string;
  approvedBy: string;
  effectiveFrom: string;
  expiresAt: string;
}

export interface DecisionSupportInput {
  patientAgeYears: number;
  weightKg?: number | null | undefined;
  weightRecordedAt?: string | null | undefined;
  referenceTimeIso: string;
  maxWeightAgeHours?: number | undefined;
  dosageForm: string;
  route: string;
  protocol?: ApprovedProtocolMetadata | null | undefined;
  basis?: DoseBasis | null | undefined;
  rounding?: DoseRounding | undefined;
  concentration?: { mg: number; perMl: number } | undefined;
}

export interface DecisionSupportRecommendation {
  status: "recommendation_ready" | "manual_decision_required";
  reason?:
    | "protocol_missing"
    | "protocol_expired"
    | "protocol_not_yet_effective"
    | "route_formulation_mismatch"
    | "weight_missing_or_invalid"
    | "calculation_failed"
    | undefined;
  protocol?: ApprovedProtocolMetadata | undefined;
  calculation?: DoseCalculationResult | undefined;
  volumeMl?: number | undefined;
  requiresClinicianConfirmation: true;
  autoPrescribed: false;
}

export interface ClinicianOrderConfirmation {
  recommendation: DecisionSupportRecommendation;
  clinicianEnteredDose: string;
  clinicianConfirmed: boolean;
  overrideReason?: string | undefined;
}

const MIN_PLAUSIBLE_WEIGHT_KG = 0.5;
const MAX_PLAUSIBLE_WEIGHT_KG = 300;
const DEFAULT_MAX_WEIGHT_AGE_HOURS = 24;

const COMPATIBLE_ROUTES_BY_FORM: Record<string, ReadonlySet<string>> = {
  tablet: new Set(["oral", "sublingual"]),
  capsule: new Set(["oral"]),
  syrup: new Set(["oral"]),
  suspension: new Set(["oral"]),
  drops: new Set(["oral", "ophthalmic", "otic", "nasal"]),
  injection: new Set(["iv", "im", "sc", "intradermal"]),
  cream: new Set(["topical"]),
  ointment: new Set(["topical", "ophthalmic"]),
  gel: new Set(["topical"]),
  lotion: new Set(["topical"]),
  suppository: new Set(["rectal", "vaginal"]),
  inhaler: new Set(["inhalation"]),
  solution: new Set(["oral", "topical", "iv", "inhalation", "ophthalmic", "otic", "nasal"]),
  sachet: new Set(["oral"]),
};

export function validatePatientWeight(
  weightKg: number | null | undefined,
  recordedAtIso: string | null | undefined,
  referenceTimeIso: string,
  maxAgeHours = DEFAULT_MAX_WEIGHT_AGE_HOURS,
): WeightValidationResult {
  if (weightKg == null) {
    return { valid: false, reason: "missing" };
  }
  if (typeof weightKg !== "number" || !Number.isFinite(weightKg) || weightKg <= 0) {
    return { valid: false, reason: "non_positive" };
  }
  if (weightKg < MIN_PLAUSIBLE_WEIGHT_KG || weightKg > MAX_PLAUSIBLE_WEIGHT_KG) {
    return { valid: false, reason: "implausible" };
  }
  if (!recordedAtIso) {
    return { valid: false, reason: "stale" };
  }
  const recordedMs = Date.parse(recordedAtIso);
  const refMs = Date.parse(referenceTimeIso);
  if (!Number.isFinite(recordedMs) || !Number.isFinite(refMs) || recordedMs > refMs) {
    return { valid: false, reason: "invalid_timestamp" };
  }
  const ageHours = (refMs - recordedMs) / 3_600_000;
  if (ageHours > maxAgeHours) {
    return { valid: false, reason: "stale", ageHours };
  }
  return { valid: true, ageHours };
}

export function convertMgToMl(
  doseMg: number,
  concentrationMg: number,
  concentrationMl: number,
): ConcentrationConversionResult {
  if (!Number.isFinite(doseMg) || doseMg <= 0) {
    return { valid: false, reason: "invalid_dose" };
  }
  if (
    !Number.isFinite(concentrationMg) ||
    concentrationMg <= 0 ||
    !Number.isFinite(concentrationMl) ||
    concentrationMl <= 0
  ) {
    return { valid: false, reason: "invalid_concentration" };
  }
  const volumeMl = Math.round(((doseMg * concentrationMl) / concentrationMg) * 100) / 100;
  return { valid: true, volumeMl };
}

export function isRouteConsistentWithFormulation(dosageForm: string, route: string): boolean {
  const form = dosageForm.trim().toLowerCase();
  const normalizedRoute = route.trim().toLowerCase();
  const allowed = COMPATIBLE_ROUTES_BY_FORM[form];
  if (!allowed) return false;
  return allowed.has(normalizedRoute);
}

export function evaluateMedicationDecisionSupport(
  input: DecisionSupportInput,
): DecisionSupportRecommendation {
  const base = {
    requiresClinicianConfirmation: true as const,
    autoPrescribed: false as const,
  };

  if (!input.protocol || !input.basis) {
    return { status: "manual_decision_required", reason: "protocol_missing", ...base };
  }

  const refMs = Date.parse(input.referenceTimeIso);
  const effMs = Date.parse(input.protocol.effectiveFrom);
  const expMs = Date.parse(input.protocol.expiresAt);
  if (!Number.isFinite(refMs) || !Number.isFinite(effMs) || !Number.isFinite(expMs)) {
    return { status: "manual_decision_required", reason: "protocol_expired", ...base };
  }
  if (refMs < effMs) {
    return {
      status: "manual_decision_required",
      reason: "protocol_not_yet_effective",
      protocol: input.protocol,
      ...base,
    };
  }
  if (refMs > expMs) {
    return {
      status: "manual_decision_required",
      reason: "protocol_expired",
      protocol: input.protocol,
      ...base,
    };
  }

  if (!isRouteConsistentWithFormulation(input.dosageForm, input.route)) {
    return {
      status: "manual_decision_required",
      reason: "route_formulation_mismatch",
      protocol: input.protocol,
      ...base,
    };
  }

  const isPediatric = input.patientAgeYears < 18;
  const requiresWeight = input.basis.kind !== "fixed" || isPediatric;
  if (requiresWeight) {
    const weightCheck = validatePatientWeight(
      input.weightKg,
      input.weightRecordedAt,
      input.referenceTimeIso,
      input.maxWeightAgeHours,
    );
    if (!weightCheck.valid) {
      return {
        status: "manual_decision_required",
        reason: "weight_missing_or_invalid",
        protocol: input.protocol,
        ...base,
      };
    }
  }

  const calculation = calculateDose({
    basis: input.basis,
    weightKg: input.weightKg ?? null,
    ...(input.rounding !== undefined ? { rounding: input.rounding } : {}),
  });

  if (calculation.status !== "calculated") {
    return {
      status: "manual_decision_required",
      reason: "calculation_failed",
      protocol: input.protocol,
      calculation,
      ...base,
    };
  }

  let volumeMl: number | undefined;
  if (input.concentration) {
    const converted = convertMgToMl(
      calculation.doseMg,
      input.concentration.mg,
      input.concentration.perMl,
    );
    if (!converted.valid) {
      return {
        status: "manual_decision_required",
        reason: "calculation_failed",
        protocol: input.protocol,
        calculation,
        ...base,
      };
    }
    volumeMl = converted.volumeMl;
  }

  return {
    status: "recommendation_ready",
    protocol: input.protocol,
    calculation,
    volumeMl,
    ...base,
  };
}

export function canFinalizeClinicianOrder(order: ClinicianOrderConfirmation): boolean {
  if (!order.clinicianConfirmed) return false;
  if (!order.clinicianEnteredDose.trim()) return false;
  return true;
}
