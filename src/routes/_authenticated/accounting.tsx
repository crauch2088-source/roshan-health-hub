import { createFileRoute } from "@tanstack/react-router";
import { ArrowDownToLine, ArrowUpFromLine, Landmark, Plus, ReceiptText, RefreshCw, Search, Truck, Users } from "lucide-react";
import { useMemo, useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader, StatCard } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { n, rpc, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/accounting")({
  head: () => ({ meta: [{ title: "Finance — ROSHAN Medical Center" }] }),
  component: AccountingPage,
});

type Tab = "overview" | "cashbox" | "receivables" | "suppliers";

function AccountingPage() {
  const { t } = useLang();
  const { currency } = useSettings();
  const { can } = useAuth();
  const [tab, setTab] = useState<Tab>("overview");

  if (!can("accounting.read")) {
    return <Card><CardContent className="p-6">{t("no_permission")}</CardContent></Card>;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={t("finance_hub")} subtitle={t("finance_hub_subtitle")}>
        <Button variant="outline" onClick={() => window.location.reload()}><RefreshCw className="me-2 size-4" />{t("refresh")}</Button>
      </PageHeader>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {([
          ["overview", "finance_overview", Landmark],
          ["cashbox", "cashbox", ReceiptText],
          ["receivables", "receivables", Users],
          ["suppliers", "suppliers_finance", Truck],
        ] as const).map(([key, label, Icon]) => (
          <Button key={key} variant={tab === key ? "default" : "outline"} className="justify-start" onClick={() => setTab(key)}>
            <Icon className="me-2 size-4" />{t(label)}
          </Button>
        ))}
      </div>
      {tab === "overview" && <Overview currency={currency} />}
      {tab === "cashbox" && <Cashbox currency={currency} canCreate={can("accounting.create")} />}
      {tab === "receivables" && <Receivables currency={currency} canCreate={can("payments.create") || can("accounting.create")} />}
      {tab === "suppliers" && <Suppliers currency={currency} canCreate={can("accounting.create")} canUpdate={can("accounting.update")} />}
    </div>
  );
}

function Overview({ currency }: { currency: string }) {
  const payments = useRows<Row[]>(["finance-overview-payments"], () => supabase.from("payments").select("id,amount,payment_method,payment_date,deleted_at").is("deleted_at", null).limit(1000));
  const expenses = useRows<Row[]>(["finance-overview-expenses"], () => supabase.from("expenses").select("id,amount,expense_date,deleted_at").is("deleted_at", null).limit(1000));
  const bills = useRows<Row[]>(["finance-overview-bills"], () => supabase.from("supplier_bills").select("id,total_amount,paid_amount,status,deleted_at").is("deleted_at", null).limit(1000));
  const cash = useRows<Row[]>(["finance-overview-cash"], () => supabase.from("cashbox_transactions").select("id,amount,transaction_type,transaction_date,deleted_at").is("deleted_at", null).order("transaction_date", { ascending: false }).limit(1000));
  if (payments.isLoading || expenses.isLoading || bills.isLoading || cash.isLoading) return <Loading />;
  const collected = (payments.data ?? []).reduce((a, r) => a + n(r, "amount"), 0);
  const spent = (expenses.data ?? []).reduce((a, r) => a + n(r, "amount"), 0);
  const supplierDebt = (bills.data ?? []).reduce((a, r) => a + Math.max(n(r, "total_amount") - n(r, "paid_amount"), 0), 0);
  const cashBalance = (cash.data ?? []).reduce((a, r) => a + n(r, "amount"), 0);
  return <>
    <ErrorBox error={payments.error ?? expenses.error ?? bills.error ?? cash.error} />
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="الإيرادات المحصلة" value={money(collected, currency)} tone="success" />
      <StatCard label="المصروفات" value={money(spent, currency)} tone="destructive" />
      <StatCard label="رصيد الخزنة" value={money(cashBalance, currency)} tone="primary" />
      <StatCard label="ديون الموردين" value={money(supplierDebt, currency)} tone="warning" />
    </div>
    <Card><CardHeader><CardTitle>ملخص مالي</CardTitle></CardHeader><CardContent><div className="grid gap-3 sm:grid-cols-3"><Summary label="صافي التدفق" value={money(collected - spent, currency)} /><Summary label="عدد الدفعات" value={String(payments.data?.length ?? 0)} /><Summary label="عدد حركات الخزنة" value={String(cash.data?.length ?? 0)} /></div></CardContent></Card>
  </>;
}

function Summary({ label, value }: { label: string; value: string }) { return <div className="rounded-lg border p-4"><div className="text-sm text-muted-foreground">{label}</div><div className="mt-1 text-xl font-semibold">{value}</div></div>; }

function Cashbox({ currency, canCreate }: { currency: string; canCreate: boolean }) {
  const { t } = useLang();
  const [open, setOpen] = useState<"deposit" | "withdrawal" | null>(null);
  const [amount, setAmount] = useState("");
  const [description, setDescription] = useState("");
  const rows = useRows<Row[]>(["cashbox"], () => supabase.from("cashbox_transactions").select("id,transaction_type,amount,payment_method,category,description,source_type,source_id,transaction_date,created_at").is("deleted_at", null).order("transaction_date", { ascending: false }).limit(300));
  const save = useSave(async () => {
    if (!amount || Number(amount) <= 0) throw new Error(t("invalid_amount"));
    await rpc("post_cashbox_entry", {
      _direction: open,
      _amount: Number(amount),
      _method: "cash",
      _category: "manual",
      _description: description || (open === "deposit" ? "Manual deposit" : "Manual withdrawal"),
    });
  }, { invalidate: [["cashbox"], ["finance-overview-cash"], ["cashbox-balance"], ["cashbox-transactions"]], successMessage: t("saved"), onDone: () => { setOpen(null); setAmount(""); setDescription(""); } });
  const balance = (rows.data ?? []).reduce((a, r) => a + n(r, "amount"), 0);
  if (rows.isLoading) return <Loading />;
  return <>
    <ErrorBox error={rows.error} />
    <div className="grid gap-4 sm:grid-cols-3"><StatCard label={t("cashbox_balance")} value={money(balance, currency)} tone="primary" /><StatCard label={t("cash_in")} value={money((rows.data ?? []).filter(r => n(r,"amount") > 0).reduce((a,r)=>a+n(r,"amount"),0), currency)} tone="success" /><StatCard label={t("cash_out")} value={money(Math.abs((rows.data ?? []).filter(r => n(r,"amount") < 0).reduce((a,r)=>a+n(r,"amount"),0)), currency)} tone="destructive" /></div>
    <div className="flex gap-2"><Button disabled={!canCreate} onClick={() => setOpen("deposit")}><ArrowDownToLine className="me-2 size-4" />{t("deposit")}</Button><Button disabled={!canCreate} variant="outline" onClick={() => setOpen("withdrawal")}><ArrowUpFromLine className="me-2 size-4" />{t("withdrawal")}</Button></div>
    <Card><CardContent className="p-0"><Table density="compact"><TableHeader><TableRow><TableHead>{t("date")}</TableHead><TableHead>{t("type")}</TableHead><TableHead>{t("description")}</TableHead><TableHead>{t("amount")}</TableHead></TableRow></TableHeader><TableBody>{(rows.data ?? []).length === 0 ? <TableRow><TableCell colSpan={4}><Empty /></TableCell></TableRow> : (rows.data ?? []).map(r => <TableRow key={s(r,"id")}><TableCell dir="ltr">{new Date(s(r,"transaction_date") || s(r,"created_at")).toLocaleString()}</TableCell><TableCell>{s(r,"transaction_type")}</TableCell><TableCell>{s(r,"description") || "—"}</TableCell><TableCell className={n(r,"amount") >= 0 ? "font-medium" : "font-medium text-destructive"}>{money(n(r,"amount"), currency)}</TableCell></TableRow>)}</TableBody></Table></CardContent></Card>
    <Dialog open={!!open} onOpenChange={v => !v && setOpen(null)}><DialogContent><DialogHeader><DialogTitle>{open === "deposit" ? t("deposit") : t("withdrawal")}</DialogTitle></DialogHeader><div className="grid gap-4"><Field label={t("amount")}><Input type="number" min="0.01" dir="ltr" value={amount} onChange={e=>setAmount(e.target.value)} /></Field><Field label={t("description")}><Input value={description} onChange={e=>setDescription(e.target.value)} /></Field></div><DialogFooter><Button variant="outline" onClick={()=>setOpen(null)}>{t("cancel")}</Button><Button disabled={save.isPending} onClick={()=>save.mutate(undefined as never)}>{t("save")}</Button></DialogFooter></DialogContent></Dialog>
  </>;
}

function Receivables({ currency, canCreate }: { currency: string; canCreate: boolean }) {
  const { t } = useLang();
  const [search, setSearch] = useState("");
  const [paymentFor, setPaymentFor] = useState<Row | null>(null);
  const [amount, setAmount] = useState("");
  const invoices = useRows<Row[]>(["receivables", search], () => {
    let q = supabase.from("invoices").select("id,invoice_number,patient_id,net_amount,paid_amount,status,invoice_date,patients(full_name,mrn)").is("deleted_at", null).order("invoice_date", { ascending: false }).limit(500);
    if (search.trim()) q = q.or(`invoice_number.ilike.%${search.trim()}%`);
    return q;
  });
  const save = useSave(async () => {
    if (!paymentFor || Number(amount) <= 0) throw new Error(t("invalid_amount"));
    const outstanding = Math.max(n(paymentFor,"net_amount") - n(paymentFor,"paid_amount"), 0);
    if (Number(amount) > outstanding) throw new Error(t("payment_exceeds_balance"));
    await rpc("post_invoice_payment", {
      _invoice_id: s(paymentFor, "id"),
      _amount: Number(amount),
      _method: "cash",
      _reference: null,
    });
  }, { invalidate: [["receivables"], ["cashbox"], ["finance-overview-payments"], ["finance-overview-cash"], ["cashbox-balance"], ["cashbox-transactions"]], successMessage: t("saved"), onDone: ()=>{setPaymentFor(null);setAmount("");} });
  if (invoices.isLoading) return <Loading />;
  const rows = (invoices.data ?? []).filter(r => Math.max(n(r,"net_amount") - n(r,"paid_amount"), 0) > 0);
  return <><ErrorBox error={invoices.error} /><div className="flex gap-2"><div className="relative max-w-sm flex-1"><Search className="absolute start-3 top-2.5 size-4 text-muted-foreground"/><Input className="ps-9" placeholder={t("search") } value={search} onChange={e=>setSearch(e.target.value)} /></div></div><Card><CardContent className="p-0"><Table density="compact"><TableHeader><TableRow><TableHead>{t("invoice_number")}</TableHead><TableHead>{t("patient")}</TableHead><TableHead>{t("net")}</TableHead><TableHead>{t("paid")}</TableHead><TableHead>{t("balance")}</TableHead><TableHead /></TableRow></TableHeader><TableBody>{rows.length===0?<TableRow><TableCell colSpan={6}><Empty /></TableCell></TableRow>:rows.map(r=><TableRow key={s(r,"id")}><TableCell dir="ltr">{s(r,"invoice_number")}</TableCell><TableCell>{s((Array.isArray(r["patients"])?r["patients"][0]:r["patients"]) as Row,"full_name") || s((Array.isArray(r["patients"])?r["patients"][0]:r["patients"]) as Row,"mrn")}</TableCell><TableCell>{money(n(r,"net_amount"),currency)}</TableCell><TableCell>{money(n(r,"paid_amount"),currency)}</TableCell><TableCell className="font-semibold">{money(Math.max(n(r,"net_amount")-n(r,"paid_amount"),0),currency)}</TableCell><TableCell><Button size="sm" disabled={!canCreate} onClick={()=>setPaymentFor(r)}>{t("take_payment")}</Button></TableCell></TableRow>)}</TableBody></Table></CardContent></Card><Dialog open={!!paymentFor} onOpenChange={v=>!v&&setPaymentFor(null)}><DialogContent><DialogHeader><DialogTitle>{t("take_payment")}</DialogTitle></DialogHeader><Field label={t("amount")}><Input type="number" min="0.01" dir="ltr" value={amount} onChange={e=>setAmount(e.target.value)} /></Field><DialogFooter><Button variant="outline" onClick={()=>setPaymentFor(null)}>{t("cancel")}</Button><Button disabled={save.isPending} onClick={()=>save.mutate(undefined as never)}>{t("save")}</Button></DialogFooter></DialogContent></Dialog></>;
}

function Suppliers({ currency, canCreate, canUpdate }: { currency: string; canCreate: boolean; canUpdate: boolean }) {
  const { t } = useLang();
  const [supplier, setSupplier] = useState<Row | null>(null);
  const [billOpen, setBillOpen] = useState(false);
  const [paymentOpen, setPaymentOpen] = useState<Row | null>(null);
  const [name, setName] = useState(""); const [phone,setPhone]=useState(""); const [address,setAddress]=useState("");
  const [billTotal,setBillTotal]=useState(""); const [billNo,setBillNo]=useState(""); const [billDate,setBillDate]=useState(new Date().toISOString().slice(0,10));
  const [payAmount,setPayAmount]=useState("");
  const suppliers = useRows<Row[]>(["suppliers"], ()=>supabase.from("suppliers").select("id,name,phone,address,active,created_at").is("deleted_at",null).order("name").limit(500));
  const bills = useRows<Row[]>(["supplier-bills", supplier ? s(supplier,"id") : "none"], ()=>supabase.from("supplier_bills").select("id,supplier_id,invoice_number,bill_date,due_date,total_amount,paid_amount,status,notes").eq("supplier_id",s(supplier,"id")).is("deleted_at",null).order("bill_date",{ascending:false}));
  const addSupplier = useSave(async()=>{if(!name.trim()) throw new Error(t("required")); const {error}=await supabase.from("suppliers").insert({name:name.trim(),phone:phone||null,address:address||null,active:true}); if(error) throw error;},{invalidate:[["suppliers"]],successMessage:t("saved"),onDone:()=>{setName("");setPhone("");setAddress("");}});
  const addBill = useSave(async()=>{if(!supplier||Number(billTotal)<=0) throw new Error(t("invalid_amount")); await rpc("post_supplier_bill", { _supplier_id: s(supplier,"id"), _invoice_number: billNo || null, _bill_date: billDate, _due_date: null, _subtotal: Number(billTotal), _discount: 0 });},{invalidate:[["supplier-bills",supplier?s(supplier,"id"):"none"],["suppliers"],["supplier-outstanding"]],successMessage:t("saved"),onDone:()=>{setBillOpen(false);setBillTotal("");setBillNo("");}});
  const payBill = useSave(async()=>{if(!paymentOpen||Number(payAmount)<=0) throw new Error(t("invalid_amount")); const outstanding=Math.max(n(paymentOpen,"total_amount")-n(paymentOpen,"paid_amount"),0);if(Number(payAmount)>outstanding)throw new Error(t("payment_exceeds_balance"));await rpc("post_supplier_payment", { _bill_id: s(paymentOpen,"id"), _amount: Number(payAmount), _method: "cash" });},{invalidate:[["supplier-bills",supplier?s(supplier,"id"):"none"],["cashbox"],["finance-overview-cash"],["supplier-outstanding"],["cashbox-balance"],["cashbox-transactions"]],successMessage:t("saved"),onDone:()=>{setPaymentOpen(null);setPayAmount("");}});
  if(suppliers.isLoading)return <Loading/>;
  return <><ErrorBox error={suppliers.error??bills.error}/><Card><CardHeader><CardTitle>{t("suppliers_finance")}</CardTitle></CardHeader><CardContent><div className="grid gap-4 md:grid-cols-[1fr_2fr]"><div className="space-y-3"><div className="rounded-lg border p-3"><div className="mb-2 font-medium">{t("add_supplier")}</div><div className="grid gap-2"><Input placeholder={t("name")} value={name} onChange={e=>setName(e.target.value)}/><Input placeholder={t("phone")} value={phone} onChange={e=>setPhone(e.target.value)}/><Input placeholder={t("address")} value={address} onChange={e=>setAddress(e.target.value)}/><Button disabled={!canCreate||addSupplier.isPending} onClick={()=>addSupplier.mutate(undefined as never)}><Plus className="me-2 size-4"/>{t("add")}</Button></div></div>{(suppliers.data??[]).map(r=><button key={s(r,"id")} type="button" onClick={()=>setSupplier(r)} className={`w-full rounded-lg border p-3 text-start hover:bg-muted ${supplier&&s(supplier,"id")===s(r,"id")?"ring-2 ring-primary":""}`}><div className="font-medium">{s(r,"name")}</div><div className="text-xs text-muted-foreground">{s(r,"phone")||"—"}</div></button>)}</div><div>{!supplier?<Empty/>:<><div className="mb-3 flex items-center justify-between"><div><div className="text-lg font-semibold">{s(supplier,"name")}</div><div className="text-sm text-muted-foreground">{s(supplier,"phone")}</div></div><Button disabled={!canCreate} onClick={()=>setBillOpen(true)}><Plus className="me-2 size-4"/>{t("new_supplier_bill")}</Button></div><Table density="compact"><TableHeader><TableRow><TableHead>{t("invoice_number")}</TableHead><TableHead>{t("date")}</TableHead><TableHead>{t("total")}</TableHead><TableHead>{t("paid")}</TableHead><TableHead>{t("balance")}</TableHead><TableHead /></TableRow></TableHeader><TableBody>{(bills.data??[]).length===0?<TableRow><TableCell colSpan={6}><Empty/></TableCell></TableRow>:(bills.data??[]).map(r=><TableRow key={s(r,"id")}><TableCell dir="ltr">{s(r,"invoice_number")||"—"}</TableCell><TableCell dir="ltr">{s(r,"bill_date")}</TableCell><TableCell>{money(n(r,"total_amount"),currency)}</TableCell><TableCell>{money(n(r,"paid_amount"),currency)}</TableCell><TableCell className="font-semibold">{money(Math.max(n(r,"total_amount")-n(r,"paid_amount"),0),currency)}</TableCell><TableCell><Button size="sm" variant="outline" disabled={!canUpdate||n(r,"total_amount")<=n(r,"paid_amount")} onClick={()=>setPaymentOpen(r)}>{t("take_payment")}</Button></TableCell></TableRow>)}</TableBody></Table></>}</div></div></CardContent></Card><Dialog open={billOpen} onOpenChange={v=>setBillOpen(v)}><DialogContent><DialogHeader><DialogTitle>{t("new_supplier_bill")}</DialogTitle></DialogHeader><div className="grid gap-3"><Field label={t("invoice_number")}><Input value={billNo} onChange={e=>setBillNo(e.target.value)}/></Field><Field label={t("date")}><Input type="date" dir="ltr" value={billDate} onChange={e=>setBillDate(e.target.value)}/></Field><Field label={t("total")}><Input type="number" min="0.01" dir="ltr" value={billTotal} onChange={e=>setBillTotal(e.target.value)}/></Field></div><DialogFooter><Button variant="outline" onClick={()=>setBillOpen(false)}>{t("cancel")}</Button><Button disabled={addBill.isPending} onClick={()=>addBill.mutate(undefined as never)}>{t("save")}</Button></DialogFooter></DialogContent></Dialog><Dialog open={!!paymentOpen} onOpenChange={v=>!v&&setPaymentOpen(null)}><DialogContent><DialogHeader><DialogTitle>{t("supplier_payment")}</DialogTitle></DialogHeader><Field label={t("amount")}><Input type="number" min="0.01" dir="ltr" value={payAmount} onChange={e=>setPayAmount(e.target.value)}/></Field><DialogFooter><Button variant="outline" onClick={()=>setPaymentOpen(null)}>{t("cancel")}</Button><Button disabled={payBill.isPending} onClick={()=>payBill.mutate(undefined as never)}>{t("save")}</Button></DialogFooter></DialogContent></Dialog></>;
}
