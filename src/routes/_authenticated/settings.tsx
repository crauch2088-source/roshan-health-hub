import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { ErrorBox, Field, Loading, PageHeader, PermissionGate } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/settings")({
  head: () => ({
    meta: [
      { title: "Settings — ROSHAN Medical Center" },
      { name: "description", content: "Center identity, currency and invoice preferences." },
      { property: "og:title", content: "Settings — ROSHAN Medical Center" },
      { property: "og:description", content: "Center identity, currency and invoice preferences." },
    ],
  }),
  component: SettingsPage,
});

// Every key this page manages is intentionally public/UI configuration
// (center identity, currency, invoice text) — never a secret. See the
// Phase 1 migration for the `is_public` column this relies on.
const KEYS = [
  "center_name",
  "center_name_ar",
  "phone",
  "address",
  "currency",
  "tax_percent",
  "invoice_footer",
  "pharmacy_expiry_threshold_days",
] as const;

function SettingsPage() {
  return (
    <PermissionGate perm="settings.read">
      <SettingsPageInner />
    </PermissionGate>
  );
}

function SettingsPageInner() {
  const { lang, t } = useLang();
  const { can } = useAuth();
  const [form, setForm] = useState<Record<string, string>>({});

  const list = useRows(["system_settings"], () =>
    supabase.from("system_settings").select("setting_key, setting_value"),
  );

  useEffect(() => {
    const rows = (list.data ?? []) as Row[];
    if (!rows.length) return;
    const next: Record<string, string> = {};
    for (const r of rows) next[s(r, "setting_key")] = s(r, "setting_value");
    setForm((prev) => (Object.keys(prev).length ? prev : next));
  }, [list.data]);

  const save = useSave(
    async () => {
      const payload = KEYS.map((k) => ({
        setting_key: k,
        setting_value: form[k] ?? "",
        is_public: true,
      }));
      const { error } = await supabase.from("system_settings").upsert(payload, { onConflict: "setting_key" });
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["system_settings"]], successMessage: t("saved") },
  );

  if (!can("settings.read")) {
    return (
      <div className="rounded-lg border p-6 text-sm text-muted-foreground">
        {lang === "ar"
          ? "ليس لديك صلاحية للوصول إلى الإعدادات."
          : "You are not authorized to access settings."}
      </div>
    );
  }

  if (list.isLoading) return <Loading />;
  const set = (k: string) => (e: { target: { value: string } }) => setForm({ ...form, [k]: e.target.value });

  return (
    <div className="max-w-2xl">
      <PageHeader title={t("settings")} subtitle={t("system_configuration")} />
      <ErrorBox error={list.error} />

      <Card>
        <CardHeader>
          <CardTitle className="text-base">{t("center_info")}</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4">
          <Field label={t("center_name")}>
            <Input value={form["center_name"] ?? ""} onChange={set("center_name")} />
          </Field>
          <Field label={`${t("center_name")} (AR)`}>
            <Input value={form["center_name_ar"] ?? ""} onChange={set("center_name_ar")} />
          </Field>
          <Field label={t("phone")}>
            <Input dir="ltr" value={form["phone"] ?? ""} onChange={set("phone")} />
          </Field>
          <Field label={t("address")}>
            <Input value={form["address"] ?? ""} onChange={set("address")} />
          </Field>
          <Field label={t("currency")}>
            <Input dir="ltr" value={form["currency"] ?? ""} onChange={set("currency")} />
          </Field>
          <Field label={t("tax_percent")}>
            <Input type="number" dir="ltr" value={form["tax_percent"] ?? "0"} onChange={set("tax_percent")} />
          </Field>
          <Field label={t("invoice_footer")}>
            <Textarea rows={2} value={form["invoice_footer"] ?? ""} onChange={set("invoice_footer")} />
          </Field>
        </CardContent>
      </Card>

      <Card className="mt-4">
        <CardHeader>
          <CardTitle className="text-base">{t("pharmacy")}</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4">
          <Field label={t("pharmacy_expiry_threshold")}>
            <Input
              type="number"
              min={1}
              dir="ltr"
              value={form["pharmacy_expiry_threshold_days"] ?? "90"}
              onChange={set("pharmacy_expiry_threshold_days")}
            />
          </Field>
        </CardContent>
      </Card>

      <div className="mt-4">
        <Button disabled={!can("settings.update") || save.isPending} onClick={() => save.mutate(undefined as never)}>
          {save.isPending ? t("saving") : t("save")}
        </Button>
      </div>
    </div>
  );
}