import { createFileRoute, Outlet, redirect, useNavigate } from "@tanstack/react-router";

import { AppShell } from "@/components/app-shell";
import { ErrorBox, Loading } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated")({
  ssr: false,
  beforeLoad: async () => {
    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) throw redirect({ to: "/auth" });
    return { authUser: data.user };
  },
  component: ProtectedLayout,
});

function ProtectedLayout() {
  const { loading, user, error, signOut } = useAuth();
  const { t, lang } = useLang();
  const navigate = useNavigate();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Loading />
      </div>
    );
  }

  // Signed in with Supabase Auth but not linked to a public.users row yet.
  if (!user) {
    return (
      <div className="flex min-h-screen items-center justify-center px-4">
        <div className="w-full max-w-md space-y-4 text-center">
          <img src="/roshan-logo.png" alt="" className="mx-auto h-16 object-contain" />
          <ErrorBox error={error} />
          <p className="text-sm text-muted-foreground">
            {lang === "ar"
              ? "هذا الحساب غير مرتبط بمستخدم في النظام. تواصل مع المدير العام، أو أكمل التهيئة الأولى إذا كان النظام جديداً."
              : "This account is not linked to a system user. Contact the Super Admin, or complete first-time setup if this is a new system."}
          </p>
          <div className="flex justify-center gap-2">
            <Button onClick={() => void navigate({ to: "/setup" })}>{t("first_run_setup")}</Button>
            <Button
              variant="outline"
              onClick={async () => {
                await signOut();
                void navigate({ to: "/auth", replace: true });
              }}
            >
              {t("sign_out")}
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <AppShell>
      <Outlet />
    </AppShell>
  );
}
