import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { SUPABASE_URL } from "./supabase";

/**
 * SERVER-ONLY Supabase client authenticated with the Supabase secret key (full access).
 *
 * ⚠️ Import this ONLY from `createServerFn` handlers (e.g. `*.server.ts`
 * files). Never import it from a route `component`, a hook that runs in the
 * browser, or any file reachable from client-rendered code — TanStack
 * Start only strips server-function bodies out of the client bundle, not
 * arbitrary modules, so a stray client-side import here would ship the
 * service_role key to every visitor's browser.
 *
 * The service_role key bypasses every Row Level Security policy. Any code
 * built on top of `getSupabaseAdmin()` is fully responsible for checking
 * "is this caller allowed to do this?" itself, in the handler, before
 * touching the database.
 */
let cached: SupabaseClient | null = null;

export function getSupabaseAdmin(): SupabaseClient {
  if (cached) return cached;

  // Prefer the new Supabase secret key (sb_secret_...). SUPABASE_SERVICE_ROLE_KEY is read only as a
  // fallback name so existing host settings keep working; it should hold the secret key too.
  const serviceRoleKey =
    process.env["SUPABASE_SECRET_KEY"] ?? process.env["SUPABASE_SERVICE_ROLE_KEY"];
  if (!serviceRoleKey) {
    throw new Error(
      "SUPABASE_SECRET_KEY is not set on the server. Add it to your " +
        "environment (.env locally, your host's project settings in " +
        "production) — see .env.example. Do NOT prefix it with VITE_, or " +
        "it will be bundled into the client and exposed publicly.",
    );
  }

  cached = createClient(SUPABASE_URL, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  return cached;
}
