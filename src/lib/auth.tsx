import type { Session } from "@supabase/supabase-js";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { dbError, supabase } from "./supabase";

export type AppUser = {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  role_id: string | null;
  role_code: string | null;
  role_name: string | null;
  active: boolean;
};

type Role = {
  code: string;
  name: string;
};

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
  permissionsReady: boolean;
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
  const [permissionsReady, setPermissionsReady] = useState(false);

  const clearProfile = useCallback(() => {
    setUser(null);
    setPerms(new Set());
    setPermissionsReady(false);
  }, []);

  const loadProfile = useCallback(
    async (authUserId: string | undefined) => {
      if (!authUserId) {
        clearProfile();
        return;
      }

      setPermissionsReady(false);
      setError(null);

      const { data, error: profileError } = await supabase
        .from("users")
        .select(
          "id, full_name, email, phone, role_id, active, roles(code, name)",
        )
        .eq("auth_user_id", authUserId)
        .maybeSingle();

      if (profileError) {
        setError(dbError(profileError));
        clearProfile();
        return;
      }

      if (!data) {
        setUser(null);
        setPerms(new Set());
        setPermissionsReady(true);
        return;
      }

      const userData = data as unknown as UserDbResponse;
      const roleRel = Array.isArray(userData.roles)
        ? userData.roles[0]
        : userData.roles;

      const appUser: AppUser = {
        id: userData.id,
        full_name: userData.full_name ?? null,
        email: userData.email ?? null,
        phone: userData.phone ?? null,
        role_id: userData.role_id ?? null,
        role_code: roleRel?.code ?? null,
        role_name: roleRel?.name ?? null,
        active: userData.active ?? false,
      };

      /*
       * Never allow an inactive application user to operate the system,
       * even if the Supabase Auth session itself is still valid.
       */
      if (!appUser.active) {
        setUser(appUser);
        setPerms(new Set());
        setPermissionsReady(true);
        setError("Your Roshan account is inactive.");
        return;
      }

      setUser(appUser);

      /*
       * Super Admin is the ONLY role with implicit full permissions.
       * Admin is NOT Super Admin.
       */
      if (appUser.role_code === "super_admin") {
        setPerms(new Set(["*"]));
        setPermissionsReady(true);
        return;
      }

      if (!appUser.role_id) {
        setPerms(new Set());
        setPermissionsReady(true);
        setError("No application role is assigned to this account.");
        return;
      }

      const { data: rolePermissions, error: permissionsError } =
        await supabase
          .from("role_permissions")
          .select("permissions(code)")
          .eq("role_id", appUser.role_id);

      if (permissionsError) {
        setPerms(new Set());
        setPermissionsReady(false);
        setError(dbError(permissionsError));
        return;
      }

      const codes = (rolePermissions ?? [])
        .map(
          (row) =>
            (row as unknown as { permissions?: { code?: string } }).permissions
              ?.code,
        )
        .filter((code): code is string => Boolean(code));

      setPerms(new Set(codes));
      setPermissionsReady(true);
    },
    [clearProfile],
  );

  useEffect(() => {
    let mounted = true;

    const initialize = async () => {
      const { data, error: sessionError } =
        await supabase.auth.getSession();

      if (!mounted) return;

      if (sessionError) {
        setError(sessionError.message);
        setSession(null);
        clearProfile();
        setLoading(false);
        return;
      }

      setSession(data.session);

      if (data.session?.user?.id) {
        await loadProfile(data.session.user.id);
      } else {
        clearProfile();
      }

      if (mounted) {
        setLoading(false);
      }
    };

    void initialize();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!mounted) return;

      setSession(nextSession);

      /*
       * Do not perform database queries inside Supabase's auth event
       * callback. Schedule the profile load instead.
       */
      if (
        event === "SIGNED_IN" ||
        event === "SIGNED_OUT" ||
        event === "USER_UPDATED"
      ) {
        setTimeout(() => {
          if (!mounted) return;
          void loadProfile(nextSession?.user?.id);
        }, 0);
      }

      if (event === "SIGNED_OUT") {
        clearProfile();
      }
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [clearProfile, loadProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    const normalizedEmail = email.trim().toLowerCase();

    const { error: signInError } =
      await supabase.auth.signInWithPassword({
        email: normalizedEmail,
        password,
      });

    if (signInError) {
      throw new Error(signInError.message);
    }
  }, []);

  const signOut = useCallback(async () => {
    const { error: signOutError } = await supabase.auth.signOut();

    clearProfile();

    if (signOutError) {
      throw new Error(signOutError.message);
    }
  }, [clearProfile]);

  const refresh = useCallback(async () => {
    const { data, error: sessionError } =
      await supabase.auth.getSession();

    if (sessionError) {
      setError(sessionError.message);
      return;
    }

    setSession(data.session);
    await loadProfile(data.session?.user?.id);
  }, [loadProfile]);

  /*
   * SECURITY:
   * Only the exact super_admin role gets implicit full access.
   *
   * Admin permissions must come from role_permissions.
   */
  const isSuperAdmin = user?.role_code === "super_admin";

  const can = useCallback(
    (code: string) => {
      if (!user || !user.active) return false;
      if (!permissionsReady) return false;
      if (isSuperAdmin) return true;

      return perms.has(code);
    },
    [user, permissionsReady, isSuperAdmin, perms],
  );

  const canModule = useCallback(
    (module: string) => can(`${module}.read`),
    [can],
  );

  const value = useMemo<AuthCtx>(
    () => ({
      loading,
      session,
      user,
      perms,
      error,
      permissionsReady,
      can,
      canModule,
      isSuperAdmin,
      signIn,
      signOut,
      refresh,
    }),
    [
      loading,
      session,
      user,
      perms,
      error,
      permissionsReady,
      can,
      canModule,
      isSuperAdmin,
      signIn,
      signOut,
      refresh,
    ],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  const ctx = useContext(Ctx);

  if (!ctx) {
    throw new Error("useAuth must be used inside AuthProvider");
  }

  return ctx;
}