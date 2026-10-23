/**
 * Server-only data path for the Roshan AI assistants.
 *
 * Two jobs:
 * 1. Prove who is calling. The bearer token attached to the server-function
 *    call is revalidated with Supabase Auth, then the caller's real Roshan
 *    profile and permissions are read from `get_my_app_profile` — the same
 *    source the sidebar uses. Everything fails closed.
 * 2. Build the model input. Rows are read with the caller's own token, so RLS
 *    applies exactly as it does in the rest of the app; contact details are
 *    dropped before anything is handed to the model.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getRequestHeader } from "@tanstack/react-start/server";
import { isSensitivePromptColumn, sanitizePromptValue } from "./prompt-utils.ts";

import { resolveSupabaseKey } from "@/lib/supabase-key";

export type Row = Record<string, unknown>;

export type AppAccess = {
  /** RLS-scoped client: reads as the signed-in user, never as a service role. */
  supabase: SupabaseClient;
  userId: string;
  roleCode: string | null;
  isSuperAdmin: boolean;
  can: (code: string) => boolean;
};

const PROJECT_URL_FALLBACK = "https://jewzonxplxhogqrnhosl.supabase.co";

/**
 * Contact identifiers the assistant has no clinical use for. Clinical content
 * itself is passed through — a clinician approved full record access, with
 * every answer reviewed before it is used.
 */
const MAX_FIELD_CHARS = 600;

function dataApiConfig(): { url: string; key: string } {
  const url =
    process.env["SUPABASE_URL"] || import.meta.env["VITE_SUPABASE_URL"] || PROJECT_URL_FALLBACK;
  const key =
    process.env["SUPABASE_PUBLISHABLE_KEY"] ||
    resolveSupabaseKey({
      VITE_SUPABASE_PUBLISHABLE_KEY: import.meta.env["VITE_SUPABASE_PUBLISHABLE_KEY"],
      VITE_SUPABASE_ANON_KEY: import.meta.env["VITE_SUPABASE_ANON_KEY"],
    });
  if (!key) {
    throw new Error(
      "The assistant cannot read records because the Supabase publishable key is not configured on the server.",
    );
  }
  return { url, key };
}

/**
 * Verifies the caller and returns an access handle. `permission` is the module
 * read permission the assistant is standing in for — the assistant never
 * grants access the screen itself would not.
 */
export async function requireAppAccess(permission: string): Promise<AppAccess> {
  const authHeader = getRequestHeader("authorization") ?? "";
  const token = authHeader.replace(/^\s*bearer\s+/i, "").trim();
  if (!token) {
    throw new Error("Please sign in again to use the assistant.");
  }

  const { url, key } = dataApiConfig();
  const supabase = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, storage: undefined },
    global: { headers: { apikey: key, Authorization: `Bearer ${token}` } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) {
    throw new Error("Your session has expired. Please sign in again.");
  }

  const { data: profileData, error: profileError } = await supabase.rpc("get_my_app_profile");
  if (profileError || !profileData) {
    throw new Error("Could not confirm your Roshan permissions. Please try again.");
  }

  const profile = profileData as { user?: Row; permissions?: unknown };
  const profileUser = profile.user ?? {};
  const roleCode = typeof profileUser["role_code"] === "string" ? profileUser["role_code"] : null;
  const isSuperAdmin = roleCode === "super_admin";
  const active = profileUser["active"] !== false;
  const permissions = new Set(
    Array.isArray(profile.permissions)
      ? profile.permissions.filter((code): code is string => typeof code === "string")
      : [],
  );

  if (!active) throw new Error("Your Roshan account is inactive.");

  const can = (code: string) => active && (isSuperAdmin || permissions.has(code));
  if (!can(permission)) {
    throw new Error("You don't have permission to use the assistant here.");
  }

  return { supabase, userId: userData.user.id, roleCode, isSuperAdmin, can };
}

/** Row → plain text, dropping direct/internal identifiers and truncating long prose. */
export function renderRow(row: Row, columns?: string[]): string {
  const entries = columns ? columns.map((c) => [c, row[c]] as const) : Object.entries(row);
  const parts: string[] = [];
  for (const [column, value] of entries) {
    if (isSensitivePromptColumn(column)) continue;
    if (value === null || value === undefined || value === "") continue;
    const text =
      typeof value === "object"
        ? JSON.stringify(sanitizePromptValue(value))
        : String(value);
    parts.push(
      `${column}=${text.length > MAX_FIELD_CHARS ? `${text.slice(0, MAX_FIELD_CHARS)}…` : text}`,
    );
  }
  return parts.join(" | ");
}

/**
 * Row set → a numbered brief the model can cite. Returns the legend of record
 * labels so the UI can show which rows an answer was built from.
 */
export function renderRows(
  title: string,
  rows: Row[],
  options: { prefix: string; columns?: string[]; maxRows: number },
): { text: string; legend: string[] } {
  if (!rows.length) return { text: `${title}: none`, legend: [] };
  const legend: string[] = [];
  const lines: string[] = [`${title}:`];
  rows.slice(0, options.maxRows).forEach((row, index) => {
    const label = `${options.prefix}${index + 1}`;
    legend.push(label);
    lines.push(`[${label}] ${renderRow(row, options.columns)}`);
  });
  if (rows.length > options.maxRows) {
    lines.push(`(${rows.length - options.maxRows} more not shown)`);
  }
  return { text: lines.join("\n"), legend };
}

/** Single record → brief line, or `none`. */
export function renderOne(title: string, row: Row | null | undefined, columns?: string[]): string {
  if (!row) return `${title}: none`;
  return `${title}: ${renderRow(row, columns)}`;
}

export function clampText(value: string | null | undefined, max = 2000): string {
  const text = (value ?? "").trim();
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

/** Reads rows or returns [] — used for optional context the model can do without. */
export async function readRows(
  access: AppAccess,
  build: (client: SupabaseClient) => PromiseLike<{ data: unknown; error: unknown }>,
): Promise<Row[]> {
  try {
    const { data, error } = await build(access.supabase);
    if (error) return [];
    return Array.isArray(data) ? (data as Row[]) : [];
  } catch {
    return [];
  }
}
