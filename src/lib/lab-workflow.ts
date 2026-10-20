export type LabResultFlag = "low" | "high" | "critical" | "critical-low" | "critical-high" | "normal" | null;

export type LabResultMapping =
  | { kind: "empty" }
  | { kind: "pending" }
  | {
      kind: "numeric";
      value: number;
      lower: number | null;
      upper: number | null;
      abnormal: boolean;
      critical: boolean;
      flag: LabResultFlag;
    }
  | { kind: "text"; value: string }
  | { kind: "coded"; code: string; display: string };

export interface LabResultInput {
  value?: string | number | null;
  dataType?: string | null;
  status?: string | null;
  code?: string | null;
  display?: string | null;
  lower?: number | null;
  upper?: number | null;
  criticalLower?: number | null;
  criticalUpper?: number | null;
  flag?: string | null;
}

function finiteBound(value: number | null | undefined): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function normalizedFlag(flag: string | null | undefined): LabResultFlag {
  const value = (flag ?? "").trim().toLowerCase().replace(/_/g, "-");
  if (value === "critical") return "critical";
  if (value === "critical-low") return "critical-low";
  if (value === "critical-high") return "critical-high";
  if (value === "low") return "low";
  if (value === "high") return "high";
  if (value === "normal") return "normal";
  return null;
}

/** Map legacy string-backed rows without ever coercing an empty value to zero. */
export function mapLabResult(input: LabResultInput): LabResultMapping {
  if ((input.status ?? "").trim().toLowerCase() === "pending") return { kind: "pending" };
  const raw = input.value;
  const value = raw == null ? "" : String(raw).trim();
  if (!value) return { kind: "empty" };

  const dataType = (input.dataType ?? "").trim().toLowerCase();
  const explicitFlag = normalizedFlag(input.flag);
  if (dataType === "coded" || input.code != null) {
    return {
      kind: "coded",
      code: (input.code ?? value).trim(),
      display: input.display?.trim() || value,
    };
  }
  if (dataType === "text" || dataType === "string" || dataType === "qualitative") {
    return { kind: "text", value };
  }

  const numeric = typeof raw === "number" ? raw : Number(value);
  if (dataType === "numeric" || dataType === "number" || Number.isFinite(numeric)) {
    if (!Number.isFinite(numeric)) return { kind: "text", value };
    const lower = finiteBound(input.lower);
    const upper = finiteBound(input.upper);
    const criticalLower = finiteBound(input.criticalLower);
    const criticalUpper = finiteBound(input.criticalUpper);
    const criticalLow = criticalLower !== null && numeric < criticalLower;
    const criticalHigh = criticalUpper !== null && numeric > criticalUpper;
    const low = lower !== null && numeric < lower;
    const high = upper !== null && numeric > upper;
    const critical =
      criticalLow ||
      criticalHigh ||
      explicitFlag === "critical" ||
      explicitFlag === "critical-low" ||
      explicitFlag === "critical-high";
    const flag: LabResultFlag =
      criticalLow || explicitFlag === "critical-low"
        ? "critical-low"
        : criticalHigh || explicitFlag === "critical-high"
          ? "critical-high"
          : explicitFlag === "critical"
            ? "critical"
            : low || explicitFlag === "low"
              ? "low"
              : high || explicitFlag === "high"
                ? "high"
                : explicitFlag === "normal"
                  ? "normal"
                  : null;
    return {
      kind: "numeric",
      value: numeric,
      lower,
      upper,
      abnormal: low || high || critical || explicitFlag === "low" || explicitFlag === "high",
      critical,
      flag,
    };
  }
  return { kind: "text", value };
}

function rangeAgeBound(
  range: Record<string, unknown>,
  primary: "min_age" | "max_age",
  alias: "age_min" | "age_max",
): number | null {
  const raw = range[primary] ?? range[alias];
  if (raw == null || String(raw).trim() === "") return null;
  const value = Number(raw);
  if (!Number.isFinite(value) || value === 0) return null;
  return value;
}

/**
 * Select only a reference interval compatible with known patient demographics.
 * If no interval matches, return undefined instead of silently using an unrelated range.
 */
export function selectLabReferenceRange<T extends Record<string, unknown>>(
  ranges: T[],
  parameterId: string,
  patientGender: string | null | undefined,
  age: number | undefined,
): T | undefined {
  const normalizedGender = (patientGender ?? "").trim().toLowerCase();

  return ranges
    .map((range, index) => {
      if (range["parameter_id"] !== parameterId) return null;

      const rawGender = range["gender"];
      const rangeGender =
        rawGender == null ? "" : String(rawGender).trim().toLowerCase();
      if (rangeGender && (!normalizedGender || rangeGender !== normalizedGender)) {
        return null;
      }

      const minAge = rangeAgeBound(range, "min_age", "age_min");
      const maxAge = rangeAgeBound(range, "max_age", "age_max");
      if (age === undefined && (minAge !== null || maxAge !== null)) return null;
      if (age !== undefined && minAge !== null && age < minAge) return null;
      if (age !== undefined && maxAge !== null && age > maxAge) return null;

      const specificity = (rangeGender ? 2 : 0) + (minAge !== null ? 1 : 0) + (maxAge !== null ? 1 : 0);
      return { range, index, specificity };
    })
    .filter(
      (candidate): candidate is { range: T; index: number; specificity: number } =>
        candidate !== null,
    )
    .sort((a, b) => b.specificity - a.specificity || a.index - b.index)[0]?.range;
}

export const LAB_WORKFLOW_STAGES = [
  "ordered",
  "sample_collected",
  "in_progress",
  "completed",
  "verified",
] as const;

/** Maps persisted workflow states to a stable, display-only progress step. */
export function labWorkflowStage(status: string): number {
  const index = LAB_WORKFLOW_STAGES.indexOf(
    status as (typeof LAB_WORKFLOW_STAGES)[number],
  );
  return index < 0 ? 0 : index;
}

/**
 * Returns true only for a non-empty, numeric result outside a configured bound.
 * Blank inputs must not be coerced to zero and displayed as abnormal.
 */
export function isAbnormalLabResult(value: string, low: number, high: number): boolean {
  // Legacy callers use zero as “no bound”; the typed mapper accepts zero bounds.
  const mapped = mapLabResult({
    value,
    lower: low === 0 ? null : low,
    upper: high === 0 ? null : high,
  });
  return mapped.kind === "numeric" && mapped.abnormal;
}

/** True when the user has at least one non-blank result for a lab order item. */
export function hasLabItemResultInput(
  itemId: string,
  parameterIds: string[],
  values: Record<string, string>,
): boolean {
  return parameterIds.some(
    (parameterId) => (values[itemId + ":" + parameterId] ?? "").trim().length > 0,
  );
}
