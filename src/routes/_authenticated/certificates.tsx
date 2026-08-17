import { createFileRoute } from "@tanstack/react-router";
import { Plus, Printer } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader } from "@/components/kit";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/certificates")({
  head: () => ({
    meta: [
      { title: "Medical Certificates — ROSHAN Medical Center" },
      { name: "description", content: "Issue and print sick-leave and medical fitness certificates." },
      { property: "og:title", content: "Medical Certificates — ROSHAN Medical Center" },
      { property: "og:description", content: "Issue and print sick-leave and medical fitness certificates." },
    ],
  }),
  component: CertificatesPage,
});

function CertificatesPage() {
  const { t } = useLang();
  const { can, user } = useAuth();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [form, setForm] = useState({
    patient_id: "",
    type: "sick_leave",
    days: "1",
    start_date: todayISO(),
    notes: "",
  });

  const list = useRows(["certificates"], () =>
    supabase
      .from("medical_certificates")
      .select("*, patients(full_name, patient_number), users(full_name)")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(200),
  );

  const patients = useRows(["cert-patients", q], () =>
    q.length >= 2
      ? supabase.from("patients").select("id, full_name, patient_number").ilike("full_name", `%${q}%`).limit(20)
      : supabase.from("patients").select("id, full_name, patient_number").order("created_at", { ascending: false }).limit(20),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("medical_certificates").insert({
        patient_id: form.patient_id,
        type: form.type,
        days: Number(form.days) || 1,
        start_date: form.start_date,
        notes: form.notes || null,
        issued_by: user?.id ?? null,
        created_by: user?.id ?? null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["certificates"]], successMessage: t("saved"), onDone: () => setOpen(false) },
  );

  const rows = (list.data ?? []) as Row[];
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("certificates")} subtitle={t("issued_documents")}>
        <Button size="sm" variant="outline" onClick={() => window.print()}>
          <Printer className="size-4" /> {t("print")}
        </Button>
        {can("certificates.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("certificates")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={t("search")}>
                  <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("patient")} />
                </Field>
                <Field label={`${t("patient")} *`}>
                  <Select value={form.patient_id} onValueChange={(v) => setForm({ ...form, patient_id: v })}>
                    <SelectTrigger>
                      <SelectValue placeholder={t("patient")} />
                    </SelectTrigger>
                    <SelectContent>
                      {((patients.data ?? []) as Row[]).map((p) => (
                        <SelectItem key={s(p, "id")} value={s(p, "id")}>
                          {s(p, "full_name")} — {s(p, "patient_number")}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("type")}>
                  <Select value={form.type} onValueChange={(v) => setForm({ ...form, type: v })}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="sick_leave">{t("sick_leave")}</SelectItem>
                      <SelectItem value="fitness">{t("fitness")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("days")}>
                  <Input type="number" dir="ltr" min={1} value={form.days} onChange={(e) => setForm({ ...form, days: e.target.value })} />
                </Field>
                <Field label={t("start_date")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={form.start_date}
                    onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                  />
                </Field>
                <Field label={t("notes")}>
                  <Textarea rows={2} value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!form.patient_id || create.isPending} onClick={() => create.mutate(undefined as never)}>
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
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("type")}</TableHead>
                  <TableHead>{t("days")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("notes")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((c) => (
                  <TableRow key={s(c, "id")}>
                    <TableCell dir="ltr">{formatDate(s(c, "start_date") || s(c, "created_at"))}</TableCell>
                    <TableCell className="font-medium">{s(rel(c, "patients"), "full_name")}</TableCell>
                    <TableCell>{t(s(c, "type"))}</TableCell>
                    <TableCell dir="ltr">{n(c, "days")}</TableCell>
                    <TableCell>{s(rel(c, "users"), "full_name") || "—"}</TableCell>
                    <TableCell className="max-w-[16rem] truncate">{s(c, "notes") || "—"}</TableCell>
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
