export type SupabaseKeyEnvironment = {
  VITE_SUPABASE_PUBLISHABLE_KEY?: string;
  VITE_SUPABASE_ANON_KEY?: string;
};

/** Prefer the current Supabase publishable key, while supporting existing Vercel envs. */
export function resolveSupabaseKey(env: SupabaseKeyEnvironment): string | undefined {
  return env.VITE_SUPABASE_PUBLISHABLE_KEY || env.VITE_SUPABASE_ANON_KEY;
}
