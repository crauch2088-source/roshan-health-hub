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
  medicines?: { id: string; name: string | null; generic_name: string | null; unit: string | null } | null;
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

export type ExpiryStatus = "healthy" | "expiring_soon" | "expired";

export const DEFAULT_EXPIRY_THRESHOLD_DAYS = 90;

// ---------------------------------------------------------------------------
// Expiry status (Part 3)
// ---------------------------------------------------------------------------

/**
 * Classifies a batch by its expiry date against the clinic's configurable
 * threshold (system_settings.pharmacy_expiry_threshold_days, default 90).
 * A null expiry date is treated as healthy (nothing to warn about).
 */
export function expiryStatus(expiryDate: string | null | undefined, thresholdDays: number): ExpiryStatus {
  if (!expiryDate) return "healthy";
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expiry = new Date(expiryDate);
  if (Number.isNaN(expiry.getTime())) return "healthy";
  const daysLeft = Math.floor((expiry.getTime() - today.getTime()) / 86_400_000);
  if (daysLeft < 0) return "expired";
  if (daysLeft <= thresholdDays) return "expiring_soon";
  return "healthy";
}

export function daysUntil(expiryDate: string | null | undefined): number | null {
  if (!expiryDate) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expiry = new Date(expiryDate);
  if (Number.isNaN(expiry.getTime())) return null;
  return Math.floor((expiry.getTime() - today.getTime()) / 86_400_000);
}

/** Tailwind classes for the expiry badge, matching the tone scale already used by StatusBadge. */
export const EXPIRY_TONE: Record<ExpiryStatus, string> = {
  healthy: "bg-success/15 text-success border-success/30",
  expiring_soon: "bg-warning/15 text-warning border-warning/30",
  expired: "bg-destructive/15 text-destructive border-destructive/30",
};

// ---------------------------------------------------------------------------
// FEFO dispensing (Part 2)
// ---------------------------------------------------------------------------

/**
 * Dispenses every item on a pending prescription First-Expire-First-Out.
 * Runs entirely inside one Postgres function (fn_dispense_prescription) so
 * it's atomic under concurrent dispensing, and returns one row per batch
 * (or legacy-stock) consumption for display.
 */
export async function dispensePrescriptionFefo(prescriptionId: string): Promise<DispenseResultRow[]> {
  return rpc<DispenseResultRow[]>("fn_dispense_prescription", { p_prescription_id: prescriptionId });
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

export const MOVEMENT_TYPES = ["purchase", "dispense", "adjustment", "return", "writeoff"] as const;
