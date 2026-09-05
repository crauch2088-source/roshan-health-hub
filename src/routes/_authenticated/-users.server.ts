import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { getSupabaseAdmin } from "@/lib/supabase-admin";

const CreateStaffUserInput = z.object({
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

export const createStaffUser = createServerFn({ method: "POST" })
  .validator(CreateStaffUserInput)
  .handler(async ({ data }): Promise<CreateStaffUserResult> => {
    const admin = getSupabaseAdmin();
    const { data: callerAuth, error: callerAuthError } = await admin.auth.getUser(
      data.accessToken,
    );
    if (callerAuthError || !callerAuth.user) {
      throw new Error("Your session has expired. Please sign in again.");
    }

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

    const { data: created, error: createError } =
      await admin.auth.admin.createUser({
        email: data.email,
        password: data.password,
        email_confirm: true,
        user_metadata: { full_name: data.full_name },
      });
    if (createError || !created.user) {
      throw new Error(createError?.message ?? "Could not create the account.");
    }

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