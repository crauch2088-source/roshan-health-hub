import { createFileRoute, Link } from "@tanstack/react-router";
import {
  AlertTriangle,
  ChevronLeft,
  ChevronRight,
  Banknote,
  FlaskConical,
  Pill,
  Receipt,
  UserRound,
  Users,
  Wallet,
} from "lucide-react";

import {
  DataPanel,
  Empty,
  ErrorBox,
  Metric,
  MetricStrip,
  PageHeader,
  PageSkeleton,
  SectionTitle,
  StatusBadge,
  PermissionGate,
  Loading,
} from "@/components/kit";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useAllRows, useCount, useRows, useSettings, type Row } from "@/lib/db";
import { PENDING_LAB_STATUSES, sumAmounts } from "@/lib/dashboard-metrics";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { DEFAULT_EXPIRY_THRESHOLD_DAYS, EXPIRY_TONE, expiryStatus } from "@/lib/pharmacy";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_authenticated/dashboard")({
  head: () => ({
    meta: [
      { title: "Dashboard — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Live clinic overview: patients, visits, laboratory, pharmacy and revenue.",
      },
      { property: "og:title", content: "Dashboard — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Live clinic overview: patients, visits, laboratory, pharmacy and revenue.",
      },
    ],
  }),
  component: DashboardPage,
});

type ViewAllTarget =
  "/visits" | "/appointments" | "/lab" | "/followups" | "/inventory" | "/insurance" | "/pharmacy";

/** "View all" link in a panel header; hidden when the user may not open the destination. */
function ViewAll({ to, perm }: { to: ViewAllTarget; perm: string }) {
  const { t, lang } = useLang();
  const { can } = useAuth();
  if (!can(perm)) return null;
  const Chevron = lang === "ar" ? ChevronLeft : ChevronRight;
  return (
    <Link
      to={to}
      className="inline-flex min-h-9 items-center gap-0.5 rounded-md px-1.5 text-xs font-semibold text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring"
    >
      {t("view_all")} <Chevron className="size-3.5" aria-hidden />
    </Link>
  );
}

function DashboardPage() {
  return (
    <PermissionGate perm="dashboard.read">
      <DashboardPageInner />
    </PermissionGate>
  );
}

function DashboardPageInner() {
  const { t, lang } = useLang();
  const { user } = useAuth();
  const { currency, settings } = useSettings();
  const today = todayISO();
  const monthStart = `${today.slice(0, 7)}-01`;

  const visits = useRows(["dash-visits", today], () =>
    supabase
      .from("visits")
      .select(
        "id, status, visit_date, consultation_fee, patients(full_name, mrn), departments(name, name_ar)",
      )
      .eq("visit_date", today)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  // Exact database counts: the metric cards never depend on how many rows
  // the list queries below happen to load (or on `.limit()` / `max-rows`).
  const visitsCount = useCount(["dash-visits-count", today], () =>
    supabase
      .from("visits")
      .select("id", { count: "exact", head: true })
      .eq("visit_date", today)
      .is("deleted_at", null),
  );
  const waitingCount = useCount(["dash-visits-waiting-count", today], () =>
    supabase
      .from("visits")
      .select("id", { count: "exact", head: true })
      .eq("visit_date", today)
      .eq("status", "waiting")
      .is("deleted_at", null),
  );
  const patientsCount = useCount(["dash-patients-count", today], () =>
    supabase
      .from("patients")
      .select("id", { count: "exact", head: true })
      .gte("created_at", `${today}T00:00:00`)
      .is("deleted_at", null),
  );
  const appointmentsCount = useCount(["dash-appts-count", today], () =>
    supabase
      .from("appointments")
      .select("id", { count: "exact", head: true })
      .eq("appointment_date", today)
      .is("deleted_at", null),
  );
  const labCount = useCount(["dash-lab-count"], () =>
    supabase
      .from("lab_orders")
      .select("id", { count: "exact", head: true })
      .in("status", PENDING_LAB_STATUSES)
      .is("deleted_at", null),
  );
  const rxCount = useCount(["dash-rx-count"], () =>
    supabase
      .from("prescriptions")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending")
      .eq("is_external", false)
      .is("deleted_at", null),
  );

  const appointments = useRows(["dash-appts", today], () =>
    supabase
      .from("appointments")
      .select("id, status, appointment_date, appointment_time, patients(full_name)")
      .eq("appointment_date", today)
      .is("deleted_at", null)
      .order("appointment_time", { ascending: true }),
  );

  // Revenue and expenses are summed in the browser (no aggregate view/RPC
  // exists for them), so every page is read and the totals are only shown if
  // the rows received match the server's exact count (see `financeVerified`).
  const payments = useAllRows<Row>(["dash-payments", monthStart], ({ from, to }) =>
    supabase
      .from("payments")
      .select("id, amount, payment_date, method", { count: "exact" })
      .gte("payment_date", monthStart)
      .is("deleted_at", null)
      .order("payment_date", { ascending: true })
      .order("id", { ascending: true })
      .range(from, to),
  );

  const expenses = useAllRows<Row>(["dash-expenses", monthStart], ({ from, to }) =>
    supabase
      .from("expenses")
      .select("id, amount, expense_date, category", { count: "exact" })
      .gte("expense_date", monthStart)
      .is("deleted_at", null)
      .order("expense_date", { ascending: true })
      .order("id", { ascending: true })
      .range(from, to),
  );

  const labPending = useRows(["dash-lab"], () =>
    supabase
      .from("lab_orders")
      .select("id, status, created_at, patients(full_name)")
      .in("status", PENDING_LAB_STATUSES)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(10),
  );

  const rxPending = useRows(["dash-rx"], () =>
    supabase
      .from("prescriptions")
      .select("id, status, created_at, patients(full_name)")
      .eq("status", "pending")
      .eq("is_external", false)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(10),
  );

  const followups = useRows(["dash-followups"], () =>
    supabase
      .from("followups")
      .select("id, followup_date, status, reason, patients(full_name)")
      .gte("followup_date", today)
      .is("deleted_at", null)
      .order("followup_date", { ascending: true })
      .limit(8),
  );

  // Phase 3 — pharmacy alert widgets. Low stock reads the medicine-level
  // aggregate (stock_quantity/reorder_level), same numbers as the
  // Inventory > Medicines tab. Expiring/expired read actual batches, since
  // a medicine's aggregate stock can be fine while one specific batch is
  // about to expire.
  const thresholdDays =
    Number(settings["pharmacy_expiry_threshold_days"]) || DEFAULT_EXPIRY_THRESHOLD_DAYS;

  // Both alert sources are read completely (all pages): a fixed `.limit()`
  // would silently drop low-stock medicines or expiring batches that sort late.
  const lowStockMeds = useAllRows<Row>(["dash-low-stock"], ({ from, to }) =>
    supabase
      .from("medicines")
      .select("id, name, stock_quantity, reorder_level", { count: "exact" })
      .is("deleted_at", null)
      .order("stock_quantity", { ascending: true })
      .order("id", { ascending: true })
      .range(from, to),
  );

  const batchesForAlerts = useAllRows<Row>(["dash-batches"], ({ from, to }) =>
    supabase
      .from("pharmacy_inventory")
      .select("id, expiry_date, quantity_remaining, medicines(name)", { count: "exact" })
      .is("deleted_at", null)
      .gt("quantity_remaining", 0)
      .order("expiry_date", { ascending: true, nullsFirst: false })
      .order("id", { ascending: true })
      .range(from, to),
  );

  // Phase 6 dashboard addition — reuses insurance_claims (Phase 5), no new
  // table/RPC. "Pending" = awaiting a decision, i.e. needs someone's attention.
  const insurance = useRows(["dash-insurance-claims"], () =>
    supabase
      .from("insurance_claims")
      .select("id, claim_number, status, submitted_amount")
      .is("deleted_at", null)
      .in("status", ["submitted", "under_review"])
      .order("created_at", { ascending: false })
      .limit(8),
  );
  const insurancePendingRows = (insurance.data ?? []) as Row[];

  const anyError =
    visits.error ??
    visitsCount.error ??
    waitingCount.error ??
    patientsCount.error ??
    appointments.error ??
    appointmentsCount.error ??
    payments.error ??
    expenses.error ??
    labPending.error ??
    labCount.error ??
    rxPending.error ??
    rxCount.error ??
    followups.error ??
    lowStockMeds.error ??
    batchesForAlerts.error ??
    insurance.error;

  const visitRows = (visits.data ?? []) as Row[];
  const paymentRows = payments.data?.rows ?? [];
  const expenseRows = expenses.data?.rows ?? [];
  const financeVerified = Boolean(payments.data?.exact && expenses.data?.exact);

  const revenueToday = sumAmounts(paymentRows, (p) => s(p, "payment_date").startsWith(today));
  const revenueMonth = sumAmounts(paymentRows);
  const expensesToday = sumAmounts(expenseRows, (p) => s(p, "expense_date").startsWith(today));
  const expensesMonth = sumAmounts(expenseRows);
  const netMonth = revenueMonth - expensesMonth;
  /** Money cards show a dash rather than a number that might be truncated. */
  const fin = (value: number) => (financeVerified ? money(value, currency) : "—");
  const countValue = (q: { data: number | undefined }) => q.data ?? "—";

  const lowStockRows = (lowStockMeds.data?.rows ?? [])
    .filter((m) => n(m, "stock_quantity") <= n(m, "reorder_level"))
    .slice(0, 8);
  const batchRows = batchesForAlerts.data?.rows ?? [];
  const expiringRows = batchRows
    .filter((b) => expiryStatus(s(b, "expiry_date") || null, thresholdDays) === "expiring_soon")
    .slice(0, 8);
  const expiredRows = batchRows
    .filter((b) => expiryStatus(s(b, "expiry_date") || null, thresholdDays) === "expired")
    .slice(0, 8);

  if (visits.isLoading) return <PageSkeleton />;

  return (
    <div>
      <PageHeader
        eyebrow={t("app_name")}
        title={t("dashboard")}
        subtitle={`${user?.full_name ?? ""} · ${user?.role_name ?? ""} · ${formatDate(today)}`}
      />
      <ErrorBox error={anyError} />
      {!payments.isLoading &&
      !expenses.isLoading &&
      !payments.error &&
      !expenses.error &&
      !financeVerified ? (
        <p
          role="alert"
          className="mb-3 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-sm"
        >
          {t("totals_unverified")}
        </p>
      ) : null}

      <SectionTitle>{t("executive_summary")}</SectionTitle>
      <div className="space-y-3">
        <MetricStrip label={t("clinical_summary")} cols="sm:grid-cols-3 xl:grid-cols-5">
          <Metric
            label={t("visits_today")}
            value={countValue(visitsCount)}
            hint={`${t("waiting_patients")}: ${countValue(waitingCount)}`}
            icon={<Users />}
          />
          <Metric
            label={t("patients_today")}
            value={countValue(patientsCount)}
            icon={<UserRound />}
            tone="primary"
          />
          <Metric
            label={t("appointments_today")}
            value={countValue(appointmentsCount)}
            icon={<Receipt />}
          />
          <Metric
            label={t("pending_lab")}
            value={countValue(labCount)}
            icon={<FlaskConical />}
            tone="warning"
          />
          <Metric
            label={t("pending_pharmacy")}
            value={countValue(rxCount)}
            icon={<Pill />}
            tone="warning"
          />
        </MetricStrip>
        <MetricStrip label={t("revenue_today")} cols="sm:grid-cols-3">
          <Metric
            label={t("revenue_today")}
            value={fin(revenueToday)}
            hint={`${t("monthly_revenue")}: ${fin(revenueMonth)}`}
            icon={<Banknote />}
            tone="success"
          />
          <Metric
            label={t("expenses_today")}
            value={fin(expensesToday)}
            hint={`${t("net_profit")}: ${fin(netMonth)}`}
            icon={<Wallet />}
            tone="warning"
          />
          <Metric
            label={t("net_profit")}
            value={fin(netMonth)}
            hint={t("monthly_revenue")}
            tone={!financeVerified || netMonth >= 0 ? "success" : "destructive"}
          />
        </MetricStrip>
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <div className="col-span-full">
          <SectionTitle>{t("clinical_summary")}</SectionTitle>
        </div>
        <DataPanel title={t("visits_today")} action={<ViewAll to="/visits" perm="visits.read" />}>
          {visitRows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {visitRows.slice(0, 8).map((v) => (
                  <TableRow key={s(v, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(v, "patients"), "full_name") || "—"}
                    </TableCell>
                    <TableCell>
                      {lang === "ar"
                        ? s(rel(v, "departments"), "name_ar") || s(rel(v, "departments"), "name")
                        : s(rel(v, "departments"), "name")}
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={s(v, "status")} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <DataPanel
          title={t("upcoming_appointments")}
          action={<ViewAll to="/appointments" perm="appointments.read" />}
        >
          {((appointments.data ?? []) as Row[]).length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("time")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {((appointments.data ?? []) as Row[]).slice(0, 8).map((a) => (
                  <TableRow key={s(a, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(a, "patients"), "full_name") || "—"}
                    </TableCell>
                    <TableCell dir="ltr">{s(a, "appointment_time").slice(0, 5) || "—"}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(a, "status")} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <div className="col-span-full">
          <SectionTitle>{t("pending_tasks")}</SectionTitle>
        </div>
        <DataPanel title={t("pending_lab")} action={<ViewAll to="/lab" perm="lab.read" />}>
          {((labPending.data ?? []) as Row[]).length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {((labPending.data ?? []) as Row[]).map((o) => (
                  <TableRow key={s(o, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(o, "patients"), "full_name") || "—"}
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={s(o, "status")} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <DataPanel
          title={t("upcoming_followups")}
          action={<ViewAll to="/followups" perm="followups.read" />}
        >
          {((followups.data ?? []) as Row[]).length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("due_date")}</TableHead>
                  <TableHead>{t("reason")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {((followups.data ?? []) as Row[]).map((f) => (
                  <TableRow key={s(f, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(f, "patients"), "full_name") || "—"}
                    </TableCell>
                    <TableCell dir="ltr">{formatDate(s(f, "followup_date"))}</TableCell>
                    <TableCell className="max-w-40 truncate">{s(f, "reason") || "—"}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <div className="col-span-full">
          <SectionTitle>{t("pharmacy_summary")}</SectionTitle>
        </div>
        <DataPanel
          title={t("low_stock_medicines")}
          icon={<AlertTriangle className="text-warning" aria-hidden />}
          action={<ViewAll to="/inventory" perm="pharmacy.read" />}
        >
          {lowStockRows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("stock")}</TableHead>
                  <TableHead>{t("reorder_level")}</TableHead>
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
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <DataPanel
          title={t("expiring_medicines")}
          icon={<AlertTriangle className="text-warning" aria-hidden />}
        >
          {expiringRows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("expiry_date")}</TableHead>
                  <TableHead>{t("remaining_quantity")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {expiringRows.map((b) => (
                  <TableRow key={s(b, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(b, "medicines"), "name") || "—"}
                    </TableCell>
                    <TableCell dir="ltr">
                      <Badge
                        variant="outline"
                        className={cn("font-medium", EXPIRY_TONE.expiring_soon)}
                      >
                        {formatDate(s(b, "expiry_date"))}
                      </Badge>
                    </TableCell>
                    <TableCell dir="ltr">{n(b, "quantity_remaining")}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <DataPanel
          title={t("expired_medicines")}
          icon={<AlertTriangle className="text-destructive" aria-hidden />}
        >
          {expiredRows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("expiry_date")}</TableHead>
                  <TableHead>{t("remaining_quantity")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {expiredRows.map((b) => (
                  <TableRow key={s(b, "id")}>
                    <TableCell className="font-medium">
                      {s(rel(b, "medicines"), "name") || "—"}
                    </TableCell>
                    <TableCell dir="ltr">
                      <Badge variant="outline" className={cn("font-medium", EXPIRY_TONE.expired)}>
                        {formatDate(s(b, "expiry_date"))}
                      </Badge>
                    </TableCell>
                    <TableCell dir="ltr">{n(b, "quantity_remaining")}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>

        <div className="col-span-full">
          <SectionTitle>{t("insurance_summary")}</SectionTitle>
        </div>
        <DataPanel
          title={t("insurance_claims")}
          icon={<Receipt className="text-warning" aria-hidden />}
          action={<ViewAll to="/insurance" perm="insurance.read" />}
        >
          {insurance.isLoading ? (
            <Loading />
          ) : insurancePendingRows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("claim_number")}</TableHead>
                  <TableHead>{t("net")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {insurancePendingRows.map((c) => (
                  <TableRow key={s(c, "id")}>
                    <TableCell dir="ltr" className="font-mono text-xs">
                      {s(c, "claim_number")}
                    </TableCell>
                    <TableCell>{money(n(c, "submitted_amount"), currency)}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(c, "status")} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DataPanel>
      </div>
    </div>
  );
}
