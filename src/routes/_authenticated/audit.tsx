import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader } from "@/components/kit";
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
import { rel, s, useRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDateTime } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/audit")({
  head: () => ({
    meta: [
      { title: "Audit Log — ROSHAN Medical Center" },
      { name: "description", content: "Traceable record of system actions by user, table and time." },
      { property: "og:title", content: "Audit Log — ROSHAN Medical Center" },
      { property: "og:description", content: "Traceable record of system actions by user, table and time." },
    ],
  }),
  component: AuditPage,
});

function AuditPage() {
  const { t } = useLang();
  const [q, setQ] = useState("");

  const list = useRows(["audit"], () =>
    supabase
      .from("audit_logs")
      .select("*, users(full_name)")
      .order("created_at", { ascending: false })
      .limit(300),
  );

  const rows = ((list.data ?? []) as Row[]).filter((r) => {
    if (!q) return true;
    const hay = `${s(r, "action")} ${s(r, "table_name")} ${s(rel(r, "users"), "full_name")}`.toLowerCase();
    return hay.includes(q.toLowerCase());
  });

  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("audit_log")} subtitle={t("recent_activity")}>
        <Input placeholder={t("search")} value={q} onChange={(e) => setQ(e.target.value)} className="w-56" />
        <ExportButtons rows={rows} filename="roshan-audit" />
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
                  <TableHead>{t("user")}</TableHead>
                  <TableHead>{t("action")}</TableHead>
                  <TableHead>{t("table")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={s(r, "id")}>
                    <TableCell dir="ltr">{formatDateTime(s(r, "created_at"))}</TableCell>
                    <TableCell>{s(rel(r, "users"), "full_name") || "—"}</TableCell>
                    <TableCell>{s(r, "action")}</TableCell>
                    <TableCell dir="ltr">{s(r, "table_name")}</TableCell>
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
