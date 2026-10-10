/**
 * Privileged-role assignment rules, shared by every SERVER-side code path that
 * writes `users.role_id` with the service-role client (which bypasses RLS).
 *
 * The database enforces the same rule independently (see
 * db/roshan_security_privileged_role_guard.sql); this module is the
 * application-layer half of that defence in depth.
 *
 * Everything here fails closed: unknown caller or unknown role => denied.
 */

export const SUPER_ADMIN_ROLE_CODE = "super_admin";

export type CallerContext = {
  /** True only when the caller's *active* profile has the super_admin role. */
  isSuperAdmin: boolean;
};

export type TargetRole = {
  code: string | null;
};

/** The only privileged role today. Add codes here to protect more roles. */
export function isPrivilegedRole(role: TargetRole | null | undefined): boolean {
  // Unknown role => treat as privileged (fail closed).
  if (!role) return true;
  return role.code === SUPER_ADMIN_ROLE_CODE;
}

/**
 * May `caller` assign `target` to a user?
 * - The target role must exist (null => false, even for a super admin).
 * - Only a super admin may assign a privileged role.
 */
export function canAssignRole(
  caller: CallerContext | null | undefined,
  target: TargetRole | null | undefined,
): boolean {
  if (!caller || !target) return false;
  if (caller.isSuperAdmin === true) return true;
  return !isPrivilegedRole(target);
}
