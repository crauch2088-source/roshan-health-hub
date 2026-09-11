import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
  PrintButton,
  SectionTitle,
  StatusBadge, PermissionGate } from "@/components/kit";
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
import {
  n,
  rel,
  rpc,
  s,
  useRows,
  useSave,
  useSettings,
  type Row,
} from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/billing_/$invoiceId")({
  head: () => ({
    meta: [
      { title: "Invoice — ROSHAN Medical Center" },
      {
        name: "description",
        content:
          "Printable invoice with line items, payments and outstanding balance.",
      },
      {
        property: "og:title",
        content: "Invoice — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Printable invoice with line items, payments and outstanding balance.",
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

  const { t } = useLang();
  const { can } = useAuth();
  const { currency, settings } = useSettings();

  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");
  const [reference, setReference] = useState("");

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
    supabase
      .from("invoice_items")
      .select("*")
      .eq("invoice_id", invoiceId),
  );

  const paymentsQ = useRows(["payments", invoiceId], () =>
    supabase
      .from("payments")
      .select(
        "id, amount, payment_method, payment_date, created_at",
      )
      .eq("invoice_id", invoiceId)
      .order("created_at", { ascending: false }),
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
        throw new Error(
          t("invalid_amount") || "مبلغ غير صالح",
        );
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

  const balance =
    n(invoice, "net_amount") -
    n(invoice, "paid_amount");

  return (
    <div>
      <PageHeader
        title={`${t("invoice")} ${s(
          invoice,
          "invoice_number",
        )}`}
        subtitle={`${s(
          patient,
          "full_name",
        )} · ${t("mrn")}: ${s(
          patient,
          "mrn",
        )} · ${formatDate(
          s(invoice, "invoice_date"),
        )}`}
      >
        <StatusBadge
          status={s(invoice, "status")}
        />

        <PrintButton />

        <Button
          asChild
          variant="outline"
          size="sm"
        >
          <Link to="/billing">
            <ArrowLeft className="size-4" />
            {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox
        error={
          invoiceQ.error ??
          itemsQ.error ??
          paymentsQ.error
        }
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="print-area lg:col-span-2">
          <CardContent className="p-4">
            <div className="mb-4 border-b pb-3">
              <p className="text-lg font-semibold text-primary">
                {settings["clinic_name"] ||
                  t("app_name")}
              </p>

              <p className="text-xs text-muted-foreground">
                {settings["clinic_address"] || ""}{" "}
                {settings["clinic_phone"] || ""}
              </p>
            </div>

            <SectionTitle>
              {t("items")}
            </SectionTitle>

            {items.length === 0 ? (
              <Empty />
            ) : (
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>
                      {t("description")}
                    </TableHead>

                    <TableHead>
                      {t("quantity")}
                    </TableHead>

                    <TableHead>
                      {t("unit_price")}
                    </TableHead>

                    <TableHead>
                      {t("total")}
                    </TableHead>
                  </TableRow>
                </TableHeader>

                <TableBody>
                  {items.map((item) => (
                    <TableRow
                      key={s(item, "id")}
                    >
                      <TableCell>
                        {s(item, "item_name") ||
                          s(item, "description") ||
                          s(item, "item_type") ||
                          "—"}
                      </TableCell>

                      <TableCell dir="ltr">
                        {n(item, "quantity")}
                      </TableCell>

                      <TableCell>
                        {money(
                          n(item, "unit_price"),
                          currency,
                        )}
                      </TableCell>

                      <TableCell>
                        {money(
                          n(item, "total_price"),
                          currency,
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}

            <div className="mt-4 space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">
                  {t("subtotal")}
                </span>

                <span>
                  {money(
                    n(invoice, "total_amount"),
                    currency,
                  )}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-muted-foreground">
                  {t("discount")}
                </span>

                <span>
                  {money(
                    n(invoice, "discount_amount"),
                    currency,
                  )}
                </span>
              </div>

              <div className="flex justify-between font-semibold">
                <span>{t("net")}</span>

                <span>
                  {money(
                    n(invoice, "net_amount"),
                    currency,
                  )}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-muted-foreground">
                  {t("paid")}
                </span>

                <span>
                  {money(
                    n(invoice, "paid_amount"),
                    currency,
                  )}
                </span>
              </div>

              <div className="flex justify-between font-semibold text-primary">
                <span>{t("balance")}</span>

                <span>
                  {money(balance, currency)}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="space-y-4">
          {can("payments.create") ? (
            <Card className="no-print">
              <CardContent className="grid gap-4 p-4">
                <SectionTitle>
                  {t("record_payment")}
                </SectionTitle>

                <Field label={t("amount")}>
                  <Input
                    type="number"
                    dir="ltr"
                    min={0}
                    value={amount}
                    onChange={(event) =>
                      setAmount(
                        event.target.value,
                      )
                    }
                  />
                </Field>

                <Field
                  label={t("payment_method")}
                >
                  <Select
                    value={method}
                    onValueChange={setMethod}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>

                    <SelectContent>
                      <SelectItem value="cash">
                        {t("cash")}
                      </SelectItem>

                      <SelectItem value="bank">
                        {t("bank")}
                      </SelectItem>

                      <SelectItem value="bankak">
                        Bankak / بنكك
                      </SelectItem>

                      <SelectItem value="mobile">
                        {t("mobile_money")}
                      </SelectItem>

                      <SelectItem value="insurance">
                        {t("insurance")}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </Field>

                {(method === "bankak" ||
                  method === "mobile" ||
                  method === "bank") && (
                  <Field
                    label={
                      t("reference") ||
                      "Transaction reference"
                    }
                  >
                    <Input
                      dir="ltr"
                      value={reference}
                      onChange={(event) =>
                        setReference(
                          event.target.value,
                        )
                      }
                      placeholder="Reference / transaction number"
                    />
                  </Field>
                )}

                <Button
                  disabled={
                    pay.isPending ||
                    balance <= 0
                  }
                  onClick={() =>
                    pay.mutate(
                      undefined as never,
                    )
                  }
                >
                  {pay.isPending
                    ? t("saving")
                    : t("save")}
                </Button>
              </CardContent>
            </Card>
          ) : null}

          <Card>
            <CardContent className="p-4">
              <SectionTitle>
                {t("payments")}
              </SectionTitle>

              {(
                (paymentsQ.data ??
                  []) as Row[]
              ).length === 0 ? (
                <Empty />
              ) : (
                <ul className="space-y-2 text-sm">
                  {(
                    (paymentsQ.data ??
                      []) as Row[]
                  ).map((payment) => (
                    <li
                      key={s(
                        payment,
                        "id",
                      )}
                      className="flex justify-between rounded-md border p-2"
                    >
                      <span>
                        {money(
                          n(
                            payment,
                            "amount",
                          ),
                          currency,
                        )}
                      </span>

                      <span className="text-muted-foreground">
                        {t(
                          s(
                            payment,
                            "payment_method",
                          ),
                        )}{" "}
                        ·{" "}
                        {formatDateTime(
                          s(
                            payment,
                            "created_at",
                          ),
                        )}
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