import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, StatCard } from "@/components/kit";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { n, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/accounting")({
  head: () => ({ meta: [{ title: "Accounting — ROSHAN Medical Center" }] }),
  component: AccountingPage,
});

function monthStart(date:string){ return `${date.slice(0,7)}-01`; }
function utcBoundary(date:string){ return new Date(`${date}T00:00:00+02:00`).toISOString(); }
function nextDay(date:string){ const d=new Date(`${date}T00:00:00+02:00`); d.setDate(d.getDate()+1); return d.toISOString(); }

function AccountingPage(){
  const { t, lang }=useLang();
  const { currency }=useSettings();
  const [from,setFrom]=useState(monthStart(todayISO()));
  const [to,setTo]=useState(todayISO());

  const payments=useRows<Row[]>(["acc-payments",from,to],()=>supabase.from("payments").select("id,invoice_id,amount,payment_method,method,payment_date,received_at,reference_no,reference").gte("payment_date",utcBoundary(from)).lt("payment_date",nextDay(to)).is("deleted_at",null).order("payment_date",{ascending:false}));
  const expenses=useRows<Row[]>(["acc-expenses",from,to],()=>supabase.from("expenses").select("id,amount,category,description,expense_date,payment_method,paid_to").gte("expense_date",from).lte("expense_date",to).is("deleted_at",null).order("expense_date",{ascending:false}));
  const invoices=useRows<Row[]>(["acc-invoices",from,to],()=>supabase.from("invoices").select("id,invoice_number,invoice_date,net_amount,paid_amount,status,patient_id,visit_id,invoice_items(item_type,item_name,total_price,quantity)").gte("invoice_date",from).lte("invoice_date",to).is("deleted_at",null).order("invoice_date",{ascending:false}));

  const payRows=(payments.data??[]) as Row[]; const expRows=(expenses.data??[]) as Row[]; const invRows=(invoices.data??[]) as Row[];
  const revenue=payRows.reduce((a,r)=>a+n(r,"amount"),0);
  const spend=expRows.reduce((a,r)=>a+n(r,"amount"),0);
  const billed=invRows.reduce((a,r)=>a+n(r,"net_amount"),0);
  const receivable=invRows.reduce((a,r)=>a+Math.max(n(r,"net_amount")-n(r,"paid_amount"),0),0);

  const byMethod=useMemo(()=>{const x:Record<string,number>={};for(const r of payRows){const m=s(r,"payment_method")||s(r,"method")||"cash";x[m]=(x[m]??0)+n(r,"amount");}return x;},[payRows]);
  const bySource=useMemo(()=>{const x:Record<string,number>={};for(const inv of invRows){for(const item of ((inv["invoice_items"] as Row[])??[])){const k=s(item,"item_type")||"other";x[k]=(x[k]??0)+n(item,"total_price");}}return x;},[invRows]);

  if(payments.isLoading||expenses.isLoading||invoices.isLoading) return <Loading/>;

  return <div className="space-y-4">
    <PageHeader title={t("accounting")} subtitle={lang==="ar"?"الإيراد المحصل والفواتير والمصروفات خلال الفترة":"Collected revenue, billing and expenses for the selected period"}>
      <Input type="date" dir="ltr" value={from} onChange={e=>setFrom(e.target.value)} className="w-40"/>
      <Input type="date" dir="ltr" value={to} onChange={e=>setTo(e.target.value)} className="w-40"/>
      <ExportButtons rows={payRows} filename={`roshan-revenue-${from}-${to}`}/>
    </PageHeader>
    <ErrorBox error={payments.error??expenses.error??invoices.error}/>
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label={lang==="ar"?"الإيرادات المحصلة":"Collected revenue"} value={money(revenue,currency)} tone="success"/>
      <StatCard label={lang==="ar"?"الفواتير":"Billed"} value={money(billed,currency)} tone="primary"/>
      <StatCard label={lang==="ar"?"المصروفات":"Expenses"} value={money(spend,currency)} tone="destructive"/>
      <StatCard label={lang==="ar"?"المستحقات":"Receivables"} value={money(receivable,currency)} tone="warning"/>
    </div>
    <Card><CardContent className="p-4"><div className="text-sm text-muted-foreground">{lang==="ar"?"صافي النقد":"Net cash result"}</div><div className="text-2xl font-bold">{money(revenue-spend,currency)}</div><p className="mt-1 text-xs text-muted-foreground">{lang==="ar"?"الإيراد هنا يعني المدفوعات المسجلة فعلياً، وليس قيمة الفواتير غير المدفوعة.":"Revenue is based on recorded payments, not unpaid invoice totals."}</p></CardContent></Card>
    <div className="grid gap-4 lg:grid-cols-2">
      <Card><CardContent className="p-4"><h3 className="mb-3 font-semibold">{lang==="ar"?"حسب طريقة الدفع":"By payment method"}</h3>{Object.keys(byMethod).length===0?<Empty/>:<div className="space-y-2">{Object.entries(byMethod).map(([k,v])=><div key={k} className="flex justify-between rounded border p-2"><span>{k==="cash"?(lang==="ar"?"نقداً":"Cash"):k==="bankak"?"Bankak":k}</span><span className="font-medium">{money(v,currency)}</span></div>)}</div>}</CardContent></Card>
      <Card><CardContent className="p-4"><h3 className="mb-3 font-semibold">{lang==="ar"?"الإيراد حسب مصدر الخدمة":"Billed by service source"}</h3>{Object.keys(bySource).length===0?<Empty/>:<div className="space-y-2">{Object.entries(bySource).map(([k,v])=><div key={k} className="flex justify-between rounded border p-2"><span>{k}</span><span>{money(v,currency)}</span></div>)}</div>}</CardContent></Card>
    </div>
    <Card><CardContent className="p-0"><div className="p-4 font-semibold">{lang==="ar"?"المدفوعات":"Payments"}</div>{payRows.length===0?<Empty/>:<div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>{t("date")}</TableHead><TableHead>{t("amount")}</TableHead><TableHead>{lang==="ar"?"الطريقة":"Method"}</TableHead><TableHead>{lang==="ar"?"المرجع":"Reference"}</TableHead></TableRow></TableHeader><TableBody>{payRows.map(p=><TableRow key={s(p,"id")}><TableCell dir="ltr">{new Date(s(p,"payment_date")||s(p,"received_at")).toLocaleString()}</TableCell><TableCell>{money(n(p,"amount"),currency)}</TableCell><TableCell>{s(p,"payment_method")||s(p,"method")||"cash"}</TableCell><TableCell dir="ltr">{s(p,"reference_no")||s(p,"reference")||"—"}</TableCell></TableRow>)}</TableBody></Table></div>}</CardContent></Card>
    <Card><CardContent className="p-0"><div className="p-4 font-semibold">{t("expenses")}</div>{expRows.length===0?<Empty/>:<div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>{t("date")}</TableHead><TableHead>{t("category")}</TableHead><TableHead>{t("amount")}</TableHead></TableRow></TableHeader><TableBody>{expRows.slice(0,50).map(e=><TableRow key={s(e,"id")}><TableCell dir="ltr">{formatDate(s(e,"expense_date"))}</TableCell><TableCell>{s(e,"category")||"—"}</TableCell><TableCell>{money(n(e,"amount"),currency)}</TableCell></TableRow>)}</TableBody></Table></div>}</CardContent></Card>
  </div>;
}
