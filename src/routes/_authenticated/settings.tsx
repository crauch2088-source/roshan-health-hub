import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { ErrorBox, Field, Loading, PageHeader } from "@/components/kit";
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

const KEYS = [
  "center_name",
  "center_name_ar",
  "phone",
  "address",
  "currency",
  "tax_percent",
  "invoice_footer",
] as const;

function SettingsPage() {
  const { t } = useLang();
  const { can } = useAuth();
  const [form, setForm] = useState<Record<string, string>>({});

  const list = useRows(["settings"], () => supabase.from("settings").select("*"));

  useEffect(() => {
    const rows = (list.data ?? []) as Row[];
    if (!rows.length) return;
    const next: Record<string, string> = {};
    for (const r of rows) next[s(r, "key")] = s(r, "value");
    setForm((prev) => (Object.keys(prev).length ? prev : next));
  }, [list.data]);

  const save = useSave(
    async () => {
      const payload = KEYS.map((k) => ({ key: k, value: form[k] ?? "" }));
      const { error } = await supabase.from("settings").upsert(payload, { onConflict: "key" });
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["settings"]], successMessage: t("saved") },
  );

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
          <div>
            <Button disabled={!can("settings.manage") || save.isPending} onClick={() => save.mutate(undefined as never)}>
              {save.isPending ? t("saving") : t("save")}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
