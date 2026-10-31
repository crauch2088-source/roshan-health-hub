export type ExpiryStatus = "healthy" | "expiring_soon" | "expired" | "unknown";

export const DEFAULT_EXPIRY_THRESHOLD_DAYS = 90;

/** Parse a date-only value as a calendar date, not UTC midnight. */
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
  ) {
    return null;
  }
  return utc / 86_400_000;
}

function todayDayNumber(): number {
  const today = new Date();
  return Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()) / 86_400_000;
}

/**
 * Missing, malformed, and impossible expiry dates are unknown, never healthy.
 * Date-only comparisons are timezone independent and use the local calendar day.
 */
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

export const EXPIRY_TONE: Record<ExpiryStatus, string> = {
  healthy: "bg-success/15 text-success border-success/30",
  expiring_soon: "bg-warning/15 text-warning border-warning/30",
  expired: "bg-destructive/15 text-destructive border-destructive/30",
  unknown: "bg-muted text-muted-foreground border-border",
};
