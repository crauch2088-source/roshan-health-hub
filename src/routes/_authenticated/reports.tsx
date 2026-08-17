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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { n, rel, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/reports")({
  head: () => ({
    meta: [
      { title: "Reports — ROSHAN Medical Center" },
      { name: "description", content: "Operational reports: visits, diagnoses, laboratory volume and revenue." },
      { property: "og:title", content: "Reports — ROSHAN Medical Center" },
      { property: "og:description", content: "Operational reports: visits, diagnoses, laboratory volume and revenue." },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  const { t, lang } = useLang();
  const { currency } = useSettings();
  const [from, setFrom] = useState(`${todayISO().slice(0, 7)}-01`);
  const [to, setTo] = useState(todayISO());

  const visits = useRows(["rep-visits", from, to], () =>
    supabase
      .from("visits")
      .select("id, visit_date, status, consultation_fee, departments(name, name_ar), users(full_name)")
      .gte("visit_date", from)
      .lte("visit_date", to)
      .is("deleted_at", null),
  );

  const labs = useRows(["rep-labs", from, to], () =>
    supabase
      .from("lab_order_items")
      .select("id, price, lab_tests(name, name_ar), lab_orders!inner(created_at)")
      .gte("lab_orders.created_at", from)
      .lte("lab_orders.created_at", `${to}T23:59:59`),
  );

  const diagnoses = useRows(["rep-dx", from, to], () =>
    supabase
      .from("medical_records")
      .select("id, diagnosis, created_at")
      .gte("created_at", from)
      .lte("created_at", `${to}T23:59:59`)
      .is("deleted_at", null),
  );

  const visitRows = (visits.data ?? []) as Row[];
  const labRows = (labs.data ?? []) as Row[];
  const dxRows = (diagnoses.data ?? []) as Row[];

  const byDepartment: Record<string, number> = {};
  for (const v of visitRows) {
    const dep = rel(v, "departments");
    const name = (lang === "ar" ? s(dep, "name_ar") || s(dep, "name") : s(dep, "name")) || t("none");
    byDepartment[name] = (byDepartment[name] ?? 0) + 1;
  }

  const byDoctor: Record<string, number> = {};
  for (const v of visitRows) {
    const name = s(rel(v, "users"), "full_name") || t("none");
    byDoctor[name] = (byDoctor[name] ?? 0) + 1;
  }

  const byTest: Record<string, number> = {};
  for (const l of labRows) {
    const test = rel(l, "lab_tests");
    const name = (lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")) || "—";
    byTest[name] = (byTest[name] ?? 0) + 1;
  }

  const byDiagnosis: Record<string, number> = {};
  for (const d of dxRows) {
    const key = s(d, "diagnosis").trim();
    if (!key) continue;
    byDiagnosis[key] = (byDiagnosis[key] ?? 0) + 1;
  }

  const consultRevenue = visitRows.reduce((sum, v) => sum + n(v, "consultation_fee"), 0);
  const labRevenue = labRows.reduce((sum, l) => sum + n(l, "price"), 0);

  if (visits.isLoading) return <Loading />;

  const rank = (map: Record<string, number>) =>
    Object.entries(map)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20);

  return (
    <div>
      <PageHeader title={t("reports")} subtitle={`${formatDate(from)} — ${formatDate(to)}`}>
        <Input type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} className="w-40" />
        <Input type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} className="w-40" />
        <ExportButtons rows={visitRows} filename={`roshan-visits-${from}-${to}`} />
      </PageHeader>

      <ErrorBox error={visits.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("visits")} value={String(visitRows.length)} />
        <StatCard label={t("laboratory")} value={String(labRows.length)} />
        <StatCard label={t("consultation_fee")} value={money(consultRevenue, currency)} />
        <StatCard label={t("lab_revenue")} value={money(labRevenue, currency)} />
      </div>

      <Tabs defaultValue="dept">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="dept">{t("department")}</TabsTrigger>
          <TabsTrigger value="doctor">{t("doctor")}</TabsTrigger>
          <TabsTrigger value="tests">{t("test")}</TabsTrigger>
          <TabsTrigger value="dx">{t("diagnosis")}</TabsTrigger>
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
                  <Table>
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
      </Tabs>
    </div>
  );
}
