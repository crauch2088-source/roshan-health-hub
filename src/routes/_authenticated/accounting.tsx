import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatCard } from "@/components/kit";
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
import { n, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/accounting")({
  head: () => ({
    meta: [
      { title: "Accounting — ROSHAN Medical Center" },
      { name: "description", content: "Daily and monthly cash position: revenue, expenses and net result." },
      { property: "og:title", content: "Accounting — ROSHAN Medical Center" },
      { property: "og:description", content: "Daily and monthly cash position: revenue, expenses and net result." },
    ],
  }),
  component: AccountingPage,
});

function monthStart(date: string) {
  return `${date.slice(0, 7)}-01`;
}

function AccountingPage() {
  const { t } = useLang();
  const { currency } = useSettings();
  const [from, setFrom] = useState(monthStart(todayISO()));
  const [to, setTo] = useState(todayISO());

  const payments = useRows(["acc-payments", from, to], () =>
    supabase
      .from("payments")
      .select("id, amount, payment_method, payment_date")
      .gte("payment_date", from)
      .lte("payment_date", to)
      .order("payment_date", { ascending: false }),
  );

  const expenses = useRows(["acc-expenses", from, to], () =>
    supabase
      .from("expenses")
      .select("id, amount, category, description, expense_date")
      .gte("expense_date", from)
      .lte("expense_date", to)
      .is("deleted_at", null)
      .order("expense_date", { ascending: false }),
  );

  const invoices = useRows(["acc-invoices", from, to], () =>
    supabase
      .from("invoices")
      .select("id, net_amount, paid_amount, invoice_date")
      .gte("invoice_date", from)
      .lte("invoice_date", to)
      .is("deleted_at", null),
  );

  const payRows = (payments.data ?? []) as Row[];
  const expRows = (expenses.data ?? []) as Row[];
  const invRows = (invoices.data ?? []) as Row[];

  const revenue = payRows.reduce((sum, r) => sum + n(r, "amount"), 0);
  const spend = expRows.reduce((sum, r) => sum + n(r, "amount"), 0);
  const receivable = invRows.reduce((sum, r) => sum + (n(r, "net_amount") - n(r, "paid_amount")), 0);

  const byMethod: Record<string, number> = {};
  for (const p of payRows) {
    const method = s(p, "payment_method") || "cash";
    byMethod[method] = (byMethod[method] ?? 0) + n(p, "amount");
  }

  if (payments.isLoading && expenses.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("accounting")} subtitle={`${formatDate(from)} — ${formatDate(to)}`}>
        <Input type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} className="w-40" />
        <Input type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} className="w-40" />
        <ExportButtons rows={payRows} filename={`roshan-revenue-${from}-${to}`} />
      </PageHeader>

      <ErrorBox error={payments.error ?? expenses.error ?? invoices.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("revenue")} value={money(revenue, currency)} tone="success" />
        <StatCard label={t("expenses")} value={money(spend, currency)} tone="destructive" />
        <StatCard label={t("net_profit")} value={money(revenue - spend, currency)} tone="primary" />
        <StatCard label={t("receivables")} value={money(receivable, currency)} tone="warning" />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardContent className="p-4">
            <h3 className="mb-3 text-sm font-semibold">{t("by_payment_method")}</h3>
            {Object.keys(byMethod).length === 0 ? (
              <Empty />
            ) : (
              <ul className="space-y-2 text-sm">
                {Object.entries(byMethod).map(([key, value]) => (
                  <li key={key} className="flex justify-between rounded-md border p-2">
                    <span>{t(key)}</span>
                    <span className="font-medium">{money(value, currency)}</span>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-0">
            <div className="p-4 pb-2 text-sm font-semibold">{t("expenses")}</div>
            {expRows.length === 0 ? (
              <Empty />
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("date")}</TableHead>
                    <TableHead>{t("category")}</TableHead>
                    <TableHead>{t("amount")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {expRows.slice(0, 15).map((e) => (
                    <TableRow key={s(e, "id")}>
                      <TableCell dir="ltr">{formatDate(s(e, "expense_date"))}</TableCell>
                      <TableCell>{t(s(e, "category")) || s(e, "category")}</TableCell>
                      <TableCell>{money(n(e, "amount"), currency)}</TableCell>
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
