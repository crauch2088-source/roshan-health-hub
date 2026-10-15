export type InvoiceBalanceRow = {
  net_amount?: unknown;
  total_amount?: unknown;
  paid_amount?: unknown;
};

/** Calculate outstanding debt only from the complete invoice set supplied by the caller. */
export function calculateOutstandingBalance(rows: readonly InvoiceBalanceRow[]): number {
  return rows.reduce((sum, invoice) => {
    const netValue =
      invoice.net_amount === null || invoice.net_amount === undefined
        ? Number(invoice.total_amount)
        : Number(invoice.net_amount);
    const fallbackTotal = Number(invoice.total_amount);
    const netAmount = Number.isFinite(netValue)
      ? netValue
      : Number.isFinite(fallbackTotal)
        ? fallbackTotal
        : 0;
    const paidValue = Number(invoice.paid_amount);
    const paidAmount = Number.isFinite(paidValue) ? paidValue : 0;
    return sum + Math.max(0, netAmount - paidAmount);
  }, 0);
}
