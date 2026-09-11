import { createFileRoute, Link } from "@tanstack/react-router";
import { Check, Clock3, Play, Search, UserRound } from "lucide-react";
import { useState } from "react";
import { Empty, ErrorBox, Loading, PageHeader, StatusBadge, PermissionGate } from "@/components/kit";
import { Button, buttonVariants } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { s, rel, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

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

  const queue = useRows<Row[]>(["queue", date, status], () => {
    let q = supabase.from("queue_tickets")
      .select("id,visit_id,queue_number,status,created_at,called_at,completed_at,visits(id,visit_number,patient_id,department_id,status,consultation_fee,patients(id,full_name,mrn),departments(id,name,name_ar),users!visits_doctor_id_fkey(full_name))")
      .eq("visit_date", date).is("deleted_at", null).order("created_at", { ascending: true });
    if (status !== "all") q = q.eq("status", status);
    return q;
  }, { refetchInterval: 10000 });

  const update = useSave<{ id: string; status: string }>(
    async ({ id, status }) => {
      if (!canUpdate) throw new Error("Not authorized");
      const patch: Row = { status };
      if (status === "called") patch["called_at"] = new Date().toISOString();
      if (status === "completed") patch["completed_at"] = new Date().toISOString();
      const { error } = await supabase.from("queue_tickets").update(patch).eq("id", id);
      if (error) throw new Error(error.message);
      const ticket = ((queue.data ?? []) as Row[]).find((r) => s(r, "id") === id);
      const visitId = s(ticket, "visit_id") || s(rel(ticket, "visits"), "id");
      if (visitId) {
        const visitStatus = status === "called" ? "in_progress" : status === "completed" ? "completed" : status === "cancelled" ? "cancelled" : "waiting";
        await supabase.from("visits").update({ status: visitStatus }).eq("id", visitId);
      }
      return null;
    },
    { invalidate: [["queue", date, status], ["visits", date]], successMessage: t("saved") },
  );

  if (queue.isLoading) return <Loading />;
  const rows = ((queue.data ?? []) as Row[]).filter((ticket) => {
    const patient = rel(rel(ticket, "visits"), "patients");
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return [s(patient, "full_name"), s(patient, "mrn"), s(ticket, "queue_number")].some((x) => x.toLowerCase().includes(q));
  });

  const waiting = rows.filter((r) => s(r, "status") === "waiting").length;
  const active = rows.filter((r) => ["called","in_progress"].includes(s(r, "status"))).length;

  return <div className="space-y-4">
    <PageHeader title={lang === "ar" ? "الطابور" : "Queue"} subtitle={lang === "ar" ? "إدارة انتظار المرضى والنداء والانتقال للعيادة" : "Live patient queue and clinic flow"}>
      <Input type="date" dir="ltr" className="w-40" value={date} onChange={(e) => setDate(e.target.value)} />
      <div className="relative w-56"><Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"/><Input className="ps-9" value={search} onChange={(e)=>setSearch(e.target.value)} placeholder={lang==="ar"?"ابحث عن المريض أو رقم الطابور":"Search patient or queue #"}/></div>
      <Select value={status} onValueChange={setStatus}><SelectTrigger className="w-40"><SelectValue/></SelectTrigger><SelectContent>{STATUSES.map(x=><SelectItem key={x} value={x}>{x==="all"?(lang==="ar"?"الكل":"All"):x}</SelectItem>)}</SelectContent></Select>
    </PageHeader>
    <ErrorBox error={queue.error}/>
    <div className="grid gap-3 sm:grid-cols-2"><Card><CardContent className="p-4"><div className="text-sm text-muted-foreground">{lang==="ar"?"بانتظار النداء":"Waiting"}</div><div className="text-3xl font-bold">{waiting}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-sm text-muted-foreground">{lang==="ar"?"نشط":"Active"}</div><div className="text-3xl font-bold">{active}</div></CardContent></Card></div>
     <Card><CardContent className="p-0">{rows.length===0?<Empty title={t("no_data")} description={lang==="ar"?"الطابور فارغ حالياً.":"The queue is empty right now."}/>:<div className="overflow-x-auto"><Table density="compact"><TableHeader><TableRow><TableHead>#</TableHead><TableHead>{t("patient")}</TableHead><TableHead>{t("department")}</TableHead><TableHead>{t("doctor")}</TableHead><TableHead>{t("status")}</TableHead><TableHead className="text-end">{t("actions")}</TableHead></TableRow></TableHeader><TableBody>{rows.map(ticket=>{const visit=rel(ticket,"visits");const patient=rel(visit,"patients");const dept=rel(visit,"departments");const doctor=rel(visit,"users");const st=s(ticket,"status");return <TableRow key={s(ticket,"id")}><TableCell dir="ltr" className="font-mono font-bold">{s(ticket,"queue_number")}</TableCell><TableCell><div className="flex items-center gap-2"><UserRound className="size-4 text-muted-foreground"/><div><div className="font-medium">{s(patient,"full_name")}</div><div className="text-xs text-muted-foreground" dir="ltr">{s(patient,"mrn")}</div></div></div></TableCell><TableCell>{lang==="ar"?s(dept,"name_ar")||s(dept,"name"):s(dept,"name")}</TableCell><TableCell>{s(doctor,"full_name")||"—"}</TableCell><TableCell><StatusBadge status={st}/></TableCell><TableCell className="text-end"><div className="flex justify-end gap-1">{canUpdate&&st==="waiting"&&<Button size="sm" variant="outline" onClick={()=>update.mutate({id:s(ticket,"id"),status:"called"})}><Play className="size-4"/>{lang==="ar"?"نداء":"Call"}</Button>}{canUpdate&&st==="called"&&<Button size="sm" onClick={()=>update.mutate({id:s(ticket,"id"),status:"in_progress"})}><Clock3 className="size-4"/>{lang==="ar"?"بدء":"Start"}</Button>}{canUpdate&&st==="in_progress"&&<Button size="sm" onClick={()=>update.mutate({id:s(ticket,"id"),status:"completed"})}><Check className="size-4"/>{lang==="ar"?"إنهاء":"Complete"}</Button>}<Link to="/clinic/$visitId" params={{visitId:s(visit,"id")}} className={buttonVariants({variant:"ghost",size:"sm"})}>{t("clinic")}</Link></div></TableCell></TableRow>})}</TableBody></Table></div>}</CardContent></Card>
  </div>;
}
