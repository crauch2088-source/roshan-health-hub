// Redacts secrets and patient-identifying data from text that is about to be written to
// server logs (SSR error reporting). Pure and dependency-free so it can be unit tested with
// `node --test`. Over-redacting is intentional: a log line may be less readable, never leaky.

const REDACTED = "[REDACTED]";

const RULES: Array<[RegExp, string]> = [
  // Authorization / cookie style headers or fields, whole value to end of line.
  [
    /\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key|apikey)\b\s*[:=]\s*[^\r\n]*/gi,
    `$1: ${REDACTED}`,
  ],
  // Bearer / Basic credentials anywhere.
  [/\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}/gi, `$1 ${REDACTED}`],
  // JWTs (header.payload.signature): Supabase legacy keys and user access tokens.
  [/\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}/g, REDACTED],
  // Supabase new-style keys and common provider prefixes.
  [/\bsb_(?:secret|publishable)_[A-Za-z0-9_-]+/g, REDACTED],
  [/\b(?:sk|pk|rk|ghp|gho|github_pat|xox[abprs])[-_][A-Za-z0-9_-]{16,}/g, REDACTED],
  // key=value / key: value pairs whose key name looks sensitive.
  [
    /\b([A-Za-z_]*(?:password|passwd|secret|token|api[_-]?key|service[_-]?role|private[_-]?key)[A-Za-z_]*)\b(["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;&}]+)/gi,
    `$1$2${REDACTED}`,
  ],
  // Postgres / PostgREST detail values: Key (national_id)=(123) -> value hidden.
  [/\(([A-Za-z0-9_, "]+)\)=\(([^)]*)\)/g, `($1)=(${REDACTED})`],
  // Emails.
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, REDACTED],
  // UUIDs (patient, user and row ids).
  [/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "[UUID]"],
  // Phone numbers / national ids / MRNs: 7+ consecutive digits (optionally spaced or dashed).
  [/\+?\d(?:[\s-]?\d){6,}/g, REDACTED],
];

export function redactSensitive(text: string): string {
  let out = text;
  for (const [pattern, replacement] of RULES) out = out.replace(pattern, replacement);
  return out;
}

/** Method and path only: no query string, no hash, ids replaced. Never log headers or bodies. */
export function safeRequestTarget(rawUrl: string, method: string): string {
  let path: string;
  try {
    path = new URL(rawUrl).pathname;
  } catch {
    path = rawUrl.split(/[?#]/)[0] ?? "";
  }
  return `${method.toUpperCase()} ${redactSensitive(path)}`;
}
