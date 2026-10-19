export const LAB_WORKFLOW_STAGES = [
  "ordered",
  "sample_collected",
  "in_progress",
  "completed",
  "verified",
] as const;

export type LabResultFlag = "low" | "high" | "critical_low" | "critical_high" | null;

export type LabMappedResult =
  | {
      kind: "empty";
      status: "pending";
      rawValue: "";
      numericValue: null;
      abnormal: false;
      critical: false;
      flag: null;
    }
  | {
      kind: "numeric";
      status: "result";
      rawValue: string;
      numericValue: number;
      lower: number | null;
      upper: number | null;
      abnormal: boolean;
      critical: boolean;
      flag: LabResultFlag;
    }
  | {
      kind: "text" | "coded";
      status: "result";
      rawValue: string;
      numericValue: null;
      abnormal: false;
      critical: false;
      flag: null;
    };

export type LabResultRange = Record<string, unknown>;

function finiteBound(...values: unknown[]): number | null {
  for (const value of values) {
    if (value === null || value === undefined || String(value).trim() === "") {
      continue;
    }
    const numeric = Number(value);
    if (Number.isFinite(numeric)) return numeric;
  }
  return null;
}

/** Maps persisted result strings without conflating blank with numeric zero. */
export function mapLabResult(
  value: string | number | null | undefined,
  dataType: string | null | undefined,
  range?: LabResultRange | null,
  existingFlag?: string | null,
): LabMappedResult {
  if (value === null || value === undefined || String(value).trim() === "") {
    return {
      kind: "empty",
      status: "pending",
      rawValue: "",
      numericValue: null,
      abnormal: false,
      critical: false,
      flag: null,
    };
  }

  const rawValue = String(value).trim();
  const type = (dataType ?? "").trim().toLowerCase();
  const coded = ["coded", "code", "enum", "enumeration", "boolean", "bool"].includes(type);
  const text = ["text", "string", "varchar", "char", "date", "datetime", "timestamp"].includes(type);

  if (coded || text) {
    return {
      kind: coded ? "coded" : "text",
      status: "result",
      rawValue,
      numericValue: null,
      abnormal: false,
      critical: false,
      flag: null,
    };
  }

  const parsed = Number(rawValue);
  // Unknown legacy data types preserve numeric strings, falling back to text otherwise.
  if (!Number.isFinite(parsed)) {
    return {
      kind: "text",
      status: "result",
      rawValue,
      numericValue: null,
      abnormal: false,
      critical: false,
      flag: null,
    };
  }

  const lower = finiteBound(range?.["lower_limit"], range?.["min_value"]);
  const upper = finiteBound(range?.["upper_limit"], range?.["max_value"]);
  const criticalLower = finiteBound(range?.["critical_lower_limit"], range?.["critical_min_value"]);
  const criticalUpper = finiteBound(range?.["critical_upper_limit"], range?.["critical_max_value"]);
  const persisted = (existingFlag ?? "").trim().toLowerCase();
  let flag: LabResultFlag = null;

  if (["low", "high", "critical_low", "critical_high"].includes(persisted)) {
    flag = persisted as LabResultFlag;
  } else if (criticalLower !== null && parsed < criticalLower) {
    flag = "critical_low";
  } else if (criticalUpper !== null && parsed > criticalUpper) {
    flag = "critical_high";
  } else if (lower !== null && parsed < lower) {
    flag = "low";
  } else if (upper !== null && parsed > upper) {
    flag = "high";
  }

  const critical = flag === "critical_low" || flag === "critical_high";
  return {
    kind: "numeric",
    status: "result",
    rawValue,
    numericValue: parsed,
    lower,
    upper,
    abnormal: flag !== null,
    critical,
    flag,
  };
}

export function labWorkflowStage(status: string): number {
  const index = LAB_WORKFLOW_STAGES.indexOf(status as (typeof LAB_WORKFLOW_STAGES)[number]);
  return index < 0 ? 0 : index;
}

/** Compatibility helper retained for legacy callers. */
export function isAbnormalLabResult(value: string, low: number, high: number): boolean {
  const mapped = mapLabResult(value, "numeric", {
    lower_limit: low === 0 ? null : low,
    upper_limit: high === 0 ? null : high,
  });
  return mapped.kind === "numeric" && mapped.abnormal;
}

export function hasLabItemResultInput(
  itemId: string,
  parameterIds: string[],
  values: Record<string, string>,
): boolean {
  return parameterIds.some(
    (parameterId) => (values[itemId + ":" + parameterId] ?? "").trim().length > 0,
  );
}
