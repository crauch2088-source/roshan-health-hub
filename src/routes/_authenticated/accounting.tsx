import { createFileRoute } from "@tanstack/react-router";
import { ArrowDownCircle, ArrowUpCircle, Landmark, Plus, ReceiptText, WalletCards } from "lucide-react";
import { useMemo, useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatCard } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, s, useRows, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/accounting")({
  head: () => ({
    meta: [
      { title: "Finance — ROSHAN Medical Center" },
      { name: "description", content: "Cashbox, receivables, supplier debts and financial activity." },
    ],
  }),
  component: AccountingPage,
});

type ManualForm = {
  direction: "in" | "out";
  amount: string;
  type: "deposit" | "withdrawal" | "adjustment";
  method: string;
  category: string;
  description: string;
};

type BillForm = {
  supplier_id: string;
  invoice_number: string;
  bill_date: string;
  due_date: string;
  total_amount: string;
  notes: string;
};

function AccountingPage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const [from, setFrom] = useState(`${todayISO().slice(0, 7)}-01`);
  const [to, setTo] = useState(todayISO());
  const [manualOpen, setManualOpen] = useState(false);
  const [billOpen, setBillOpen] = useState(false);
  const [payBill, setPayBill] = useState<Row | null>(null);
  const [manual, setManual] = useState<ManualForm>({
    direction: "in",
    amount: "",
    type: "deposit",
    method: "cash",
    category: "",
    description: "",
  });
  const [bill, setBill] = useState<BillForm>({
    supplier_id: "",
    invoice_number: "",
    bill_date: todayISO(),
    due_date: "",
    total_amount: "",
    notes: "",
  });
  const [billPayment, setBillPayment] = useState({ amount: "", method: "cash", reference: "", notes: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const cashbox = useRows(["cashbox", from, to], () =>
    supabase
      .from("cashbox_transactions")
      .select("*")
      .gte("transaction_date", `${from}T00:00:00`)
      .lt("transaction_date", `${to}T23:59:59.999`)
      .is("deleted_at", null)
      .order("transaction_date", { ascending: false }),
  );
  const cashboxAll = useRows(["cashbox-balance"], () =>
    supabase.from("cashbox_transactions").select("amount").is("deleted_at", null),
  );
  const receivables = useRows(["finance-receivables"], () =>
    supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, net_amount, paid_amount, payment_status, patients(full_name, mrn)")
      .is("deleted_at", null)
      .neq("status", "cancelled")
      .order("invoice_date", { ascending: false })
      .limit(500),
  );
  const suppliers = useRows(["finance-suppliers"], () =>
    supabase.from("suppliers").select("id, name").eq("active", true).is("deleted_at", null).order("name"),
  );
  const supplierBills = useRows(["supplier-bills"], () =>
    supabase
      .from("supplier_bills")
      .select("id, supplier_id, invoice_number, bill_date, due_date, total_amount, paid_amount, status, notes, suppliers(name)")
      .is("deleted_at", null)
      .order("bill_date", { ascending: false }),
  );

  const cashRows = (cashbox.data ?? []) as Row[];
  const balance = ((cashboxAll.data ?? []) as Row[]).reduce((sum, row) => sum + n(row, "amount"), 0);
  const periodIn = cashRows.filter((r) => n(r, "amount") > 0).reduce((sum, r) => sum + n(r, "amount"), 0);
  const periodOut = cashRows.filter((r) => n(r, "amount") < 0).reduce((sum, r) => sum + Math.abs(n(r, "amount")), 0);

  const receivableRows = useMemo(
    () =>
      ((receivables.data ?? []) as Row[]).filter(
        (r) => Math.max(n(r, "net_amount") - n(r, "paid_amount"), 0) > 0,
      ),
    [receivables.data],
  );
  const totalReceivable = receivableRows.reduce(
    (sum, r) => sum + Math.max(n(r, "net_amount") - n(r, "paid_amount"), 0),
    0,
  );
  const billRows = (supplierBills.data ?? []) as Row[];
  const totalSupplierDebt = billRows.reduce(
    (sum, r) => sum + Math.max(n(r, "total_amount") - n(r, "paid_amount"), 0),
    0,
  );

  const refreshKeys = () => {
    void cashbox.refetch();
    void cashboxAll.refetch();
    void supplierBills.refetch();
    void receivables.refetch();
  };

  async function addManualEntry() {
    setBusy(true);
    setError(null);
    try {
      const amount = Number(manual.amount);
      if (!amount || amount <= 0) throw new Error(t("invalid_amount") || "Invalid amount");
      const { error: e } = await supabase.rpc("add_cashbox_entry", {
        _direction: manual.direction,
        _amount: amount,
        _type: manual.type,
        _method: manual.method,
        _category: manual.category.trim() || null,
        _description: manual.description.trim() || null,
        _date: new Date().toISOString(),
      });
      if (e) throw new Error(e.message);
      setManualOpen(false);
      setManual({ direction: "in", amount: "", type: "deposit", method: "cash", category: "", description: "" });
      refreshKeys();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function createSupplierBill() {
    setBusy(true);
    setError(null);
    try {
      const total = Number(bill.total_amount);
      if (!bill.supplier_id) throw new Error(t("supplier_required") || "Supplier is required");
      if (!total || total <= 0) throw new Error(t("invalid_amount") || "Invalid amount");
      const { error: e } = await supabase.from("supplier_bills").insert({
        supplier_id: bill.supplier_id,
        invoice_number: bill.invoice_number.trim() || null,
        bill_date: bill.bill_date,
        due_date: bill.due_date || null,
        subtotal: total,
        discount_amount: 0,
        total_amount: total,
        paid_amount: 0,
        status: "unpaid",
        notes: bill.notes.trim() || null,
      });
      if (e) throw new Error(e.message);
      setBillOpen(false);
      setBill({ supplier_id: "", invoice_number: "", bill_date: todayISO(), due_date: "", total_amount: "", notes: "" });
      refreshKeys();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function paySupplierBill() {
    if (!payBill) return;
    setBusy(true);
    setError(null);
    try {
      const amount = Number(billPayment.amount);
      const outstanding = Math.max(n(payBill, "total_amount") - n(payBill, "paid_amount"), 0);
      if (!amount || amount <= 0 || amount > outstanding) {
        throw new Error(t("invalid_payment_amount") || "Payment exceeds the outstanding balance");
      }
      const { error: e } = await supabase.from("supplier_payments").insert({
        supplier_bill_id: s(payBill, "id"),
        supplier_id: s(payBill, "supplier_id"),
        amount,
        payment_method: billPayment.method,
        reference: billPayment.reference.trim() || null,
        notes: billPayment.notes.trim() || null,
      });
      if (e) throw new Error(e.message);
      setPayBill(null);
      setBillPayment({ amount: "", method: "cash", reference: "", notes: "" });
      refreshKeys();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  const loading =
    cashbox.isLoading || cashboxAll.isLoading || receivables.isLoading || suppliers.isLoading || supplierBills.isLoading;

  if (loading) return <Loading />;

  return (
    <div className="space-y-4">
      <PageHeader
        title={t("accounting")}
        subtitle={lang === "ar" ? "الخزنة والذمم المدينة وديون الموردين" : "Cashbox, receivables and supplier payables"}
      >
        <Input type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} className="w-40" />
        <Input type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} className="w-40" />
        <ExportButtons rows={cashRows} filename={`roshan-cashbox-${from}-${to}`} />
        {can("accounting.create") ? (
          <>
            <Button size="sm" variant="outline" onClick={() => setManualOpen(true)}>
              <Plus className="size-4" /> {t("cashbox_entry")}
            </Button>
            <Button size="sm" onClick={() => setBillOpen(true)}>
              <ReceiptText className="size-4" /> {t("new_supplier_bill")}
            </Button>
          </>
        ) : null}
      </PageHeader>

      <ErrorBox error={error ?? cashbox.error ?? cashboxAll.error ?? receivables.error ?? suppliers.error ?? supplierBills.error} />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("cashbox_balance")} value={money(balance, currency)} tone={balance >= 0 ? "success" : "destructive"} />
        <StatCard label={t("period_inflow")} value={money(periodIn, currency)} tone="success" />
        <StatCard label={t("period_outflow")} value={money(periodOut, currency)} tone="destructive" />
        <StatCard label={t("customer_receivables")} value={money(totalReceivable, currency)} tone="warning" />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardContent className="p-4">
            <div className="mb-3 flex items-center gap-2 font-semibold"><WalletCards className="size-4" />{t("cashbox")}</div>
            <div className="text-3xl font-bold">{money(balance, currency)}</div>
            <p className="mt-1 text-xs text-muted-foreground">{t("cashbox_balance_hint")}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="mb-3 flex items-center gap-2 font-semibold"><ArrowUpCircle className="size-4" />{t("customer_receivables")}</div>
            <div className="text-3xl font-bold">{money(totalReceivable, currency)}</div>
            <p className="mt-1 text-xs text-muted-foreground">{receivableRows.length} {t("records")}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="mb-3 flex items-center gap-2 font-semibold"><ArrowDownCircle className="size-4" />{t("supplier_debt")}</div>
            <div className="text-3xl font-bold">{money(totalSupplierDebt, currency)}</div>
            <p className="mt-1 text-xs text-muted-foreground">{billRows.filter((r) => n(r, "total_amount") > n(r, "paid_amount")).length} {t("records")}</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardContent className="p-0">
          <div className="flex items-center gap-2 border-b p-4 font-semibold"><Landmark className="size-4" />{t("cashbox_movements")}</div>
          {cashRows.length === 0 ? <Empty /> : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b text-start">
                  <th className="p-3 text-start">{t("date")}</th>
                  <th className="p-3 text-start">{t("type")}</th>
                  <th className="p-3 text-start">{t("description")}</th>
                  <th className="p-3 text-start">{t("payment_method")}</th>
                  <th className="p-3 text-start">{t("amount")}</th>
                </tr></thead>
                <tbody>{cashRows.map((r) => (
                  <tr key={s(r, "id")} className="border-b last:border-0">
                    <td className="p-3" dir="ltr">{new Date(s(r, "transaction_date")).toLocaleString()}</td>
                    <td className="p-3">{t(`cashbox_${s(r, "transaction_type")}`)}</td>
                    <td className="p-3">{s(r, "description") || s(r, "category") || "—"}</td>
                    <td className="p-3">{s(r, "payment_method") || "cash"}</td>
                    <td className={`p-3 font-semibold ${n(r, "amount") >= 0 ? "text-emerald-600" : "text-destructive"}`} dir="ltr">
                      {money(n(r, "amount"), currency)}
                    </td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardContent className="p-0">
            <div className="border-b p-4 font-semibold">{t("customer_receivables")}</div>
            {receivableRows.length === 0 ? <Empty /> : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead><tr className="border-b">
                    <th className="p-3 text-start">{t("invoice_number")}</th>
                    <th className="p-3 text-start">{t("patient")}</th>
                    <th className="p-3 text-start">{t("date")}</th>
                    <th className="p-3 text-start">{t("balance")}</th>
                  </tr></thead>
                  <tbody>{receivableRows.map((r) => {
                    const patient = (r["patients"] as Row | null) ?? {};
                    return <tr key={s(r, "id")} className="border-b last:border-0">
                      <td className="p-3">{s(r, "invoice_number")}</td>
                      <td className="p-3">{s(patient, "full_name") || "—"}</td>
                      <td className="p-3" dir="ltr">{formatDate(s(r, "invoice_date"))}</td>
                      <td className="p-3 font-semibold">{money(Math.max(n(r, "net_amount") - n(r, "paid_amount"), 0), currency)}</td>
                    </tr>;
                  })}</tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-0">
            <div className="border-b p-4 font-semibold">{t("supplier_debt")}</div>
            {billRows.length === 0 ? <Empty /> : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead><tr className="border-b">
                    <th className="p-3 text-start">{t("supplier")}</th>
                    <th className="p-3 text-start">{t("invoice_number")}</th>
                    <th className="p-3 text-start">{t("date")}</th>
                    <th className="p-3 text-start">{t("balance")}</th>
                    <th className="p-3 text-start">{t("actions")}</th>
                  </tr></thead>
                  <tbody>{billRows.map((r) => {
                    const supplier = (r["suppliers"] as Row | null) ?? {};
                    const outstanding = Math.max(n(r, "total_amount") - n(r, "paid_amount"), 0);
                    return <tr key={s(r, "id")} className="border-b last:border-0">
                      <td className="p-3">{s(supplier, "name") || "—"}</td>
                      <td className="p-3">{s(r, "invoice_number") || "—"}</td>
                      <td className="p-3" dir="ltr">{formatDate(s(r, "bill_date"))}</td>
                      <td className="p-3 font-semibold">{money(outstanding, currency)}</td>
                      <td className="p-3">{outstanding > 0 && can("accounting.create") ? <Button size="sm" variant="outline" onClick={() => setPayBill(r)}>{t("pay")}</Button> : "—"}</td>
                    </tr>;
                  })}</tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Dialog open={manualOpen} onOpenChange={setManualOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>{t("cashbox_entry")}</DialogTitle></DialogHeader>
          <div className="grid gap-4">
            <Field label={t("cashbox_direction")}>
              <Select value={manual.direction} onValueChange={(v: "in" | "out") => setManual({ ...manual, direction: v, type: v === "in" ? "deposit" : "withdrawal" })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent><SelectItem value="in">{t("cash_in")}</SelectItem><SelectItem value="out">{t("cash_out")}</SelectItem></SelectContent>
              </Select>
            </Field>
            <Field label={t("amount")}><Input type="number" min={0} dir="ltr" value={manual.amount} onChange={(e) => setManual({ ...manual, amount: e.target.value })} /></Field>
            <Field label={t("payment_method")}><Select value={manual.method} onValueChange={(v) => setManual({ ...manual, method: v })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="cash">{t("cash")}</SelectItem><SelectItem value="bankak">Bankak</SelectItem><SelectItem value="bank">{t("bank")}</SelectItem></SelectContent></Select></Field>
            <Field label={t("category")}><Input value={manual.category} onChange={(e) => setManual({ ...manual, category: e.target.value })} /></Field>
            <Field label={t("description")}><Textarea value={manual.description} onChange={(e) => setManual({ ...manual, description: e.target.value })} /></Field>
          </div>
          <DialogFooter><Button variant="outline" onClick={() => setManualOpen(false)}>{t("cancel")}</Button><Button disabled={busy} onClick={addManualEntry}>{busy ? t("saving") : t("save")}</Button></DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={billOpen} onOpenChange={setBillOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>{t("new_supplier_bill")}</DialogTitle></DialogHeader>
          <div className="grid gap-4">
            <Field label={t("supplier")}><Select value={bill.supplier_id} onValueChange={(v) => setBill({ ...bill, supplier_id: v })}><SelectTrigger><SelectValue placeholder={t("supplier")} /></SelectTrigger><SelectContent>{((suppliers.data ?? []) as Row[]).map((r) => <SelectItem key={s(r, "id")} value={s(r, "id")}>{s(r, "name")}</SelectItem>)}</SelectContent></Select></Field>
            <Field label={t("invoice_number")}><Input dir="ltr" value={bill.invoice_number} onChange={(e) => setBill({ ...bill, invoice_number: e.target.value })} /></Field>
            <div className="grid gap-4 sm:grid-cols-2"><Field label={t("date")}><Input type="date" dir="ltr" value={bill.bill_date} onChange={(e) => setBill({ ...bill, bill_date: e.target.value })} /></Field><Field label={t("due_date")}><Input type="date" dir="ltr" value={bill.due_date} onChange={(e) => setBill({ ...bill, due_date: e.target.value })} /></Field></div>
            <Field label={t("amount")}><Input type="number" min={0} dir="ltr" value={bill.total_amount} onChange={(e) => setBill({ ...bill, total_amount: e.target.value })} /></Field>
            <Field label={t("notes")}><Textarea value={bill.notes} onChange={(e) => setBill({ ...bill, notes: e.target.value })} /></Field>
          </div>
          <DialogFooter><Button variant="outline" onClick={() => setBillOpen(false)}>{t("cancel")}</Button><Button disabled={busy} onClick={createSupplierBill}>{busy ? t("saving") : t("save")}</Button></DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={Boolean(payBill)} onOpenChange={(open) => !open && setPayBill(null)}>
        <DialogContent>
          <DialogHeader><DialogTitle>{t("supplier_payment")}</DialogTitle></DialogHeader>
          <div className="grid gap-4">
            <div className="rounded-lg border p-3 text-sm">{t("balance")}: <strong>{money(payBill ? Math.max(n(payBill, "total_amount") - n(payBill, "paid_amount"), 0) : 0, currency)}</strong></div>
            <Field label={t("amount")}><Input type="number" min={0} dir="ltr" value={billPayment.amount} onChange={(e) => setBillPayment({ ...billPayment, amount: e.target.value })} /></Field>
            <Field label={t("payment_method")}><Select value={billPayment.method} onValueChange={(v) => setBillPayment({ ...billPayment, method: v })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="cash">{t("cash")}</SelectItem><SelectItem value="bankak">Bankak</SelectItem><SelectItem value="bank">{t("bank")}</SelectItem></SelectContent></Select></Field>
            <Field label={t("reference")}><Input dir="ltr" value={billPayment.reference} onChange={(e) => setBillPayment({ ...billPayment, reference: e.target.value })} /></Field>
            <Field label={t("notes")}><Textarea value={billPayment.notes} onChange={(e) => setBillPayment({ ...billPayment, notes: e.target.value })} /></Field>
          </div>
          <DialogFooter><Button variant="outline" onClick={() => setPayBill(null)}>{t("cancel")}</Button><Button disabled={busy} onClick={paySupplierBill}>{busy ? t("saving") : t("save")}</Button></DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
