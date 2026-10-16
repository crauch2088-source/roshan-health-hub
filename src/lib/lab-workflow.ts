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
