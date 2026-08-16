import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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

export const Route = createFileRoute("/_authenticated/lab")({
  head: () => ({
    meta: [
      { title: "Laboratory — ROSHAN Medical Center" },
      { name: "description", content: "Laboratory worklist: sample collection, result entry and verification." },
      { property: "og:title", content: "Laboratory — ROSHAN Medical Center" },
      { property: "og:description", content: "Laboratory worklist: sample collection, result entry and verification." },
    ],
  }),
  component: LabPage,
});

const STATUSES = ["all", "ordered", "sample_collected", "in_progress", "completed", "verified"];

function LabPage() {
  const { t, lang } = useLang();
  const [status, setStatus] = useState("all");

  const orders = useRows(
    ["lab-orders", status],
    () => {
      let q = supabase
        .from("lab_orders")
        .select(
          "id, status, created_at, patients(full_name, mrn), users(full_name), lab_order_items(id, lab_tests(name, name_ar))",
        )
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(300);
      if (status !== "all") q = q.eq("status", status);
      return q;
    },
    { refetchInterval: 20000 },
  );

  const rows = (orders.data ?? []) as Row[];
  if (orders.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("laboratory")} subtitle={t("lab_worklist")}>
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUSES.map((x) => (
              <SelectItem key={x} value={x}>
                {t(x)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <ExportButtons rows={rows} filename="roshan-lab-orders" />
      </PageHeader>

      <ErrorBox error={orders.error} />

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
                  <TableHead>{t("test")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((o) => (
                  <TableRow key={s(o, "id")}>
                    <TableCell dir="ltr">{formatDateTime(s(o, "created_at"))}</TableCell>
                    <TableCell className="font-medium">
                      {s(rel(o, "patients"), "full_name")}
                      <span className="ms-2 text-xs text-muted-foreground" dir="ltr">
                        {s(rel(o, "patients"), "mrn")}
                      </span>
                    </TableCell>
                    <TableCell className="max-w-[22rem] truncate">
                      {((o["lab_order_items"] as Row[]) ?? [])
                        .map((i) =>
                          lang === "ar"
                            ? s(rel(i, "lab_tests"), "name_ar") || s(rel(i, "lab_tests"), "name")
                            : s(rel(i, "lab_tests"), "name"),
                        )
                        .join(", ") || "—"}
                    </TableCell>
                    <TableCell>{s(rel(o, "users"), "full_name") || "—"}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(o, "status")} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      <Button asChild size="sm">
                        <Link to="/lab/$orderId" params={{ orderId: s(o, "id") }}>
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
