import { createClient } from "@supabase/supabase-js";

import { resolveSupabaseKey } from "@/lib/supabase-key";

/**
 * Roshan Medical Center — existing Supabase project.
 * The publishable/anon key is safe in client code; database access is still
 * protected by RLS policies (see db/roshan_phase1_migration.sql).
 */
export const SUPABASE_URL = "https://jewzonxplxhogqrnhosl.supabase.co";
export const SUPABASE_PUBLISHABLE_KEY = resolveSupabaseKey({
  VITE_SUPABASE_PUBLISHABLE_KEY: import.meta.env["VITE_SUPABASE_PUBLISHABLE_KEY"],
  VITE_SUPABASE_ANON_KEY: import.meta.env["VITE_SUPABASE_ANON_KEY"],
});

if (!SUPABASE_PUBLISHABLE_KEY) {
  throw new Error(
    "Missing VITE_SUPABASE_PUBLISHABLE_KEY (or legacy VITE_SUPABASE_ANON_KEY) environment variable.",
  );
}

const isBrowser = typeof window !== "undefined";

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: isBrowser,
    autoRefreshToken: isBrowser,
    detectSessionInUrl: isBrowser,
    storageKey: "roshan-auth",
  },
});

/** Turns any Supabase/PostgREST failure into a readable, visible message. */
export function dbError(error: unknown): string {
  if (!error) return "";
  const e = error as { message?: string; details?: string; hint?: string; code?: string };
  const parts = [e.message, e.details, e.hint].filter(Boolean);
  const text = parts.join(" — ") || String(error);
  if (e.code === "42501" || /row-level security/i.test(text)) {
    return `${text} (permission denied by database policy)`;
  }
  if (e.code === "42703") {
    return `${text} (column missing — run db/roshan_phase1_migration.sql)`;
  }
  if (e.code === "42883" || e.code === "PGRST202") {
    return `${text} (database function missing — run db/roshan_phase1_migration.sql)`;
  }
  return text;
}
