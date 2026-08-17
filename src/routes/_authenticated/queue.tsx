import { createFileRoute } from "@tanstack/react-router";

import { Empty, ErrorBox, Loading, PageHeader, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
import { formatDate, formatDateTime, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/queue")({
  head: () => ({
    meta: [
      { title: "Live queue — ROSHAN Medical Center" },
      { name: "description", content: "Live waiting queue with call-next and in-progress tracking." },
      { property: "og:title", content: "Live queue — ROSHAN Medical Center" },
      { property: "og:description", content: "Live waiting queue with call-next and in-progress tracking." },
    ],
  }),
  component: QueuePage,
});

function QueuePage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const date = todayISO();

  const queue = useRows(
    ["queue", date],
    () =>
      supabase
        .from("queue_tickets")
        .select(
          "id, queue_number, status, created_at, called_at, visit_id, patients(full_name, mrn), departments(name, name_ar)",
        )
        .eq("visit_date", date)
        .order("queue_number", { ascending: true }),
    { refetchInterval: 15000 },
  );

  const setStatus = useSave<{ id: string; visitId: string; status: string }>(
    async ({ id, visitId, status }) => {
      const patch: Row = { status };
      if (status === "called") patch["called_at"] = new Date().toISOString();
      const { error } = await supabase.from("queue_tickets").update(patch).eq("id", id);
      if (error) throw new Error(error.message);
      const visitStatus =
        status === "called" ? "in_consultation" : status === "done" ? "completed" : "waiting";
      if (visitId) await supabase.from("visits").update({ status: visitStatus }).eq("id", visitId);
      return null;
    },
    { invalidate: [["queue", date], ["visits", date]], successMessage: t("saved") },
  );

  const rows = (queue.data ?? []) as Row[];
  if (queue.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("queue")} subtitle={formatDate(date)} />
      <ErrorBox error={queue.error} />
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
                  <TableHead>{t("department")}</TableHead>
                  <TableHead>{t("time")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((q) => (
                  <TableRow key={s(q, "id")}>
                    <TableCell dir="ltr" className="font-mono text-base font-semibold">
                      {s(q, "queue_number")}
                    </TableCell>
                    <TableCell className="font-medium">
                      {s(rel(q, "patients"), "full_name")}
                      <span className="ms-2 text-xs text-muted-foreground" dir="ltr">
                        {s(rel(q, "patients"), "mrn")}
                      </span>
                    </TableCell>
                    <TableCell>
                      {lang === "ar"
                        ? s(rel(q, "departments"), "name_ar") || s(rel(q, "departments"), "name")
                        : s(rel(q, "departments"), "name")}
                    </TableCell>
                    <TableCell dir="ltr">{formatDateTime(s(q, "created_at"))}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(q, "status")} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      {can("queue.update") ? (
                        <div className="flex justify-end gap-1">
                          <Button
                            size="sm"
                            variant="outline"
                            disabled={setStatus.isPending}
                            onClick={() =>
                              setStatus.mutate({
                                id: s(q, "id"),
                                visitId: s(q, "visit_id"),
                                status: "called",
                              })
                            }
                          >
                            {t("call_next")}
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={setStatus.isPending}
                            onClick={() =>
                              setStatus.mutate({
                                id: s(q, "id"),
                                visitId: s(q, "visit_id"),
                                status: "done",
                              })
                            }
                          >
                            {t("done")}
                          </Button>
                        </div>
                      ) : null}
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
