import { createClient } from "@supabase/supabase-js";

/**
 * Roshan Medical Center — existing Supabase project.
 * The publishable (anon) key is safe in client code; every table is protected
 * by RLS policies (see db/roshan_phase1_migration.sql).
 */
export const SUPABASE_URL = "https://jewzonxplxhogqrnhosl.supabase.co";
export const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impld3pvbnhwbHhob2dxcm5ob3NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzQ1MzgsImV4cCI6MjEwMjExMDUzOH0.jYy4Gevuv9s-AOIOYGkQynryNblR-zW4vUPr-tARMMI";

const isBrowser = typeof window !== "undefined";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
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
