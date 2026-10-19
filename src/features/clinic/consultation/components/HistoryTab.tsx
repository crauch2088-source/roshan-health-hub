import { Link } from "@tanstack/react-router";
import { Empty, ErrorBox, Loading, StatusBadge } from "@/components/kit";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { s, useRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export function HistoryTab({ visitId }: { visitId: string }) {
  const { lang } = useLang();
  const visitQ = useRows<Row[]>(["history-visit", visitId], () =>
    supabase.from("visits").select("patient_id").eq("id", visitId).limit(1),
  );
  const patientId = s((visitQ.data ?? [])[0], "patient_id");
  const visits = useRows<Row[]>(["history-visits", patientId], () =>
    supabase
      .from("visits")
      .select(
        "id,visit_number,visit_date,status,departments(name,name_ar),users!visits_doctor_id_fkey(full_name),diagnoses(diagnosis_name,is_primary)",
      )
      .eq("patient_id", patientId)
      .is("deleted_at", null)
      .neq("id", visitId)
      .order("visit_date", { ascending: false })
      .limit(30),
  );
  if (visitQ.error)
    return (
      <div role="alert" className="space-y-2">
        <ErrorBox error={visitQ.error} />
        <Button
          variant="outline"
          size="sm"
          onClick={() => void visitQ.refetch()}
        >
          {lang === "ar" ? "إعادة المحاولة" : "Retry patient history"}
        </Button>
      </div>
    );
  if (visitQ.isLoading) return <Loading />;
  if (visits.isLoading) return <Loading />;
  if (visits.error)
    return (
      <div role="alert" className="space-y-2">
        <ErrorBox error={visits.error} />
        <Button
          variant="outline"
          size="sm"
          onClick={() => void visits.refetch()}
        >
          {lang === "ar" ? "إعادة المحاولة" : "Retry previous visits"}
        </Button>
      </div>
    );
  const rows = (visits.data ?? []) as Row[];
  return (
    <div className="space-y-3">
      {rows.length === 0 ? (
        <Empty label={lang === "ar" ? "لا توجد زيارات سابقة" : "No previous visits"} />
      ) : (
        rows.map((v) => {
          const dept = rel(v, "departments");
          const ds = (v["diagnoses"] as Row[]) ?? [];
          return (
            <Card key={s(v, "id")}>
              <CardContent className="p-4">
                <div className="flex flex-wrap items-center gap-3">
                  <span className="font-mono text-xs">
                    {s(v, "visit_number") || s(v, "id").slice(0, 8)}
                  </span>
                  <span dir="ltr">{formatDate(s(v, "visit_date"))}</span>
                  <StatusBadge status={s(v, "status")} />
                  <span>
                    {lang === "ar" ? s(dept, "name_ar") || s(dept, "name") : s(dept, "name")}
                  </span>
                  <span className="text-muted-foreground">{s(rel(v, "users"), "full_name")}</span>
                  <Link
                    className="ms-auto text-primary underline"
                    to="/clinic/$visitId"
                    params={{ visitId: s(v, "id") }}
                  >
                    Open
                  </Link>
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {ds.map((d) => (
                    <span key={s(d, "id")} className="rounded-full bg-muted px-2 py-1 text-xs">
                      {s(d, "diagnosis_name")}
                    </span>
                  ))}
                </div>
              </CardContent>
            </Card>
          );
        })
      )}
    </div>
  );
}
function rel(row: Row | undefined, key: string): Row {
  const x = row?.[key];
  return (Array.isArray(x) ? x[0] : x) || {};
}
