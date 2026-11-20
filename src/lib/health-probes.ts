export interface HealthProbeEnv {
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  commitSha?: string;
}

export interface ReadinessCheckResult {
  ok: boolean;
  status: "ok" | "unconfigured" | "unavailable";
}

export type DependencyProbe = (url: string, apiKey: string, timeoutMs: number) => Promise<boolean>;

const DEFAULT_TIMEOUT_MS = 3000;

function readProcessEnv(): HealthProbeEnv {
  const env = typeof process !== "undefined" && process.env ? process.env : {};
  return {
    supabaseUrl: env.VITE_SUPABASE_URL ?? env.SUPABASE_URL,
    supabaseAnonKey:
      env.VITE_SUPABASE_PUBLISHABLE_KEY ?? env.VITE_SUPABASE_ANON_KEY ?? env.SUPABASE_ANON_KEY,
    commitSha: env.VERCEL_GIT_COMMIT_SHA ?? env.GITHUB_SHA ?? "unknown",
  };
}

async function defaultSupabaseProbe(
  supabaseUrl: string,
  apiKey: string,
  timeoutMs: number,
): Promise<boolean> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const base = supabaseUrl.replace(/\/+$/, "");
    const response = await fetch(`${base}/auth/v1/health`, {
      method: "GET",
      headers: { apikey: apiKey },
      signal: controller.signal,
    });
    return response.ok;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

export function buildLivenessResponse(env: HealthProbeEnv = readProcessEnv()): Response {
  const body = {
    status: "alive",
    service: "roshan-health-hub",
    commitSha: env.commitSha ?? "unknown",
    timestamp: new Date().toISOString(),
  };
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

export async function checkSupabaseReadiness(
  env: HealthProbeEnv = readProcessEnv(),
  probe: DependencyProbe = defaultSupabaseProbe,
  timeoutMs = DEFAULT_TIMEOUT_MS,
): Promise<ReadinessCheckResult> {
  const url = env.supabaseUrl?.trim();
  const key = env.supabaseAnonKey?.trim();
  if (!url || !key) {
    return { ok: false, status: "unconfigured" };
  }
  const reachable = await probe(url, key, timeoutMs);
  return reachable ? { ok: true, status: "ok" } : { ok: false, status: "unavailable" };
}

export async function buildReadinessResponse(
  env: HealthProbeEnv = readProcessEnv(),
  probe: DependencyProbe = defaultSupabaseProbe,
  timeoutMs = DEFAULT_TIMEOUT_MS,
): Promise<Response> {
  const supabaseCheck = await checkSupabaseReadiness(env, probe, timeoutMs);
  const ready = supabaseCheck.ok;
  const body = {
    status: ready ? "ready" : "not_ready",
    service: "roshan-health-hub",
    checks: {
      supabase: supabaseCheck.status,
    },
    commitSha: env.commitSha ?? "unknown",
    timestamp: new Date().toISOString(),
  };
  return new Response(JSON.stringify(body), {
    status: ready ? 200 : 503,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}
