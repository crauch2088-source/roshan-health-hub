import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, Loading, PageHeader, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
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
import { useAuth } from "@/lib/auth";
import { rel, s, useRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/clinic")({
  head: () => ({
    meta: [
      { title: "Clinic — ROSHAN Medical Center" },
      { name: "description", content: "Doctor worklist: today's patients, consultations and clinical records." },
      { property: "og:title", content: "Clinic — ROSHAN Medical Center" },
      { property: "og:description", content: "Doctor worklist: today's patients, consultations and clinical records." },
    ],
  }),
  component: ClinicPage,
});

function ClinicPage() {
  const { t, lang } = useLang();
  const { user } = useAuth();
  const [date, setDate] = useState(todayISO());
  const [mine, setMine] = useState(true);

  const visits = useRows(
    ["clinic-visits", date, mine ? s(user ?? {}, "id") : "all"],
    () => {
      let q = supabase
        .from("visits")
        .select(
          "id, visit_number, status, visit_date, patients(id, full_name, mrn, gender, date_of_birth), departments(name, name_ar), users(full_name)",
        )
        .eq("visit_date", date)
        .is("deleted_at", null)
        .order("visit_number", { ascending: true });
      if (mine && user?.id) q = q.eq("doctor_id", user.id);
      return q;
    },
    { refetchInterval: 20000 },
  );

  const rows = (visits.data ?? []) as Row[];
  if (visits.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("clinic")} subtitle={formatDate(date)}>
        <Input type="date" dir="ltr" value={date} onChange={(e) => setDate(e.target.value)} className="w-40" />
        <Button variant={mine ? "default" : "outline"} size="sm" onClick={() => setMine(!mine)}>
          {mine ? t("my_patients") : t("all")}
        </Button>
      </PageHeader>

      <ErrorBox error={visits.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("queue_number")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("age")}</TableHead>
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((v) => (
                  <TableRow key={s(v, "id")}>
                    <TableCell dir="ltr" className="font-mono text-xs">
                      {s(v, "visit_number") || "—"}
                    </TableCell>
                    <TableCell className="font-medium">
                      {s(rel(v, "patients"), "full_name")}
                      <span className="ms-2 text-xs text-muted-foreground" dir="ltr">
                        {s(rel(v, "patients"), "mrn")}
                      </span>
                    </TableCell>
                    <TableCell>{calcAge(s(rel(v, "patients"), "date_of_birth")) ?? "—"}</TableCell>
                    <TableCell>
                      {lang === "ar"
                        ? s(rel(v, "departments"), "name_ar") || s(rel(v, "departments"), "name")
                        : s(rel(v, "departments"), "name")}
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={s(v, "status")} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      <Button asChild size="sm">
                        <Link to="/clinic/$visitId" params={{ visitId: s(v, "id") }}>
                          {t("open")}
                        </Link>
                      </Button>
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
