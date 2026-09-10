import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, CalendarDays, ClipboardList, FlaskConical, Plus, Receipt, Stethoscope } from "lucide-react";
import { Component, useEffect, useMemo, useState, type ReactNode } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader, SectionTitle, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { BLOOD_GROUPS, MARITAL, calcAge, formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients_/$patientId")({
  head: () => ({
    meta: [
      { title: "Patient chart — ROSHAN Medical Center" },
      { name: "description", content: "Patient demographics, visit history, laboratory results and invoices." },
      { property: "og:title", content: "Patient chart — ROSHAN Medical Center" },
      { property: "og:description", content: "Patient demographics, visit history, laboratory results and invoices." },
    ],
  }),
  component: PatientChartWithBoundary,
});

type ChartErrorBoundaryProps = { children: ReactNode };
type ChartErrorBoundaryState = { error: Error | null };

class ChartErrorBoundary extends Component<ChartErrorBoundaryProps, ChartErrorBoundaryState> {
  override state: ChartErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ChartErrorBoundaryState {
    return { error };
  }

  override render() {
    if (!this.state.error) return this.props.children;

    return (
      <div className="space-y-4">
        <ErrorBox error={this.state.error} />
        <Empty label="تعذر تحميل ملف المريض / Unable to load patient chart" />
      </div>
    );
  }
}

function PatientChartWithBoundary() {
  return (
    <ChartErrorBoundary>
      <PatientChart />
    </ChartErrorBoundary>
  );
}

function PatientChart() {
  const { patientId } = useParams({ from: "/_authenticated/patients_/$patientId" });
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const [form, setForm] = useState<Row>({});

  const patient = useRows(["patient", patientId], () =>
    supabase.from("patients").select("*").eq("id", patientId).limit(1),
  );
  const record = ((patient.data ?? []) as Row[])[0];

  useEffect(() => {
    if (record) setForm(record);
  }, [record]);

  const visits = useRows(["patient-visits", patientId], () =>
    supabase
      .from("visits")
      .select("id, visit_date, status, consultation_fee, departments(name, name_ar), users(full_name)")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("visit_date", { ascending: false }),
  );

  const labs = useRows(["patient-labs", patientId], () =>
    supabase
      .from("lab_orders")
      .select("id, status, created_at, lab_order_items(id, lab_tests(name, name_ar))")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const invoices = useRows(["patient-invoices", patientId], () =>
    supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, status, net_amount, paid_amount")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("invoice_date", { ascending: false }),
  );

  const appointments = useRows(["patient-appointments", patientId], () =>
    supabase
      .from("appointments")
      .select("id, appointment_date, appointment_time, status, notes, departments(name, name_ar), users(full_name)")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("appointment_date", { ascending: false })
      .limit(50),
  );

  const followups = useRows(["patient-followups", patientId], () =>
    supabase
      .from("followups")
      .select("id, followup_date, reason, status")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("followup_date", { ascending: false })
      .limit(50),
  );

  type TimelineItem = {
    id: string;
    kind: "visit" | "appointment" | "followup" | "lab" | "invoice";
    date: string;
    title: string;
    subtitle?: string;
    status?: string;
    href?: string;
  };

  const timeline = useMemo(() => {
    const items: TimelineItem[] = [];
    for (const v of (visits.data ?? []) as Row[]) {
      const dept = rel(v, "departments");
      items.push({
        id: `visit-${s(v, "id")}`,
        kind: "visit",
        date: s(v, "visit_date") || "",
        title: lang === "ar" ? "زيارة" : "Visit",
        subtitle: (lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")) || s(rel(v, "users"), "full_name"),
        status: s(v, "status"),
        href: `/clinic/${s(v, "id")}`,
      });
    }
    for (const a of (appointments.data ?? []) as Row[]) {
      const dept = rel(a, "departments");
      items.push({
        id: `appt-${s(a, "id")}`,
        kind: "appointment",
        date: (s(a, "appointment_date") || "").slice(0, 10),
        title: lang === "ar" ? "موعد" : "Appointment",
        subtitle: (lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")) || s(rel(a, "users"), "full_name"),
        status: s(a, "status"),
      });
    }
    for (const f of (followups.data ?? []) as Row[]) {
      items.push({
        id: `fu-${s(f, "id")}`,
        kind: "followup",
        date: s(f, "followup_date") || "",
        title: lang === "ar" ? "متابعة" : "Follow-up",
        subtitle: s(f, "reason") || undefined,
        status: s(f, "status"),
      });
    }
    for (const o of (labs.data ?? []) as Row[]) {
      const itemsList = (o["lab_order_items"] as Row[]) ?? [];
      const names = itemsList
        .map((i) => {
          const test = rel(i, "lab_tests");
          return lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name");
        })
        .filter(Boolean)
        .join(", ");
      items.push({
        id: `lab-${s(o, "id")}`,
        kind: "lab",
        date: (s(o, "created_at") || "").slice(0, 10),
        title: lang === "ar" ? "تحاليل" : "Lab order",
        subtitle: names || undefined,
        status: s(o, "status"),
        href: `/lab/${s(o, "id")}`,
      });
    }
    for (const inv of (invoices.data ?? []) as Row[]) {
      items.push({
        id: `inv-${s(inv, "id")}`,
        kind: "invoice",
        date: s(inv, "invoice_date") || "",
        title: s(inv, "invoice_number") || (lang === "ar" ? "فاتورة" : "Invoice"),
        subtitle: money(n(inv, "net_amount"), currency),
        status: s(inv, "status"),
        href: `/billing/${s(inv, "id")}`,
      });
    }
    items.sort((a, b) => (b.date || "").localeCompare(a.date || ""));
    return items;
  }, [visits.data, appointments.data, followups.data, labs.data, invoices.data, lang, currency]);


  const prescriptions = useRows(["patient-rx", patientId], () =>
    supabase
      .from("prescriptions")
      .select("id, created_at, status, is_external, prescription_items(id, dosage, medicines(name))")
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const save = useSave(
    async () => {
      const payload = {
        full_name: s(form, "full_name"),
        gender: s(form, "gender"),
        date_of_birth: s(form, "date_of_birth") || null,
        phone: s(form, "phone"),
        address: s(form, "address"),
        occupation: s(form, "occupation"),
        marital_status: s(form, "marital_status") || null,
        blood_group: s(form, "blood_group") || null,
        national_id: s(form, "national_id"),
        emergency_contact: s(form, "emergency_contact"),
        notes: s(form, "notes"),
      };
      const { error } = await supabase.from("patients").update(payload).eq("id", patientId);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["patient", patientId], ["patients"]], successMessage: t("saved") },
  );

  if (patient.isLoading) return <Loading />;
  if (patient.error) {
    return (
      <div>
        <ErrorBox error={patient.error} />
        <Empty label={t("no_data")} />
      </div>
    );
  }
  if (!record) return <Empty label={t("no_data")} />;

  return (
    <div>
      <PageHeader
        title={s(record, "full_name")}
        subtitle={`${t("mrn")}: ${s(record, "mrn")} · ${t("age")}: ${calcAge(s(record, "date_of_birth")) ?? "—"} · ${t(s(record, "gender"))}`}
      >
        <Button asChild variant="outline" size="sm">
          <Link to="/patients">
            <ArrowLeft className="size-4" /> {t("back")}
          </Link>
        </Button>
        {can("visits.create") ? (
          <Button asChild size="sm">
            <Link to="/visits" search={{ patient: s(record, "id") }}>
              <Plus className="size-4" /> {t("new_visit")}
            </Link>
          </Button>
        ) : null}
      </PageHeader>

      <ErrorBox error={patient.error} />

      <Tabs defaultValue="profile">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="timeline">{lang === "ar" ? "الخط الزمني" : "Timeline"}</TabsTrigger>
          <TabsTrigger value="profile">{t("patient")}</TabsTrigger>
          <TabsTrigger value="visits">{t("visits")}</TabsTrigger>
          <TabsTrigger value="labs">{t("laboratory")}</TabsTrigger>
          <TabsTrigger value="rx">{t("prescription")}</TabsTrigger>
          <TabsTrigger value="invoices">{t("invoices")}</TabsTrigger>
        </TabsList>

        
        <TabsContent value="timeline">
          <Card>
            <CardContent className="p-0">
              {timeline.length === 0 ? (
                <Empty
                  title={lang === "ar" ? "لا أحداث بعد" : "No events yet"}
                  description={lang === "ar" ? "ستظهر هنا الزيارات والمواعيد والتحاليل والفواتير." : "Visits, appointments, labs and invoices will appear here."}
                />
              ) : (
                <ul className="divide-y">
                  {timeline.map((item) => {
                    const Icon =
                      item.kind === "visit"
                        ? ClipboardList
                        : item.kind === "appointment"
                          ? CalendarDays
                          : item.kind === "followup"
                            ? Stethoscope
                            : item.kind === "lab"
                              ? FlaskConical
                              : Receipt;
                    const body = (
                      <div className="flex items-start gap-3 px-4 py-3 transition-colors hover:bg-muted/40">
                        <div className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-muted text-muted-foreground">
                          <Icon className="size-4" aria-hidden />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="font-medium text-foreground">{item.title}</span>
                            {item.status ? <StatusBadge status={item.status} /> : null}
                          </div>
                          {item.subtitle ? (
                            <p className="mt-0.5 truncate text-sm text-muted-foreground">{item.subtitle}</p>
                          ) : null}
                        </div>
                        <time className="shrink-0 text-xs tabular-nums text-muted-foreground" dir="ltr">
                          {item.date ? formatDate(item.date) : "—"}
                        </time>
                      </div>
                    );
                    if (item.href) {
                      // Use plain <a> for dynamic path segments to avoid router type friction
                      return (
                        <li key={item.id}>
                          <a href={item.href} className="block">
                            {body}
                          </a>
                        </li>
                      );
                    }
                    return <li key={item.id}>{body}</li>;
                  })}
                </ul>
              )}
            </CardContent>
          </Card>
        </TabsContent>

<TabsContent value="profile">
          <Card>
            <CardContent className="p-4">
              <SectionTitle>{t("patient")}</SectionTitle>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <Field label={t("full_name")}>
                  <Input
                    value={s(form, "full_name")}
                    onChange={(e) => setForm({ ...form, full_name: e.target.value })}
                  />
                </Field>
                <Field label={t("gender")}>
                  <Select
                    value={s(form, "gender") || "male"}
                    onValueChange={(v) => setForm({ ...form, gender: v })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="male">{t("male")}</SelectItem>
                      <SelectItem value="female">{t("female")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("dob")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={s(form, "date_of_birth").slice(0, 10)}
                    onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
                  />
                </Field>
                <Field label={t("phone")}>
                  <Input
                    dir="ltr"
                    value={s(form, "phone")}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  />
                </Field>
                <Field label={t("blood_group")}>
                  <Select
                    value={s(form, "blood_group")}
                    onValueChange={(v) => setForm({ ...form, blood_group: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")} />
                    </SelectTrigger>
                    <SelectContent>
                      {BLOOD_GROUPS.map((g) => (
                        <SelectItem key={g} value={g}>
                          {g}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("marital_status")}>
                  <Select
                    value={s(form, "marital_status")}
                    onValueChange={(v) => setForm({ ...form, marital_status: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")} />
                    </SelectTrigger>
                    <SelectContent>
                      {MARITAL.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("occupation")}>
                  <Input
                    value={s(form, "occupation")}
                    onChange={(e) => setForm({ ...form, occupation: e.target.value })}
                  />
                </Field>
                <Field label={t("address")}>
                  <Input
                    value={s(form, "address")}
                    onChange={(e) => setForm({ ...form, address: e.target.value })}
                  />
                </Field>
                <Field label="ID / National no.">
                  <Input
                    dir="ltr"
                    value={s(form, "national_id")}
                    onChange={(e) => setForm({ ...form, national_id: e.target.value })}
                  />
                </Field>
                <Field label={t("notes")} className="sm:col-span-2 lg:col-span-3">
                  <Textarea
                    rows={2}
                    value={s(form, "notes")}
                    onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  />
                </Field>
              </div>
              {can("patients.update") ? (
                <div className="mt-4">
                  <Button disabled={save.isPending} onClick={() => save.mutate(undefined as never)}>
                    {save.isPending ? t("saving") : t("save")}
                  </Button>
                </div>
              ) : null}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="visits">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">{t("visits")}</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              {((visits.data ?? []) as Row[]).length === 0 ? (
                <Empty />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("date")}</TableHead>
                      <TableHead>{t("department")}</TableHead>
                      <TableHead>{t("doctor")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                      <TableHead className="no-print" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {((visits.data ?? []) as Row[]).map((v) => (
                      <TableRow key={s(v, "id")}>
                        <TableCell dir="ltr">{formatDate(s(v, "visit_date"))}</TableCell>
                        <TableCell>
                          {lang === "ar"
                            ? s(rel(v, "departments"), "name_ar") || s(rel(v, "departments"), "name")
                            : s(rel(v, "departments"), "name")}
                        </TableCell>
                        <TableCell>{s(rel(v, "users"), "full_name") || "—"}</TableCell>
                        <TableCell>
                          <StatusBadge status={s(v, "status")} />
                        </TableCell>
                        <TableCell className="no-print text-end">
                          {can("emr.read") ? (
                            <Button asChild variant="ghost" size="sm">
                              <Link to="/clinic/$visitId" params={{ visitId: s(v, "id") }}>
                                {t("clinical_notes")}
                              </Link>
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
        </TabsContent>

        <TabsContent value="labs">
          <Card>
            <CardContent className="p-0">
              {((labs.data ?? []) as Row[]).length === 0 ? (
                <Empty />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("date")}</TableHead>
                      <TableHead>{t("test")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                      <TableHead className="no-print" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {((labs.data ?? []) as Row[]).map((o) => (
                      <TableRow key={s(o, "id")}>
                        <TableCell dir="ltr">{formatDateTime(s(o, "created_at"))}</TableCell>
                        <TableCell>
                          {((o["lab_order_items"] as Row[]) ?? [])
                            .map((i) =>
                              lang === "ar"
                                ? s(rel(i, "lab_tests"), "name_ar") || s(rel(i, "lab_tests"), "name")
                                : s(rel(i, "lab_tests"), "name"),
                            )
                            .join(", ") || "—"}
                        </TableCell>
                        <TableCell>
                          <StatusBadge status={s(o, "status")} />
                        </TableCell>
                        <TableCell className="no-print text-end">
                          {can("lab.read") ? (
                            <Button asChild variant="ghost" size="sm">
                              <Link to="/lab/$orderId" params={{ orderId: s(o, "id") }}>
                                {t("result")}
                              </Link>
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
        </TabsContent>

        <TabsContent value="rx">
          <Card>
            <CardContent className="p-0">
              {((prescriptions.data ?? []) as Row[]).length === 0 ? (
                <Empty />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("date")}</TableHead>
                      <TableHead>{t("medicines")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {((prescriptions.data ?? []) as Row[]).map((p) => (
                      <TableRow key={s(p, "id")}>
                        <TableCell dir="ltr">{formatDateTime(s(p, "created_at"))}</TableCell>
                        <TableCell>
                          {((p["prescription_items"] as Row[]) ?? [])
                            .map((i) => s(rel(i, "medicines"), "name"))
                            .filter(Boolean)
                            .join(", ") || "—"}
                        </TableCell>
                        <TableCell>
                          <StatusBadge status={s(p, "status")} />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="invoices">
          <Card>
            <CardContent className="p-0">
              {((invoices.data ?? []) as Row[]).length === 0 ? (
                <Empty />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("invoice_number")}</TableHead>
                      <TableHead>{t("date")}</TableHead>
                      <TableHead>{t("net")}</TableHead>
                      <TableHead>{t("paid")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                      <TableHead className="no-print" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {((invoices.data ?? []) as Row[]).map((inv) => (
                      <TableRow key={s(inv, "id")}>
                        <TableCell dir="ltr" className="font-mono text-xs">
                          {s(inv, "invoice_number")}
                        </TableCell>
                        <TableCell dir="ltr">{formatDate(s(inv, "invoice_date"))}</TableCell>
                        <TableCell>{money(n(inv, "net_amount"), currency)}</TableCell>
                        <TableCell>{money(n(inv, "paid_amount"), currency)}</TableCell>
                        <TableCell>
                          <StatusBadge status={s(inv, "status")} />
                        </TableCell>
                        <TableCell className="no-print text-end">
                          {can("billing.read") ? (
                            <Button asChild variant="ghost" size="sm">
                              <Link to="/billing/$invoiceId" params={{ invoiceId: s(inv, "id") }}>
                                {t("invoice")}
                              </Link>
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
        </TabsContent>
      </Tabs>
    </div>
  );
}
