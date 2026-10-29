import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { CheckCircle2 } from "lucide-react";
import { useCallback, useEffect, useState } from "react";

import { ErrorBox, Field } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/lib/auth";
import { rpc } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/setup")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "First-time setup — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Create the first Super Admin account for the ROSHAN Medical Center system.",
      },
      { property: "og:title", content: "First-time setup — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Create the first Super Admin account for the ROSHAN Medical Center system.",
      },
    ],
  }),
  component: SetupPage,
});

function SetupPage() {
  const { t, lang } = useLang();
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const [checking, setChecking] = useState(true);
  const [required, setRequired] = useState(false);
  const [checkFailed, setCheckFailed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ full_name: "", email: "", phone: "", password: "" });

  const checkSetupRequired = useCallback(async () => {
    setChecking(true);
    setCheckFailed(false);
    setError(null);
    try {
      const need = await rpc<boolean>("setup_required");
      setRequired(Boolean(need));
    } catch (e) {
      if (e instanceof Error && /permission denied/i.test(e.message)) {
        // The setup RPC is intentionally unavailable to anon after initialization.
        setRequired(false);
        return;
      }
      console.warn("[public/setup] status check failed; server details suppressed");
      setCheckFailed(true);
    } finally {
      setChecking(false);
    }
  }, []);

  useEffect(() => {
    void checkSetupRequired();
  }, [checkSetupRequired]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      // 1. Create the auth account (or sign in if it already exists).
      const { data: signUp, error: suErr } = await supabase.auth.signUp({
        email: form.email.trim(),
        password: form.password,
        options: { emailRedirectTo: window.location.origin },
      });
      if (suErr && !/already/i.test(suErr.message)) {
        throw new Error("First-run account creation failed");
      }

      if (!signUp?.session) {
        const { error: siErr } = await supabase.auth.signInWithPassword({
          email: form.email.trim(),
          password: form.password,
        });
        if (siErr) {
          throw new Error("First-run account sign-in failed");
        }
      }

      // 2. Link auth.uid() into public.users with the super_admin role.
      await rpc("bootstrap_super_admin", {
        _full_name: form.full_name,
        _email: form.email.trim(),
        _phone: form.phone,
      });

      await refresh();
      void navigate({ to: "/dashboard", replace: true });
    } catch {
      console.warn("[public/setup] first-run submission failed; server details suppressed");
      setError(
        lang === "ar"
          ? "تعذّر إكمال التهيئة. تحقق من البيانات والاتصال، وأكّد بريدك الإلكتروني إذا طُلب منك ذلك، ثم حاول مرة أخرى."
          : "Could not complete setup. Check the details and connection, confirm your email if prompted, and try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <a
        href="#setup-card"
        className="sr-only focus:not-sr-only focus:fixed focus:start-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground"
      >
        {t("skip_to_content")}
      </a>
      <main
        id="setup-card"
        className="flex min-h-screen items-center justify-center bg-gradient-to-b from-accent/40 to-background px-4 py-10"
      >
        <div className="w-full max-w-lg">
          <div className="mb-6 flex flex-col items-center gap-3 text-center">
            <img src="/roshan-logo.png" alt={t("app_name")} className="h-20 object-contain" />
            <h1 className="text-xl font-bold">{t("first_run_setup")}</h1>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>{t("create_super_admin")}</CardTitle>
              <CardDescription>
                {lang === "ar"
                  ? "يتم إنشاء حساب واحد فقط. بعد ذلك يقوم المدير العام بإنشاء بقية المستخدمين."
                  : "Only one account is created here. The Super Admin then creates all other users."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ErrorBox error={error} />
              {checking ? (
                <p className="text-sm text-muted-foreground">{t("loading")}</p>
              ) : checkFailed ? (
                <div className="space-y-4">
                  <p className="text-sm text-muted-foreground" role="status">
                    {lang === "ar"
                      ? "تعذّر التحقق من حالة التهيئة. تحقق من اتصالك وحاول مرة أخرى."
                      : "Could not check setup status. Check your connection and try again."}
                  </p>
                  <Button
                    type="button"
                    className="w-full"
                    onClick={() => void checkSetupRequired()}
                  >
                    {t("retry")}
                  </Button>
                </div>
              ) : !required ? (
                <div className="space-y-4">
                  <div className="flex items-center gap-2 rounded-lg border border-success/40 bg-success/10 p-3 text-sm text-success">
                    <CheckCircle2 className="size-4" /> {t("setup_done")}
                  </div>
                  <Button className="w-full" onClick={() => void navigate({ to: "/auth" })}>
                    {t("sign_in")}
                  </Button>
                </div>
              ) : (
                <form method="POST" onSubmit={submit} className="space-y-4">
                  <Field label={t("full_name")}>
                    <Input
                      required
                      autoComplete="name"
                      value={form.full_name}
                      onChange={(e) => setForm({ ...form, full_name: e.target.value })}
                    />
                  </Field>
                  <Field label={t("email")}>
                    <Input
                      type="email"
                      dir="ltr"
                      required
                      autoComplete="email"
                      value={form.email}
                      onChange={(e) => setForm({ ...form, email: e.target.value })}
                    />
                  </Field>
                  <Field label={t("phone")}>
                    <Input
                      dir="ltr"
                      autoComplete="tel"
                      value={form.phone}
                      onChange={(e) => setForm({ ...form, phone: e.target.value })}
                    />
                  </Field>
                  <Field label={t("password")}>
                    <Input
                      type="password"
                      dir="ltr"
                      required
                      minLength={8}
                      autoComplete="new-password"
                      value={form.password}
                      onChange={(e) => setForm({ ...form, password: e.target.value })}
                    />
                  </Field>
                  <Button type="submit" className="w-full" disabled={busy}>
                    {busy ? t("saving") : t("create_super_admin")}
                  </Button>
                </form>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </>
  );
}
