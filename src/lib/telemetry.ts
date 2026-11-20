import { redactSensitive, safeRequestTarget } from "./redact.ts";

export interface RawTelemetryInput {
  environment?: string;
  commitSha?: string;
  route?: string;
  method?: string;
  rpcName?: string;
  sqlState?: string;
  errorCategory?: string;
  message?: string;
  [extra: string]: unknown;
}

export interface TelemetryEnvelope {
  timestamp: string;
  environment: string;
  commitSha: string;
  route: string;
  rpcName: string | null;
  sqlState: string | null;
  errorCategory: string;
  redactedMessage: string;
}

export interface TelemetryDispatchResult {
  sent: boolean;
  reason?: "unconfigured" | "http_error" | "network_or_timeout";
}

export type TelemetryFetcher = (
  input: string,
  init: { method: string; headers: Record<string, string>; body: string; signal: AbortSignal },
) => Promise<{ ok: boolean }>;

const MAX_MESSAGE_LENGTH = 500;
const DEFAULT_DISPATCH_TIMEOUT_MS = 1500;

const ARABIC_PHONE_OR_ID_RE = /(?:\+?249|00249|0)[19]\d[\s-]?\d{3}[\s-]?\d{4}/g;
const NAMED_PERSON_FIELD_RE =
  /\b(?:patient|name|full_name|المريض|الاسم)\s*[:=]\s*[^\n,;]+/giu;

export function redactClinicalText(value: string): string {
  const stage1 = redactSensitive(value);
  const stage2 = stage1.replace(ARABIC_PHONE_OR_ID_RE, "[REDACTED]");
  return stage2.replace(NAMED_PERSON_FIELD_RE, "[REDACTED]").slice(0, MAX_MESSAGE_LENGTH);
}

export function buildAllowlistedTelemetryEnvelope(input: RawTelemetryInput): TelemetryEnvelope {
  const rawRoute = typeof input.route === "string" && input.route.trim() ? input.route : "/";
  const method = typeof input.method === "string" && input.method.trim() ? input.method : "GET";
  const safeRoute = safeRequestTarget(rawRoute, method);

  return {
    timestamp: new Date().toISOString(),
    environment:
      typeof input.environment === "string" && input.environment.trim()
        ? input.environment.trim().slice(0, 32)
        : "unknown",
    commitSha:
      typeof input.commitSha === "string" && input.commitSha.trim()
        ? input.commitSha.trim().slice(0, 40)
        : "unknown",
    route: safeRoute,
    rpcName:
      typeof input.rpcName === "string" && /^[a-zA-Z0-9_.]+$/.test(input.rpcName)
        ? input.rpcName.slice(0, 100)
        : null,
    sqlState:
      typeof input.sqlState === "string" && /^[0-9A-Z]{5}$/.test(input.sqlState)
        ? input.sqlState
        : null,
    errorCategory:
      typeof input.errorCategory === "string" && /^[a-zA-Z0-9_.-]+$/.test(input.errorCategory)
        ? input.errorCategory.slice(0, 64)
        : "unclassified_error",
    redactedMessage:
      typeof input.message === "string" ? redactClinicalText(input.message) : "error",
  };
}

export async function dispatchTelemetryFailOpen(
  envelope: TelemetryEnvelope,
  endpoint: string | undefined,
  fetcher: TelemetryFetcher = fetch,
  timeoutMs = DEFAULT_DISPATCH_TIMEOUT_MS,
): Promise<TelemetryDispatchResult> {
  const target = endpoint?.trim();
  if (!target) {
    return { sent: false, reason: "unconfigured" };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetcher(target, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(envelope),
      signal: controller.signal,
    });
    return response.ok ? { sent: true } : { sent: false, reason: "http_error" };
  } catch {
    return { sent: false, reason: "network_or_timeout" };
  } finally {
    clearTimeout(timer);
  }
}
