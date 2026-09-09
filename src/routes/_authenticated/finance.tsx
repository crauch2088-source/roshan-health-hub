import { createFileRoute } from "@tanstack/react-router";
import { Banknote, Plus, RotateCcw, Wallet } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatCard } from "@/components/kit";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rpc, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/finance")({
  head: () => ({
    meta: [
      { title: "Finance — ROSHAN Medical Center" },
      { name: "description", content: "Cashbox, patient receivables, and supplier bills/payments." },
      { property: "og:title", content: "Finance — ROSHAN Medical Center" },
      { property: "og:description", content: "Cashbox, patient receivables, and supplier bills/payments." },
    ],
  }),
  component: FinancePage,
});

function FinancePage() {
  const { t } = useLang();
  const { currency } = useSettings();

  return (
    <div>
      <PageHeader title={t("finance_hub")} subtitle={t("finance_hub_subtitle")} />
      <Tabs defaultValue="cashbox">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="cashbox">{t("cashbox")}</TabsTrigger>
          <TabsTrigger value="receivables">{t("receivables")}</TabsTrigger>
          <TabsTrigger value="suppliers_debt">{t("supplier_debt")}</TabsTrigger>
        </TabsList>
        <TabsContent value="cashbox">
          <CashboxTab currency={currency} />
        </TabsContent>
        <TabsContent value="receivables">
          <ReceivablesTab currency={currency} />
        </TabsContent>
        <TabsContent value="suppliers_debt">
          <SupplierDebtTab currency={currency} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// =============================================================================
// Cashbox — balance from the cashbox_balance view, ledger from
// cashbox_transactions, deposits/withdrawals via post_cashbox_entry(),
// reversals (not edits/deletes — the ledger is immutable at the DB layer)
// via reverse_cashbox_entry().
// =============================================================================

function CashboxTab({ currency }: { currency: string }) {
  const { t } = useLang();
  const { can } = useAuth();
  const [entryOpen, setEntryOpen] = useState(false);
  const [direction, setDirection] = useState<"deposit" | "withdrawal">("deposit");
  const [amount, setAmount] = useState("0");
  const [method, setMethod] = useState("cash");
  const [description, setDescription] = useState("");
  const [reverseTarget, setReverseTarget] = useState<Row | null>(null);
  const [reverseReason, setReverseReason] = useState("");

  const balance = useRows<Row[]>(["cashbox-balance"], () => supabase.from("cashbox_balance").select("*"));
  const txns = useRows<Row[]>(["cashbox-transactions"], () =>
    supabase
      .from("cashbox_transactions")
      .select("id, transaction_type, amount, payment_method, category, description, transaction_date, is_reversed, reversal_of")
      .is("deleted_at", null)
      .order("transaction_date", { ascending: false })
      .limit(200),
  );

  const post = useSave(
    async () => {
      const amt = Number(amount);
      if (!amt || amt <= 0) throw new Error(t("invalid_quantity"));
      await rpc("post_cashbox_entry", {
        _direction: direction,
        _amount: amt,
        _method: method,
        _category: "manual",
        _description: description || null,
      });
      return null;
    },
    {
      invalidate: [["cashbox-balance"], ["cashbox-transactions"]],
      successMessage: t("saved"),
      onDone: () => {
        setEntryOpen(false);
        setAmount("0");
        setDescription("");
      },
    },
  );

  const reverse = useSave(
    async () => {
      if (!reverseTarget) return null;
      if (!reverseReason.trim()) throw new Error(t("reversal_reason_required"));
      await rpc("reverse_cashbox_entry", { _transaction_id: s(reverseTarget, "id"), _reason: reverseReason.trim() });
      return null;
    },
    {
      invalidate: [["cashbox-balance"], ["cashbox-transactions"]],
      successMessage: t("saved"),
      onDone: () => {
        setReverseTarget(null);
        setReverseReason("");
      },
    },
  );

  const bal = (balance.data ?? [])[0] as Row | undefined;
  const rows = (txns.data ?? []) as Row[];

  if (balance.isLoading) return <Loading />;

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-cashbox" />
        {can("cashbox.create") ? (
          <Button size="sm" onClick={() => setEntryOpen(true)}>
            <Plus className="size-4" /> {t("cashbox_entry")}
          </Button>
        ) : null}
      </div>

      <ErrorBox error={balance.error ?? txns.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <StatCard label={t("cashbox_balance")} value={money(n(bal, "balance"), currency)} />
        <StatCard label={t("cash_in")} value={money(n(bal, "total_in"), currency)} tone="success" />
        <StatCard label={t("cash_out")} value={money(n(bal, "total_out"), currency)} tone="destructive" />
      </div>

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("type")}</TableHead>
                  <TableHead>{t("category")}</TableHead>
                  <TableHead>{t("description")}</TableHead>
                  <TableHead>{t("amount")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((tx) => {
                  const amt = n(tx, "amount");
                  return (
                    <TableRow key={s(tx, "id")}>
                      <TableCell dir="ltr">{formatDateTime(s(tx, "transaction_date"))}</TableCell>
                      <TableCell>{t(s(tx, "transaction_type"))}</TableCell>
                      <TableCell>{s(tx, "category") || "—"}</TableCell>
                      <TableCell className="max-w-64 truncate">
                        {s(tx, "description") || "—"}
                        {tx["is_reversed"] ? (
                          <Badge variant="outline" className="ms-2 text-[10px]">
                            {t("reversed")}
                          </Badge>
                        ) : null}
                        {tx["reversal_of"] ? (
                          <Badge variant="outline" className="ms-2 text-[10px]">
                            {t("reversal")}
                          </Badge>
                        ) : null}
                      </TableCell>
                      <TableCell dir="ltr" className={amt < 0 ? "font-semibold text-destructive" : "font-semibold text-success"}>
                        {amt > 0 ? `+${money(amt, currency)}` : money(amt, currency)}
                      </TableCell>
                      <TableCell className="no-print text-end">
                        {can("cashbox.update") && !tx["is_reversed"] && !tx["reversal_of"] ? (
                          <Button variant="ghost" size="sm" onClick={() => setReverseTarget(tx)}>
                            <RotateCcw className="size-3.5" /> {t("reverse")}
                          </Button>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={entryOpen} onOpenChange={setEntryOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("cashbox_entry")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <Field label={t("type")}>
              <Select value={direction} onValueChange={(v) => setDirection(v as "deposit" | "withdrawal")}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="deposit">{t("deposit")}</SelectItem>
                  <SelectItem value="withdrawal">{t("withdrawal")}</SelectItem>
                </SelectContent>
              </Select>
            </Field>
            <Field label={`${t("amount")} *`}>
              <Input type="number" dir="ltr" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </Field>
            <Field label={t("payment_method")}>
              <Select value={method} onValueChange={setMethod}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cash">{t("cash")}</SelectItem>
                  <SelectItem value="bank">{t("bank")}</SelectItem>
                </SelectContent>
              </Select>
            </Field>
            <Field label={t("description")}>
              <Textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
            </Field>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEntryOpen(false)}>
              {t("cancel")}
            </Button>
            <Button disabled={post.isPending} onClick={() => post.mutate(undefined as never)}>
              {post.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={Boolean(reverseTarget)} onOpenChange={(o) => (o ? null : setReverseTarget(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("reverse")}</DialogTitle>
          </DialogHeader>
          <Field label={`${t("reversal_reason")} *`}>
            <Textarea rows={2} value={reverseReason} onChange={(e) => setReverseReason(e.target.value)} />
          </Field>
          <DialogFooter>
            <Button variant="outline" onClick={() => setReverseTarget(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={!reverseReason.trim() || reverse.isPending} onClick={() => reverse.mutate(undefined as never)}>
              {reverse.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// =============================================================================
// Receivables — v_patient_receivables view; recording a payment goes
// through post_invoice_payment() so invoice status/paid_amount and the
// cashbox stay in sync atomically (never a payment row without a ledger
// entry, or vice versa).
// =============================================================================

function ReceivablesTab({ currency }: { currency: string }) {
  const { t } = useLang();
  const { can } = useAuth();
  const [payTarget, setPayTarget] = useState<Row | null>(null);
  const [amount, setAmount] = useState("0");
  const [method, setMethod] = useState("cash");
  const [reference, setReference] = useState("");

  const list = useRows<Row[]>(["patient-receivables"], () =>
    supabase.from("v_patient_receivables").select("*").order("outstanding", { ascending: false }).limit(300),
  );

  const pay = useSave(
    async () => {
      if (!payTarget) return null;
      const amt = Number(amount);
      if (!amt || amt <= 0) throw new Error(t("invalid_quantity"));
      await rpc("post_invoice_payment", {
        _invoice_id: s(payTarget, "invoice_id"),
        _amount: amt,
        _method: method,
        _reference: reference || null,
      });
      return null;
    },
    {
      invalidate: [["patient-receivables"], ["cashbox-balance"], ["cashbox-transactions"]],
      successMessage: t("saved"),
      onDone: () => {
        setPayTarget(null);
        setAmount("0");
        setReference("");
      },
    },
  );

  const rows = (list.data ?? []) as Row[];
  const totalOutstanding = rows.reduce((sum, r) => sum + n(r, "outstanding"), 0);

  if (list.isLoading) return <Loading />;

  return (
    <div>
      <div className="no-print mb-4 flex justify-end">
        <ExportButtons rows={rows} filename="roshan-receivables" />
      </div>
      <ErrorBox error={list.error} />
      <div className="mb-4">
        <StatCard label={t("outstanding_balance")} value={money(totalOutstanding, currency)} tone="warning" />
      </div>
      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("invoice_number")}</TableHead>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("net")}</TableHead>
                  <TableHead>{t("paid_amount")}</TableHead>
                  <TableHead>{t("outstanding_balance")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={s(r, "invoice_id")}>
                    <TableCell className="font-medium">
                      {s(r, "patient_name")}
                      <span className="ms-1 text-xs text-muted-foreground" dir="ltr">
                        ({s(r, "mrn")})
                      </span>
                    </TableCell>
                    <TableCell dir="ltr">{s(r, "invoice_number") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(r, "invoice_date") ? formatDate(s(r, "invoice_date")) : "—"}</TableCell>
                    <TableCell>{money(n(r, "net_amount"), currency)}</TableCell>
                    <TableCell>{money(n(r, "paid_amount"), currency)}</TableCell>
                    <TableCell className="font-semibold text-destructive">{money(n(r, "outstanding"), currency)}</TableCell>
                    <TableCell className="no-print text-end">
                      {can("payments.create") || can("billing.create") ? (
                        <Button
                          size="sm"
                          onClick={() => {
                            setPayTarget(r);
                            setAmount(String(n(r, "outstanding")));
                          }}
                        >
                          {t("record_payment")}
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={Boolean(payTarget)} onOpenChange={(o) => (o ? null : setPayTarget(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("record_payment")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <Field label={`${t("amount")} *`}>
              <Input type="number" dir="ltr" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </Field>
            <Field label={t("payment_method")}>
              <Select value={method} onValueChange={setMethod}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cash">{t("cash")}</SelectItem>
                  <SelectItem value="bank">{t("bank")}</SelectItem>
                </SelectContent>
              </Select>
            </Field>
            <Field label={t("reference")}>
              <Input dir="ltr" value={reference} onChange={(e) => setReference(e.target.value)} />
            </Field>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPayTarget(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={pay.isPending} onClick={() => pay.mutate(undefined as never)}>
              {pay.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// =============================================================================
// Supplier debt — v_supplier_outstanding for the summary, supplier_bills
// for the detail. New bill via post_supplier_bill(), payment via
// post_supplier_payment() — both atomic, both feed the same cashbox ledger.
// =============================================================================

function SupplierDebtTab({ currency }: { currency: string }) {
  const { t } = useLang();
  const { can } = useAuth();
  const [billOpen, setBillOpen] = useState(false);
  const [supplierId, setSupplierId] = useState("");
  const [invoiceNumber, setInvoiceNumber] = useState("");
  const [subtotal, setSubtotal] = useState("0");
  const [discount, setDiscount] = useState("0");
  const [payTarget, setPayTarget] = useState<Row | null>(null);
  const [amount, setAmount] = useState("0");
  const [method, setMethod] = useState("cash");

  const outstanding = useRows<Row[]>(["supplier-outstanding"], () =>
    supabase.from("v_supplier_outstanding").select("*").order("outstanding", { ascending: false }),
  );

  const suppliers = useRows<Row[]>(["suppliers-picker-finance"], () =>
    supabase.from("suppliers").select("id, name").is("deleted_at", null).eq("active", true).order("name", { ascending: true }),
  );

  const bills = useRows<Row[]>(["supplier-bills"], () =>
    supabase
      .from("supplier_bills")
      .select("id, supplier_id, invoice_number, bill_date, total_amount, paid_amount, status, suppliers(name)")
      .is("deleted_at", null)
      .order("bill_date", { ascending: false })
      .limit(200),
  );

  const createBill = useSave(
    async () => {
      if (!supplierId) throw new Error(t("select_medicine"));
      const sub = Number(subtotal);
      if (!sub || sub <= 0) throw new Error(t("invalid_quantity"));
      await rpc("post_supplier_bill", {
        _supplier_id: supplierId,
        _invoice_number: invoiceNumber || null,
        _bill_date: new Date().toISOString().slice(0, 10),
        _due_date: null,
        _subtotal: sub,
        _discount: Number(discount) || 0,
      });
      return null;
    },
    {
      invalidate: [["supplier-bills"], ["supplier-outstanding"]],
      successMessage: t("saved"),
      onDone: () => {
        setBillOpen(false);
        setSupplierId("");
        setInvoiceNumber("");
        setSubtotal("0");
        setDiscount("0");
      },
    },
  );

  const pay = useSave(
    async () => {
      if (!payTarget) return null;
      const amt = Number(amount);
      if (!amt || amt <= 0) throw new Error(t("invalid_quantity"));
      await rpc("post_supplier_payment", { _bill_id: s(payTarget, "id"), _amount: amt, _method: method });
      return null;
    },
    {
      invalidate: [["supplier-bills"], ["supplier-outstanding"], ["cashbox-balance"], ["cashbox-transactions"]],
      successMessage: t("saved"),
      onDone: () => {
        setPayTarget(null);
        setAmount("0");
      },
    },
  );

  const outstandingRows = (outstanding.data ?? []) as Row[];
  const billRows = (bills.data ?? []) as Row[];
  const totalOutstanding = outstandingRows.reduce((sum, r) => sum + n(r, "outstanding"), 0);

  if (outstanding.isLoading) return <Loading />;

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-end gap-2">
        <ExportButtons rows={billRows} filename="roshan-supplier-bills" />
        {can("debts.create") || can("pharmacy.create") ? (
          <Button size="sm" onClick={() => setBillOpen(true)}>
            <Plus className="size-4" /> {t("new_supplier_bill")}
          </Button>
        ) : null}
      </div>

      <ErrorBox error={outstanding.error ?? bills.error} />

      <div className="mb-4">
        <StatCard label={t("supplier_debt")} value={money(totalOutstanding, currency)} tone="warning" />
      </div>

      <Card className="mb-4">
        <CardContent className="p-0">
          {outstandingRows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("supplier")}</TableHead>
                  <TableHead>{t("total_billed")}</TableHead>
                  <TableHead>{t("total_paid")}</TableHead>
                  <TableHead>{t("outstanding_balance")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {outstandingRows
                  .filter((r) => n(r, "bills_count") > 0)
                  .map((r) => (
                    <TableRow key={s(r, "supplier_id")}>
                      <TableCell className="font-medium">{s(r, "name")}</TableCell>
                      <TableCell>{money(n(r, "total_billed"), currency)}</TableCell>
                      <TableCell>{money(n(r, "total_paid"), currency)}</TableCell>
                      <TableCell className={n(r, "outstanding") > 0 ? "font-semibold text-destructive" : undefined}>
                        {money(n(r, "outstanding"), currency)}
                      </TableCell>
                    </TableRow>
                  ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-0">
          {billRows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("supplier")}</TableHead>
                  <TableHead>{t("invoice_number")}</TableHead>
                  <TableHead>{t("net")}</TableHead>
                  <TableHead>{t("paid_amount")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {billRows.map((b) => {
                  const outstandingAmt = n(b, "total_amount") - n(b, "paid_amount");
                  return (
                    <TableRow key={s(b, "id")}>
                      <TableCell dir="ltr">{formatDate(s(b, "bill_date"))}</TableCell>
                      <TableCell className="font-medium">{s(b, "suppliers") ? (b["suppliers"] as Row).name as string : "—"}</TableCell>
                      <TableCell dir="ltr">{s(b, "invoice_number") || "—"}</TableCell>
                      <TableCell>{money(n(b, "total_amount"), currency)}</TableCell>
                      <TableCell>{money(n(b, "paid_amount"), currency)}</TableCell>
                      <TableCell>{t(s(b, "status"))}</TableCell>
                      <TableCell className="no-print text-end">
                        {(can("debts.create") || can("accounting.create")) && outstandingAmt > 0 ? (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => {
                              setPayTarget(b);
                              setAmount(String(outstandingAmt));
                            }}
                          >
                            {t("record_payment")}
                          </Button>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={billOpen} onOpenChange={setBillOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("new_supplier_bill")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <Field label={`${t("supplier")} *`}>
              <Select value={supplierId} onValueChange={setSupplierId}>
                <SelectTrigger>
                  <SelectValue placeholder={t("select_medicine")} />
                </SelectTrigger>
                <SelectContent>
                  {((suppliers.data ?? []) as Row[]).map((sp) => (
                    <SelectItem key={s(sp, "id")} value={s(sp, "id")}>
                      {s(sp, "name")}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
            <Field label={t("invoice_number")}>
              <Input dir="ltr" value={invoiceNumber} onChange={(e) => setInvoiceNumber(e.target.value)} />
            </Field>
            <Field label={`${t("subtotal")} *`}>
              <Input type="number" dir="ltr" value={subtotal} onChange={(e) => setSubtotal(e.target.value)} />
            </Field>
            <Field label={t("discount")}>
              <Input type="number" dir="ltr" value={discount} onChange={(e) => setDiscount(e.target.value)} />
            </Field>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setBillOpen(false)}>
              {t("cancel")}
            </Button>
            <Button disabled={!supplierId || !subtotal || createBill.isPending} onClick={() => createBill.mutate(undefined as never)}>
              {createBill.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={Boolean(payTarget)} onOpenChange={(o) => (o ? null : setPayTarget(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("record_payment")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <Field label={`${t("amount")} *`}>
              <Input type="number" dir="ltr" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </Field>
            <Field label={t("payment_method")}>
              <Select value={method} onValueChange={setMethod}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cash">{t("cash")}</SelectItem>
                  <SelectItem value="bank">{t("bank")}</SelectItem>
                </SelectContent>
              </Select>
            </Field>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPayTarget(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={pay.isPending} onClick={() => pay.mutate(undefined as never)}>
              {pay.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
