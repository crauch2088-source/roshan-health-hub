import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
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
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/appointments")({
  head: () => ({
    meta: [
      { title: "Appointments — ROSHAN Medical Center" },
      { name: "description", content: "Book and manage patient appointments per doctor and department." },
      { property: "og:title", content: "Appointments — ROSHAN Medical Center" },
      { property: "og:description", content: "Book and manage patient appointments per doctor and department." },
    ],
  }),
  component: AppointmentsPage,
});

function AppointmentsPage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const [date, setDate] = useState(todayISO());
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    patient_id: "",
    doctor_id: "",
    department_id: "",
    appointment_time: "09:00",
    notes: "",
  });

  const list = useRows(["appointments", date], () =>
    supabase
      .from("appointments")
      .select(
        "id, appointment_date, appointment_time, status, notes, patients!appointments_patient_id_fkey(full_name, mrn), users(full_name), departments(name, name_ar)",
      )
      .eq("appointment_date", date)
      .is("deleted_at", null)
      .order("appointment_time", { ascending: true }),
  );

  const patients = useRows(["patients-lite"], () =>
    supabase.from("patients").select("id, full_name, mrn").is("deleted_at", null).limit(500),
  );
  const departments = useRows(["departments"], () =>
    supabase.from("departments").select("id, name, name_ar").is("deleted_at", null),
  );
  const doctors = useRows(["doctors"], () =>
    supabase.from("users").select("id, full_name, roles(code)").eq("active", true).is("deleted_at", null),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("appointments").insert({
        patient_id: form.patient_id,
        doctor_id: form.doctor_id || null,
        department_id: form.department_id || null,
        appointment_date: date,
        appointment_time: form.appointment_time,
        status: "scheduled",
        notes: form.notes || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["appointments", date]],
      successMessage: t("saved"),
      onDone: () => setOpen(false),
    },
  );

  const setStatus = useSave<{ id: string; status: string }>(
    async ({ id, status }) => {
      const { error } = await supabase.from("appointments").update({ status }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["appointments", date]], successMessage: t("saved") },
  );

  const rows = (list.data ?? []) as Row[];
  const doctorRows = ((doctors.data ?? []) as Row[]).filter((d) =>
    ["gp", "dentist", "specialist"].includes(s(rel(d, "roles"), "code")),
  );
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("appointments")} subtitle={formatDate(date)}>
        <Input type="date" dir="ltr" value={date} onChange={(e) => setDate(e.target.value)} className="w-40" />
        <ExportButtons rows={rows} filename={`roshan-appointments-${date}`} />
        {can("appointments.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("appointments")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("patient")} *`}>
                  <Select value={form.patient_id} onValueChange={(v) => setForm({ ...form, patient_id: v })}>
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
                <Field label={t("doctor")}>
                  <Select value={form.doctor_id} onValueChange={(v) => setForm({ ...form, doctor_id: v })}>
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
                <Field label={t("time")}>
                  <Input
                    type="time"
                    dir="ltr"
                    value={form.appointment_time}
                    onChange={(e) => setForm({ ...form, appointment_time: e.target.value })}
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
                  <TableHead>{t("time")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((a) => (
                  <TableRow key={s(a, "id")}>
                    <TableCell dir="ltr">{s(a, "appointment_time").slice(0, 5)}</TableCell>
                    <TableCell className="font-medium">{s(rel(a, "patients"), "full_name")}</TableCell>
                    <TableCell>{s(rel(a, "users"), "full_name") || "—"}</TableCell>
                    <TableCell>
                      {lang === "ar"
                        ? s(rel(a, "departments"), "name_ar") || s(rel(a, "departments"), "name")
                        : s(rel(a, "departments"), "name")}
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={s(a, "status")} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      {can("appointments.update") ? (
                        <div className="flex justify-end gap-1">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => setStatus.mutate({ id: s(a, "id"), status: "confirmed" })}
                          >
                            {t("confirm")}
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setStatus.mutate({ id: s(a, "id"), status: "cancelled" })}
                          >
                            {t("cancel")}
                          </Button>
                        </div>
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
