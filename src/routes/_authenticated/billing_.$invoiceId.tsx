import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, Printer } from "lucide-react";
import { flushSync } from "react-dom";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
  PrintButton,
  SectionTitle,
  StatusBadge,
  PermissionGate,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
import { n, rel, rpc, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { buildInvoicePaymentReceiptModel, ROSHAN_CURRENCY } from "@/lib/print/receipt";

export const Route = createFileRoute("/_authenticated/billing_/$invoiceId")({
  head: () => ({
    meta: [
      { title: "Invoice — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Printable invoice with line items, payments and outstanding balance.",
      },
      {
        property: "og:title",
        content: "Invoice — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content: "Printable invoice with line items, payments and outstanding balance.",
      },
    ],
  }),
  component: InvoicePage,
});

function InvoicePage() {
  return (
    <PermissionGate perm="billing.read">
      <InvoicePageInner />
    </PermissionGate>
  );
}

function InvoicePageInner() {
  const { invoiceId } = useParams({
    from: "/_authenticated/billing_/$invoiceId",
  });

  const { t, lang } = useLang();
  const { can, user } = useAuth();
  const { currency, settings } = useSettings();

  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");
  const [reference, setReference] = useState("");
  const [printingPaymentId, setPrintingPaymentId] = useState<string | null>(null);

  const invoiceQ = useRows(["invoice", invoiceId], () =>
    supabase
      .from("invoices")
      .select(
        "id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, notes, branch_id, deleted_at, patients(id, full_name, mrn, phone, branch_id, deleted_at), partners(name)",
      )
      .eq("id", invoiceId)
      .limit(1),
  );

  const invoice = ((invoiceQ.data ?? []) as Row[])[0];

  const itemsQ = useRows(["invoice-items", invoiceId], () =>
    supabase.from("invoice_items").select("*").eq("invoice_id", invoiceId),
  );

  const paymentsQ = useRows(["payments", invoiceId], () =>
    supabase
      .from("payments")
      .select(
        "id, invoice_id, amount, payment_method, method, reference_no, reference, received_at, received_by, branch_id, deleted_at, created_at, received_user:users!payments_received_by_fkey(full_name, deleted_at, active)",
      )
      .eq("invoice_id", invoiceId)
      .order("created_at", { ascending: false }),
  );

  const paymentIds = ((paymentsQ.data ?? []) as Row[])
    .map((payment) => s(payment, "id"))
    .filter(Boolean);
  const paymentIdKey = paymentIds.join(",");
  const receiptStatusQ = useQuery({
    queryKey: ["invoice-payment-receipt-status", invoiceId, paymentIdKey],
    queryFn: async () => {
      const batches: string[][] = [];
      for (let index = 0; index < paymentIds.length; index += 200) {
        batches.push(paymentIds.slice(index, index + 200));
      }
      const results = await Promise.all(
        batches.map((ids) =>
          rpc<Row[]>("get_invoice_payment_receipt_status", { _payment_ids: ids }),
        ),
      );
      return results.flat();
    },
    enabled: can("payments.read") && paymentIds.length > 0,
    retry: false,
  });

  // Same atomic path as Finance → Receivables: post_invoice_payment locks the
  // invoice, validates outstanding, inserts payment; triggers recompute
  // paid_amount/status and post cashbox ledger. Do not dual-write from the client.
  const pay = useSave(
    async () => {
      if (!invoice) {
        throw new Error("Invoice not found");
      }

      const value = Number(amount);

      if (!value || value <= 0) {
        throw new Error(t("invalid_amount") || "مبلغ غير صالح");
      }

      await rpc("post_invoice_payment", {
        _invoice_id: invoiceId,
        _amount: value,
        _method: method,
        _reference: reference.trim() || null,
      });

      return null;
    },
    {
      invalidate: [
        ["invoice", invoiceId],
        ["payments", invoiceId],
        ["invoices"],
        ["patient-receivables"],
        ["cashbox-balance"],
        ["cashbox-transactions"],
      ],
      successMessage: t("saved"),
      onDone: () => {
        setAmount("");
        setReference("");
      },
    },
  );

  if (invoiceQ.isLoading) {
    return <Loading />;
  }

  if (!invoice) {
    return <Empty label={t("no_data")} />;
  }

  const patient = rel(invoice, "patients");
  const items = (itemsQ.data ?? []) as Row[];

  const balance = n(invoice, "net_amount") - n(invoice, "paid_amount");

  const receiptStatuses = (receiptStatusQ.data ?? []) as Row[];
  const paymentRows = (paymentsQ.data ?? []) as Row[];
  const receiptModelFor = (payment: Row) => {
    const receivedBy = s(payment, "received_by");
    const receivedUser = rel(payment, "received_user");
    const cashierName =
      receivedBy && receivedBy === user?.id
        ? user?.full_name || ""
        : can("users.read") &&
            s(receivedUser, "active") === "true" &&
            !s(receivedUser, "deleted_at")
          ? s(receivedUser, "full_name")
          : "";
    const ledger = receiptStatuses.find((status) => s(status, "payment_id") === s(payment, "id"));
    return buildInvoicePaymentReceiptModel(payment, invoice, ledger, cashierName, ROSHAN_CURRENCY);
  };
  const selectedPayment = paymentRows.find((payment) => s(payment, "id") === printingPaymentId);
  const selectedReceipt = selectedPayment ? receiptModelFor(selectedPayment) : null;

  const handlePrintPayment = (paymentId: string) => {
    flushSync(() => setPrintingPaymentId(paymentId));
    document.body.classList.add("print-scope-active");
    const printRoot = document.getElementById("payment-receipt-print-document");
    if (!printRoot) {
      setPrintingPaymentId(null);
      return;
    }
    printRoot.classList.add("print-target-active");
    const cleanup = () => {
      printRoot.classList.remove("print-target-active");
      document.body.classList.remove("print-scope-active");
      window.removeEventListener("afterprint", cleanup);
      setPrintingPaymentId(null);
    };
    window.addEventListener("afterprint", cleanup, { once: true });
    try {
      window.print();
    } catch (error) {
      cleanup();
      throw error;
    }
  };

  return (
    <div>
      <div className="no-print">
        <PageHeader
          title={`${t("invoice")} ${s(invoice, "invoice_number")}`}
          subtitle={`${s(patient, "full_name")} · ${t("mrn")}: ${s(patient, "mrn")} · ${formatDate(
            s(invoice, "invoice_date"),
          )}`}
        >
          <StatusBadge status={s(invoice, "status")} />

          {!s(invoice, "deleted_at") && !s(patient, "deleted_at") && (
            <PrintButton scoped targetId="invoice-print-document" />
          )}

          <Button asChild variant="outline" size="sm">
            <Link to="/billing">
              <ArrowLeft className="size-4" />
              {t("back")}
            </Link>
          </Button>
        </PageHeader>
      </div>

      <div className="no-print">
        <ErrorBox error={invoiceQ.error ?? itemsQ.error ?? paymentsQ.error} />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card id="invoice-print-document" className="print-area print-document-root lg:col-span-2">
          <CardContent className="p-4">
            <div className="mb-4 border-b pb-3">
              <p className="text-lg font-semibold text-primary">
                {(lang === "ar" ? settings["center_name_ar"] : settings["center_name"]) ||
                  settings["center_name"] ||
                  settings["center_name_ar"] ||
                  t("app_name")}
              </p>

              <p className="text-xs text-muted-foreground">
                {settings["address"] || ""} {settings["phone"] || ""}
              </p>
              <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
                <p>
                  <strong>{lang === "ar" ? "رقم الفاتورة:" : "Invoice #:"}</strong>{" "}
                  {s(invoice, "invoice_number")}
                </p>
                <p>
                  <strong>{lang === "ar" ? "التاريخ:" : "Date:"}</strong>{" "}
                  {formatDate(s(invoice, "invoice_date"))}
                </p>
                <p>
                  <strong>{lang === "ar" ? "المريض:" : "Patient:"}</strong>{" "}
                  {s(patient, "full_name")}
                </p>
                <p>
                  <strong>{t("mrn")}:</strong> {s(patient, "mrn")}
                </p>
              </div>
            </div>

            <SectionTitle>{t("items")}</SectionTitle>

            {items.length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("description")}</TableHead>

                    <TableHead>{t("quantity")}</TableHead>

                    <TableHead>{t("unit_price")}</TableHead>

                    <TableHead>{t("total")}</TableHead>
                  </TableRow>
                </TableHeader>

                <TableBody>
                  {items.map((item) => (
                    <TableRow key={s(item, "id")}>
                      <TableCell>
                        {s(item, "item_name") ||
                          s(item, "description") ||
                          s(item, "item_type") ||
                          "—"}
                      </TableCell>

                      <TableCell dir="ltr">{n(item, "quantity")}</TableCell>

                      <TableCell>{money(n(item, "unit_price"), currency)}</TableCell>

                      <TableCell>{money(n(item, "total_price"), currency)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}

            <div className="mt-4 space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">{t("subtotal")}</span>

                <span>{money(n(invoice, "total_amount"), currency)}</span>
              </div>

              <div className="flex justify-between">
                <span className="text-muted-foreground">{t("discount")}</span>

                <span>{money(n(invoice, "discount_amount"), currency)}</span>
              </div>

              <div className="flex justify-between font-semibold">
                <span>{t("net")}</span>

                <span>{money(n(invoice, "net_amount"), currency)}</span>
              </div>

              <div className="flex justify-between">
                <span className="text-muted-foreground">{t("paid")}</span>

                <span>{money(n(invoice, "paid_amount"), currency)}</span>
              </div>

              <div className="flex justify-between font-semibold text-primary">
                <span>{t("balance")}</span>

                <span>{money(balance, currency)}</span>
              </div>
            </div>
            {settings["invoice_footer"] && (
              <p className="mt-6 border-t pt-3 text-xs">{settings["invoice_footer"]}</p>
            )}
          </CardContent>
        </Card>

        <div className="no-print space-y-4">
          {can("payments.create") ? (
            <Card className="no-print">
              <CardContent className="grid gap-4 p-4">
                <SectionTitle>{t("record_payment")}</SectionTitle>

                <Field label={t("amount")}>
                  <Input
                    type="number"
                    dir="ltr"
                    min={0}
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                  />
                </Field>

                <Field label={t("payment_method")}>
                  <Select value={method} onValueChange={setMethod}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>

                    <SelectContent>
                      <SelectItem value="cash">{t("cash")}</SelectItem>

                      <SelectItem value="bank">{t("bank")}</SelectItem>

                      <SelectItem value="bankak">Bankak / بنكك</SelectItem>

                      <SelectItem value="mobile">{t("mobile_money")}</SelectItem>

                      <SelectItem value="insurance">{t("insurance")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>

                {(method === "bankak" || method === "mobile" || method === "bank") && (
                  <Field label={t("reference") || "Transaction reference"}>
                    <Input
                      dir="ltr"
                      value={reference}
                      onChange={(event) => setReference(event.target.value)}
                      placeholder="Reference / transaction number"
                    />
                  </Field>
                )}

                <Button
                  disabled={pay.isPending || balance <= 0}
                  onClick={() => pay.mutate(undefined as never)}
                >
                  {pay.isPending ? t("saving") : t("save")}
                </Button>
              </CardContent>
            </Card>
          ) : null}

          <Card>
            <CardContent className="p-4">
              <SectionTitle>{t("payments")}</SectionTitle>

              {((paymentsQ.data ?? []) as Row[]).length === 0 ? (
                <Empty />
              ) : (
                <>
                  <ul className="space-y-2 text-sm">
                    {paymentRows.map((payment) => {
                      const receipt = receiptModelFor(payment);
                      return (
                        <li
                          key={s(payment, "id")}
                          className="flex flex-wrap items-center justify-between gap-2 rounded-md border p-2"
                        >
                          <span>{money(n(payment, "amount"), currency)}</span>
                          <span className="text-muted-foreground">
                            {t(s(payment, "payment_method") || s(payment, "method"))} ·{" "}
                            {formatDateTime(s(payment, "received_at") || s(payment, "created_at"))}
                          </span>
                          {can("payments.read") && (
                            <div className="flex items-center gap-2">
                              {receipt?.isReversed && (
                                <span className="text-xs font-semibold text-destructive">
                                  {lang === "ar" ? "ملغي / مسترد" : "Reversed"}
                                </span>
                              )}
                              {receipt?.complete ? (
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  aria-label={
                                    lang === "ar" ? "طباعة إيصال الدفع" : "Print payment receipt"
                                  }
                                  disabled={Boolean(printingPaymentId) || receiptStatusQ.isLoading}
                                  onClick={() => handlePrintPayment(s(payment, "id"))}
                                >
                                  <Printer className="size-4" />
                                </Button>
                              ) : (
                                <span className="text-xs text-muted-foreground">
                                  {receiptStatusQ.isLoading
                                    ? lang === "ar"
                                      ? "جارٍ التحقق من سجل الدفع…"
                                      : "Verifying payment ledger…"
                                    : lang === "ar"
                                      ? "الإيصال غير متاح: تعذر التحقق من السجل أو بيانات المستلم."
                                      : "Receipt unavailable: ledger or cashier data could not be verified."}
                                </span>
                              )}
                            </div>
                          )}
                        </li>
                      );
                    })}
                  </ul>
                  {can("payments.read") && receiptStatusQ.error && (
                    <p role="status" className="mt-3 text-xs text-muted-foreground">
                      {lang === "ar"
                        ? "طباعة الإيصالات غير مفعّلة في هذه البيئة حتى يتوفر فحص سلامة سجل الدفع."
                        : "Receipt printing is unavailable in this environment until payment-ledger verification is deployed."}
                    </p>
                  )}
                </>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
      {selectedReceipt?.complete && (
        <div className="print-only">
          <article
            id="payment-receipt-print-document"
            className="print-document-root mx-auto max-w-2xl space-y-5"
            dir={lang === "ar" ? "rtl" : "ltr"}
          >
            <header className="space-y-2 border-b pb-5 text-center">
              <h1 className="text-xl font-bold">
                {(lang === "ar" ? settings["center_name_ar"] : settings["center_name"]) ||
                  settings["center_name"] ||
                  settings["center_name_ar"] ||
                  (lang === "ar" ? "مركز روشان الطبي" : "ROSHAN Medical Center")}
              </h1>
              <p className="text-sm text-muted-foreground">
                {settings["address"] || ""} {settings["phone"] || ""}
              </p>
              <h2 className="text-lg font-semibold">
                {lang === "ar" ? "إيصال استلام دفعة" : "Payment receipt"}
              </h2>
            </header>

            {selectedReceipt.isReversed && (
              <p className="border-2 border-destructive p-3 text-center text-lg font-bold text-destructive">
                {lang === "ar"
                  ? "ملغي / مسترد — لا يثبت وجود دفعة قائمة"
                  : "REVERSED / VOID — NOT PROOF OF AN ACTIVE PAYMENT"}
              </p>
            )}

            <dl className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <dt className="text-muted-foreground">
                  {lang === "ar" ? "رقم الفاتورة" : "Invoice #"}
                </dt>
                <dd className="font-semibold" dir="ltr">
                  {selectedReceipt.invoiceNumber}
                </dd>
              </div>
              <div>
                <dt className="text-muted-foreground">
                  {lang === "ar" ? "تاريخ الاستلام" : "Received at"}
                </dt>
                <dd dir="ltr">{formatDateTime(selectedReceipt.receivedAt)}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">{lang === "ar" ? "المريض" : "Patient"}</dt>
                <dd>{selectedReceipt.patientName}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">{lang === "ar" ? "الرقم الطبي" : "MRN"}</dt>
                <dd dir="ltr">{selectedReceipt.patientMrn || "—"}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">
                  {lang === "ar" ? "طريقة الدفع" : "Payment method"}
                </dt>
                <dd>{t(selectedReceipt.paymentMethod) || selectedReceipt.paymentMethod}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">
                  {lang === "ar" ? "المستلم / أمين الصندوق" : "Cashier"}
                </dt>
                <dd>{selectedReceipt.cashierName}</dd>
              </div>
              {selectedReceipt.reference && (
                <div className="col-span-2">
                  <dt className="text-muted-foreground">
                    {lang === "ar" ? "مرجع العملية" : "Payment reference"}
                  </dt>
                  <dd dir="ltr">{selectedReceipt.reference}</dd>
                </div>
              )}
            </dl>

            <div className="space-y-2 border-y py-4 text-sm">
              <div className="flex justify-between text-base font-bold">
                <span>{lang === "ar" ? "المبلغ المستلم" : "Amount received"}</span>
                <span dir="ltr">{money(selectedReceipt.amount, selectedReceipt.currency)}</span>
              </div>
              <div className="flex justify-between">
                <span>{lang === "ar" ? "الرصيد الحالي للفاتورة" : "Current invoice balance"}</span>
                <span dir="ltr">
                  {money(selectedReceipt.currentBalance, selectedReceipt.currency)}
                </span>
              </div>
            </div>

            {selectedReceipt.isReversed && (
              <div className="space-y-1 text-sm text-destructive">
                <p>
                  {lang === "ar" ? "تاريخ الإلغاء" : "Reversal date"}:{" "}
                  {formatDateTime(selectedReceipt.reversalAt)}
                </p>
                {selectedReceipt.reversalReason && (
                  <p>
                    {lang === "ar" ? "سبب الإلغاء" : "Reversal reason"}:{" "}
                    {selectedReceipt.reversalReason}
                  </p>
                )}
              </div>
            )}

            {settings["invoice_footer"] && (
              <footer className="border-t pt-4 text-xs">{settings["invoice_footer"]}</footer>
            )}
          </article>
        </div>
      )}
    </div>
  );
}
