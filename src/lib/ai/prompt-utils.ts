/** Pure prompt formatting and privacy helpers for the server-only AI assistants. */

export type PromptPart = string | { text: string; legend: readonly string[] };

const SENSITIVE_PROMPT_COLUMNS = new Set([
  "id",
  "full_name",
  "patient_name",
  "first_name",
  "last_name",
  "phone",
  "mobile",
  "email",
  "address",
  "national_id",
  "nationality",
  "emergency_contact",
  "emergency_phone",
  "photo",
  "signature",
  "mrn",
  "medical_record_number",
  "patient_id",
  "visit_id",
  "branch_id",
  "invoice_id",
  "user_id",
  "auth_user_id",
  "created_by",
  "updated_by",
]);

function normalizeColumnName(column: string): string {
  return column.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/[-\s]/g, "_").toLowerCase();
}

export function isSensitivePromptColumn(column: string): boolean {
  return SENSITIVE_PROMPT_COLUMNS.has(normalizeColumnName(column));
}

/** Recursively strip identifying keys so nested Supabase relations cannot bypass row-level redaction. */
export function sanitizePromptValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sanitizePromptValue);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => !isSensitivePromptColumn(key))
        .map(([key, nested]) => [key, sanitizePromptValue(nested)]),
    );
  }
  return value;
}

/** Converts rendered row objects to text and bounds the full model prompt. */
export function withinBudget(parts: readonly PromptPart[], maxChars: number): string {
  const joined = parts
    .map((part) => (typeof part === "string" ? part : part.text))
    .filter(Boolean)
    .join("\n\n");
  return joined.length > maxChars ? `${joined.slice(0, maxChars)}\n(truncated)` : joined;
}
