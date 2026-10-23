import { createFileRoute, Link } from "@tanstack/react-router";
import { Check, Clock3, Play } from "lucide-react";
import { useState } from "react";
import {
  DataPanel,
  Empty,
  ErrorBox,
  InitialAvatar,
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
import { Button, buttonVariants } from "@/components/ui/button";
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
import { useAuth } from "@/lib/auth";
import { s, rel, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { useBranchRealtime } from "@/lib/realtime";

export const Route = createFileRoute("/_authenticated/queue")({
  head: () => ({ meta: [{ title: "Queue — ROSHAN Medical Center" }] }),
  component: QueuePage,
});

const STATUSES = ["all", "waiting", "called", "in_progress", "completed", "cancelled"];

function QueuePage() {
  return (
    <PermissionGate perm="queue.read">
      <QueuePageInner />
    </PermissionGate>
  );
}

function QueuePageInner() {
  const { lang, t } = useLang();
  const { can } = useAuth();
  const canUpdate = can("visits.update");
  const [date, setDate] = useState(todayISO());
  const [status, setStatus] = useState("all");
  const [search, setSearch] = useState("");

  const queueMetrics = useRows<{
    total: number;
    waiting: number;
    active: number;
    completed: number;
  }>(
    ["queue", date, "metrics"],
    async () => {
      const countQuery = () =>
        supabase
          .from("queue_tickets")
          .select("id", { count: "exact", head: true })
          .eq("visit_date", date)
          .is("deleted_at", null);
      const [total, waiting, active, completed] = await Promise.all([
        countQuery(),
        countQuery().eq("status", "waiting"),
        countQuery().in("status", ["called", "in_progress"]),
        countQuery().eq("status", "completed"),
      ]);
      const failed = [total, waiting, active, completed].find((result) => result.error);
      return {
        data: failed
          ? null
          : {
              total: total.count ?? 0,
              waiting: waiting.count ?? 0,
              active: active.count ?? 0,
              completed: completed.count ?? 0,
            },
        error: failed?.error ?? null,
      };
    },
    { refetchInterval: 10000 },
  );

  const queue = useRows<Row[]>(
    ["queue", date, status],
    () => {
      let q = supabase
        .from("queue_tickets")
        .select(
          "id,branch_id,visit_id,queue_number,status,created_at,called_at,completed_at,visits(id,branch_id,visit_number,patient_id,department_id,status,consultation_fee,patients(id,full_name,mrn),departments(id,name,name_ar),users!visits_doctor_id_fkey(full_name))",
        )
        .eq("visit_date", date)
        .is("deleted_at", null)
        .order("created_at", { ascending: true });
      if (status !== "all") q = q.eq("status", status);
      return q;
    },
    { refetchInterval: 10000 },
  );

  const realtimeRow = (queue.data ?? [])[0] as Row | undefined;
  const realtimeBranchId =
    s(realtimeRow, "branch_id") || s(rel(realtimeRow, "visits"), "branch_id") || null;
  useBranchRealtime(realtimeBranchId);

  const update = useSave<{ id: string; status: string }>(
    async ({ id, status }) => {
      if (!canUpdate) throw new Error("Not authorized");
      const ticket = ((queue.data ?? []) as Row[]).find((r) => s(r, "id") === id);
      const visitId = s(ticket, "visit_id") || s(rel(ticket, "visits"), "id");
      if (status === "completed" && visitId) {
        const { error: visitError } = await supabase.rpc("complete_visit_atomic", {
          p_visit_id: visitId,
        });
        if (visitError) throw new Error(visitError.message);
        // The RPC atomically completes the visit and its queue tickets. Avoid a
        // second browser write that could replace the server timestamp or fail
        // after the visit has already committed.
        return null;
      } else if (visitId) {
        const visitStatus =
          status === "called" ? "in_progress" : status === "cancelled" ? "cancelled" : "waiting";
        const { error: visitError } = await supabase
          .from("visits")
          .update({ status: visitStatus })
          .eq("id", visitId);
        if (visitError) throw new Error(visitError.message);
      }
      const patch: Row = { status };
      if (status === "called") patch["called_at"] = new Date().toISOString();
      if (status === "completed") patch["completed_at"] = new Date().toISOString();
      const { error: ticketError } = await supabase
        .from("queue_tickets")
        .update(patch)
        .eq("id", id);
      if (ticketError) throw new Error(ticketError.message);
      return null;
    },
    {
      invalidate: [
        ["queue", date],
        ["visits", date],
      ],
      successMessage: t("saved"),
    },
  );

  if (queue.isLoading || queueMetrics.isLoading) return <PageSkeleton />;
  const rows = ((queue.data ?? []) as Row[]).filter((ticket) => {
    const patient = rel(rel(ticket, "visits"), "patients");
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return [s(patient, "full_name"), s(patient, "mrn"), s(ticket, "queue_number")].some((x) =>
      x.toLowerCase().includes(q),
    );
  });

  const waiting = queueMetrics.data?.waiting ?? "—";
  const active = queueMetrics.data?.active ?? "—";
  const done = queueMetrics.data?.completed ?? "—";
  const total = queueMetrics.data?.total ?? "—";
  const filtered = search.trim() !== "" || status !== "all";

  return (
    <div className="space-y-4">
      <PageHeader
        title={lang === "ar" ? "الطابور" : "Queue"}
        subtitle={
          lang === "ar"
            ? "إدارة انتظار المرضى والنداء والانتقال للعيادة"
            : "Live patient queue and clinic flow"
        }
      >
        <Input
          type="date"
          dir="ltr"
          aria-label={t("date")}
          className="h-11 w-full sm:w-40"
          value={date}
          onChange={(e) => setDate(e.target.value)}
        />
      </PageHeader>
      <ErrorBox error={queue.error ?? queueMetrics.error} />
      <MetricStrip label={lang === "ar" ? "ملخص الطابور" : "Queue summary"} cols="sm:grid-cols-4">
        <Metric
          label={lang === "ar" ? "بانتظار النداء" : "Waiting"}
          value={waiting}
          tone={typeof waiting === "number" && waiting > 0 ? "warning" : "default"}
        />
        <Metric label={lang === "ar" ? "نشط" : "Active"} value={active} tone="primary" />
        <Metric label={t("completed")} value={done} tone="success" />
        <Metric label={lang === "ar" ? "الإجمالي" : "Total"} value={total} />
      </MetricStrip>
      <Toolbar>
        <SearchField
          value={search}
          onChange={setSearch}
          placeholder={
            lang === "ar" ? "ابحث عن المريض أو رقم الطابور" : "Search patient or queue #"
          }
        />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="h-11 w-full sm:w-44" aria-label={t("status")}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUSES.map((x) => (
              <SelectItem key={x} value={x}>
                {x === "all" ? (lang === "ar" ? "الكل" : "All") : t(x)}
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
            description={lang === "ar" ? "الطابور فارغ حالياً." : "The queue is empty right now."}
          />
        ) : (
          <>
            <ul className="divide-y md:hidden" aria-label={t("queue")}>
              {rows.map((ticket) => {
                const visit = rel(ticket, "visits");
                const patient = rel(visit, "patients");
                const dept = rel(visit, "departments");
                const doctor = rel(visit, "users");
                const st = s(ticket, "status");
                return (
                  <li key={s(ticket, "id")} className="space-y-2 px-4 py-3">
                    <div className="flex items-start gap-3">
                      <span
                        className="min-w-12 rounded-lg bg-muted px-2 py-1 text-center font-mono text-lg font-extrabold"
                        dir="ltr"
                      >
                        {s(ticket, "queue_number")}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="break-words font-semibold">{s(patient, "full_name")}</p>
                        <p className="text-xs text-muted-foreground" dir="ltr">
                          {s(patient, "mrn")}
                        </p>
                        <p className="mt-0.5 text-xs text-muted-foreground">
                          {lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")}
                          {" · "}
                          {s(doctor, "full_name") || "—"}
                        </p>
                      </div>
                      <StatusBadge status={st} />
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      {canUpdate && st === "waiting" && (
                        <Button
                          size="sm"
                          variant="outline"
                          className="min-h-10 flex-1"
                          onClick={() => update.mutate({ id: s(ticket, "id"), status: "called" })}
                        >
                          <Play className="size-4" />
                          {lang === "ar" ? "نداء" : "Call"}
                        </Button>
                      )}
                      {canUpdate && st === "called" && (
                        <Button
                          size="sm"
                          className="min-h-10 flex-1"
                          onClick={() =>
                            update.mutate({ id: s(ticket, "id"), status: "in_progress" })
                          }
                        >
                          <Clock3 className="size-4" />
                          {lang === "ar" ? "بدء" : "Start"}
                        </Button>
                      )}
                      {canUpdate && st === "in_progress" && (
                        <Button
                          size="sm"
                          className="min-h-10 flex-1"
                          onClick={() =>
                            update.mutate({ id: s(ticket, "id"), status: "completed" })
                          }
                        >
                          <Check className="size-4" />
                          {lang === "ar" ? "إنهاء" : "Complete"}
                        </Button>
                      )}
                      {can("visits.read") && s(visit, "id") ? (
                        <Link
                          to="/clinic/$visitId"
                          params={{ visitId: s(visit, "id") }}
                          className={buttonVariants({
                            variant: "outline",
                            size: "sm",
                            className: "min-h-10 flex-1",
                          })}
                        >
                          {lang === "ar" ? "فتح العيادة" : "Clinic"}
                        </Link>
                      ) : null}
                    </div>
                  </li>
                );
              })}
            </ul>
            <div className="hidden overflow-x-auto md:block">
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>#</TableHead>
                    <TableHead>{t("patient")}</TableHead>
                    <TableHead>{t("department")}</TableHead>
                    <TableHead>{t("doctor")}</TableHead>
                    <TableHead>{t("status")}</TableHead>
                    <TableHead className="text-end">{t("actions")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((ticket) => {
                    const visit = rel(ticket, "visits");
                    const patient = rel(visit, "patients");
                    const dept = rel(visit, "departments");
                    const doctor = rel(visit, "users");
                    const st = s(ticket, "status");
                    return (
                      <TableRow key={s(ticket, "id")}>
                        <TableCell dir="ltr" className="font-mono font-bold">
                          {s(ticket, "queue_number")}
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center gap-2">
                            <InitialAvatar name={s(patient, "full_name")} />
                            <div>
                              <div className="font-medium">{s(patient, "full_name")}</div>
                              <div className="text-xs text-muted-foreground" dir="ltr">
                                {s(patient, "mrn")}
                              </div>
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          {lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")}
                        </TableCell>
                        <TableCell>{s(doctor, "full_name") || "—"}</TableCell>
                        <TableCell>
                          <StatusBadge status={st} />
                        </TableCell>
                        <TableCell className="text-end">
                          <div className="flex justify-end gap-1">
                            {canUpdate && st === "waiting" && (
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() =>
                                  update.mutate({ id: s(ticket, "id"), status: "called" })
                                }
                              >
                                <Play className="size-4" />
                                {lang === "ar" ? "نداء" : "Call"}
                              </Button>
                            )}
                            {canUpdate && st === "called" && (
                              <Button
                                size="sm"
                                onClick={() =>
                                  update.mutate({ id: s(ticket, "id"), status: "in_progress" })
                                }
                              >
                                <Clock3 className="size-4" />
                                {lang === "ar" ? "بدء" : "Start"}
                              </Button>
                            )}
                            {canUpdate && st === "in_progress" && (
                              <Button
                                size="sm"
                                onClick={() =>
                                  update.mutate({ id: s(ticket, "id"), status: "completed" })
                                }
                              >
                                <Check className="size-4" />
                                {lang === "ar" ? "إنهاء" : "Complete"}
                              </Button>
                            )}
                            {can("visits.read") && s(visit, "id") ? (
                              <Link
                                to="/clinic/$visitId"
                                params={{ visitId: s(visit, "id") }}
                                className={buttonVariants({ variant: "ghost", size: "sm" })}
                              >
                                {lang === "ar" ? "فتح العيادة" : "Clinic"}
                              </Link>
                            ) : null}
                          </div>
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
