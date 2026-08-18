import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";

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
import { s, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, formatDateTime, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/queue")({
  head: () => ({
    meta: [
      { title: "Live queue — ROSHAN Medical Center" },
      { name: "description", content: "Live waiting queue." },
    ],
  }),
  component: QueuePage,
});

function QueuePage() {
  const { t } = useLang();
  const { can } = useAuth();
  const date = todayISO();

  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<any>(null);

  // جلب البيانات مباشرة عبر جافاسكريبت متجاوزين أي كاش قديم
  const fetchQueue = async () => {
    try {
      setLoading(true);
      const { data, error: fetchError } = await supabase
        .from("queue_tickets")
        .select("id, queue_number, status, created_at, visit_id, visit_date")
        .order("created_at", { ascending: false })
        .limit(50);

      if (fetchError) throw fetchError;
      setRows(data || []);
    } catch (err: any) {
      setError(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchQueue();
    // تحديث تلقائي كل 5 ثوانٍ
    const interval = setInterval(fetchQueue, 5000);
    return () => clearInterval(interval);
  }, []);

  const updateStatus = async (id: string, visitId: string, status: string) => {
    try {
      const patch: Row = { status };
      if (status === "called") patch["called_at"] = new Date().toISOString();

      const { error: updateError } = await supabase.from("queue_tickets").update(patch).eq("id", id);
      if (updateError) throw updateError;

      const visitStatus = status === "called" ? "in_consultation" : status === "done" ? "completed" : "waiting";
      if (visitId) {
        await supabase.from("visits").update({ status: visitStatus }).eq("id", visitId);
      }

      // إعادة الجلب فوراً لتحديث الواجهة
      fetchQueue();
    } catch (err: any) {
      alert(`خطأ أثناء التحديث: ${err.message}`);
    }
  };

  if (loading && rows.length === 0) return <Loading />;

  return (
    <div>
      <PageHeader title={t("queue")} subtitle={formatDate(date)} />
      <ErrorBox error={error} />
      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("queue_number")}</TableHead>
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
                            onClick={() => updateStatus(s(q, "id"), s(q, "visit_id"), "called")}
                          >
                            {t("call_next")}
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => updateStatus(s(q, "id"), s(q, "visit_id"), "done")}
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
