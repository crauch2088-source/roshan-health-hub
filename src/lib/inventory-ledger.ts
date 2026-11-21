import { supabase } from "@/lib/supabase";

export const WRITEOFF_TYPES = ["expired", "damaged", "lost", "supplier_return"] as const;
export type WriteoffType = (typeof WRITEOFF_TYPES)[number];

export interface ReconcileLedgerResult {
  batch_sum: number;
  ledger_net: number;
  is_balanced: boolean;
}

type UntypedRpcClient = {
  rpc: (
    fn: string,
    args?: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { message: string } | null }>;
};

const rpcClient = supabase as unknown as UntypedRpcClient;

export function assertNonEmptyReason(reason: string): string {
  const trimmed = reason.trim();
  if (!trimmed) {
    throw new Error("Reason is required.");
  }
  return trimmed;
}

export function assertValidWriteoffType(value: string): WriteoffType {
  if (!(WRITEOFF_TYPES as readonly string[]).includes(value)) {
    throw new Error(`Invalid write-off type: ${value}`);
  }
  return value as WriteoffType;
}

export async function adjustInventoryBatchAtomic(params: {
  batchId: string;
  delta: number;
  reason: string;
  idempotencyKey: string;
}): Promise<string> {
  if (!params.batchId) throw new Error("Batch is required.");
  if (!Number.isFinite(params.delta) || params.delta === 0) {
    throw new Error("Adjustment delta must be a non-zero number.");
  }
  const reason = assertNonEmptyReason(params.reason);
  const { data, error } = await rpcClient.rpc("adjust_inventory_batch_atomic", {
    p_batch_id: params.batchId,
    p_delta: params.delta,
    p_reason: reason,
    p_idempotency_key: params.idempotencyKey,
  });
  if (error) throw new Error(error.message);
  return String(data ?? "");
}

export async function quarantineExpiredBatchAtomic(params: {
  batchId: string;
  reason: string;
  idempotencyKey: string;
}): Promise<string> {
  if (!params.batchId) throw new Error("Batch is required.");
  const reason = assertNonEmptyReason(params.reason);
  const { data, error } = await rpcClient.rpc("quarantine_expired_batch_atomic", {
    p_batch_id: params.batchId,
    p_reason: reason,
    p_idempotency_key: params.idempotencyKey,
  });
  if (error) throw new Error(error.message);
  return String(data ?? "");
}

export async function recordInventoryWriteoffAtomic(params: {
  batchId: string;
  quantity: number;
  writeoffType: WriteoffType;
  reason: string;
  idempotencyKey: string;
}): Promise<string> {
  if (!params.batchId) throw new Error("Batch is required.");
  if (!Number.isFinite(params.quantity) || params.quantity <= 0) {
    throw new Error("Write-off quantity must be greater than zero.");
  }
  const writeoffType = assertValidWriteoffType(params.writeoffType);
  const reason = assertNonEmptyReason(params.reason);
  const { data, error } = await rpcClient.rpc("record_inventory_writeoff_atomic", {
    p_batch_id: params.batchId,
    p_quantity: params.quantity,
    p_writeoff_type: writeoffType,
    p_reason: reason,
    p_idempotency_key: params.idempotencyKey,
  });
  if (error) throw new Error(error.message);
  return String(data ?? "");
}

export async function updateMedicineSellingPriceAtomic(params: {
  medicineId: string;
  branchId: string;
  newSellingPrice: number;
  reason: string;
  idempotencyKey: string;
}): Promise<string> {
  if (!params.medicineId) throw new Error("Medicine is required.");
  if (!params.branchId) throw new Error("Branch is required.");
  if (!Number.isFinite(params.newSellingPrice) || params.newSellingPrice < 0) {
    throw new Error("Selling price must be zero or greater.");
  }
  const reason = assertNonEmptyReason(params.reason);
  const { data, error } = await rpcClient.rpc("update_medicine_selling_price_atomic", {
    p_medicine_id: params.medicineId,
    p_branch_id: params.branchId,
    p_new_selling_price: params.newSellingPrice,
    p_reason: reason,
    p_idempotency_key: params.idempotencyKey,
  });
  if (error) throw new Error(error.message);
  return String(data ?? "");
}

export async function reconcileMedicineStockLedger(params: {
  medicineId: string;
  branchId: string;
}): Promise<ReconcileLedgerResult | null> {
  if (!params.medicineId || !params.branchId) return null;
  const { data, error } = await rpcClient.rpc("reconcile_medicine_stock_ledger", {
    p_medicine_id: params.medicineId,
    p_branch_id: params.branchId,
  });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : data;
  if (!row || typeof row !== "object") return null;
  const rec = row as Record<string, unknown>;
  return {
    batch_sum: Number(rec["batch_sum"] ?? 0),
    ledger_net: Number(rec["ledger_net"] ?? 0),
    is_balanced: Boolean(rec["is_balanced"]),
  };
}
