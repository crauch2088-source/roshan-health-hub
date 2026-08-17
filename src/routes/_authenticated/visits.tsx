import { createFileRoute, Link } from "@tanstack/react-router";
import { Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatusBadge } from "@/components/kit";
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
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/visits")({
  head: () => ({
    meta: [
      { title: "Visits — ROSHAN Medical Center" },
      { name: "description", content: "Register walk-in and scheduled visits and route patients to clinics." },
      { property: "og:title", content: "Visits — ROSHAN Medical Center" },
      { property: "og:description", content: "Register walk-in and scheduled visits and route patients to clinics." },
    ],
  }),
  component: VisitsPage,
});

function VisitsPage() {
  const { t, lang } = useLang();
  const { user, can } = useAuth();
  const { currency } = useSettings();
  const [date, setDate] = useState(todayISO());
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    patient_id: "",
    department_id: "",
    doctor_id: "",
    visit_type: "walk_in",
    consultation_fee: "0",
    notes: "",
  });

  const visits = useRows(["visits", date], () =>
    supabase
      .from("visits")
      .select(
        "id, visit_number, visit_date, status, visit_type, consultation_fee, patients!visits_patient_id_fkey(id, full_name, mrn), departments!visits_department_id_fkey(name, name_ar), users!visits_doctor_id_fkey(full_name)",
      )
      .eq("visit_date", date)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const patients = useRows(["patients-lite"], () =>
    supabase
      .from("patients")
      .select("id, full_name, mrn")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(500),
  );

  const departments = useRows(["departments"], () =>
    supabase.from("departments").select("id, name, name_ar").is("deleted_at", null),
  );

  const doctors = useRows(["doctors"], () =>
    supabase
      .from("users")
      .select("id, full_name, roles(code)")
      .eq("active", true)
      .is("deleted_at", null),
  );

  const create = useSave(
    async () => {
      const numericQueue = Math.floor(Math.random() * 900) + 100;
      const qString = `Q${numericQueue}`;
      
      const { data: visit, error } = await supabase
        .from("visits")
        .insert({
          patient_id: form.patient_id,
          department_id: form.department_id || null,
          doctor_id: form.doctor_id || null,
          visit_date: date,
          visit_type: form.visit_type,
          status: "waiting",
          consultation_fee: Number(form.consultation_fee) || 0,
          notes: form.notes || null,
          visit_number: numericQueue,
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);

      // إدخال تذكرة الطابور بالقيمة النصية الصحيحة لكي تظهر فوراً في صفحة الطابور
      const { error: qErr } = await supabase.from("queue_tickets").insert({
        visit_id: visit.id,
        patient_id: form.patient_id,
        department_id: form.department_id || null,
        visit_date: date,
        queue_number: qString,
        status: "waiting",
      });
      if (qErr) throw new Error(qErr.message);
      return null;
    },
    {
      invalidate: [["visits", date], ["queue"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm({ ...form, patient_id: "", notes: "" });
      },
    },
  );

  // دالة لحذف الزيارة وإخفائها
  const deleteVisit = useSave(
    async (visitId: string) => {
      const { error } = await supabase
        .from("visits")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", visitId);
      if (error) throw new Error(error.message);

      // تحديث تذاكر الطابور المرتبطة أيضاً
      await supabase
        .from("queue_tickets")
        .update({ status: "cancelled" })
        .eq("visit_id", visitId);

      return null;
    },
    {
      invalidate: [["visits", date], ["queue"]],
      successMessage: t("deleted"),
    },
  );

  const rows = (visits.data ?? []) as Row[];
  const doctorRows = ((doctors.data ?? []) as Row[]).filter((d) =>
    ["gp", "dentist", "specialist"].includes(s(rel(d, "roles"), "code")),
  );

  if (visits.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("visits")} subtitle={formatDate(date)}>
        <Input
          type="date"
          dir="ltr"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className="w-40"
        />
        <ExportButtons rows={rows} filename={`roshan-visits-${date}`} />
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm">
              <Plus className="size-4" /> {t("new_visit")}
            </Button>
          </DialogTrigger>
          <DialogContent className="max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>{t("new_visit")}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4">
              <Field label={`${t("patient")} *`}>
                <Select
                  value={form.patient_id}
                  onValueChange={(v) => setForm({ ...form, patient_id: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t("search")} />
                  </SelectTrigger>
                  <SelectContent className="max-h-72">
                    {((patients.data ?? []) as Row[]).map((p) => (
                      <SelectItem key={s(p, "id")} value={s(p, "id")}>
                        {s(p, "full_name")} — {s(p, "mrn")}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <Field label={t("department")}>
                <Select
                  value={form.department_id}
                  onValueChange={(v) => setForm({ ...form, department_id: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t("none")} />
                  </SelectTrigger>
                  <SelectContent>
                    {((departments.data ?? []) as Row[]).map((d) => (
                      <SelectItem key={s(d, "id")} value={s(d, "id")}>
                        {lang === "ar" ? s(d, "name_ar") || s(d, "name") : s(d, "name")}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <Field label={t("doctor")}>
                <Select
                  value={form.doctor_id}
                  onValueChange={(v) => setForm({ ...form, doctor_id: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t("none")} />
                  </SelectTrigger>
                  <SelectContent>
                    {doctorRows.map((d) => (
                      <SelectItem key={s(d, "id")} value={s(d, "id")}>
                        {s(d, "full_name")}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={t("visit_type")}>
                  <Select
                    value={form.visit_type}
                    onValueChange={(v) => setForm({ ...form, visit_type: v })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="walk_in">{t("walk_in")}</SelectItem>
                      <SelectItem value="scheduled">{t("scheduled")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("consultation_fee")}>
                  <Input
                    type="number"
                    dir="ltr"
                    min={0}
                    value={form.consultation_fee}
                    onChange={(e) => setForm({ ...form, consultation_fee: e.target.value })}
                  />
                </Field>
              </div>
              <Field label={t("notes")}>
                <Textarea
                  rows={2}
                  value={form.notes}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                />
              </Field>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setOpen(false)}>
                {t("cancel")}
              </Button>
              <Button
                disabled={!form.patient_id || create.isPending}
                onClick={() => create.mutate(undefined as never)}
              >
                {create.isPending ? t("saving") : t("save")}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </PageHeader>

      <ErrorBox error={visits.error} />

      <Card>
        <CardContent className="p-0 overflow-x-auto">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("queue_number")}</TableHead>
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("consultation_fee")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="text-end">{t("actions")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((v) => (
                  <TableRow key={s(v, "id")}>
                    <TableCell className="font-medium whitespace-nowrap">
                      {s(rel(v, "patients"), "full_name")}
                      <span className="ms-2 text-xs text-muted-foreground" dir="ltr">
                        {s(rel(v, "patients"), "mrn")}
                      </span>
                    </TableCell>
                    <TableCell dir="ltr" className="font-mono text-xs">
                      Q{s(v, "visit_number") || "—"}
                    </TableCell>
                    <TableCell className="whitespace-nowrap">
                      {lang === "ar"
                        ? s(rel(v, "departments"), "name_ar") || s(rel(v, "departments"), "name")
                        : s(rel(v, "departments"), "name")}
                    </TableCell>
                    <TableCell className="whitespace-nowrap">{s(rel(v, "users"), "full_name") || "—"}</TableCell>
                    <TableCell className="whitespace-nowrap">{money(n(v, "consultation_fee"), currency)}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(v, "status")} />
                    </TableCell>
                    <TableCell className="text-end space-x-1 space-x-reverse whitespace-nowrap">
                      <Button asChild variant="ghost" size="sm">
                        <Link to="/clinic/$visitId" params={{ visitId: s(v, "id") }}>
                          {t("clinic")}
                        </Link>
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="text-destructive hover:text-destructive"
                        onClick={() => {
                          if (confirm(t("are_you_sure"))) {
                            deleteVisit.mutate(s(v, "id"));
                          }
                        }}
                      >
                        <Trash2 className="size-4" />
                      </Button>
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
