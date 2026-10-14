// Conservative redaction for server-side diagnostics. Never use this to alter clinical
// data displayed to clinicians; it is only for values sent to log sinks.
const REDACTED = "[REDACTED]";
const MAX_DEPTH = 8;
const SENSITIVE_KEY =
  /(?:password|passwd|secret|token|api[_-]?key|authorization|cookie|email|phone|mobile|national[_-]?id|patient|medical[_-]?record|mrn|access[_-]?key|date[_-]?of[_-]?birth|\bdob\b|address|social[_-]?security)/i;
const RULES: Array<[RegExp, string]> = [
  [
    /\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key|apikey)\b\s*[:=]\s*[^\r\n]*/gi,
    "$1: " + REDACTED,
  ],
  [/\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}/gi, "$1 " + REDACTED],
  [/\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}/g, REDACTED],
  [/\bsb_(?:secret|publishable)_[A-Za-z0-9_-]+/g, REDACTED],
  [/\b(?:sk|pk|rk|ghp|gho|github_pat|xox[abprs])[-_][A-Za-z0-9_-]{16,}/gi, REDACTED],
  [
    /\b([A-Za-z_]*(?:password|passwd|secret|token|api[_-]?key|service[_-]?role|private[_-]?key)[A-Za-z_]*)\b(["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;&}]+)/gi,
    "$1$2" + REDACTED,
  ],
  [/\(([A-Za-z0-9_, "]+)\)=\(([^)]*)\)/g, "($1)=(" + REDACTED + ")"],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, REDACTED],
  [/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "[UUID]"],
  [/\+?\d(?:[\s-]?\d){6,}/g, REDACTED],
];
export function redactSensitive(text: string): string {
  let output = text;
  for (const [pattern, replacement] of RULES) output = output.replace(pattern, replacement);
  return output;
}
export function sanitizeLogValue(value: unknown): unknown {
  const seen = new WeakSet<object>();
  const visit = (current: unknown, depth: number, key?: string): unknown => {
    if (key && SENSITIVE_KEY.test(key)) return REDACTED;
    if (typeof current === "string") return redactSensitive(current);
    if (typeof current === "bigint") return current.toString();
    if (
      current === null ||
      current === undefined ||
      typeof current === "number" ||
      typeof current === "boolean"
    )
      return current;
    if (typeof current === "function" || typeof current === "symbol")
      return "[" + typeof current + "]";
    if (depth >= MAX_DEPTH) return "[MaxDepth]";
    if (typeof current !== "object") return String(current);
    if (seen.has(current)) return "[Circular]";
    seen.add(current);
    if (current instanceof Error) {
      const error = current as Error & { cause?: unknown };
      return {
        name: redactSensitive(error.name),
        message: redactSensitive(error.message),
        ...(error.stack ? { stack: redactSensitive(error.stack) } : {}),
        ...(error.cause !== undefined ? { cause: visit(error.cause, depth + 1, "cause") } : {}),
      };
    }
    if (current instanceof Date)
      return Number.isNaN(current.getTime()) ? "[Invalid Date]" : current.toISOString();
    if (Array.isArray(current)) return current.map((item) => visit(item, depth + 1));
    const output: Record<string, unknown> = {};
    for (const [childKey, childValue] of Object.entries(current)) {
      output[childKey] = visit(childValue, depth + 1, childKey);
    }
    return output;
  };
  return visit(value, 0);
}
export function safeRequestTarget(rawUrl: string, method: string): string {
  let path: string;
  try {
    path = new URL(rawUrl).pathname;
  } catch {
    path = rawUrl.split(/[?#]/)[0] ?? "";
  }
  return method.toUpperCase() + " " + redactSensitive(path);
}