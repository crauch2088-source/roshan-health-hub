import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { n, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/partners")({
  head: () => ({
    meta: [
      { title: "Partners — ROSHAN Medical Center" },
      { name: "description", content: "Contracted companies and insurers with agreed discounts." },
      { property: "og:title", content: "Partners — ROSHAN Medical Center" },
      { property: "og:description", content: "Contracted companies and insurers with agreed discounts." },
    ],
  }),
  component: PartnersPage,
});

function PartnersPage() {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", contact_person: "", phone: "", discount_percent: "0" });

  const list = useRows(["partners-all"], () =>
    supabase.from("partners").select("*").is("deleted_at", null).order("name", { ascending: true }),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("partners").insert({
        name: form.name,
        contact_person: form.contact_person || null,
        phone: form.phone || null,
        discount_percent: Number(form.discount_percent) || 0,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["partners-all"], ["partners"]], successMessage: t("saved"), onDone: () => setOpen(false) },
  );

  const rows = (list.data ?? []) as Row[];
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("partners")} subtitle={t("contracted_entities")}>
        <ExportButtons rows={rows} filename="roshan-partners" />
        {can("partners.manage") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("partners")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("name")} *`}>
                  <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label={t("contact_person")}>
                  <Input
                    value={form.contact_person}
                    onChange={(e) => setForm({ ...form, contact_person: e.target.value })}
                  />
                </Field>
                <Field label={t("phone")}>
                  <Input dir="ltr" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </Field>
                <Field label={t("discount_percent")}>
                  <Input
                    type="number"
                    dir="ltr"
                    min={0}
                    max={100}
                    value={form.discount_percent}
                    onChange={(e) => setForm({ ...form, discount_percent: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!form.name || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("contact_person")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("discount_percent")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((p) => (
                  <TableRow key={s(p, "id")}>
                    <TableCell className="font-medium">{s(p, "name")}</TableCell>
                    <TableCell>{s(p, "contact_person") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(p, "phone") || "—"}</TableCell>
                    <TableCell dir="ltr">{n(p, "discount_percent")}%</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
