import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";

import { useAuth } from "@/lib/auth";
import { rpc } from "@/lib/db";
import { useLang } from "@/lib/i18n";

export const Route = createFileRoute("/")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "ROSHAN Medical Center — Clinic Management System" },
      {
        name: "description",
        content:
          "ROSHAN Medical Center management system: reception, clinics, EMR, laboratory, pharmacy, billing and accounting.",
      },
      { property: "og:title", content: "ROSHAN Medical Center — Clinic Management System" },
      {
        property: "og:description",
        content:
          "ROSHAN Medical Center management system: reception, clinics, EMR, laboratory, pharmacy, billing and accounting.",
      },
    ],
  }),
  component: Landing,
});

function Landing() {
  const navigate = useNavigate();
  const { loading, session, user } = useAuth();
  const { t } = useLang();

  useEffect(() => {
    if (loading) return;
    if (session && user) {
      void navigate({ to: "/dashboard", replace: true });
      return;
    }
    rpc<boolean>("setup_required")
      .then((need) => {
        void navigate({ to: need ? "/setup" : "/auth", replace: true });
      })
      .catch(() => {
        void navigate({ to: "/auth", replace: true });
      });
  }, [loading, session, user, navigate]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-gradient-to-b from-accent/40 to-background px-4 text-center">
      <img src="/roshan-logo.png" alt={t("app_name")} className="h-24 object-contain" />
      <h1 className="text-2xl font-bold text-foreground">{t("app_name")}</h1>
      <p className="text-sm text-muted-foreground">{t("loading")}</p>
    </div>
  );
}
