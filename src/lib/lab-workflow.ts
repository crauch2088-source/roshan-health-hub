export type LabResultFlag = "low" | "high" | "critical-low" | "critical-high" | "normal" | null;

export type LabResultMapping =
  | { kind: "empty" }
  | { kind: "pending" }
  | { kind: "numeric"; value: number; lower: number | null; upper: number | null; abnormal: boolean; critical: boolean; flag: LabResultFlag }
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
  if (value === "critical") return "critical-high";
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
    const critical = criticalLow || criticalHigh || explicitFlag === "critical-low" || explicitFlag === "critical-high";
    const flag: LabResultFlag =
      criticalLow || explicitFlag === "critical-low" ? "critical-low" :
      criticalHigh || explicitFlag === "critical-high" ? "critical-high" :
      low || explicitFlag === "low" ? "low" :
      high || explicitFlag === "high" ? "high" :
      explicitFlag === "normal" ? "normal" : null;
    return {
      kind: "numeric", value: numeric, lower, upper,
      abnormal: low || high || critical || explicitFlag === "low" || explicitFlag === "high",
      critical, flag,
    };
  }
  return { kind: "text", value };
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
  const index = LAB_WORKFLOW_STAGES.indexOf(status as (typeof LAB_WORKFLOW_STAGES)[number]);
  return index < 0 ? 0 : index;
}

/**
 * Returns true only for a non-empty, numeric result outside a configured bound.
 * Blank inputs must not be coerced to zero and displayed as abnormal.
 */
export function isAbnormalLabResult(value: string, low: number, high: number): boolean {
  // Legacy callers use zero as “no bound”; the typed mapper accepts zero bounds.
  const mapped = mapLabResult({ value, lower: low === 0 ? null : low, upper: high === 0 ? null : high });
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
