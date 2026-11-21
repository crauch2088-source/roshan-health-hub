export const RETURN_CONDITIONS = [
  "unopened_intact",
  "opened",
  "damaged",
  "expired",
  "contaminated",
  "uncertain",
] as const;

export type ReturnCondition = (typeof RETURN_CONDITIONS)[number];

export const QUARANTINE_DISPOSITIONS = [
  "approved_restock",
  "destroyed_writeoff",
  "returned_to_supplier",
] as const;

export type QuarantineDisposition = (typeof QUARANTINE_DISPOSITIONS)[number];

export interface SupabaseRpcClient {
  rpc: (
    fn: string,
    params?: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function formatRpcError(error: unknown): string {
  if (!error || typeof error !== "object") return String(error);
  const e = error as {
    message?: string;
    details?: string;
    hint?: string;
    code?: string;
  };
  const msg = e.message ?? "Database error";
  const parts = [msg, e.details, e.hint].filter(Boolean);
  const text = parts.join(" — ");
  if (e.code === "42501" || /row-level security/i.test(text)) {
    return `${text} (permission denied by database policy)`;
  }
  if (e.code === "42703") {
    return `${text} (database schema mismatch — run pending migrations)`;
  }
  if (e.code === "42883" || e.code === "PGRST202") {
    return `${text} (missing RPC function — run pending migrations)`;
  }
  return text;
}

async function getRpcClient(client?: SupabaseRpcClient): Promise<SupabaseRpcClient> {
  if (client) return client;
  const { supabase } = await import("./supabase");
  return supabase as unknown as SupabaseRpcClient;
}

async function invokeRpc<T>(
  fn: string,
  params: Record<string, unknown>,
  client?: SupabaseRpcClient,
): Promise<T> {
  const rpcClient = await getRpcClient(client);
  const { data, error } = await rpcClient.rpc(fn, params);
  if (error) {
    throw new Error(formatRpcError(error));
  }
  return data as T;
}

function assertNonEmptyId(value: string, label: string): string {
  const trimmed = typeof value === "string" ? value.trim() : "";
  if (!trimmed) {
    throw new Error(`${label} is required.`);
  }
  return trimmed;
}

function assertUuid(value: string, label: string): string {
  const trimmed = assertNonEmptyId(value, label);
  if (!UUID_RE.test(trimmed)) {
    throw new Error(`${label} must be a valid UUID.`);
  }
  return trimmed;
}

function assertReason(value: string): string {
  const trimmed = typeof value === "string" ? value.trim() : "";
  if (!trimmed) {
    throw new Error("Reason is required.");
  }
  return trimmed;
}

export async function confirmPharmacyHandover(
  prescriptionId: string,
  client?: SupabaseRpcClient,
): Promise<unknown> {
  const p_prescription_id = assertNonEmptyId(prescriptionId, "Prescription ID");
  return invokeRpc("confirm_pharmacy_handover", { p_prescription_id }, client);
}

export interface CancelDispenseBeforeHandoverInput {
  prescriptionId: string;
  reason: string;
  idempotencyKey: string;
}

export async function cancelDispenseBeforeHandover(
  input: CancelDispenseBeforeHandoverInput,
  client?: SupabaseRpcClient,
): Promise<unknown> {
  const p_prescription_id = assertNonEmptyId(input.prescriptionId, "Prescription ID");
  const p_reason = assertReason(input.reason);
  const p_idempotency_key = assertUuid(input.idempotencyKey, "Idempotency key");
  return invokeRpc(
    "cancel_dispense_before_handover",
    { p_prescription_id, p_reason, p_idempotency_key },
    client,
  );
}

export interface RecordPostHandoverReturnInput {
  prescriptionId: string;
  medicineId: string;
  batchId: string;
  quantity: number;
  condition: ReturnCondition;
  reason: string;
  idempotencyKey: string;
}

export async function recordPostHandoverReturn(
  input: RecordPostHandoverReturnInput,
  client?: SupabaseRpcClient,
): Promise<unknown> {
  const p_prescription_id = assertNonEmptyId(input.prescriptionId, "Prescription ID");
  const p_medicine_id = assertNonEmptyId(input.medicineId, "Medicine ID");
  const p_batch_id = assertNonEmptyId(input.batchId, "Batch ID");
  if (
    typeof input.quantity !== "number" ||
    !Number.isFinite(input.quantity) ||
    input.quantity <= 0
  ) {
    throw new Error("Return quantity must be a positive number.");
  }
  if (!RETURN_CONDITIONS.includes(input.condition)) {
    throw new Error(`Invalid return condition: ${String(input.condition)}`);
  }
  const p_reason = assertReason(input.reason);
  const p_idempotency_key = assertUuid(input.idempotencyKey, "Idempotency key");
  return invokeRpc(
    "record_post_handover_return",
    {
      p_prescription_id,
      p_medicine_id,
      p_batch_id,
      p_quantity: input.quantity,
      p_condition: input.condition,
      p_reason,
      p_idempotency_key,
    },
    client,
  );
}

export interface ResolveQuarantineDispositionInput {
  quarantineId: string;
  disposition: QuarantineDisposition;
  notes?: string | null;
}

export async function resolveQuarantineDisposition(
  input: ResolveQuarantineDispositionInput,
  client?: SupabaseRpcClient,
): Promise<unknown> {
  const p_quarantine_id = assertNonEmptyId(input.quarantineId, "Quarantine ID");
  if (!QUARANTINE_DISPOSITIONS.includes(input.disposition)) {
    throw new Error(`Invalid quarantine disposition: ${String(input.disposition)}`);
  }
  const trimmedNotes = typeof input.notes === "string" ? input.notes.trim() : "";
  const p_notes = trimmedNotes ? trimmedNotes : null;
  return invokeRpc(
    "resolve_quarantine_disposition",
    {
      p_quarantine_id,
      p_disposition: input.disposition,
      p_notes,
    },
    client,
  );
}
