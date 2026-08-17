import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader, PrintButton, SectionTitle, StatusBadge } from "@/components/kit";
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
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/billing/$invoiceId")({
  head: () => ({
    meta: [
      { title: "Invoice — ROSHAN Medical Center" },
      { name: "description", content: "Printable invoice with line items, payments and outstanding balance." },
      { property: "og:title", content: "Invoice — ROSHAN Medical Center" },
      { property: "og:description", content: "Printable invoice with line items, payments and outstanding balance." },
    ],
  }),
  component: InvoicePage,
});

function InvoicePage() {
  const { invoiceId } = useParams({ from: "/_authenticated/billing/$invoiceId" });
  const { t } = useLang();
  const { can, user } = useAuth();
  const { currency, settings } = useSettings();
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");

  const invoiceQ = useRows(["invoice", invoiceId], () =>
    supabase
      .from("invoices")
      .select(
        "id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, notes, patients(id, full_name, mrn, phone), partners(name)",
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
      .select("id, amount, payment_method, payment_date, created_at")
      .eq("invoice_id", invoiceId)
      .order("created_at", { ascending: false }),
  );

  const pay = useSave(
    async () => {
      const value = Number(amount);
      if (!value || value <= 0) throw new Error(t("invalid_amount"));
      const { error } = await supabase.from("payments").insert({
        invoice_id: invoiceId,
        patient_id: s(rel(invoice, "patients"), "id"),
        amount: value,
        payment_method: method,
        payment_date: new Date().toISOString().slice(0, 10),
        received_by: user?.id ?? null,
      });
      if (error) throw new Error(error.message);

      const paid = n(invoice, "paid_amount") + value;
      const net = n(invoice, "net_amount");
      const status = paid >= net ? "paid" : paid > 0 ? "partial" : "unpaid";
      const { error: uErr } = await supabase
        .from("invoices")
        .update({ paid_amount: paid, status })
        .eq("id", invoiceId);
      if (uErr) throw new Error(uErr.message);
      return null;
    },
    {
      invalidate: [["invoice", invoiceId], ["payments", invoiceId], ["invoices"]],
      successMessage: t("saved"),
      onDone: () => setAmount(""),
    },
  );

  if (invoiceQ.isLoading) return <Loading />;
  if (!invoice) return <Empty label={t("no_data")} />;

  const patient = rel(invoice, "patients");
  const items = (itemsQ.data ?? []) as Row[];
  const balance = n(invoice, "net_amount") - n(invoice, "paid_amount");

  return (
    <div>
      <PageHeader
        title={`${t("invoice")} ${s(invoice, "invoice_number")}`}
        subtitle={`${s(patient, "full_name")} · ${t("mrn")}: ${s(patient, "mrn")} · ${formatDate(s(invoice, "invoice_date"))}`}
      >
        <StatusBadge status={s(invoice, "status")} />
        <PrintButton />
        <Button asChild variant="outline" size="sm">
          <Link to="/billing">
            <ArrowLeft className="size-4" /> {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox error={invoiceQ.error} />

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardContent className="p-4">
            <div className="mb-4 border-b pb-3">
              <p className="text-lg font-semibold text-primary">
                {settings["clinic_name"] || t("app_name")}
              </p>
              <p className="text-xs text-muted-foreground">
                {settings["clinic_address"] || ""} {settings["clinic_phone"] || ""}
              </p>
            </div>
            <SectionTitle>{t("items")}</SectionTitle>
            {items.length === 0 ? (
              <Empty />
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("description")}</TableHead>
                    <TableHead>{t("quantity")}</TableHead>
                    <TableHead>{t("unit_price")}</TableHead>
                    <TableHead>{t("total")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {items.map((it) => (
                    <TableRow key={s(it, "id")}>
                      <TableCell>{s(it, "description")}</TableCell>
                      <TableCell dir="ltr">{n(it, "quantity")}</TableCell>
                      <TableCell>{money(n(it, "unit_price"), currency)}</TableCell>
                      <TableCell>{money(n(it, "total_price"), currency)}</TableCell>
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
          </CardContent>
        </Card>

        <div className="space-y-4">
          {can("payments.create") ? (
            <Card className="no-print">
              <CardContent className="grid gap-4 p-4">
                <SectionTitle>{t("record_payment")}</SectionTitle>
                <Field label={t("amount")}>
                  <Input type="number" dir="ltr" min={0} value={amount} onChange={(e) => setAmount(e.target.value)} />
                </Field>
                <Field label={t("payment_method")}>
                  <Select value={method} onValueChange={setMethod}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="cash">{t("cash")}</SelectItem>
                      <SelectItem value="bank">{t("bank")}</SelectItem>
                      <SelectItem value="mobile">{t("mobile_money")}</SelectItem>
                      <SelectItem value="insurance">{t("insurance")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Button disabled={pay.isPending} onClick={() => pay.mutate(undefined as never)}>
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
                <ul className="space-y-2 text-sm">
                  {((paymentsQ.data ?? []) as Row[]).map((p) => (
                    <li key={s(p, "id")} className="flex justify-between rounded-md border p-2">
                      <span>{money(n(p, "amount"), currency)}</span>
                      <span className="text-muted-foreground">
                        {t(s(p, "payment_method"))} · {formatDateTime(s(p, "created_at"))}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
