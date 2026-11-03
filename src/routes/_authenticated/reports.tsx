import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  ExportButtons,
  Loading,
  PageHeader,
  PermissionGate,
  StatCard,
} from "@/components/kit";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
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
import { formatDate, money, todayISO } from "@/lib/medical";
import { DEFAULT_EXPIRY_THRESHOLD_DAYS, expiryStatus } from "@/lib/pharmacy";
import { isValidReportingRange, type ReportingPayload } from "@/lib/reporting";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/reports")({
  head: () => ({
    meta: [
      { title: "Reports — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Operational reports: visits, diagnoses, laboratory volume and revenue.",
      },
      { property: "og:title", content: "Reports — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Operational reports: visits, diagnoses, laboratory volume and revenue.",
      },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  return (
    <PermissionGate perm="reports.read">
      <ReportsPageInner />
    </PermissionGate>
  );
}

function ReportsPageInner() {
  const { t, lang } = useLang();
  const { currency } = useSettings();
  const [from, setFrom] = useState(`${todayISO().slice(0, 7)}-01`);
  const [to, setTo] = useState(todayISO());

  const rangeValid = isValidReportingRange(from, to);
  const report = useRows<ReportingPayload>(
    ["rep-summary", from, to],
    () =>
      supabase.rpc("get_reporting_analytics", {
        p_from_date: from,
        p_to_date: to,
        p_branch_id: null,
      }),
    { enabled: rangeValid },
  );
  const payload = report.data as ReportingPayload | undefined;
  const summary = payload?.summary;
  const coverage = payload?.coverage;
  const byDepartment = Object.fromEntries(
    (payload?.by_department ?? []).map((row) => [row.name || t("none"), Number(row.count)]),
  );
  const byDoctor = Object.fromEntries(
    (payload?.by_doctor ?? []).map((row) => [row.name || t("none"), Number(row.count)]),
  );
  const byTest = Object.fromEntries(
    (payload?.by_test ?? []).map((row) => [
      lang === "ar" ? row.name_ar || row.name : row.name,
      Number(row.count),
    ]),
  );
  const byDiagnosis = Object.fromEntries(
    (payload?.by_diagnosis ?? []).map((row) => [row.name || t("none"), Number(row.count)]),
  );
  const monthlyRows = payload?.monthly ?? [];
  const visitCount = Number(summary?.visits ?? 0);
  const labItemCount = Number(summary?.lab_items ?? 0);
  const consultRevenue = Number(summary?.consultation_revenue ?? 0);
  const labRevenue = Number(summary?.lab_revenue ?? 0);
  const summaryRows: Row[] = [
    { metric: t("visits"), value: visitCount },
    { metric: t("completed_visits"), value: Number(summary?.completed_visits ?? 0) },
    { metric: t("laboratory"), value: labItemCount },
    { metric: t("consultation_fee"), value: consultRevenue },
    { metric: t("lab_revenue"), value: labRevenue },
    { metric: t("payments_collected"), value: Number(summary?.payments_collected ?? 0) },
    { metric: t("operating_expenses"), value: Number(summary?.operating_expenses ?? 0) },
    { metric: t("net_cashflow"), value: Number(summary?.net_cashflow ?? 0) },
  ];

  const rank = (map: Record<string, number>) =>
    Object.entries(map)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20);

  if (report.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("reports")} subtitle={`${formatDate(from)} — ${formatDate(to)}`}>
        <Input
          type="date"
          dir="ltr"
          value={from}
          onChange={(e) => setFrom(e.target.value)}
          className="w-40"
        />
        <Input
          type="date"
          dir="ltr"
          value={to}
          onChange={(e) => setTo(e.target.value)}
          className="w-40"
        />
        <ExportButtons rows={summaryRows} filename={`roshan-report-summary-${from}-${to}`} />
      </PageHeader>

      <ErrorBox
        error={report.error ?? (rangeValid ? null : new Error(t("invalid_reporting_range")))}
      />
      {coverage && !coverage.insurance ? (
        <p
          className="mb-4 rounded-lg border border-border bg-muted/40 p-3 text-sm text-muted-foreground"
          role="status"
        >
          {t("insurance_metrics_unavailable")}
        </p>
      ) : null}

      <div className="mb-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("visits")} value={String(visitCount)} />
        <StatCard label={t("laboratory")} value={String(labItemCount)} />
        <StatCard
          label={t("completed_visits")}
          value={String(Number(summary?.completed_visits ?? 0))}
        />
        <StatCard label={t("consultation_fee")} value={money(consultRevenue, currency)} />
        <StatCard
          label={t("payments_collected")}
          value={money(Number(summary?.payments_collected ?? 0), currency)}
          tone="success"
        />
        <StatCard
          label={t("operating_expenses")}
          value={money(Number(summary?.operating_expenses ?? 0), currency)}
          tone="destructive"
        />
        <StatCard
          label={t("net_cashflow")}
          value={money(Number(summary?.net_cashflow ?? 0), currency)}
        />
        <StatCard label={t("lab_revenue")} value={money(labRevenue, currency)} />
      </div>

      <Tabs defaultValue="dept">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="dept">{t("department")}</TabsTrigger>
          <TabsTrigger value="doctor">{t("doctor")}</TabsTrigger>
          <TabsTrigger value="tests">{t("test")}</TabsTrigger>
          <TabsTrigger value="dx">{t("diagnosis")}</TabsTrigger>
          <TabsTrigger value="monthly">{t("monthly_trends")}</TabsTrigger>
        </TabsList>
        {[
          ["dept", byDepartment] as const,
          ["doctor", byDoctor] as const,
          ["tests", byTest] as const,
          ["dx", byDiagnosis] as const,
        ].map(([key, map]) => (
          <TabsContent key={key} value={key}>
            <Card>
              <CardContent className="p-0">
                {Object.keys(map).length === 0 ? (
                  <Empty />
                ) : (
                  <Table density="compact">
                    <TableHeader>
                      <TableRow>
                        <TableHead>{t("name")}</TableHead>
                        <TableHead>{t("count")}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {rank(map).map(([name, count]) => (
                        <TableRow key={name}>
                          <TableCell className="font-medium">{name}</TableCell>
                          <TableCell dir="ltr">{count}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        ))}
        <TabsContent value="monthly">
          <Card>
            <CardContent className="p-4">
              <div className="mb-3 flex justify-end">
                <ExportButtons rows={monthlyRows as Row[]} filename="roshan-monthly-report" />
              </div>
              {monthlyRows.length === 0 ? (
                <Empty />
              ) : (
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("month")}</TableHead>
                      <TableHead>{t("visits")}</TableHead>
                      <TableHead>{t("payments_collected")}</TableHead>
                      <TableHead>{t("operating_expenses")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {monthlyRows.map((row) => (
                      <TableRow key={row.month}>
                        <TableCell dir="ltr">{row.month}</TableCell>
                        <TableCell dir="ltr">{Number(row.visits)}</TableCell>
                        <TableCell>{money(Number(row.payments), currency)}</TableCell>
                        <TableCell>{money(Number(row.expenses), currency)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      <PharmacyReports />
    </div>
  );
}

// =============================================================================
// Pharmacy reports — Phase 3 Part 7. Separate section (own data, own date
// scope: these are point-in-time stock reports, not visit-date-ranged like
// the section above) so it doesn't disturb the existing clinical reports.
// =============================================================================

function PharmacyReports() {
  const { t } = useLang();
  const { currency, settings } = useSettings();
  const thresholdDays =
    Number(settings["pharmacy_expiry_threshold_days"]) || DEFAULT_EXPIRY_THRESHOLD_DAYS;

  const medicines = useRows<Row[]>(["rep-medicines"], () =>
    supabase
      .from("medicines")
      .select("id, name, unit, stock_quantity, reorder_level, cost_price, selling_price")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const batches = useRows<Row[]>(["rep-batches"], () =>
    supabase
      .from("pharmacy_inventory")
      .select(
        "id, batch_number, expiry_date, quantity_received, quantity_remaining, purchase_price, selling_price, medicines(name), suppliers(name)",
      )
      .is("deleted_at", null)
      .order("expiry_date", { ascending: true, nullsFirst: false }),
  );

  const medRows = (medicines.data ?? []) as Row[];
  const batchRows = (batches.data ?? []) as Row[];

  const lowStockRows = medRows.filter((m) => n(m, "stock_quantity") <= n(m, "reorder_level"));
  const expiryRows = batchRows.filter((b) => {
    const status = expiryStatus(s(b, "expiry_date") || null, thresholdDays);
    return status === "expiring_soon" || status === "expired" || status === "unknown";
  });

  const batchInventoryValue = batchRows.reduce(
    (sum, b) => sum + n(b, "quantity_remaining") * n(b, "purchase_price"),
    0,
  );

  if (medicines.isLoading) return <Loading />;

  return (
    <div className="mt-8">
      <h2 className="mb-4 text-lg font-bold tracking-tight text-foreground">{t("pharmacy")}</h2>
      <Tabs defaultValue="expiry">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="expiry">{t("expiry_report")}</TabsTrigger>
          <TabsTrigger value="low-stock">{t("low_stock_report")}</TabsTrigger>
          <TabsTrigger value="batch-inventory">{t("batch_inventory_report")}</TabsTrigger>
        </TabsList>

        <TabsContent value="expiry">
          <Card>
            <CardContent className="p-4">
              <div className="mb-3 flex justify-end">
                <ExportButtons rows={expiryRows} filename="roshan-expiry-report" />
              </div>
              {expiryRows.length === 0 ? (
                <Empty />
              ) : (
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("medicines")}</TableHead>
                      <TableHead>{t("batch_number")}</TableHead>
                      <TableHead>{t("supplier")}</TableHead>
                      <TableHead>{t("expiry_date")}</TableHead>
                      <TableHead>{t("remaining_quantity")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {expiryRows.map((b) => (
                      <TableRow key={s(b, "id")}>
                        <TableCell className="font-medium">
                          {s(rel(b, "medicines"), "name") || "—"}
                        </TableCell>
                        <TableCell dir="ltr">{s(b, "batch_number") || "—"}</TableCell>
                        <TableCell>{s(rel(b, "suppliers"), "name") || "—"}</TableCell>
                        <TableCell dir="ltr">
                          {s(b, "expiry_date") ? formatDate(s(b, "expiry_date")) : t("unknown")}
                        </TableCell>
                        <TableCell dir="ltr">{n(b, "quantity_remaining")}</TableCell>
                        <TableCell>
                          {t(expiryStatus(s(b, "expiry_date") || null, thresholdDays))}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="low-stock">
          <Card>
            <CardContent className="p-4">
              <div className="mb-3 flex justify-end">
                <ExportButtons rows={lowStockRows} filename="roshan-low-stock-report" />
              </div>
              {lowStockRows.length === 0 ? (
                <Empty />
              ) : (
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("medicines")}</TableHead>
                      <TableHead>{t("stock")}</TableHead>
                      <TableHead>{t("reorder_level")}</TableHead>
                      <TableHead>{t("selling_price")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {lowStockRows.map((m) => (
                      <TableRow key={s(m, "id")}>
                        <TableCell className="font-medium">{s(m, "name")}</TableCell>
                        <TableCell dir="ltr" className="font-semibold text-destructive">
                          {n(m, "stock_quantity")}
                        </TableCell>
                        <TableCell dir="ltr">{n(m, "reorder_level")}</TableCell>
                        <TableCell>{money(n(m, "selling_price"), currency)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="batch-inventory">
          <div className="mb-4 grid gap-4 sm:grid-cols-2">
            <StatCard label={t("batches")} value={String(batchRows.length)} />
            <StatCard label={t("stock_value")} value={money(batchInventoryValue, currency)} />
          </div>
          <Card>
            <CardContent className="p-4">
              <div className="mb-3 flex justify-end">
                <ExportButtons rows={batchRows} filename="roshan-batch-inventory-report" />
              </div>
              {batchRows.length === 0 ? (
                <Empty />
              ) : (
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("medicines")}</TableHead>
                      <TableHead>{t("batch_number")}</TableHead>
                      <TableHead>{t("supplier")}</TableHead>
                      <TableHead>{t("expiry_date")}</TableHead>
                      <TableHead>{t("quantity_received")}</TableHead>
                      <TableHead>{t("remaining_quantity")}</TableHead>
                      <TableHead>{t("purchase_price")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {batchRows.map((b) => (
                      <TableRow key={s(b, "id")}>
                        <TableCell className="font-medium">
                          {s(rel(b, "medicines"), "name") || "—"}
                        </TableCell>
                        <TableCell dir="ltr">{s(b, "batch_number") || "—"}</TableCell>
                        <TableCell>{s(rel(b, "suppliers"), "name") || "—"}</TableCell>
                        <TableCell dir="ltr">
                          {s(b, "expiry_date") ? formatDate(s(b, "expiry_date")) : "—"}
                        </TableCell>
                        <TableCell dir="ltr">{n(b, "quantity_received")}</TableCell>
                        <TableCell dir="ltr">{n(b, "quantity_remaining")}</TableCell>
                        <TableCell>{money(n(b, "purchase_price"), currency)}</TableCell>
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
