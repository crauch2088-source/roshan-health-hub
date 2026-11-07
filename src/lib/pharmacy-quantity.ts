/**
 * Parse a persisted pharmacy quantity without inventing a default.
 * The database dispense RPC accepts positive whole numbers up to int4 max.
 */
export function parsePositiveWholeQuantity(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !/^\d+(?:\.0+)?$/.test(value.trim())) return null;

  const parsed = typeof value === "number" ? value : Number(value.trim());
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > 2_147_483_647) return null;
  return parsed;
}
