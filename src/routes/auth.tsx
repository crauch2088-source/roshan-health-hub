import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Field, ErrorBox } from "@/components/kit";
import { useAuth } from "@/lib/auth";
import { rpc } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/auth")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Sign in — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Staff sign-in for the ROSHAN Medical Center management system.",
      },
      { property: "og:title", content: "Sign in — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Staff sign-in for the ROSHAN Medical Center management system.",
      },
    ],
  }),
  component: AuthPage,
});

type Mode = "signin" | "forgot" | "recover";

function AuthPage() {
  const { t, lang, toggle } = useLang();
  const { signIn, session, user } = useAuth();
  const navigate = useNavigate();
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [setupNeeded, setSetupNeeded] = useState(false);
  const [setupCheckFailed, setSetupCheckFailed] = useState(false);

  useEffect(() => {
    if (window.location.hash.includes("type=recovery")) setMode("recover");
    rpc<boolean>("setup_required")
      .then((need) => setSetupNeeded(Boolean(need)))
      .catch(() => setSetupCheckFailed(true));
  }, []);

  useEffect(() => {
    if (session && user && mode !== "recover") void navigate({ to: "/dashboard", replace: true });
  }, [session, user, mode, navigate]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      if (mode === "signin") {
        await signIn(email.trim(), password);
        void navigate({ to: "/dashboard", replace: true });
      } else if (mode === "forgot") {
        const { error: e2 } = await supabase.auth.resetPasswordForEmail(email.trim(), {
          redirectTo: `${window.location.origin}/auth`,
        });
        if (e2) throw new Error("Password reset request failed");
        toast.success(lang === "ar" ? "تم إرسال رابط الاستعادة" : "Reset link sent");
        setMode("signin");
      } else {
        const { error: e3 } = await supabase.auth.updateUser({ password });
        if (e3) throw new Error("Password recovery update failed");
        toast.success(t("saved"));
        void navigate({ to: "/dashboard", replace: true });
      }
    } catch {
      console.warn(`[public/auth] ${mode} failed; server details suppressed`);
      setError(
        lang === "ar"
          ? mode === "signin"
            ? "تعذّر تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور ثم حاول مرة أخرى."
            : mode === "forgot"
              ? "تعذّر إرسال رابط إعادة تعيين كلمة المرور. تحقق من العنوان وحاول مرة أخرى."
              : "تعذّر تحديث كلمة المرور. افتح رابط استعادة صالحاً ثم حاول مرة أخرى."
          : mode === "signin"
            ? "Sign-in failed. Check the email and password, then try again."
            : mode === "forgot"
              ? "Could not send a password-reset link. Check the address and try again."
              : "Could not update the password. Open a valid recovery link and try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <a
        href="#auth-card"
        className="sr-only focus:not-sr-only focus:fixed focus:start-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground"
      >
        {t("skip_to_content")}
      </a>
      <main
        id="auth-card"
        className="flex min-h-screen items-center justify-center bg-gradient-to-b from-accent/40 to-background px-4 py-10"
      >
        <div className="w-full max-w-md">
          <div className="mb-6 flex flex-col items-center gap-3 text-center">
            <img src="/roshan-logo.png" alt={t("app_name")} className="h-20 object-contain" />
            <h1 className="text-xl font-bold text-foreground">{t("app_name")}</h1>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>
                {mode === "signin"
                  ? t("sign_in")
                  : mode === "forgot"
                    ? t("reset_password")
                    : t("new_password")}
              </CardTitle>
              <CardDescription>{t("signup_disabled")}</CardDescription>
            </CardHeader>
            <CardContent>
              <ErrorBox error={error} />
              <form method="POST" onSubmit={submit} className="space-y-4">
                {mode !== "recover" ? (
                  <Field label={t("email")}>
                    <Input
                      type="email"
                      dir="ltr"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      autoComplete="username"
                    />
                  </Field>
                ) : null}
                {mode !== "forgot" ? (
                  <Field label={mode === "recover" ? t("new_password") : t("password")}>
                    <Input
                      type="password"
                      dir="ltr"
                      required
                      minLength={6}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      autoComplete={mode === "recover" ? "new-password" : "current-password"}
                    />
                  </Field>
                ) : null}

                <Button type="submit" className="w-full" disabled={busy}>
                  {busy
                    ? t("loading")
                    : mode === "signin"
                      ? t("sign_in")
                      : mode === "forgot"
                        ? t("send_reset_link")
                        : t("update_password")}
                </Button>
              </form>

              <div className="mt-4 flex flex-wrap items-center justify-between gap-2 text-sm">
                {mode === "signin" ? (
                  <button
                    type="button"
                    className="text-primary hover:underline"
                    onClick={() => setMode("forgot")}
                  >
                    {t("forgot_password")}
                  </button>
                ) : (
                  <button
                    type="button"
                    className="text-primary hover:underline"
                    onClick={() => setMode("signin")}
                  >
                    {t("back")}
                  </button>
                )}
                <button
                  type="button"
                  className="text-muted-foreground hover:underline"
                  onClick={toggle}
                >
                  {lang === "ar" ? "English" : "العربية"}
                </button>
              </div>

              {setupCheckFailed ? (
                <div className="mt-4 space-y-3" role="status">
                  <p className="text-sm text-muted-foreground">
                    {lang === "ar"
                      ? "تعذّر التحقق من حالة التهيئة. يمكنك إعادة المحاولة من صفحة التهيئة الأولى."
                      : "Could not check setup status. You can retry from the first-time setup page."}
                  </p>
                  <Button
                    type="button"
                    variant="outline"
                    className="w-full"
                    onClick={() => void navigate({ to: "/setup" })}
                  >
                    {t("first_run_setup")}
                  </Button>
                </div>
              ) : setupNeeded ? (
                <Button
                  type="button"
                  variant="outline"
                  className="mt-4 w-full"
                  onClick={() => void navigate({ to: "/setup" })}
                >
                  {t("first_run_setup")}
                </Button>
              ) : null}
            </CardContent>
          </Card>
        </div>
      </main>
    </>
  );
}
