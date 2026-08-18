import type { Session } from "@supabase/supabase-js";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

import { dbError, supabase } from "./supabase";

export type AppUser = {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  role_id: string | null;
  role_code: string | null;
  role_name: string | null;
  active: boolean | null;
};

type Role = { code: string; name: string };
type UserDbResponse = {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  role_id: string | null;
  active: boolean | null;
  roles: Role | Role[] | null;
};

type AuthCtx = {
  loading: boolean;
  session: Session | null;
  user: AppUser | null;
  perms: Set<string>;
  error: string | null;
  can: (code: string) => boolean;
  canModule: (module: string) => boolean;
  isSuperAdmin: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  refresh: () => Promise<void>;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<AppUser | null>(null);
  const [perms, setPerms] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);

  const loadProfile = useCallback(async (authUserId: string | undefined) => {
    if (!authUserId) {
      setUser(null);
      setPerms(new Set());
      return;
    }
    const { data, error: e } = await supabase
      .from("users")
      .select("id, full_name, email, phone, role_id, active, roles(code, name)")
      .eq("auth_user_id", authUserId)
      .maybeSingle();

    if (e) {
      setError(dbError(e));
      setUser(null);
      setPerms(new Set());
      return;
    }
    if (!data) {
      setUser(null);
      setPerms(new Set());
      setError(null);
      return;
    }

    const userData = data as unknown as UserDbResponse;
    const roleRel = Array.isArray(userData.roles) ? userData.roles[0] : userData.roles;
    
    const appUser: AppUser = {
      id: userData.id,
      full_name: userData.full_name ?? null,
      email: userData.email ?? null,
      phone: userData.phone ?? null,
      role_id: userData.role_id ?? null,
      role_code: roleRel?.code ?? null,
      role_name: roleRel?.name ?? null,
      active: userData.active ?? true,
    };
    
    setUser(appUser);
    setError(null);

    if (appUser.role_id) {
      const { data: rp, error: pe } = await supabase
        .from("role_permissions")
        .select("permissions(code)")
        .eq("role_id", appUser.role_id);
      if (pe) setError(dbError(pe));
      const codes = (rp ?? [])
        .map((r) => (r as unknown as { permissions?: { code?: string } }).permissions?.code)
        .filter((c): c is string => Boolean(c));
      setPerms(new Set(codes));
    } else {
      setPerms(new Set());
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    supabase.auth.getSession().then(async ({ data }) => {
      if (!mounted) return;
      setSession(data.session);
      await loadProfile(data.session?.user?.id);
      if (mounted) setLoading(false);
    });

    const { data: sub } = supabase.auth.onAuthStateChange(async (event, next) => {
      if (!mounted) return;
      if (event === "TOKEN_REFRESHED" || event === "INITIAL_SESSION") {
        setSession(next);
        return;
      }
      setSession(next);
      await loadProfile(next?.user?.id);
    });
    return () => {
      mounted = false;
      sub.subscription.unsubscribe();
    };
  }, [loadProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    const { error: e } = await supabase.auth.signInWithPassword({ email, password });
    if (e) throw new Error(e.message);
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    setUser(null);
    setPerms(new Set());
  }, []);

  const refresh = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    setSession(data.session);
    await loadProfile(data.session?.user?.id);
  }, [loadProfile]);

  const roleCode = user?.role_code?.toLowerCase?.();
  const roleName = user?.role_name?.toLowerCase?.();
  const fallbackRole = (user as unknown as { role?: string })?.role?.toLowerCase?.();
  const isSuperAdmin =
    roleCode === "super_admin" ||
    roleCode === "admin" ||
    roleName === "super admin" ||
    roleName === "admin" ||
    fallbackRole === "super_admin";

  // If the permission table could not be resolved (empty set), don't lock the
  // user out of the whole UI — the database RLS policies remain the real gate.
  const permsUnresolved = perms.size === 0;

  const value = useMemo<AuthCtx>(
    () => ({
      loading,
      session,
      user,
      perms,
      error,
      isSuperAdmin,
      can: (code: string) => isSuperAdmin || permsUnresolved || perms.has(code),
      canModule: (module: string) =>
        isSuperAdmin || permsUnresolved || perms.has(`${module}.read`),
      signIn,
      signOut,
      refresh,
    }),
    [loading, session, user, perms, error, isSuperAdmin, permsUnresolved, signIn, signOut, refresh],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
