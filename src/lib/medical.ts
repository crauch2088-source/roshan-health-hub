/** Clinical + formatting calculations shared across the app. */

export function calcAge(dob?: string | null): number | null {
  if (!dob) return null;
  const d = new Date(dob);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();

  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();

  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) {
    age--;
  }
  return age >= 0 ? age : null;
}

export function calcBmi(weightKg?: number | null, heightCm?: number | null): number | null {
  if (!weightKg || !heightCm || heightCm <= 0) return null;
  const m = heightCm / 100;
  return Math.round((weightKg / (m * m)) * 10) / 10;
}

/** Naegele's rule: LMP + 280 days. */
export function calcEdd(lmp?: string | null): string | null {
  if (!lmp) return null;
  const d = new Date(lmp);
  if (Number.isNaN(d.getTime())) return null;
  d.setDate(d.getDate() + 280);
  return d.toISOString().slice(0, 10);
}

export function calcGestationalDays(lmp?: string | null): number | null {
  if (!lmp) return null;
  const d = new Date(lmp);
  if (Number.isNaN(d.getTime())) return null;
  const diffTime = Math.abs(Date.now() - d.getTime());
  const days = Math.floor(diffTime / (1000 * 60 * 60 * 24));
  return days >= 0 ? days : null;
}

export function formatGestationalAge(days?: number | null, lang: "ar" | "en" = "ar"): string {
  if (days == null) return "—";
  const w = Math.floor(days / 7);
  const d = days % 7;
  return lang === "ar" ? `${w} أسبوع و${d} يوم` : `${w}w ${d}d`;
}

export function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

export function money(value?: number | null, currency = "SDG"): string {
  const n = Number(value ?? 0);
  return `${n.toLocaleString(undefined, { maximumFractionDigits: 2 })} ${currency}`;
}

export function formatDate(value?: string | null): string {
  if (!value) return "—";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toISOString().slice(0, 10);
}

export function formatDateTime(value?: string | null): string {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return `${d.toISOString().slice(0, 10)} ${d.toTimeString().slice(0, 5)}`;
}

export const BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"] as const;
export const MARITAL = ["single", "married", "divorced", "widowed"] as const;
export const EXPENSE_CATEGORIES = [
  "salaries", "rent", "electricity", "water", "internet", "maintenance", "other"
] as const;

export type ResultFlag = "low" | "high" | "normal";

/** Flags a numeric lab result against a reference range. */
export function flagResult(
  value: string | null | undefined,
  min?: number | null,
  max?: number | null,
): ResultFlag | null {
  if (value == null || value === "") return null;
  const n = Number(value);
  if (Number.isNaN(n)) return null;

  if (min != null && n < min) return "low";
  if (max != null && n > max) return "high";
  if (min != null || max != null) return "normal";
  return null;
}
