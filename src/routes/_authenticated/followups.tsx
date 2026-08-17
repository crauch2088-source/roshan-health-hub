import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatusBadge } from "@/components/kit";
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
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/followups")({
  head: () => ({
    meta: [
      { title: "Follow-ups — ROSHAN Medical Center" },
      { name: "description", content: "Track scheduled patient follow-up visits and contact status." },
      { property: "og:title", content: "Follow-ups — ROSHAN Medical Center" },
      { property: "og:description", content: "Track scheduled patient follow-up visits and contact status." },
    ],
  }),
  component: FollowupsPage,
});

function FollowupsPage() {
  const { t } = useLang();
  const { can } = useAuth();
  const [from, setFrom] = useState(todayISO());
  const [to, setTo] = useState(todayISO());

  const list = useRows(["followups", from, to], () =>
    supabase
      .from("follow_ups")
      .select("*, patients(id, full_name, phone, patient_number), users(full_name)")
      .gte("follow_up_date", from)
      .lte("follow_up_date", to)
      .is("deleted_at", null)
      .order("follow_up_date", { ascending: true }),
  );

  const mark = useSave<{ id: string; status: string }>(
    async ({ id, status }) => {
      const { error } = await supabase.from("follow_ups").update({ status }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["followups", from, to]], successMessage: t("saved") },
  );

  const rows = (list.data ?? []) as Row[];
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("followups")} subtitle={`${formatDate(from)} — ${formatDate(to)}`}>
        <Input type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} className="w-40" />
        <Input type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} className="w-40" />
        <ExportButtons rows={rows} filename={`roshan-followups-${from}`} />
      </PageHeader>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("notes")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((f) => {
                  const p = rel(f, "patients");
                  const status = s(f, "status") || "pending";
                  return (
                    <TableRow key={s(f, "id")}>
                      <TableCell dir="ltr">{formatDate(s(f, "follow_up_date"))}</TableCell>
                      <TableCell className="font-medium">
                        {s(p, "id") ? (
                          <Link to="/patients/$patientId" params={{ patientId: s(p, "id") }} className="hover:underline">
                            {s(p, "full_name")}
                          </Link>
                        ) : (
                          "—"
                        )}
                      </TableCell>
                      <TableCell dir="ltr">{s(p, "phone") || "—"}</TableCell>
                      <TableCell>{s(rel(f, "users"), "full_name") || "—"}</TableCell>
                      <TableCell className="max-w-[16rem] truncate">{s(f, "notes") || "—"}</TableCell>
                      <TableCell>
                        <StatusBadge status={status} />
                      </TableCell>
                      <TableCell className="no-print text-end">
                        {can("visits.update") && status !== "completed" ? (
                          <Button size="sm" variant="outline" onClick={() => mark.mutate({ id: s(f, "id"), status: "completed" })}>
                            {t("mark_done")}
                          </Button>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
