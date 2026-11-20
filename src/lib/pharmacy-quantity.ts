/**
 * Parse a persisted prescription quantity without inventing a default.
 * Pharmacy dispensing accepts only finite positive whole units that fit the
 * integer quantity recorded by the dispensing workflow.
 */
export function parseDispenseQuantity(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string") {
    const normalized = value.trim();
    if (!/^\d+(?:\.0+)?$/.test(normalized)) return null;
  }

  const quantity = Number(value);
  if (
    !Number.isFinite(quantity) ||
    !Number.isInteger(quantity) ||
    quantity <= 0 ||
    quantity > 2_147_483_647
  ) {
    return null;
  }

  return quantity;
}
