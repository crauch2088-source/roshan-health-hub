/**
 * Phase 3 — Pharmacy Inventory Modernization.
 *
 * Shared types + pure helpers for the batch/FEFO/expiry system. This repo
 * doesn't use generated Supabase types anywhere (see lib/db.ts's `Row =
 * Record<string, unknown>` + `s()/n()/rel()` accessor pattern) so these
 * are hand-written to match that same convention, not a codegen dump.
 */

import { rpc } from "./db";

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/** A single received lot of a medicine — public.pharmacy_inventory. */
export type PharmacyBatch = {
  id: string;
  medicine_id: string;
  batch_number: string | null;
  supplier_id: string | null;
  purchase_price: number | null;
  selling_price: number | null;
  quantity_received: number;
  quantity_remaining: number;
  manufacture_date: string | null;
  expiry_date: string | null;
  invoice_reference: string | null;
  reorder_level: number | null;
  created_at: string;
  updated_at: string;
  // Joined
  medicines?: {
    id: string;
    name: string | null;
    generic_name: string | null;
    unit: string | null;
  } | null;
  suppliers?: { id: string; name: string | null; phone: string | null } | null;
};

export type Supplier = {
  id: string;
  name: string;
  phone: string | null;
  address: string | null;
  active: boolean | null;
};

export type StockMovement = {
  id: string;
  medicine_id: string;
  batch_id: string | null;
  movement_type: "purchase" | "dispense" | "adjustment" | "return" | "writeoff";
  quantity: number;
  reference_id: string | null;
  reference_table: string | null;
  notes: string | null;
  created_at: string;
};

/** One row per branch-owned, unexpired FEFO batch consumed by the atomic dispense RPC. */
export type DispenseResultRow = {
  item_id: string;
  medicine_id: string;
  medicine_name: string;
  batch_id: string | null;
  batch_number: string | null;
  expiry_date: string | null;
  quantity_dispensed: number;
  batch_quantity_remaining: number | null;
  source: "batch";
};

export {
  DEFAULT_EXPIRY_THRESHOLD_DAYS,
  daysUntil,
  expiryStatus,
  EXPIRY_TONE,
} from "./pharmacy-expiry";
export type { ExpiryStatus } from "./pharmacy-expiry";

// ---------------------------------------------------------------------------
// FEFO dispensing (Part 2)
// ---------------------------------------------------------------------------

/**
 * Dispenses every item on a pending prescription First-Expire-First-Out.
 * Runs entirely inside the idempotent atomic_pharmacy_dispense Postgres RPC so
 * it's atomic under concurrent dispensing, and returns one row per batch
 * (or legacy-stock) consumption for display.
 */
export async function dispensePrescriptionFefo(
  prescriptionId: string,
  separateInvoice: boolean,
  requestId: string,
): Promise<DispenseResultRow[]> {
  if (!requestId) throw new Error("A stable dispense request id is required");
  return rpc<DispenseResultRow[]>("atomic_pharmacy_dispense", {
    p_prescription_id: prescriptionId,
    p_separate_invoice: separateInvoice,
    p_request_id: requestId,
  });
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

export const MOVEMENT_TYPES = ["purchase", "dispense", "adjustment", "return", "writeoff"] as const;
