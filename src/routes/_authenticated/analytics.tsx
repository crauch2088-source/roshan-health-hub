import { createFileRoute } from "@tanstack/react-router";
import { useMemo, type ReactNode } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatCard } from "@/components/kit";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { n, rel, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/analytics")({
  head: () => ({
    meta: [
      { title: "Analytics — ROSHAN Medical Center" },
      { name: "description", content: "Revenue, pharmacy, and clinical performance trends." },
      { property: "og:title", content: "Analytics — ROSHAN Medical Center" },
      { property: "og:description", content: "Revenue, pharmacy, and clinical performance trends." },
    ],
  }),
  component: AnalyticsPage,
});

// A year is more than enough history for trend reports on a single clinic
// and keeps every query bounded (no unfiltered full-table pulls).
function monthsAgoISO(months: number): string {
  const d = new Date();
  d.setMonth(d.getMonth() - months);
  d.setDate(1);
  return d.toISOString().slice(0, 10);
}

/** "2026-03" -> "Mar 2026" (or an Arabic-numeral-safe equivalent via Intl when lang=ar handled by caller). */
function monthLabel(key: string, lang: string): string {
  const [y, m] = key.split("-").map(Number);
  const d = new Date(y ?? new Date().getFullYear(), (m || 1) - 1, 1);
  return d.toLocaleDateString(lang === "ar" ? "ar" : "en", { year: "numeric", month: "short" });
}

function monthKey(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  return dateStr.slice(0, 7);
}

/** Groups rows by month and sums one numeric field, returning the last N months in order (oldest first). */
function sumByMonth(rows: Row[], dateField: string, amountField: string, months: number): { month: string; total: number }[] {
  const buckets = new Map<string, number>();
  for (const r of rows) {
    const key = monthKey(s(r, dateField));
    if (key === "—") continue;
    buckets.set(key, (buckets.get(key) ?? 0) + n(r, amountField));
  }
  const keys: string[] = [];
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date();
    d.setMonth(d.getMonth() - i);
    keys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
  }
  return keys.map((k) => ({ month: k, total: buckets.get(k) ?? 0 }));
}

function TrendTable({ rows, currency, lang }: { rows: { month: string; total: number }[]; currency: string; lang: string }) {
  const { t } = useLang();
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t("month")}</TableHead>
          <TableHead>{t("amount")}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((r) => (
          <TableRow key={r.month}>
            <TableCell dir="ltr">{monthLabel(r.month, lang)}</TableCell>
            <TableCell className="font-medium">{money(r.total, currency)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

function ReportCard({ title, children, exportRows, filename }: { title: string; children: ReactNode; exportRows?: unknown[]; filename?: string }) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
        {exportRows && filename ? <ExportButtons rows={exportRows as Row[]} filename={filename} /> : null}
      </CardHeader>
      <CardContent className="p-0">{children}</CardContent>
    </Card>
  );
}

function AnalyticsPage() {
  const { t } = useLang();

  return (
    <div>
      <PageHeader title={t("analytics")} subtitle={t("analytics_subtitle")} />
      <Tabs defaultValue="financial">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="financial">{t("finance")}</TabsTrigger>
          <TabsTrigger value="pharmacy">{t("pharmacy")}</TabsTrigger>
          <TabsTrigger value="clinical">{t("clinical")}</TabsTrigger>
        </TabsList>
        <TabsContent value="financial">
          <FinancialAnalytics />
        </TabsContent>
        <TabsContent value="pharmacy">
          <PharmacyAnalytics />
        </TabsContent>
        <TabsContent value="clinical">
          <ClinicalAnalytics />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// =============================================================================
// Financial — Revenue Trends, Expense Trends, Insurance Revenue,
// Outstanding Receivables, Supplier Debt Analysis.
// Receivables/Debt reuse the Phase 4 views directly — no new aggregation
// logic duplicating what those views already compute.
// =============================================================================

function FinancialAnalytics() {
  const { t, lang } = useLang();
  const { currency } = useSettings();
  const since = monthsAgoISO(11);

  const payments = useRows<Row[]>(["an-payments"], () =>
    supabase.from("payments").select("amount, payment_date").is("deleted_at", null).gte("payment_date", since).limit(5000),
  );
  const expenses = useRows<Row[]>(["an-expenses"], () =>
    supabase.from("expenses").select("amount, expense_date").is("deleted_at", null).gte("expense_date", since).limit(5000),
  );
  const insurancePayments = useRows<Row[]>(["an-insurance-claims-paid"], () =>
    supabase
      .from("insurance_claims")
      .select("paid_amount, paid_at")
      .is("deleted_at", null)
      .not("paid_at", "is", null)
      .gte("paid_at", since)
      .limit(2000),
  );
  const receivables = useRows<Row[]>(["an-receivables"], () =>
    supabase.from("v_patient_receivables").select("*").order("outstanding", { ascending: false }).limit(500),
  );
  const supplierDebt = useRows<Row[]>(["an-supplier-debt"], () =>
    supabase.from("v_supplier_outstanding").select("*").order("outstanding", { ascending: false }).limit(500),
  );

  const revenueTrend = useMemo(() => sumByMonth((payments.data ?? []) as Row[], "payment_date", "amount", 12), [payments.data]);
  const expenseTrend = useMemo(() => sumByMonth((expenses.data ?? []) as Row[], "expense_date", "amount", 12), [expenses.data]);
  const insuranceTrend = useMemo(
    () => sumByMonth((insurancePayments.data ?? []) as Row[], "paid_at", "paid_amount", 12),
    [insurancePayments.data],
  );

  const receivablesRows = ((receivables.data ?? []) as Row[]).filter((r) => n(r, "outstanding") > 0);
  const supplierRows = ((supplierDebt.data ?? []) as Row[]).filter((r) => n(r, "outstanding") > 0);
  const totalReceivable = receivablesRows.reduce((sum, r) => sum + n(r, "outstanding"), 0);
  const totalSupplierDebt = supplierRows.reduce((sum, r) => sum + n(r, "outstanding"), 0);
  const totalRevenue12mo = revenueTrend.reduce((sum, r) => sum + r.total, 0);
  const totalExpense12mo = expenseTrend.reduce((sum, r) => sum + r.total, 0);

  const anyLoading = payments.isLoading || expenses.isLoading || insurancePayments.isLoading || receivables.isLoading || supplierDebt.isLoading;
  if (anyLoading) return <Loading />;

  return (
    <div className="grid gap-4">
      <ErrorBox error={payments.error ?? expenses.error ?? insurancePayments.error ?? receivables.error ?? supplierDebt.error} />

      <div className="grid gap-4 sm:grid-cols-4">
        <StatCard label={t("revenue_12mo")} value={money(totalRevenue12mo, currency)} tone="success" />
        <StatCard label={t("expenses_12mo")} value={money(totalExpense12mo, currency)} tone="destructive" />
        <StatCard label={t("outstanding_balance")} value={money(totalReceivable, currency)} tone="warning" />
        <StatCard label={t("supplier_debt")} value={money(totalSupplierDebt, currency)} tone="warning" />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <ReportCard title={t("revenue_trends")} exportRows={revenueTrend} filename="roshan-revenue-trends">
          <TrendTable rows={revenueTrend} currency={currency} lang={lang} />
        </ReportCard>
        <ReportCard title={t("expense_trends")} exportRows={expenseTrend} filename="roshan-expense-trends">
          <TrendTable rows={expenseTrend} currency={currency} lang={lang} />
        </ReportCard>
        <ReportCard title={t("insurance_revenue")} exportRows={insuranceTrend} filename="roshan-insurance-revenue">
          <TrendTable rows={insuranceTrend} currency={currency} lang={lang} />
        </ReportCard>

        <ReportCard title={t("outstanding_receivables")} exportRows={receivablesRows} filename="roshan-outstanding-receivables">
          {receivablesRows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("outstanding_balance")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {receivablesRows.slice(0, 15).map((r) => (
                  <TableRow key={s(r, "invoice_id")}>
                    <TableCell className="font-medium">{s(r, "patient_name")}</TableCell>
                    <TableCell className="text-destructive">{money(n(r, "outstanding"), currency)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("supplier_debt_analysis")} exportRows={supplierRows} filename="roshan-supplier-debt-analysis">
          {supplierRows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("supplier")}</TableHead>
                  <TableHead>{t("outstanding_balance")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {supplierRows.slice(0, 15).map((r) => (
                  <TableRow key={s(r, "supplier_id")}>
                    <TableCell className="font-medium">{s(r, "name")}</TableCell>
                    <TableCell className="text-destructive">{money(n(r, "outstanding"), currency)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>
      </div>
    </div>
  );
}

// =============================================================================
// Pharmacy — Performance, FEFO Waste Tracking, Expiry Forecasting.
// All from stock_movements / pharmacy_inventory (Phase 3) — no new tables.
// =============================================================================

function PharmacyAnalytics() {
  const { t } = useLang();
  const { currency } = useSettings();
  const since = monthsAgoISO(11);

  const dispenseMoves = useRows<Row[]>(["an-dispense-moves"], () =>
    supabase
      .from("stock_movements")
      .select("medicine_id, quantity, medicines(name, selling_price)")
      .eq("movement_type", "dispense")
      .gte("created_at", since)
      .limit(5000),
  );
  const wasteMoves = useRows<Row[]>(["an-waste-moves"], () =>
    supabase
      .from("stock_movements")
      .select("medicine_id, quantity, created_at, medicines(name)")
      .eq("movement_type", "writeoff")
      .gte("created_at", since)
      .limit(2000),
  );
  const batches = useRows<Row[]>(["an-expiry-forecast"], () =>
    supabase
      .from("pharmacy_inventory")
      .select("expiry_date, quantity_remaining, purchase_price, medicines(name)")
      .is("deleted_at", null)
      .gt("quantity_remaining", 0)
      .not("expiry_date", "is", null)
      .order("expiry_date", { ascending: true })
      .limit(1000),
  );

  const performance = useMemo(() => {
    const byMed = new Map<string, { name: string; qty: number; revenue: number }>();
    for (const r of (dispenseMoves.data ?? []) as Row[]) {
      const med = rel(r, "medicines");
      const name = s(med, "name") || "—";
      const qty = Math.abs(n(r, "quantity"));
      const revenue = qty * n(med, "selling_price");
      const cur = byMed.get(name) ?? { name, qty: 0, revenue: 0 };
      cur.qty += qty;
      cur.revenue += revenue;
      byMed.set(name, cur);
    }
    return Array.from(byMed.values()).sort((a, b) => b.revenue - a.revenue).slice(0, 15);
  }, [dispenseMoves.data]);

  const waste = useMemo(() => {
    const byMed = new Map<string, { name: string; qty: number }>();
    for (const r of (wasteMoves.data ?? []) as Row[]) {
      const name = s(rel(r, "medicines"), "name") || "—";
      const qty = Math.abs(n(r, "quantity"));
      const cur = byMed.get(name) ?? { name, qty: 0 };
      cur.qty += qty;
      byMed.set(name, cur);
    }
    return Array.from(byMed.values()).sort((a, b) => b.qty - a.qty).slice(0, 15);
  }, [wasteMoves.data]);

  const forecast = useMemo(() => {
    const buckets = new Map<string, number>();
    const rows = (batches.data ?? []) as Row[];
    for (const r of rows) {
      const key = monthKey(s(r, "expiry_date"));
      if (key === "—") continue;
      buckets.set(key, (buckets.get(key) ?? 0) + n(r, "quantity_remaining") * n(r, "purchase_price"));
    }
    const keys: string[] = [];
    for (let i = 0; i < 6; i++) {
      const d = new Date();
      d.setMonth(d.getMonth() + i);
      keys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
    }
    return keys.map((k) => ({ month: k, value: buckets.get(k) ?? 0 }));
  }, [batches.data]);

  const totalWasteQty = waste.reduce((sum, w) => sum + w.qty, 0);
  const totalForecastValue = forecast.reduce((sum, f) => sum + f.value, 0);

  const anyLoading = dispenseMoves.isLoading || wasteMoves.isLoading || batches.isLoading;
  if (anyLoading) return <Loading />;

  return (
    <div className="grid gap-4">
      <ErrorBox error={dispenseMoves.error ?? wasteMoves.error ?? batches.error} />

      <div className="grid gap-4 sm:grid-cols-2">
        <StatCard label={t("fefo_waste_units")} value={String(totalWasteQty)} tone="destructive" />
        <StatCard label={t("expiry_forecast_value")} value={money(totalForecastValue, currency)} tone="warning" />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <ReportCard title={t("pharmacy_performance")} exportRows={performance} filename="roshan-pharmacy-performance">
          {performance.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("quantity_dispensed")}</TableHead>
                  <TableHead>{t("amount")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {performance.map((p) => (
                  <TableRow key={p.name}>
                    <TableCell className="font-medium">{p.name}</TableCell>
                    <TableCell dir="ltr">{p.qty}</TableCell>
                    <TableCell>{money(p.revenue, currency)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("fefo_waste_tracking")} exportRows={waste} filename="roshan-fefo-waste">
          {waste.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("quantity")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {waste.map((w) => (
                  <TableRow key={w.name}>
                    <TableCell className="font-medium">{w.name}</TableCell>
                    <TableCell dir="ltr" className="text-destructive">
                      {w.qty}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("expiry_forecasting")} exportRows={forecast} filename="roshan-expiry-forecast">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("month")}</TableHead>
                <TableHead>{t("value_at_risk")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {forecast.map((f) => (
                <TableRow key={f.month}>
                  <TableCell dir="ltr">{monthLabel(f.month, "en")}</TableCell>
                  <TableCell className={f.value > 0 ? "font-medium text-warning" : undefined}>
                    {money(f.value, currency)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </ReportCard>
      </div>
    </div>
  );
}

// =============================================================================
// Clinical — Doctor Productivity, Department Statistics, Visit Trends,
// Appointment Analytics, Laboratory Analytics.
// =============================================================================

function ClinicalAnalytics() {
  const { t, lang } = useLang();
  const { currency } = useSettings();
  const since = monthsAgoISO(11);

  const visits = useRows<Row[]>(["an-visits"], () =>
    supabase
      .from("visits")
      .select("visit_date, status, consultation_fee, doctor_id, department_id, users(full_name), departments(name, name_ar)")
      .is("deleted_at", null)
      .gte("visit_date", since)
      .limit(5000),
  );
  const appointments = useRows<Row[]>(["an-appointments"], () =>
    supabase
      .from("appointments")
      .select("appointment_date, status")
      .is("deleted_at", null)
      .gte("appointment_date", since)
      .limit(5000),
  );
  const labOrders = useRows<Row[]>(["an-lab-orders"], () =>
    supabase
      .from("lab_orders")
      .select("created_at, status, lab_order_items(price)")
      .is("deleted_at", null)
      .gte("created_at", since)
      .limit(3000),
  );

  const visitTrend = useMemo(() => {
    const rows = (visits.data ?? []) as Row[];
    return sumByMonth(
      rows.map((r) => ({ ...r, _count: 1 })) as unknown as Row[],
      "visit_date",
      "_count",
      12,
    );
  }, [visits.data]);

  const doctorStats = useMemo(() => {
    const byDoctor = new Map<string, { name: string; count: number; revenue: number }>();
    for (const r of (visits.data ?? []) as Row[]) {
      const name = s(rel(r, "users"), "full_name") || t("unassigned");
      const cur = byDoctor.get(name) ?? { name, count: 0, revenue: 0 };
      cur.count += 1;
      cur.revenue += n(r, "consultation_fee");
      byDoctor.set(name, cur);
    }
    return Array.from(byDoctor.values()).sort((a, b) => b.count - a.count).slice(0, 15);
  }, [visits.data, t]);

  const deptStats = useMemo(() => {
    const byDept = new Map<string, { name: string; count: number }>();
    for (const r of (visits.data ?? []) as Row[]) {
      const dept = rel(r, "departments");
      const name = (lang === "ar" ? s(dept, "name_ar") : s(dept, "name")) || t("unassigned");
      const cur = byDept.get(name) ?? { name, count: 0 };
      cur.count += 1;
      byDept.set(name, cur);
    }
    return Array.from(byDept.values()).sort((a, b) => b.count - a.count);
  }, [visits.data, lang, t]);

  const appointmentStats = useMemo(() => {
    const byStatus = new Map<string, number>();
    for (const r of (appointments.data ?? []) as Row[]) {
      const status = s(r, "status") || "—";
      byStatus.set(status, (byStatus.get(status) ?? 0) + 1);
    }
    return Array.from(byStatus.entries()).map(([status, count]) => ({ status, count }));
  }, [appointments.data]);

  const labStats = useMemo(() => {
    const rows = (labOrders.data ?? []) as Row[];
    const byMonth = new Map<string, { count: number; revenue: number }>();
    for (const r of rows) {
      const key = monthKey(s(r, "created_at"));
      if (key === "—") continue;
      const items = (r["lab_order_items"] as Row[]) ?? [];
      const revenue = items.reduce((sum, i) => sum + n(i, "price"), 0);
      const cur = byMonth.get(key) ?? { count: 0, revenue: 0 };
      cur.count += 1;
      cur.revenue += revenue;
      byMonth.set(key, cur);
    }
    const keys: string[] = [];
    for (let i = 11; i >= 0; i--) {
      const d = new Date();
      d.setMonth(d.getMonth() - i);
      keys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
    }
    return keys.map((k) => ({ month: k, ...(byMonth.get(k) ?? { count: 0, revenue: 0 }) }));
  }, [labOrders.data]);

  const totalVisits12mo = visitTrend.reduce((sum, r) => sum + r.total, 0);
  const totalAppointments = appointmentStats.reduce((sum, r) => sum + r.count, 0);
  const totalLabRevenue = labStats.reduce((sum, r) => sum + r.revenue, 0);

  const anyLoading = visits.isLoading || appointments.isLoading || labOrders.isLoading;
  if (anyLoading) return <Loading />;

  return (
    <div className="grid gap-4">
      <ErrorBox error={visits.error ?? appointments.error ?? labOrders.error} />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label={t("visits_12mo")} value={String(totalVisits12mo)} />
        <StatCard label={t("appointments_12mo")} value={String(totalAppointments)} />
        <StatCard label={t("lab_revenue_12mo")} value={money(totalLabRevenue, currency)} tone="success" />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <ReportCard title={t("visit_trends")} exportRows={visitTrend} filename="roshan-visit-trends">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("month")}</TableHead>
                <TableHead>{t("visits")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {visitTrend.map((r) => (
                <TableRow key={r.month}>
                  <TableCell dir="ltr">{monthLabel(r.month, lang)}</TableCell>
                  <TableCell dir="ltr">{r.total}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </ReportCard>

        <ReportCard title={t("doctor_productivity")} exportRows={doctorStats} filename="roshan-doctor-productivity">
          {doctorStats.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("visits")}</TableHead>
                  <TableHead>{t("amount")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {doctorStats.map((d) => (
                  <TableRow key={d.name}>
                    <TableCell className="font-medium">{d.name}</TableCell>
                    <TableCell dir="ltr">{d.count}</TableCell>
                    <TableCell>{money(d.revenue, currency)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("department_statistics")} exportRows={deptStats} filename="roshan-department-statistics">
          {deptStats.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("visits")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {deptStats.map((d) => (
                  <TableRow key={d.name}>
                    <TableCell className="font-medium">{d.name}</TableCell>
                    <TableCell dir="ltr">{d.count}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("appointment_analytics")} exportRows={appointmentStats} filename="roshan-appointment-analytics">
          {appointmentStats.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead>{t("quantity")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {appointmentStats.map((a) => (
                  <TableRow key={a.status}>
                    <TableCell className="font-medium">{t(a.status)}</TableCell>
                    <TableCell dir="ltr">{a.count}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </ReportCard>

        <ReportCard title={t("laboratory_analytics")} exportRows={labStats} filename="roshan-laboratory-analytics">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("month")}</TableHead>
                <TableHead>{t("quantity")}</TableHead>
                <TableHead>{t("amount")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {labStats.map((r) => (
                <TableRow key={r.month}>
                  <TableCell dir="ltr">{monthLabel(r.month, lang)}</TableCell>
                  <TableCell dir="ltr">{r.count}</TableCell>
                  <TableCell>{money(r.revenue, currency)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </ReportCard>
      </div>
    </div>
  );
}
