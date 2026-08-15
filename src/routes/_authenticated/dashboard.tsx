import { createFileRoute } from "@tanstack/react-router";
import { Banknote, FlaskConical, Pill, Receipt, UserRound, Users, Wallet } from "lucide-react";

import { Empty, ErrorBox, Loading, PageHeader, StatCard, StatusBadge } from "@/components/kit";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

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

function DashboardPage() {
  const { t, lang } = useLang();
  const { user } = useAuth();
  const { currency } = useSettings();
  const today = todayISO();
  const monthStart = `${today.slice(0, 7)}-01`;

  const visits = useRows(["dash-visits", today], () =>
    supabase
      .from("visits")
      .select("id, status, visit_date, consultation_fee, patients(full_name, mrn), departments(name, name_ar)")
      .eq("visit_date", today)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const patientsToday = useRows(["dash-patients", today], () =>
    supabase
      .from("patients")
      .select("id")
      .gte("created_at", `${today}T00:00:00`)
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

  const payments = useRows(["dash-payments", monthStart], () =>
    supabase
      .from("payments")
      .select("amount, payment_date, method")
      .gte("payment_date", monthStart)
      .is("deleted_at", null),
  );

  const expenses = useRows(["dash-expenses", monthStart], () =>
    supabase
      .from("expenses")
      .select("amount, expense_date, category")
      .gte("expense_date", monthStart)
      .is("deleted_at", null),
  );

  const labPending = useRows(["dash-lab"], () =>
    supabase
      .from("lab_orders")
      .select("id, status, created_at, patients(full_name)")
      .in("status", ["pending", "collected", "in_progress"])
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

  const anyError =
    visits.error ?? payments.error ?? expenses.error ?? labPending.error ?? rxPending.error;

  const visitRows = (visits.data ?? []) as Row[];
  const paymentRows = (payments.data ?? []) as Row[];
  const expenseRows = (expenses.data ?? []) as Row[];

  const revenueToday = paymentRows
    .filter((p) => s(p, "payment_date").startsWith(today))
    .reduce((sum, p) => sum + n(p, "amount"), 0);
  const revenueMonth = paymentRows.reduce((sum, p) => sum + n(p, "amount"), 0);
  const expensesToday = expenseRows
    .filter((p) => s(p, "expense_date").startsWith(today))
    .reduce((sum, p) => sum + n(p, "amount"), 0);
  const expensesMonth = expenseRows.reduce((sum, p) => sum + n(p, "amount"), 0);
  const waiting = visitRows.filter((v) => s(v, "status") === "waiting").length;

  if (visits.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader
        title={`${t("dashboard")} — ${t("app_name")}`}
        subtitle={`${user?.full_name ?? ""} · ${user?.role_name ?? ""} · ${formatDate(today)}`}
      />
      <ErrorBox error={anyError} />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label={t("patients_today")}
          value={((patientsToday.data ?? []) as Row[]).length}
          icon={<UserRound className="size-5" />}
          tone="primary"
        />
        <StatCard
          label={t("visits_today")}
          value={visitRows.length}
          hint={`${t("waiting_patients")}: ${waiting}`}
          icon={<Users className="size-5" />}
        />
        <StatCard
          label={t("revenue_today")}
          value={money(revenueToday, currency)}
          hint={`${t("monthly_revenue")}: ${money(revenueMonth, currency)}`}
          icon={<Banknote className="size-5" />}
          tone="success"
        />
        <StatCard
          label={t("expenses_today")}
          value={money(expensesToday, currency)}
          hint={`${t("net_profit")}: ${money(revenueMonth - expensesMonth, currency)}`}
          icon={<Wallet className="size-5" />}
          tone="warning"
        />
        <StatCard
          label={t("appointments_today")}
          value={((appointments.data ?? []) as Row[]).length}
          icon={<Receipt className="size-5" />}
        />
        <StatCard
          label={t("pending_lab")}
          value={((labPending.data ?? []) as Row[]).length}
          icon={<FlaskConical className="size-5" />}
          tone="warning"
        />
        <StatCard
          label={t("pending_pharmacy")}
          value={((rxPending.data ?? []) as Row[]).length}
          icon={<Pill className="size-5" />}
          tone="warning"
        />
        <StatCard
          label={t("net_profit")}
          value={money(revenueMonth - expensesMonth, currency)}
          hint={t("monthly_revenue")}
          tone={revenueMonth - expensesMonth >= 0 ? "success" : "destructive"}
        />
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">{t("visits_today")}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {visitRows.length === 0 ? (
              <Empty />
            ) : (
              <Table>
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
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">{t("upcoming_appointments")}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {((appointments.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("patient")}</TableHead>
                    <TableHead>{t("date")}</TableHead>
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
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">{t("pending_lab")}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {((labPending.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table>
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
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">{t("upcoming_followups")}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {((followups.data ?? []) as Row[]).length === 0 ? (
              <Empty />
            ) : (
              <Table>
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
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
