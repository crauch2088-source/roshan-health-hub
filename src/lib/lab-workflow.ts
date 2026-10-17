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
  const normalized = value.trim();
  if (!normalized) return false;
  const numeric = Number(normalized);
  if (!Number.isFinite(numeric)) return false;
  return (low !== 0 && numeric < low) || (high !== 0 && numeric > high);
}
