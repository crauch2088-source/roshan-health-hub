import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { getSupabaseAdmin } from "@/lib/supabase-admin";

const CreateStaffUserInput = z.object({
  /** The caller's current Supabase access token, used to identify + authorize them. */
  accessToken: z.string().min(1),
  full_name: z.string().trim().min(1, "Full name is required"),
  email: z.string().trim().toLowerCase().email("Invalid email"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  phone: z.string().trim().optional(),
  role_id: z.string().uuid("Invalid role"),
});

export type CreateStaffUserResult = { id: string };

type RoleRel = { code?: string | null } | { code?: string | null }[] | null;

function roleCode(roles: RoleRel): string | null {
  const r = Array.isArray(roles) ? roles[0] : roles;
  return r?.code ?? null;
}

/**
 * Creates a new staff auth account + application profile.
 *
 * This replaces the previous client-side `supabase.auth.signUp(...)` call,
 * which had two problems:
 *
 *  1. `signUp` on the client SDK signs the *browser* in as the newly
 *     created user, silently replacing the admin's own session.
 *  2. It relied entirely on the client-side `can()` check for
 *     authorization — a user could call `supabase.auth.signUp` directly
 *     from the browser console regardless of what the UI shows.
 *
 * Running this as a server function with the `service_role` key means the
 * account is created out-of-band (no session swap) and the permission
 * check happens against the database, not the client.
 */
export const createStaffUser = createServerFn({ method: "POST" })
  .validator(CreateStaffUserInput)
  .handler(async ({ data }): Promise<CreateStaffUserResult> => {
    const admin = getSupabaseAdmin();

    // 1. Identify the caller from the access token they already hold.
    const { data: callerAuth, error: callerAuthError } = await admin.auth.getUser(
      data.accessToken,
    );
    if (callerAuthError || !callerAuth.user) {
      throw new Error("Your session has expired. Please sign in again.");
    }

    // 2. Load the caller's app profile + role. Fails closed on every branch.
    const { data: callerRow, error: callerRowError } = await admin
      .from("users")
      .select("id, active, role_id, roles(code)")
      .eq("auth_user_id", callerAuth.user.id)
      .maybeSingle();

    if (callerRowError || !callerRow || !callerRow.active) {
      throw new Error("Your account is not permitted to create users.");
    }

    let allowed = roleCode(callerRow.roles as RoleRel) === "super_admin";

    if (!allowed && callerRow.role_id) {
      const { data: perm } = await admin
        .from("role_permissions")
        .select("permissions!inner(code)")
        .eq("role_id", callerRow.role_id)
        .eq("permissions.code", "users.create")
        .maybeSingle();
      allowed = Boolean(perm);
    }

    if (!allowed) {
      throw new Error("Your account is not permitted to create users.");
    }

    // 3. Create the auth account. Uses the admin API, which never touches
    //    the caller's own session.
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: data.email,
      password: data.password,
      email_confirm: true,
      user_metadata: { full_name: data.full_name },
    });

    if (createError || !created.user) {
      throw new Error(createError?.message ?? "Could not create the account.");
    }

    // 4. Create the application profile row. Roll back the auth account if
    //    this fails, so we never leave an orphaned login with no profile.
    const { error: profileError } = await admin.from("users").insert({
      full_name: data.full_name,
      email: data.email,
      phone: data.phone || null,
      role_id: data.role_id,
      auth_user_id: created.user.id,
      active: true,
    });

    if (profileError) {
      await admin.auth.admin.deleteUser(created.user.id);
      throw new Error(profileError.message);
    }

    return { id: created.user.id };
  });
