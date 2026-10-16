export type InvoiceBalanceRow = {
  net_amount?: unknown;
  total_amount?: unknown;
  paid_amount?: unknown;
};

function finiteMoney(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string" || value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Calculate outstanding debt only from the complete invoice set supplied by
 * the caller. Return null when any row has no trustworthy amount, so the UI
 * can distinguish an unknown balance from a genuine zero balance.
 */
export function calculateOutstandingBalance(rows: readonly InvoiceBalanceRow[]): number | null {
  let total = 0;

  for (const invoice of rows) {
    const netAmount = finiteMoney(invoice.net_amount) ?? finiteMoney(invoice.total_amount);
    const paidAmount = finiteMoney(invoice.paid_amount);

    if (netAmount === null || paidAmount === null) return null;
    total += Math.max(0, netAmount - paidAmount);
  }

  return total;
}
