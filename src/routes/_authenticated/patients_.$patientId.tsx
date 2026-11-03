import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import {
  ArrowLeft,
  CalendarDays,
  ClipboardList,
  FlaskConical,
  Plus,
  Printer,
  Receipt,
  ShieldCheck,
  Stethoscope,
} from "lucide-react";
import { Component, useEffect, useMemo, useState, type ReactNode } from "react";

import {
  DataPanel,
  DetailHeader,
  Empty,
  ErrorBox,
  Field,
  Loading,
  SectionTitle,
  StatusBadge,
  PermissionGate,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { PaperWidthSelect } from "@/components/paper-width-select";
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
import { getClinicIdentity, isPrescriptionPrintReady, useDocumentPrint, type PaperWidth } from "@/lib/document-print";
import { BLOOD_GROUPS, MARITAL, calcAge, formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients_/$patientId")({
  head: () => ({
    meta: [
      { title: "Patient chart — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Patient demographics, visit history, laboratory results and invoices.",
      },
      { property: "og:title", content: "Patient chart — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Patient demographics, visit history, laboratory results and invoices.",
      },
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
    <PermissionGate perm="patients.read">
      <ChartErrorBoundary>
        <PatientChart />
      </ChartErrorBoundary>
    </PermissionGate>
  );
}

function PatientChart() {
  const { patientId } = useParams({ from: "/_authenticated/patients_/$patientId" });
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency, settings } = useSettings();
  const [paperWidth, setPaperWidth] = useState<PaperWidth>("a4");
  const { request: printRequest, printDocument } = useDocumentPrint<Row>();
  const [form, setForm] = useState<Row>({});

  const patient = useRows(["patient", patientId], () =>
    supabase.from("patients").select("*").eq("id", patientId).limit(1),
  );
  const record = ((patient.data ?? []) as Row[])[0];
  const patientBranchId = s(record, "branch_id");
  const branchQ = useRows<Row[]>(["patient-print-branch", patientBranchId], () =>
    supabase.from("branches").select("id, branch_name, name, address, phone").eq("id", patientBranchId).limit(1),
    { enabled: Boolean(patientBranchId) },
  );
  const branch = ((branchQ.data ?? []) as Row[])[0];

  useEffect(() => {
    if (record) setForm(record);
  }, [record]);

  const visits = useRows(["patient-visits", patientId], () =>
    supabase
      .from("visits")
      .select(
        "id, visit_date, status, consultation_fee, departments(name, name_ar), users(full_name)",
      )
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
      .select(
        "id, appointment_date, appointment_time, status, notes, departments(name, name_ar), users(full_name)",
      )
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

  // Claims are scoped through patient_insurance (proven in insurance.tsx nested select).
  const claims = useRows(["patient-claims", patientId], () =>
    supabase
      .from("insurance_claims")
      .select(
        "id, claim_number, status, submitted_amount, submitted_at, created_at, patient_insurance!inner(patient_id, insurance_companies(name))",
      )
      .eq("patient_insurance.patient_id", patientId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(50),
  );

  type TimelineItem = {
    id: string;
    kind: "visit" | "appointment" | "followup" | "lab" | "invoice" | "claim";
    date: string;
    title: string;
    subtitle?: string | undefined;
    status?: string | undefined;
    href?: string | undefined;
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
        subtitle:
          (lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")) ||
          s(rel(v, "users"), "full_name"),
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
        subtitle:
          (lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")) ||
          s(rel(a, "users"), "full_name"),
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

    for (const c of (claims.data ?? []) as Row[]) {
      const pi = rel(c, "patient_insurance");
      const company = rel(pi, "insurance_companies");
      items.push({
        id: `claim-${s(c, "id")}`,
        kind: "claim",
        date: (s(c, "submitted_at") || s(c, "created_at") || "").slice(0, 10),
        title: s(c, "claim_number") || (lang === "ar" ? "مطالبة تأمين" : "Insurance claim"),
        subtitle: s(company, "name") || undefined,
        status: s(c, "status"),
        href: "/insurance",
      });
    }
    items.sort((a, b) => (b.date || "").localeCompare(a.date || ""));
    return items;
  }, [
    visits.data,
    appointments.data,
    followups.data,
    labs.data,
    invoices.data,
    claims.data,
    lang,
    currency,
  ]);

  const prescriptions = useRows<Row[]>(["patient-rx", patientId], () =>
    supabase
      .from("prescriptions")
      .select(
        "id, created_at, status, is_external, prescription_type, prescribed_by, doctor_id, branch_id, visit_id, notes, users!prescriptions_prescribed_by_fkey(full_name), prescription_items(id, medication_name, dose, dosage, frequency, duration, quantity, instructions, dosage_form, route, medicines(name, generic_name, strength, dosage_form))",
      )
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
      <DetailHeader
        eyebrow={t("patients")}
        name={s(record, "full_name")}
        facts={[
          { label: t("mrn"), value: <bdi dir="ltr">{s(record, "mrn") || "—"}</bdi> },
          { label: t("age"), value: calcAge(s(record, "date_of_birth")) ?? "—" },
          { label: t("gender"), value: s(record, "gender") ? t(s(record, "gender")) : "—" },
          { label: t("phone"), value: <span dir="ltr">{s(record, "phone") || "—"}</span> },
          { label: t("blood_group"), value: s(record, "blood_group") || "—" },
        ]}
        actions={
          <>
            <Button asChild variant="outline" size="sm">
              <Link to="/patients">
                <ArrowLeft className="size-4 rtl:rotate-180" /> {t("back")}
              </Link>
            </Button>
            {can("visits.create") ? (
              <Button asChild size="sm">
                <Link to="/visits" search={{ patient: s(record, "id") }}>
                  <Plus className="size-4" /> {t("new_visit")}
                </Link>
              </Button>
            ) : null}
          </>
        }
      />

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
          <DataPanel>
            {timeline.length === 0 ? (
              <Empty
                title={lang === "ar" ? "لا أحداث بعد" : "No events yet"}
                description={
                  lang === "ar"
                    ? "ستظهر هنا الزيارات والمواعيد والتحاليل والفواتير."
                    : "Visits, appointments, labs and invoices will appear here."
                }
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
                            : item.kind === "claim"
                              ? ShieldCheck
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
                          <p className="mt-0.5 truncate text-sm text-muted-foreground">
                            {item.subtitle}
                          </p>
                        ) : null}
                      </div>
                      <time
                        className="shrink-0 text-xs tabular-nums text-muted-foreground"
                        dir="ltr"
                      >
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
          </DataPanel>
        </TabsContent>

        <TabsContent value="profile">
          <DataPanel>
            <div className="p-4">
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
            </div>
          </DataPanel>
        </TabsContent>

        <TabsContent value="visits">
          <DataPanel title={t("visits")}>
            {((visits.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
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
          </DataPanel>
        </TabsContent>

        <TabsContent value="labs">
          <DataPanel>
            {((labs.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
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
          </DataPanel>
        </TabsContent>

        <TabsContent value="rx">
          <DataPanel>
            {can("emr.read") ? (
              <div className="no-print mb-3 flex justify-end">
                <PaperWidthSelect value={paperWidth} onChange={setPaperWidth} lang={lang} />
              </div>
            ) : null}
            {((prescriptions.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("date")}</TableHead>
                    <TableHead>{t("medicines")}</TableHead>
                    <TableHead>{t("status")}</TableHead>
                    {can("emr.read") ? <TableHead className="no-print text-end">{lang === "ar" ? "طباعة" : "Print"}</TableHead> : null}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {((prescriptions.data ?? []) as Row[]).map((p) => {
                    const items = (p["prescription_items"] as Row[]) ?? [];
                    const rxBranchId = s(p, "branch_id");
                    const branchMatches = Boolean(patientBranchId && rxBranchId && patientBranchId === rxBranchId);
                    const printable = branchMatches && isPrescriptionPrintReady(p);
                    const names = items
                      .map((item) => s(item, "medication_name") || s(rel(item, "medicines"), "name") || s(rel(item, "medicines"), "generic_name"))
                      .filter(Boolean)
                      .join(", ");
                    return (
                      <TableRow key={s(p, "id")}>
                        <TableCell dir="ltr">{formatDateTime(s(p, "created_at"))}</TableCell>
                        <TableCell>{names || "—"}</TableCell>
                        <TableCell>
                          <StatusBadge status={s(p, "status")} />
                          {s(p, "prescription_type") === "external" || p["is_external"] === true ? (
                            <p className="text-xs text-muted-foreground">{lang === "ar" ? "وصفة خارجية مسجلة" : "External prescription record"}</p>
                          ) : null}
                        </TableCell>
                        {can("emr.read") ? (
                          <TableCell className="no-print text-end">
                            <Button
                              size="sm"
                              variant="ghost"
                              disabled={!printable}
                              title={
                                printable
                                  ? (lang === "ar" ? "طباعة الوصفة" : "Print prescription")
                                  : (lang === "ar" ? "لا يمكن الطباعة: وصفة خارجية أو بيانات دوائية ناقصة أو فرع غير مطابق" : "Cannot print: external record, incomplete medication directions or branch mismatch")
                              }
                              aria-label={lang === "ar" ? "طباعة الوصفة" : "Print prescription"}
                              onClick={() => printDocument(p, paperWidth)}
                            >
                              <Printer className="size-4" />
                            </Button>
                          </TableCell>
                        ) : null}
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            )}
          </DataPanel>
        </TabsContent>

        <TabsContent value="invoices">
          <DataPanel>
            {((invoices.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
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
          </DataPanel>
        </TabsContent>
      </Tabs>
    </div>
    {printPrescription ? (
      <div className="print-only print-area print-surface mx-auto max-w-[180mm] p-8" dir={lang === "ar" ? "rtl" : "ltr"}>
        <header className="mb-6 border-b pb-4 text-center">
          <p className="text-xl font-bold">{printClinic.name}</p>
          {printClinic.branchName ? <p className="text-sm">{printClinic.branchName}</p> : null}
          {printClinic.address ? <p className="text-sm">{printClinic.address}</p> : null}
          {printClinic.phone ? <p className="text-sm" dir="ltr">{printClinic.phone}</p> : null}
          <h1 className="mt-5 text-xl font-bold">{lang === "ar" ? "وصفة طبية" : "Medical Prescription"}</h1>
          <p className="mt-2 text-sm">{formatDateTime(s(printPrescription, "created_at"))}</p>
        </header>
        <section className="mb-5 grid gap-2 border-b pb-4 text-sm sm:grid-cols-2">
          <p><strong>{lang === "ar" ? "المريض" : "Patient"}:</strong> {s(record, "full_name") || "—"}</p>
          <p><strong>{lang === "ar" ? "الرقم الطبي" : "MRN"}:</strong> <bdi dir="ltr">{s(record, "mrn") || "—"}</bdi></p>
          <p><strong>{lang === "ar" ? "العمر" : "Age"}:</strong> {calcAge(s(record, "date_of_birth")) ?? "—"}</p>
          <p><strong>{lang === "ar" ? "الطبيب" : "Prescriber"}:</strong> {s(printDoctor, "full_name") || "—"}</p>
        </section>
        <section className="space-y-4">
          {printItems.map((item) => {
            const medicine = rel(item, "medicines");
            const medicineName = s(item, "medication_name") || s(medicine, "name") || s(medicine, "generic_name") || "—";
            const dose = s(item, "dose") || s(item, "dosage");
            const strength = s(medicine, "strength");
            return (
              <div key={s(item, "id")} className="print-keep border-b pb-4">
                <p className="text-base font-bold">{medicineName}{strength ? " · " + strength : ""}</p>
                <div className="mt-2 grid gap-1 text-sm sm:grid-cols-2">
                  <p><strong>{lang === "ar" ? "الشكل الدوائي" : "Dosage form"}:</strong> {s(item, "dosage_form") || s(medicine, "dosage_form") || "—"}</p>
                  <p><strong>{lang === "ar" ? "طريق الإعطاء" : "Route"}:</strong> {s(item, "route") || "—"}</p>
                  <p><strong>{lang === "ar" ? "الجرعة" : "Dose"}:</strong> {dose || "—"}</p>
                  <p><strong>{lang === "ar" ? "التكرار" : "Frequency"}:</strong> {s(item, "frequency") || "—"}</p>
                  <p><strong>{lang === "ar" ? "المدة" : "Duration"}:</strong> {s(item, "duration") || "—"}</p>
                  <p><strong>{lang === "ar" ? "الكمية" : "Quantity"}:</strong> <bdi dir="ltr">{s(item, "quantity") || "—"}</bdi></p>
                </div>
                {s(item, "instructions") ? <p className="mt-2 whitespace-pre-wrap text-sm"><strong>{lang === "ar" ? "تعليمات" : "Instructions"}:</strong> {s(item, "instructions")}</p> : null}
              </div>
            );
          })}
        </section>
        {s(printPrescription, "notes") ? <p className="mt-4 whitespace-pre-wrap text-sm"><strong>{lang === "ar" ? "ملاحظات" : "Notes"}:</strong> {s(printPrescription, "notes")}</p> : null}
        <footer className="mt-16 grid grid-cols-2 gap-10 text-sm">
          <div className="print-keep border-t pt-3">{lang === "ar" ? "الطبيب" : "Prescriber"}: {s(printDoctor, "full_name") || "—"}</div>
          <div className="print-keep border-t pt-3 text-center">{lang === "ar" ? "التوقيع والختم" : "Signature and stamp"}</div>
        </footer>
      </div>
    ) : null}
    </>
  );
}
