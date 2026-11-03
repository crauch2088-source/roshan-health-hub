const SOURCE_LINKED_PAYMENT_TYPES = new Set([
  "payment",
  "supplier_payment",
  "insurance_claim_payment",
]);

/**
 * Generic cashbox reversals must never detach a source-linked payment from
 * its authoritative payment row. Those entries require their own workflow.
 */
export function isGenericCashboxReversalAllowed(sourceType: unknown): boolean {
  return typeof sourceType !== "string" || !SOURCE_LINKED_PAYMENT_TYPES.has(sourceType);
}
