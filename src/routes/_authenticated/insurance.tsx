import { createFileRoute } from "@tanstack/react-router";
import { Plus, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatCard, StatusBadge } from "@/components/kit";
import { PatientPicker, type PickedPatient } from "@/components/patient-picker";
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import {
  NEXT_CLAIM_STATUS,
  calculateInsuranceCoverage,
  createInsuranceClaim,
  postInsuranceClaimPayment,
  updateInsuranceClaimStatus,
  type ClaimItemInput,
  type ClaimStatus,
} from "@/lib/insurance";
import { useLang } from "@/lib/i18n";
import { formatDate, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/insurance")({
  head: () => ({
    meta: [
      { title: "Insurance — ROSHAN Medical Center" },
      { name: "description", content: "Insurance companies, plans, patient membership, and claims." },
      { property: "og:title", content: "Insurance — ROSHAN Medical Center" },
      { property: "og:description", content: "Insurance companies, plans, patient membership, and claims." },
    ],
  }),
  component: InsurancePage,
});

function InsurancePage() {
  const { t } = useLang();
  const { currency } = useSettings();

  return (
    <div>
      <PageHeader title={t("insurance")} subtitle={t("insurance_subtitle")} />
      <Tabs defaultValue="companies">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="companies">{t("insurance_companies")}</TabsTrigger>
          <TabsTrigger value="plans">{t("insurance_plans")}</TabsTrigger>
          <TabsTrigger value="membership">{t("patient_insurance")}</TabsTrigger>
          <TabsTrigger value="claims">{t("insurance_claims")}</TabsTrigger>
        </TabsList>
        <TabsContent value="companies">
          <CompaniesTab />
        </TabsContent>
        <TabsContent value="plans">
          <PlansTab />
        </TabsContent>
        <TabsContent value="membership">
          <MembershipTab />
        </TabsContent>
        <TabsContent value="claims">
          <ClaimsTab currency={currency} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// =============================================================================
// Companies
// =============================================================================

function CompaniesTab() {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", contact_person: "", phone: "", email: "" });

  const list = useRows<Row[]>(["insurance-companies"], () =>
    supabase
      .from("insurance_companies")
      .select("id, name, contact_person, phone, email, active")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const create = useSave(
    async () => {
      if (!form.name.trim()) throw new Error(t("name_required"));
      const { error } = await supabase.from("insurance_companies").insert({
        name: form.name.trim(),
        contact_person: form.contact_person || null,
        phone: form.phone || null,
        email: form.email || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["insurance-companies"], ["insurance-companies-picker"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm({ name: "", contact_person: "", phone: "", email: "" });
      },
    },
  );

  const toggleActive = useSave(
    async (row: Row) => {
      const { error } = await supabase.from("insurance_companies").update({ active: !row["active"] }).eq("id", s(row, "id"));
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["insurance-companies"]], successMessage: t("saved") },
  );

  const rows = (list.data ?? []) as Row[];

  return (
    <div>
      <div className="no-print mb-4 flex justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-insurance-companies" />
        {can("insurance.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("insurance_companies")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("name")} *`}>
                  <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label={t("contact_person")}>
                  <Input value={form.contact_person} onChange={(e) => setForm({ ...form, contact_person: e.target.value })} />
                </Field>
                <Field label={t("phone")}>
                  <Input dir="ltr" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </Field>
                <Field label={t("email")}>
                  <Input dir="ltr" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
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
      </div>
      <ErrorBox error={list.error} />
      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("contact_person")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((c) => (
                  <TableRow key={s(c, "id")}>
                    <TableCell className="font-medium">
                      <span className="inline-flex items-center gap-1.5">
                        <ShieldCheck className="size-3.5 text-muted-foreground" /> {s(c, "name")}
                      </span>
                    </TableCell>
                    <TableCell>{s(c, "contact_person") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(c, "phone") || "—"}</TableCell>
                    <TableCell>
                      <StatusBadge status={c["active"] ? "active" : "inactive"} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      {can("insurance.update") ? (
                        <Button variant="ghost" size="sm" onClick={() => toggleActive.mutate(c)}>
                          {c["active"] ? t("deactivate") : t("activate")}
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

// =============================================================================
// Plans
// =============================================================================

function PlansTab() {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ company_id: "", name: "", default_coverage_percent: "70" });

  const companies = useRows<Row[]>(["insurance-companies-picker"], () =>
    supabase.from("insurance_companies").select("id, name").is("deleted_at", null).eq("active", true).order("name", { ascending: true }),
  );

  const list = useRows<Row[]>(["insurance-plans"], () =>
    supabase
      .from("insurance_plans")
      .select("id, name, default_coverage_percent, requires_prior_auth, active, insurance_companies(name)")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const create = useSave(
    async () => {
      if (!form.company_id || !form.name.trim()) throw new Error(t("name_required"));
      const { error } = await supabase.from("insurance_plans").insert({
        company_id: form.company_id,
        name: form.name.trim(),
        default_coverage_percent: Number(form.default_coverage_percent) || 0,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["insurance-plans"], ["insurance-plans-picker"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm({ company_id: "", name: "", default_coverage_percent: "70" });
      },
    },
  );

  const rows = (list.data ?? []) as Row[];

  return (
    <div>
      <div className="no-print mb-4 flex justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-insurance-plans" />
        {can("insurance.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("insurance_plans")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("insurance_companies")} *`}>
                  <Select value={form.company_id} onValueChange={(v) => setForm({ ...form, company_id: v })}>
                    <SelectTrigger>
                      <SelectValue placeholder={t("select_medicine")} />
                    </SelectTrigger>
                    <SelectContent>
                      {((companies.data ?? []) as Row[]).map((c) => (
                        <SelectItem key={s(c, "id")} value={s(c, "id")}>
                          {s(c, "name")}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={`${t("name")} *`}>
                  <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label={t("default_coverage_percent")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.default_coverage_percent}
                    onChange={(e) => setForm({ ...form, default_coverage_percent: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!form.company_id || !form.name || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </div>
      <ErrorBox error={list.error} />
      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("insurance_companies")}</TableHead>
                  <TableHead>{t("default_coverage_percent")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((p) => (
                  <TableRow key={s(p, "id")}>
                    <TableCell className="font-medium">{s(p, "name")}</TableCell>
                    <TableCell>{s(rel(p, "insurance_companies"), "name") || "—"}</TableCell>
                    <TableCell dir="ltr">{n(p, "default_coverage_percent")}%</TableCell>
                    <TableCell>
                      <StatusBadge status={p["active"] ? "active" : "inactive"} />
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

// =============================================================================
// Patient membership — reuses PatientPicker, same as Visits/Appointments.
// =============================================================================

function MembershipTab() {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [patient, setPatient] = useState<PickedPatient | null>(null);
  const [companyId, setCompanyId] = useState("");
  const [planId, setPlanId] = useState("");
  const [policyNumber, setPolicyNumber] = useState("");
  const [memberNumber, setMemberNumber] = useState("");
  const [expiryDate, setExpiryDate] = useState("");

  const companies = useRows<Row[]>(["insurance-companies-picker"], () =>
    supabase.from("insurance_companies").select("id, name").is("deleted_at", null).eq("active", true).order("name", { ascending: true }),
  );
  const plans = useRows<Row[]>(
    ["insurance-plans-picker", companyId],
    () =>
      supabase
        .from("insurance_plans")
        .select("id, name")
        .eq("company_id", companyId)
        .is("deleted_at", null)
        .eq("active", true)
        .order("name", { ascending: true }),
    { enabled: Boolean(companyId) },
  );

  const list = useRows<Row[]>(["patient-insurance-list"], () =>
    supabase
      .from("patient_insurance")
      .select(
        "id, policy_number, member_number, is_primary, status, expiry_date, patients(full_name, mrn), insurance_companies(name), insurance_plans(name)",
      )
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(300),
  );

  const create = useSave(
    async () => {
      if (!patient || !companyId || !planId) throw new Error(t("select_medicine"));
      const { error } = await supabase.from("patient_insurance").insert({
        patient_id: patient.id,
        company_id: companyId,
        plan_id: planId,
        policy_number: policyNumber || null,
        member_number: memberNumber || null,
        expiry_date: expiryDate || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["patient-insurance-list"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setPatient(null);
        setCompanyId("");
        setPlanId("");
        setPolicyNumber("");
        setMemberNumber("");
        setExpiryDate("");
      },
    },
  );

  const rows = (list.data ?? []) as Row[];

  return (
    <div>
      <div className="no-print mb-4 flex justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-patient-insurance" />
        {can("insurance.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>{t("patient_insurance")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("patient")} *`}>
                  <PatientPicker value={patient} onSelect={setPatient} />
                </Field>
                <Field label={`${t("insurance_companies")} *`}>
                  <Select
                    value={companyId}
                    onValueChange={(v) => {
                      setCompanyId(v);
                      setPlanId("");
                    }}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("select_medicine")} />
                    </SelectTrigger>
                    <SelectContent>
                      {((companies.data ?? []) as Row[]).map((c) => (
                        <SelectItem key={s(c, "id")} value={s(c, "id")}>
                          {s(c, "name")}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={`${t("insurance_plans")} *`}>
                  <Select value={planId} onValueChange={setPlanId}>
                    <SelectTrigger>
                      <SelectValue placeholder={t("select_medicine")} />
                    </SelectTrigger>
                    <SelectContent>
                      {((plans.data ?? []) as Row[]).map((p) => (
                        <SelectItem key={s(p, "id")} value={s(p, "id")}>
                          {s(p, "name")}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("policy_number")}>
                  <Input dir="ltr" value={policyNumber} onChange={(e) => setPolicyNumber(e.target.value)} />
                </Field>
                <Field label={t("member_number")}>
                  <Input dir="ltr" value={memberNumber} onChange={(e) => setMemberNumber(e.target.value)} />
                </Field>
                <Field label={t("expiry_date")}>
                  <Input type="date" dir="ltr" value={expiryDate} onChange={(e) => setExpiryDate(e.target.value)} />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!patient || !companyId || !planId || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </div>
      <ErrorBox error={list.error} />
      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("insurance_companies")}</TableHead>
                  <TableHead>{t("insurance_plans")}</TableHead>
                  <TableHead>{t("policy_number")}</TableHead>
                  <TableHead>{t("expiry_date")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={s(r, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(r, "patients"), "full_name")}
                      <span className="ms-1 text-xs text-muted-foreground" dir="ltr">
                        ({s(rel(r, "patients"), "mrn")})
                      </span>
                    </TableCell>
                    <TableCell>{s(rel(r, "insurance_companies"), "name") || "—"}</TableCell>
                    <TableCell>{s(rel(r, "insurance_plans"), "name") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(r, "policy_number") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(r, "expiry_date") ? formatDate(s(r, "expiry_date")) : "—"}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(r, "status")} />
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

// =============================================================================
// Claims
// =============================================================================

type DraftItem = ClaimItemInput;

function ClaimsTab({ currency }: { currency: string }) {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [patientInsuranceId, setPatientInsuranceId] = useState("");
  const [items, setItems] = useState<DraftItem[]>([]);
  const [itemForm, setItemForm] = useState({ service_type: "consultation" as DraftItem["service_type"], description: "", gross_amount: "0" });
  const [decision, setDecision] = useState<{ claim: Row; status: ClaimStatus } | null>(null);
  const [approvedAmount, setApprovedAmount] = useState("0");
  const [payTarget, setPayTarget] = useState<Row | null>(null);
  const [payAmount, setPayAmount] = useState("0");

  const membership = useRows<Row[]>(["patient-insurance-picker"], () =>
    supabase
      .from("patient_insurance")
      .select("id, patients(full_name, mrn), insurance_companies(name)")
      .eq("status", "active")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(200),
  );

  const claims = useRows<Row[]>(["insurance-claims"], () =>
    supabase
      .from("insurance_claims")
      .select(
        "id, claim_number, status, submitted_amount, approved_amount, paid_amount, submitted_at, patient_insurance(patients(full_name, mrn), insurance_companies(name))",
      )
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(300),
  );

  async function addItem() {
    const gross = Number(itemForm.gross_amount) || 0;
    if (!itemForm.description.trim() || gross <= 0 || !patientInsuranceId) return;
    const coverage = await calculateInsuranceCoverage({
      patientInsuranceId,
      serviceType: itemForm.service_type,
      grossAmount: gross,
    });
    setItems((prev) => [
      ...prev,
      {
        service_type: itemForm.service_type,
        reference_id: null,
        description: itemForm.description.trim(),
        gross_amount: gross,
        covered_amount: coverage.covered_amount,
        patient_amount: coverage.patient_amount,
        coverage_rule_id: coverage.coverage_rule_id,
      },
    ]);
    setItemForm({ service_type: "consultation", description: "", gross_amount: "0" });
  }

  const create = useSave(
    async () => {
      if (!patientInsuranceId || items.length === 0) throw new Error(t("select_medicine"));
      await createInsuranceClaim({ patientInsuranceId, invoiceId: null, items });
      return null;
    },
    {
      invalidate: [["insurance-claims"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setPatientInsuranceId("");
        setItems([]);
      },
    },
  );

  const transition = useSave(
    async () => {
      if (!decision) return null;
      await updateInsuranceClaimStatus({
        claimId: s(decision.claim, "id"),
        newStatus: decision.status,
        approvedAmount: ["approved", "partially_approved"].includes(decision.status) ? Number(approvedAmount) || 0 : null,
      });
      return null;
    },
    {
      invalidate: [["insurance-claims"]],
      successMessage: t("saved"),
      onDone: () => {
        setDecision(null);
        setApprovedAmount("0");
      },
    },
  );

  const pay = useSave(
    async () => {
      if (!payTarget) return null;
      const amt = Number(payAmount) || 0;
      if (amt <= 0) throw new Error(t("invalid_quantity"));
      await postInsuranceClaimPayment({ claimId: s(payTarget, "id"), amount: amt });
      return null;
    },
    {
      invalidate: [["insurance-claims"], ["cashbox-balance"], ["cashbox-transactions"]],
      successMessage: t("saved"),
      onDone: () => {
        setPayTarget(null);
        setPayAmount("0");
      },
    },
  );

  const rows = (claims.data ?? []) as Row[];
  const pendingCount = rows.filter((r) => ["submitted", "under_review"].includes(s(r, "status"))).length;
  const outstandingApproved = rows.reduce((sum, r) => {
    if (!["approved", "partially_approved"].includes(s(r, "status"))) return sum;
    return sum + (n(r, "approved_amount") - n(r, "paid_amount"));
  }, 0);

  return (
    <div>
      <div className="no-print mb-4 flex justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-insurance-claims" />
        {can("insurance.create") ? (
          <Button size="sm" onClick={() => setOpen(true)}>
            <Plus className="size-4" /> {t("new_claim")}
          </Button>
        ) : null}
      </div>

      <ErrorBox error={claims.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-2">
        <StatCard label={t("pending_claims")} value={String(pendingCount)} tone="warning" />
        <StatCard label={t("outstanding_insurance")} value={money(outstandingApproved, currency)} tone="warning" />
      </div>

      <Card>
        <CardContent className="p-0">
          {claims.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("claim_number")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("insurance_companies")}</TableHead>
                  <TableHead>{t("net")}</TableHead>
                  <TableHead>{t("approved_amount")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((c) => {
                  const pi = rel(c, "patient_insurance");
                  const status = s(c, "status") as ClaimStatus;
                  const nextOptions = NEXT_CLAIM_STATUS[status] ?? [];
                  const outstanding = n(c, "approved_amount") - n(c, "paid_amount");
                  return (
                    <TableRow key={s(c, "id")}>
                      <TableCell dir="ltr" className="font-mono text-xs">
                        {s(c, "claim_number")}
                      </TableCell>
                      <TableCell className="font-medium">{s(rel(pi, "patients"), "full_name") || "—"}</TableCell>
                      <TableCell>{s(rel(pi, "insurance_companies"), "name") || "—"}</TableCell>
                      <TableCell>{money(n(c, "submitted_amount"), currency)}</TableCell>
                      <TableCell>{c["approved_amount"] != null ? money(n(c, "approved_amount"), currency) : "—"}</TableCell>
                      <TableCell>
                        <StatusBadge status={status} />
                      </TableCell>
                      <TableCell className="no-print">
                        <div className="flex justify-end gap-1.5">
                          {can("insurance.update") && nextOptions.length > 0
                            ? nextOptions.map((next) => (
                                <Button
                                  key={next}
                                  variant="outline"
                                  size="sm"
                                  onClick={() => {
                                    setDecision({ claim: c, status: next });
                                    setApprovedAmount(String(n(c, "submitted_amount")));
                                  }}
                                >
                                  {t(next)}
                                </Button>
                              ))
                            : null}
                          {can("insurance.update") && status !== "paid" && ["approved", "partially_approved"].includes(status) && outstanding > 0 ? (
                            <Button
                              size="sm"
                              onClick={() => {
                                setPayTarget(c);
                                setPayAmount(String(outstanding));
                              }}
                            >
                              {t("record_payment")}
                            </Button>
                          ) : null}
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* New claim */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90vh] max-w-2xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t("new_claim")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <Field label={`${t("patient_insurance")} *`}>
              <Select value={patientInsuranceId} onValueChange={setPatientInsuranceId}>
                <SelectTrigger>
                  <SelectValue placeholder={t("select_medicine")} />
                </SelectTrigger>
                <SelectContent>
                  {((membership.data ?? []) as Row[]).map((m) => (
                    <SelectItem key={s(m, "id")} value={s(m, "id")}>
                      {s(rel(m, "patients"), "full_name")} — {s(rel(m, "insurance_companies"), "name")}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <div className="rounded-lg border p-3">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{t("add_item")}</p>
              <div className="grid gap-2 sm:grid-cols-4">
                <Select
                  value={itemForm.service_type}
                  onValueChange={(v) => setItemForm({ ...itemForm, service_type: v as DraftItem["service_type"] })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="consultation">{t("consultation")}</SelectItem>
                    <SelectItem value="lab">{t("laboratory")}</SelectItem>
                    <SelectItem value="medicine">{t("medicines")}</SelectItem>
                  </SelectContent>
                </Select>
                <Input
                  className="sm:col-span-2"
                  placeholder={t("description")}
                  value={itemForm.description}
                  onChange={(e) => setItemForm({ ...itemForm, description: e.target.value })}
                />
                <Input
                  type="number"
                  dir="ltr"
                  placeholder={t("amount")}
                  value={itemForm.gross_amount}
                  onChange={(e) => setItemForm({ ...itemForm, gross_amount: e.target.value })}
                />
              </div>
              <Button
                variant="outline"
                size="sm"
                className="mt-2"
                disabled={!patientInsuranceId || !itemForm.description.trim() || !itemForm.gross_amount}
                onClick={() => void addItem()}
              >
                <Plus className="size-3.5" /> {t("add_item")}
              </Button>
            </div>

            {items.length > 0 ? (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("description")}</TableHead>
                    <TableHead>{t("amount")}</TableHead>
                    <TableHead>{t("covered_amount")}</TableHead>
                    <TableHead>{t("patient_amount")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {items.map((it, idx) => (
                    <TableRow key={idx}>
                      <TableCell>{it.description}</TableCell>
                      <TableCell dir="ltr">{money(it.gross_amount, currency)}</TableCell>
                      <TableCell dir="ltr">{money(it.covered_amount, currency)}</TableCell>
                      <TableCell dir="ltr">{money(it.patient_amount, currency)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : null}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              {t("cancel")}
            </Button>
            <Button disabled={!patientInsuranceId || items.length === 0 || create.isPending} onClick={() => create.mutate(undefined as never)}>
              {create.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Status transition */}
      <Dialog open={Boolean(decision)} onOpenChange={(o) => (o ? null : setDecision(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{decision ? t(decision.status) : ""}</DialogTitle>
          </DialogHeader>
          {decision && ["approved", "partially_approved"].includes(decision.status) ? (
            <Field label={`${t("approved_amount")} *`}>
              <Input type="number" dir="ltr" value={approvedAmount} onChange={(e) => setApprovedAmount(e.target.value)} />
            </Field>
          ) : (
            <p className="text-sm text-muted-foreground">{t("confirm_status_change")}</p>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setDecision(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={transition.isPending} onClick={() => transition.mutate(undefined as never)}>
              {transition.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Payment */}
      <Dialog open={Boolean(payTarget)} onOpenChange={(o) => (o ? null : setPayTarget(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("record_payment")}</DialogTitle>
          </DialogHeader>
          <Field label={`${t("amount")} *`}>
            <Input type="number" dir="ltr" value={payAmount} onChange={(e) => setPayAmount(e.target.value)} />
          </Field>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPayTarget(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={pay.isPending} onClick={() => pay.mutate(undefined as never)}>
              {pay.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
