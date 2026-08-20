import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Plus, Search, Stethoscope } from "lucide-react";
import { useMemo, useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader, Pager } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { s, rel, usePagedRows, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients")({
  head: () => ({ meta: [{ title: "Patients — ROSHAN Medical Center" }] }),
  component: PatientsPage,
});

const PAGE_SIZE = 20;

function clean(term: string) {
  return term.replace(/[,()%]/g, "").trim();
}

function emptyPatient() {
  return { full_name: "", phone: "", gender: "male", date_of_birth: "", national_id: "", notes: "" };
}

function PatientsPage() {
  const { t, lang } = useLang();
  const { can, user } = useAuth();
  const navigate = useNavigate();

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [registerOpen, setRegisterOpen] = useState(false);
  const [clinicOpen, setClinicOpen] = useState(false);
  const [form, setForm] = useState(emptyPatient());
  const [clinicPatient, setClinicPatient] = useState<Row | null>(null);
  const [clinic, setClinic] = useState({ department_id: "", doctor_id: "", fee: "0", notes: "" });

  const list = usePagedRows<Row[]>(
    ["patients", search],
    ({ from, to }) => {
      let q = supabase
        .from("patients")
        .select("id, mrn, patient_number, full_name, phone, gender, date_of_birth, national_id, created_at", { count: "exact" })
        .is("deleted_at", null);
      const term = clean(search);
      if (term) {
        q = q.or(`full_name.ilike.%${term}%,phone.ilike.%${term}%,mrn.ilike.%${term}%,patient_number.ilike.%${term}%,national_id.ilike.%${term}%`);
      }
      return q.order("created_at", { ascending: false }).range(from, to);
    },
    page,
    PAGE_SIZE,
  );

  const departments = useRows<Row[]>(["departments"], () =>
    supabase.from("departments").select("id,name,name_ar").is("deleted_at", null).eq("is_active", true).order("name"),
  );
  const doctors = useRows<Row[]>(["doctors"], () =>
    supabase.from("users").select("id,full_name,roles(code)").eq("active", true).is("deleted_at", null),
  );

  const doctorRows = useMemo(
    () => (Array.isArray(doctors.data) ? (doctors.data as Row[]) : []).filter((d) => ["gp","dentist","specialist","doctor","physician"].includes(s(rel(d, "roles"), "code").toLowerCase())),
    [doctors.data],
  );

  const createPatient = useSave(
    async () => {
      if (!form.full_name.trim()) throw new Error(t("full_name"));
      const { data, error } = await supabase
        .from("patients")
        .insert({
          full_name: form.full_name.trim(),
          phone: form.phone.trim() || null,
          gender: form.gender,
          date_of_birth: form.date_of_birth || null,
          national_id: form.national_id.trim() || null,
          notes: form.notes.trim() || null,
          registered_by: user?.id ?? null,
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);
      return data.id as string;
    },
    {
      invalidate: [["patients"], ["patients-lite"]],
      successMessage: t("saved"),
      onDone: () => {
        setRegisterOpen(false);
        setForm(emptyPatient());
      },
    },
  );

  const startVisit = useSave(
    async () => {
      if (!clinicPatient) throw new Error(t("patient"));
      const { data, error } = await supabase
        .from("visits")
        .insert({
          patient_id: s(clinicPatient, "id"),
          department_id: clinic.department_id || null,
          doctor_id: clinic.doctor_id || null,
          visit_date: `${todayISO()}T00:00:00`,
          visit_type: "walk_in",
          status: "waiting",
          consultation_fee: Number(clinic.fee) || 0,
          notes: clinic.notes.trim() || null,
          created_by: user?.id ?? null,
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);
      return data.id as string;
    },
    {
      invalidate: [["visits", todayISO()], ["queue", todayISO()], ["patients"]],
      successMessage: lang === "ar" ? "تمت إضافة المريض إلى العيادة والطابور" : "Patient added to clinic queue",
      onDone: (id) => {
        setClinicOpen(false);
        setClinicPatient(null);
        setClinic({ department_id: "", doctor_id: "", fee: "0", notes: "" });
        if (typeof id === "string") void navigate({ to: "/clinic/$visitId", params: { visitId: id } });
      },
    },
  );

  const rows = Array.isArray(list.rows) ? (list.rows as Row[]) : [];
  const deptList = Array.isArray(departments.data) ? (departments.data as Row[]) : [];

  return (
    <div className="space-y-4">
      <PageHeader title={t("patients")} subtitle={lang === "ar" ? "البحث والتسجيل والوصول إلى الملف الطبي" : "Search, register and manage patient records"}>
        <div className="flex flex-wrap gap-2">
          <div className="relative min-w-[240px]">
            <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              className="ps-9"
              value={search}
              placeholder={lang === "ar" ? "الاسم، الهاتف، الرقم الطبي أو الرقم الوطني" : "Name, phone, MRN or national ID"}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          {can("patients.create") && (
            <Button size="sm" onClick={() => setRegisterOpen(true)}>
              <Plus className="size-4" /> {t("new_patient")}
            </Button>
          )}
        </div>
      </PageHeader>

      <ErrorBox error={list.error ?? departments.error ?? doctors.error} />

      <Card>
        <CardContent className="p-0">
          {list.isLoading ? <div className="p-6"><Loading /></div> : rows.length === 0 ? <Empty /> : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader><TableRow>
                  <TableHead>{t("mrn")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("gender")}</TableHead>
                  <TableHead>{t("age")}</TableHead>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead className="text-end">{t("actions")}</TableHead>
                </TableRow></TableHeader>
                <TableBody>
                  {rows.map((patient) => {
                    const id = s(patient, "id");
                    return (
                      <TableRow key={id}>
                        <TableCell dir="ltr" className="font-mono text-xs">{s(patient, "mrn") || s(patient, "patient_number") || "—"}</TableCell>
                        <TableCell className="font-medium">{s(patient, "full_name")}</TableCell>
                        <TableCell dir="ltr">{s(patient, "phone") || "—"}</TableCell>
                        <TableCell>{t(s(patient, "gender"))}</TableCell>
                        <TableCell>{calcAge(s(patient, "date_of_birth")) ?? "—"}</TableCell>
                        <TableCell dir="ltr">{formatDate(s(patient, "created_at"))}</TableCell>
                        <TableCell className="text-end">
                          <div className="flex justify-end gap-1">
                            <Button asChild size="sm" className="bg-green-600 text-white hover:bg-green-700">
                              <Link to="/patients/$patientId" params={{ patientId: id }}>{t("open")}</Link>
                            </Button>
                            {can("visits.create") && (
                              <Button size="sm" variant="outline" onClick={() => { setClinicPatient(patient); setClinicOpen(true); }}>
                                <Stethoscope className="size-4" /> {lang === "ar" ? "إلى العيادة" : "Clinic"}
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
          <Pager page={list.page} pageCount={list.pageCount} count={list.count} pageSize={PAGE_SIZE} hasPrev={list.hasPrev} hasNext={list.hasNext} isFetching={list.isFetching}
            onPrev={() => setPage((p) => Math.max(1, p - 1))} onNext={() => setPage((p) => p + 1)} />
        </CardContent>
      </Card>

      <Dialog open={registerOpen} onOpenChange={setRegisterOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader><DialogTitle>{t("new_patient")}</DialogTitle></DialogHeader>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={`${t("full_name")} *`}><Input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} /></Field>
            <Field label={t("phone")}><Input dir="ltr" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></Field>
            <Field label={t("gender")}><Select value={form.gender} onValueChange={(v) => setForm({ ...form, gender: v })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="male">{t("male")}</SelectItem><SelectItem value="female">{t("female")}</SelectItem></SelectContent></Select></Field>
            <Field label={t("date_of_birth")}><Input type="date" dir="ltr" value={form.date_of_birth} onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })} /></Field>
            <Field label={t("national_id")}><Input dir="ltr" value={form.national_id} onChange={(e) => setForm({ ...form, national_id: e.target.value })} /></Field>
            <Field label={t("notes")}><Textarea className="sm:col-span-2" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} /></Field>
          </div>
          <DialogFooter><Button variant="outline" onClick={() => setRegisterOpen(false)}>{t("cancel")}</Button><Button disabled={createPatient.isPending || !form.full_name.trim()} onClick={() => createPatient.mutate(undefined as never)}>{createPatient.isPending ? t("saving") : t("save")}</Button></DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={clinicOpen} onOpenChange={setClinicOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader><DialogTitle>{lang === "ar" ? "إضافة المريض إلى العيادة" : "Add patient to clinic"}</DialogTitle></DialogHeader>
          {clinicPatient && <div className="rounded-lg border bg-muted/30 p-3"><div className="font-semibold">{s(clinicPatient, "full_name")}</div><div className="text-xs text-muted-foreground" dir="ltr">{s(clinicPatient, "mrn") || s(clinicPatient, "patient_number")}</div></div>}
          <div className="grid gap-4">
            <Field label={t("department")}><Select value={clinic.department_id} onValueChange={(v) => setClinic({ ...clinic, department_id: v })}><SelectTrigger><SelectValue placeholder={t("none")} /></SelectTrigger><SelectContent>{deptList.map((d) => <SelectItem key={s(d,"id")} value={s(d,"id")}>{lang === "ar" ? s(d,"name_ar") || s(d,"name") : s(d,"name")}</SelectItem>)}</SelectContent></Select></Field>
            <Field label={t("doctor")}><Select value={clinic.doctor_id} onValueChange={(v) => setClinic({ ...clinic, doctor_id: v })}><SelectTrigger><SelectValue placeholder={t("none")} /></SelectTrigger><SelectContent>{doctorRows.map((d) => <SelectItem key={s(d,"id")} value={s(d,"id")}>{s(d,"full_name")}</SelectItem>)}</SelectContent></Select></Field>
            <Field label={t("consultation_fee")}><Input dir="ltr" type="number" min="0" value={clinic.fee} onChange={(e) => setClinic({ ...clinic, fee: e.target.value })} /></Field>
            <Field label={t("notes")}><Textarea value={clinic.notes} onChange={(e) => setClinic({ ...clinic, notes: e.target.value })} /></Field>
          </div>
          <DialogFooter><Button variant="outline" onClick={() => setClinicOpen(false)}>{t("cancel")}</Button><Button disabled={startVisit.isPending || !clinicPatient} onClick={() => startVisit.mutate(undefined as never)}><Stethoscope className="size-4" />{startVisit.isPending ? t("saving") : (lang === "ar" ? "إضافة للعيادة" : "Start visit")}</Button></DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
