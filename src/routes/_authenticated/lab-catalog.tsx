import { createFileRoute } from "@tanstack/react-router";
import { Pencil, Plus } from "lucide-react";
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
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { b, n, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/lab-catalog")({
  head: () => ({
    meta: [
      { title: "Test catalogue — ROSHAN Medical Center" },
      { name: "description", content: "Manage laboratory tests, prices, units and reference ranges." },
      { property: "og:title", content: "Test catalogue — ROSHAN Medical Center" },
      { property: "og:description", content: "Manage laboratory tests, prices, units and reference ranges." },
    ],
  }),
  component: LabCatalogPage,
});

const blank = {
  name: "",
  name_ar: "",
  category: "",
  unit: "",
  price: "0",
  normal_min: "",
  normal_max: "",
  reference_range: "",
};

function LabCatalogPage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(blank);
  const [search, setSearch] = useState("");

  const tests = useRows(["lab-catalog"], () =>
    supabase.from("lab_tests").select("*").is("deleted_at", null).order("name", { ascending: true }),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("lab_tests").insert({
        name: form.name,
        name_ar: form.name_ar || null,
        category: form.category || null,
        unit: form.unit || null,
        price: Number(form.price) || 0,
        normal_min: form.normal_min === "" ? null : Number(form.normal_min),
        normal_max: form.normal_max === "" ? null : Number(form.normal_max),
        reference_range: form.reference_range || null,
        active: true,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-catalog"], ["lab-tests"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm(blank);
      },
    },
  );

  const toggle = useSave<{ id: string; active: boolean }>(
    async ({ id, active }) => {
      const { error } = await supabase.from("lab_tests").update({ active }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["lab-catalog"], ["lab-tests"]] },
  );

  const update = useSave<{ id: string }>(
    async ({ id }) => {
      const { error } = await supabase.from("lab_tests").update({
        name: form.name,
        name_ar: form.name_ar || null,
        category: form.category || null,
        unit: form.unit || null,
        price: Number(form.price) || 0,
        normal_min: form.normal_min === "" ? null : Number(form.normal_min),
        normal_max: form.normal_max === "" ? null : Number(form.normal_max),
        reference_range: form.reference_range || null,
      }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-catalog"], ["lab-tests"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setEditingId(null);
        setForm(blank);
      },
    },
  );

  const rows = ((tests.data ?? []) as Row[]).filter(
    (x) =>
      `${s(x, "name")} ${s(x, "name_ar")} ${s(x, "code")} ${s(x, "category")}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  if (tests.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("lab_catalog")} subtitle={t("tests_and_prices")}>
        <Input placeholder={t("search")} value={search} onChange={(e) => setSearch(e.target.value)} className="w-48" />
        <ExportButtons rows={rows} filename="roshan-lab-catalog" />
        {can("lab_admin.manage") ? (
          <Dialog open={open} onOpenChange={(value) => {
            setOpen(value);
            if (!value) {
              setEditingId(null);
              setForm(blank);
            }
          }}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => {
                setEditingId(null);
                setForm(blank);
              }}>
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto">
              <DialogHeader>
               <DialogTitle>{editingId ? t("edit") : t("lab_catalog")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={`${t("name")} (EN) *`}>
                  <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label={`${t("name")} (AR)`}>
                  <Input value={form.name_ar} onChange={(e) => setForm({ ...form, name_ar: e.target.value })} />
                </Field>
                <Field label={t("category")}>
                  <Input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
                </Field>
                <Field label={t("unit")}>
                  <Input dir="ltr" value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} />
                </Field>
                <Field label={t("price")}>
                  <Input type="number" dir="ltr" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
                </Field>
                <Field label={t("reference_range")}>
                  <Input
                    dir="ltr"
                    value={form.reference_range}
                    onChange={(e) => setForm({ ...form, reference_range: e.target.value })}
                  />
                </Field>
                <Field label={`${t("normal_min")}`}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.normal_min}
                    onChange={(e) => setForm({ ...form, normal_min: e.target.value })}
                  />
                </Field>
                <Field label={`${t("normal_max")}`}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.normal_max}
                    onChange={(e) => setForm({ ...form, normal_max: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                 <Button
                   disabled={!form.name || create.isPending || update.isPending}
                   onClick={() => editingId ? update.mutate({ id: editingId }) : create.mutate(undefined as never)}
                 >
                   {(create.isPending || update.isPending) ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={tests.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("category")}</TableHead>
                  <TableHead>{t("unit")}</TableHead>
                  <TableHead>{t("reference_range")}</TableHead>
                  <TableHead>{t("price")}</TableHead>
                   <TableHead className="no-print">{t("active")}</TableHead>
                   <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((x) => (
                  <TableRow key={s(x, "id")}>
                    <TableCell className="font-medium">
                      {lang === "ar" ? s(x, "name_ar") || s(x, "name") : s(x, "name")}
                    </TableCell>
                    <TableCell>{s(x, "category") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(x, "unit") || "—"}</TableCell>
                    <TableCell dir="ltr">
                      {s(x, "reference_range") ||
                        (s(x, "normal_min") && s(x, "normal_max")
                          ? `${s(x, "normal_min")} - ${s(x, "normal_max")}`
                          : "—")}
                    </TableCell>
                    <TableCell>{money(n(x, "price"), currency)}</TableCell>
                     <TableCell className="no-print">
                      <Switch
                        checked={b(x, "active")}
                        disabled={!can("lab_admin.manage")}
                        onCheckedChange={(v) => toggle.mutate({ id: s(x, "id"), active: v })}
                      />
                    </TableCell>
                     <TableCell className="no-print text-end">
                       {can("lab_admin.manage") ? (
                         <Button
                           variant="outline"
                           size="sm"
                           onClick={() => {
                             setEditingId(s(x, "id"));
                             setForm({
                               name: s(x, "name"),
                               name_ar: s(x, "name_ar"),
                               category: s(x, "category"),
                               unit: s(x, "unit"),
                               price: s(x, "price") || "0",
                               normal_min: s(x, "normal_min"),
                               normal_max: s(x, "normal_max"),
                               reference_range: s(x, "reference_range"),
                             });
                             setOpen(true);
                           }}
                         >
                           <Pencil className="size-4" /> {t("edit")}
                         </Button>
                       ) : null}
                     </TableCell>
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
