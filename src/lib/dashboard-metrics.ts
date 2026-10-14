import type { Row } from "./db";

/**
 * Lab orders still needing work. These are the statuses the Laboratory page
 * itself uses (ordered → sample_collected → in_progress); "pending" and
 * "collected" are kept as legacy spellings. The dashboard list AND its exact
 * count must both use this one list so they cannot disagree.
 */
export const PENDING_LAB_STATUSES: string[] = [
  "ordered",
  "sample_collected",
  "in_progress",
  "pending",
  "collected",
];

/** Sum of `amount` (or another key) over rows, optionally filtered; rounded to cents. */
export function sumAmounts(rows: Row[], predicate?: (row: Row) => boolean, key = "amount"): number {
  let total = 0;
  for (const row of rows) {
    if (predicate && !predicate(row)) continue;
    const value = Number(row[key]);
    if (Number.isFinite(value)) total += value;
  }
  return Math.round(total * 100) / 100;
}
