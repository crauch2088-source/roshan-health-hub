import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import {
  DataPanel,
  Empty,
  ErrorBox,
  ExportButtons,
  Metric,
  MetricStrip,
  NoResults,
  PageHeader,
  PageSkeleton,
  PermissionGate,
  SearchField,
  StatusBadge,
  Toolbar,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  head: () => ({ meta: [{ title: "Laboratory — ROSHAN Medical Center" }] }),
  component: LabPage,
});

const STATUSES = ["all", "ordered", "sample_collected", "in_progress", "completed", "verified"];

function LabPage() {
  return (
    <PermissionGate perm="lab.read">
      <LabPageInner />
    </PermissionGate>
  );
}

function LabPageInner() {
  const { t, lang } = useLang();
  const labelOf = (key: string) => (t(key) === key ? key : t(key));
  const testNames = (o: Row) =>
    ((o["lab_order_items"] as Row[]) ?? [])
      .map((i) => {
        const test = rel(i, "lab_tests");
        return lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name");
      })
      .join(", ") || "—";
  const [status, setStatus] = useState("all");
  const [search, setSearch] = useState("");

  const orders = useRows<Row[]>(
    ["lab-orders", status],
    () => {
      let q = supabase
        .from("lab_orders")
        .select(
          "id,status,created_at,ordered_at,priority,visit_id,patients(id,full_name,mrn,phone),users!lab_orders_ordered_by_fkey(full_name),lab_order_items(id,status,price,lab_tests(id,name,name_ar))",
        )
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(300);
      if (status !== "all") q = q.eq("status", status);
      return q;
    },
    { refetchInterval: 15000, keepPrevious: true },
  );

  if (orders.isLoading) return <PageSkeleton />;
  const all = (orders.data ?? []) as Row[];
  const countOf = (...st: string[]) => all.filter((o) => st.includes(s(o, "status"))).length;
  const filtered = search.trim() !== "" || status !== "all";
  const rows = all.filter((o) => {
    const p = rel(o, "patients");
    const term = search.trim().toLowerCase();
    if (!term) return true;
    const tests = ((o["lab_order_items"] as Row[]) ?? [])
      .map((i) => {
        const t = rel(i, "lab_tests");
        return `${s(t, "name")} ${s(t, "name_ar")}`;
      })
      .join(" ");
    return `${s(p, "full_name")} ${s(p, "mrn")} ${s(p, "phone")} ${s(o, "id")} ${s(o, "visit_id")} ${tests}`
      .toLowerCase()
      .includes(term);
  });

  return (
    <div className="space-y-4">
      <PageHeader
        title={t("laboratory")}
        subtitle={
          lang === "ar" ? "قائمة المختبر وإدخال النتائج" : "Laboratory worklist and result entry"
        }
      >
        <ExportButtons rows={rows} filename="roshan-lab-orders" />
      </PageHeader>
      <ErrorBox error={orders.error} />
      <MetricStrip label={t("laboratory")} cols="sm:grid-cols-4">
        <Metric label={t("ordered")} value={countOf("ordered")} tone="warning" />
        <Metric label={t("sample_collected")} value={countOf("sample_collected")} />
        <Metric label={t("in_progress")} value={countOf("in_progress")} tone="primary" />
        <Metric label={t("completed")} value={countOf("completed", "verified")} tone="success" />
      </MetricStrip>
      <Toolbar>
        <SearchField
          value={search}
          onChange={setSearch}
          placeholder={lang === "ar" ? "المريض أو الفحص" : "Patient or test"}
        />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="h-11 w-full sm:w-48" aria-label={t("status")}>
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
      </Toolbar>
      <DataPanel>
        {rows.length === 0 && filtered ? (
          <NoResults
            onClear={() => {
              setSearch("");
              setStatus("all");
            }}
          />
        ) : rows.length === 0 ? (
          <Empty
            title={t("no_data")}
            description={lang === "ar" ? "لا طلبات تحاليل مطابقة." : "No matching lab orders."}
          />
        ) : (
          <>
            <ul className="divide-y md:hidden" aria-label={t("laboratory")}>
              {rows.map((o) => {
                const p = rel(o, "patients");
                return (
                  <li key={s(o, "id")}>
                    <Link
                      to="/lab/$orderId"
                      params={{ orderId: s(o, "id") }}
                      className="block space-y-1.5 p-3 outline-none hover:bg-muted/50 focus-visible:bg-muted/50 active:bg-muted"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate font-medium">{s(p, "full_name")}</p>
                          <p className="text-xs text-muted-foreground" dir="ltr">
                            {s(p, "mrn")}
                          </p>
                        </div>
                        <StatusBadge status={s(o, "status")} />
                      </div>
                      <p className="line-clamp-2 text-sm">{testNames(o)}</p>
                      <div className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
                        <span dir="ltr">{formatDateTime(s(o, "created_at"))}</span>
                        <span>{labelOf(s(o, "priority") || "normal")}</span>
                      </div>
                    </Link>
                  </li>
                );
              })}
            </ul>
            <div className="hidden overflow-x-auto md:block">
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("date")}</TableHead>
                    <TableHead>{t("patient")}</TableHead>
                    <TableHead>{t("test")}</TableHead>
                    <TableHead>{t("priority")}</TableHead>
                    <TableHead>{t("status")}</TableHead>
                    <TableHead className="text-end" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((o) => {
                    const p = rel(o, "patients");
                    return (
                      <TableRow key={s(o, "id")}>
                        <TableCell dir="ltr">{formatDateTime(s(o, "created_at"))}</TableCell>
                        <TableCell>
                          <div className="font-medium">{s(p, "full_name")}</div>
                          <div className="text-xs text-muted-foreground" dir="ltr">
                            {s(p, "mrn")}
                          </div>
                        </TableCell>
                        <TableCell className="max-w-[24rem]">{testNames(o)}</TableCell>
                        <TableCell>{labelOf(s(o, "priority") || "normal")}</TableCell>
                        <TableCell>
                          <StatusBadge status={s(o, "status")} />
                        </TableCell>
                        <TableCell className="text-end">
                          <Button asChild size="sm">
                            <Link to="/lab/$orderId" params={{ orderId: s(o, "id") }}>
                              {t("open")}
                            </Link>
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </>
        )}
      </DataPanel>
    </div>
  );
}
