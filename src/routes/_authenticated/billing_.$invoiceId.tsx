import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, Printer } from "lucide-react";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
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
import { useAuth } from "@/lib/auth";
import { n, rel, rpc, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { PaperWidthSelect } from "@/components/paper-width-select";
import { getClinicIdentity, getReceiptPrintState, useDocumentPrint, type PaperWidth } from "@/lib/document-print";
import { formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

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

type InvoicePrintRequest =
  | { kind: "invoice" }
  | { kind: "receipt"; payment: Row; status: Row; state: "active" | "void" | "inconsistent" };

function InvoicePageInner() {
  const { invoiceId } = useParams({
    from: "/_authenticated/billing_/$invoiceId",
  });

  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency, settings } = useSettings();
  const [paperWidth, setPaperWidth] = useState<PaperWidth>("a4");
  const { request: printRequest, printDocument } = useDocumentPrint<InvoicePrintRequest>();

  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");
  const [reference, setReference] = useState("");

  const invoiceQ = useRows(["invoice", invoiceId], () =>
    supabase
      .from("invoices")
      .select(
        "id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, notes, branch_id, patients(id, full_name, mrn, phone), partners(name)",
      )
      .eq("id", invoiceId)
      .limit(1),
  );

  const invoice = ((invoiceQ.data ?? []) as Row[])[0];
  const invoiceBranchId = s(invoice, "branch_id");
  const branchQ = useRows<Row[]>(["invoice-branch", invoiceBranchId], () =>
    supabase.from("branches").select("id, branch_name, name, address, phone").eq("id", invoiceBranchId).limit(1),
    { enabled: Boolean(invoiceBranchId) },
  );
  const branch = ((branchQ.data ?? []) as Row[])[0];
  const clinic = getClinicIdentity(settings, branch, lang);

  const itemsQ = useRows(["invoice-items", invoiceId], () =>
    supabase.from("invoice_items").select("*").eq("invoice_id", invoiceId),
  );

  const paymentsQ = useRows<Row[]>(["payments", invoiceId], () =>
    supabase
      .from("payments")
      .select("id, amount, payment_method, method, payment_date, created_at, received_at, received_by, reference, reference_no, deleted_at, users!payments_received_by_fkey(full_name)")
      .eq("invoice_id", invoiceId)
      .order("created_at", { ascending: false }),
    { enabled: can("payments.read") },
  );
  const payments = (paymentsQ.data ?? []) as Row[];
  const paymentIds = payments.map((payment) => s(payment, "id")).filter(Boolean);
  const receiptStatusQ = useRows<Row[]>(
    ["payment-receipt-status", invoiceId, paymentIds.join(",")],
    () => supabase.rpc("get_invoice_payment_receipt_status", { _payment_ids: paymentIds }),
    { enabled: can("payments.read") && paymentIds.length > 0 },
  );
  const receiptStatusById = new Map(
    ((receiptStatusQ.data ?? []) as Row[]).map((status) => [s(status, "payment_id"), status]),
  );

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

  return (
    <div>
      <PageHeader
        title={`${t("invoice")} ${s(invoice, "invoice_number")}`}
        subtitle={`${s(patient, "full_name")} · ${t("mrn")}: ${s(patient, "mrn")} · ${formatDate(
          s(invoice, "invoice_date"),
        )}`}
      >
        <StatusBadge status={s(invoice, "status")} />

        <PaperWidthSelect value={paperWidth} onChange={setPaperWidth} lang={lang} />
        <Button variant="outline" size="sm" disabled={itemsQ.isLoading || Boolean(itemsQ.error)} onClick={() => printDocument({ kind: "invoice" }, paperWidth)}>
          <Printer className="size-4" /> {lang === "ar" ? "طباعة الفاتورة" : "Print invoice"}
        </Button>

        <Button asChild variant="outline" size="sm">
          <Link to="/billing">
            <ArrowLeft className="size-4" />
            {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox error={invoiceQ.error ?? itemsQ.error ?? (can("payments.read") ? paymentsQ.error : null)} />

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className={`print-area print-surface lg:col-span-2 ${printRequest?.document.kind === "receipt" ? "print-hide" : ""}`}>
          <CardContent className="p-4">
            <div className="mb-4 border-b pb-3 text-center">
              <p className="text-lg font-bold">{clinic.name}</p>
              {clinic.branchName ? <p className="text-sm">{clinic.branchName}</p> : null}
              {clinic.address ? <p className="text-xs">{clinic.address}</p> : null}
              {clinic.phone ? <p className="text-xs" dir="ltr">{clinic.phone}</p> : null}
              <h2 className="mt-3 text-base font-bold">{lang === "ar" ? "فاتورة" : "Invoice"}</h2>
              <p className="text-xs">
                {lang === "ar" ? "رقم الفاتورة" : "Invoice #"}: <bdi dir="ltr">{s(invoice, "invoice_number") || "—"}</bdi>
                {" · "}{formatDate(s(invoice, "invoice_date"))}
              </p>
            </div>

            <div className="mb-4 grid gap-2 border-b pb-3 text-sm sm:grid-cols-2">
              <p><span className="text-muted-foreground">{lang === "ar" ? "المريض" : "Patient"}: </span>{s(patient, "full_name") || "—"}</p>
              <p><span className="text-muted-foreground">{t("mrn")}: </span><bdi dir="ltr">{s(patient, "mrn") || "—"}</bdi></p>
              {s(patient, "phone") ? <p><span className="text-muted-foreground">{t("phone")}: </span><bdi dir="ltr">{s(patient, "phone")}</bdi></p> : null}
              {s(rel(invoice, "partners"), "name") ? <p><span className="text-muted-foreground">{lang === "ar" ? "الجهة" : "Partner"}: </span>{s(rel(invoice, "partners"), "name")}</p> : null}
            </div>

            <SectionTitle>{t("items")}</SectionTitle>

            {items.length === 0 ? (
              <Empty />
            ) : (
              <div className="space-y-2">
                {items.map((item) => (
                  <div key={s(item, "id")} className="print-keep flex items-start justify-between gap-3 border-b pb-2 text-sm">
                    <div className="min-w-0 flex-1">
                      <p className="break-words font-medium">
                        {s(item, "item_name") || s(item, "description") || s(item, "item_type") || "—"}
                      </p>
                      <p className="text-xs text-muted-foreground" dir="ltr">
                        {n(item, "quantity")} × {money(n(item, "unit_price"), currency)}
                      </p>
                    </div>
                    <p className="shrink-0 font-semibold" dir="ltr">{money(n(item, "total_price"), currency)}</p>
                  </div>
                ))}
              </div>
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
            {s(invoice, "notes") ? (
              <p className="mt-4 whitespace-pre-wrap border-t pt-3 text-xs">
                <span className="font-semibold">{lang === "ar" ? "ملاحظات" : "Notes"}: </span>{s(invoice, "notes")}
              </p>
            ) : null}
            {settings["invoice_footer"] ? (
              <p className="mt-4 border-t pt-3 text-center text-xs">{settings["invoice_footer"]}</p>
            ) : null}
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

          {can("payments.read") ? (
            <Card>
              <CardContent className="p-4">
                <SectionTitle>{t("payments")}</SectionTitle>
                {receiptStatusQ.error ? (
                  <p role="status" className="mb-3 rounded-md border border-warning/40 bg-warning/10 p-2 text-xs text-warning-foreground">
                    {lang === "ar"
                      ? "التحقق من دفتر الدفع غير متاح في قاعدة البيانات الحالية؛ تمت إيقاف طباعة الإيصالات حتى تثبيت تحديث التحقق."
                      : "Payment-ledger verification is unavailable in this database. Receipt printing is disabled until the verification migration is installed."}
                  </p>
                ) : null}
                {payments.length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="space-y-2 text-sm">
                    {payments.map((payment) => {
                      const status = receiptStatusById.get(s(payment, "id"));
                      const state = getReceiptPrintState(payment, status);
                      const paymentMethod = s(payment, "method") || s(payment, "payment_method");
                      return (
                        <li key={s(payment, "id")} className="flex items-center justify-between gap-2 rounded-md border p-2">
                          <div className="min-w-0">
                            <p className="font-semibold" dir="ltr">{money(n(payment, "amount"), currency)}</p>
                            <p className="text-xs text-muted-foreground">
                              {t(paymentMethod) === paymentMethod ? paymentMethod : t(paymentMethod)} ·{" "}
                              {formatDateTime(s(payment, "received_at") || s(payment, "created_at") || s(payment, "payment_date"))}
                            </p>
                            <p className="text-xs">
                              {state === "active"
                                ? (lang === "ar" ? "إيصال مطابق" : "Ledger verified")
                                : state === "void"
                                  ? (lang === "ar" ? "إيصال ملغي" : "Voided receipt")
                                  : (lang === "ar" ? "غير قابل للتحقق" : "Unverified")}
                            </p>
                          </div>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={state === "inconsistent" || receiptStatusQ.isLoading || !status}
                            title={lang === "ar" ? "طباعة الإيصال" : "Print receipt"}
                            aria-label={lang === "ar" ? "طباعة الإيصال" : "Print receipt"}
                            onClick={() => status && printDocument({ kind: "receipt", payment, status, state }, paperWidth)}
                          >
                            <Printer className="size-4" />
                          </Button>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </CardContent>
            </Card>
          ) : null}
        </div>
      </div>
      {printRequest?.document.kind === "receipt" ? (
        <div className="print-only print-area print-surface mx-auto max-w-[180mm] p-4" dir={lang === "ar" ? "rtl" : "ltr"}>
          <header className="mb-4 border-b pb-3 text-center">
            <p className="text-lg font-bold">{clinic.name}</p>
            {clinic.branchName ? <p className="text-sm">{clinic.branchName}</p> : null}
            {clinic.address ? <p className="text-xs">{clinic.address}</p> : null}
            {clinic.phone ? <p className="text-xs" dir="ltr">{clinic.phone}</p> : null}
            <h1 className="mt-3 text-base font-bold">{lang === "ar" ? "إيصال دفع" : "Payment receipt"}</h1>
          </header>
          {printRequest.document.state === "void" ? (
            <div className="mb-4 border-2 border-black p-2 text-center text-lg font-extrabold">
              {lang === "ar" ? "ملغي — VOID" : "VOID — CANCELLED"}
            </div>
          ) : null}
          <div className="space-y-2 text-sm">
            <div className="flex justify-between gap-3"><span>{lang === "ar" ? "رقم الفاتورة" : "Invoice #"}</span><bdi dir="ltr">{s(invoice, "invoice_number") || "—"}</bdi></div>
            <div className="flex justify-between gap-3"><span>{lang === "ar" ? "المريض" : "Patient"}</span><span>{s(patient, "full_name") || "—"}</span></div>
            <div className="flex justify-between gap-3"><span>{t("mrn")}</span><bdi dir="ltr">{s(patient, "mrn") || "—"}</bdi></div>
            <div className="flex justify-between gap-3"><span>{lang === "ar" ? "تاريخ الدفع" : "Payment date"}</span><bdi dir="ltr">{formatDateTime(s(printRequest.document.payment, "received_at") || s(printRequest.document.payment, "created_at") || s(printRequest.document.payment, "payment_date"))}</bdi></div>
            <div className="flex justify-between gap-3"><span>{t("payment_method")}</span><span>{s(printRequest.document.payment, "method") || s(printRequest.document.payment, "payment_method") || "—"}</span></div>
            <div className="flex justify-between gap-3"><span>{t("reference")}</span><bdi dir="ltr">{s(printRequest.document.payment, "reference") || s(printRequest.document.payment, "reference_no") || "—"}</bdi></div>
            <div className="flex justify-between gap-3"><span>{lang === "ar" ? "استلم بواسطة" : "Received by"}</span><span>{s(rel(printRequest.document.payment, "users"), "full_name") || "—"}</span></div>
            <div className="mt-3 flex justify-between gap-3 border-t pt-3 text-base font-bold"><span>{lang === "ar" ? "المبلغ" : "Amount"}</span><bdi dir="ltr">{money(n(printRequest.document.payment, "amount"), currency)}</bdi></div>
          </div>
          {printRequest.document.state === "void" ? (
            <div className="mt-4 border-t pt-3 text-sm">
              <p className="font-semibold">{lang === "ar" ? "سبب الإلغاء" : "Reversal reason"}: {s(printRequest.document.status, "reversal_reason") || "—"}</p>
              <p>{lang === "ar" ? "وقت الإلغاء" : "Reversed at"}: <bdi dir="ltr">{formatDateTime(s(printRequest.document.status, "reversal_at"))}</bdi></p>
            </div>
          ) : null}
          {settings["receipt_footer"] ? <p className="mt-5 border-t pt-3 text-center text-xs">{settings["receipt_footer"]}</p> : null}
        </div>
      ) : null}
    </div>
  );
}
