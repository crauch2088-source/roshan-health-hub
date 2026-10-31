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

/** One row per batch (or legacy fallback) consumed by fn_dispense_prescription(). */
export type DispenseResultRow = {
  item_id: string;
  medicine_id: string;
  medicine_name: string;
  batch_id: string | null;
  batch_number: string | null;
  expiry_date: string | null;
  quantity_dispensed: number;
  batch_quantity_remaining: number | null;
  source: "batch" | "legacy";
};

export type ExpiryStatus = "healthy" | "expiring_soon" | "expired" | "unknown";

export const DEFAULT_EXPIRY_THRESHOLD_DAYS = 90;

// ---------------------------------------------------------------------------
// Expiry status (Part 3)
// ---------------------------------------------------------------------------

/**
 * Parse date-only values as calendar dates rather than UTC midnight. Missing,
 * malformed, and impossible dates are unknown, never healthy by default.
 */
function expiryDayNumber(expiryDate: string | null | undefined): number | null {
  if (!expiryDate) return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(expiryDate);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const utc = Date.UTC(year, month - 1, day);
  const parsed = new Date(utc);
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) return null;
  return utc / 86_400_000;
}

function todayDayNumber(): number {
  const today = new Date();
  return Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()) / 86_400_000;
}

export function expiryStatus(
  expiryDate: string | null | undefined,
  thresholdDays: number,
): ExpiryStatus {
  const expiryDay = expiryDayNumber(expiryDate);
  if (expiryDay === null) return "unknown";
  const daysLeft = expiryDay - todayDayNumber();
  if (daysLeft < 0) return "expired";
  const threshold = Number.isFinite(thresholdDays)
    ? Math.max(0, Math.trunc(thresholdDays))
    : DEFAULT_EXPIRY_THRESHOLD_DAYS;
  if (daysLeft <= threshold) return "expiring_soon";
  return "healthy";
}

export function daysUntil(expiryDate: string | null | undefined): number | null {
  const expiryDay = expiryDayNumber(expiryDate);
  return expiryDay === null ? null : expiryDay - todayDayNumber();
}

/** Tailwind classes for the expiry badge, matching the tone scale already used by StatusBadge. */
export const EXPIRY_TONE: Record<ExpiryStatus, string> = {
  healthy: "bg-success/15 text-success border-success/30",
  expiring_soon: "bg-warning/15 text-warning border-warning/30",
  expired: "bg-destructive/15 text-destructive border-destructive/30",
  unknown: "bg-muted text-muted-foreground border-border",
};

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
