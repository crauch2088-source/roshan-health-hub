import { createFileRoute, Link } from "@tanstack/react-router";
import { Search } from "lucide-react";
import { useState } from "react";
import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
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
  const { t, lang } = useLang();
  const [status, setStatus] = useState("all");
  const [search, setSearch] = useState("");

  const orders = useRows<Row[]>(["lab-orders", status], () => {
    let q = supabase.from("lab_orders")
      .select("id,status,created_at,ordered_at,priority,patients(id,full_name,mrn,patient_number),users!lab_orders_ordered_by_fkey(full_name),lab_order_items(id,status,price,lab_tests(id,name,name_ar))")
      .is("deleted_at", null).order("created_at", { ascending: false }).limit(300);
    if (status !== "all") q = q.eq("status", status);
    return q;
  }, { refetchInterval: 15000 });

  if (orders.isLoading) return <Loading />;
  const all = (orders.data ?? []) as Row[];
  const rows = all.filter((o) => {
    const p = rel(o, "patients");
    const term = search.trim().toLowerCase();
    if (!term) return true;
    const tests = ((o["lab_order_items"] as Row[]) ?? []).map((i) => { const t = rel(i,"lab_tests"); return `${s(t,"name")} ${s(t,"name_ar")}`; }).join(" ");
    return `${s(p,"full_name")} ${s(p,"mrn")} ${s(p,"patient_number")} ${tests}`.toLowerCase().includes(term);
  });

  return <div className="space-y-4">
    <PageHeader title={t("laboratory")} subtitle={lang === "ar" ? "قائمة المختبر وإدخال النتائج" : "Laboratory worklist and result entry"}>
      <div className="relative w-64"><Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"/><Input className="ps-9" value={search} onChange={(e)=>setSearch(e.target.value)} placeholder={lang==="ar"?"المريض أو الفحص":"Patient or test"}/></div>
      <Select value={status} onValueChange={setStatus}><SelectTrigger className="w-44"><SelectValue/></SelectTrigger><SelectContent>{STATUSES.map(x=><SelectItem key={x} value={x}>{x==="all"?(lang==="ar"?"الكل":"All"):x}</SelectItem>)}</SelectContent></Select>
      <ExportButtons rows={rows} filename="roshan-lab-orders"/>
    </PageHeader>
    <ErrorBox error={orders.error}/>
    <Card><CardContent className="p-0">{rows.length===0?<Empty/>:<div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>{t("date")}</TableHead><TableHead>{t("patient")}</TableHead><TableHead>{t("test")}</TableHead><TableHead>{t("priority")}</TableHead><TableHead>{t("status")}</TableHead><TableHead className="text-end"/></TableRow></TableHeader><TableBody>{rows.map(o=>{const p=rel(o,"patients");const items=(o["lab_order_items"] as Row[])??[];return <TableRow key={s(o,"id")}><TableCell dir="ltr">{formatDateTime(s(o,"created_at"))}</TableCell><TableCell><div className="font-medium">{s(p,"full_name")}</div><div className="text-xs text-muted-foreground" dir="ltr">{s(p,"mrn")||s(p,"patient_number")}</div></TableCell><TableCell className="max-w-[24rem]">{items.map(i=>{const test=rel(i,"lab_tests");return lang==="ar"?s(test,"name_ar")||s(test,"name"):s(test,"name")}).join(", ")||"—"}</TableCell><TableCell>{s(o,"priority")||"normal"}</TableCell><TableCell><StatusBadge status={s(o,"status")}/></TableCell><TableCell className="text-end"><Button asChild size="sm"><Link to="/lab/$orderId" params={{orderId:s(o,"id")}}>{t("open")}</Link></Button></TableCell></TableRow>})}</TableBody></Table></div>}</CardContent></Card>
  </div>;
}
