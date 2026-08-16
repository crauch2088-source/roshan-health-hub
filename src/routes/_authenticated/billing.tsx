import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatCard, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/billing")({
  head: () => ({
    meta: [
      { title: "Billing — ROSHAN Medical Center" },
      { name: "description", content: "Create invoices, record payments and track outstanding balances." },
      { property: "og:title", content: "Billing — ROSHAN Medical Center" },
      { property: "og:description", content: "Create invoices, record payments and track outstanding balances." },
    ],
  }),
  component: BillingPage,
});

type Line = { description: string; quantity: string; unit_price: string; item_type: string };

function BillingPage() {
  const { t } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const navigate = useNavigate();
  const [date, setDate] = useState(todayISO());
  const [open, setOpen] = useState(false);
  const [patientId, setPatientId] = useState("");
  const [partnerId, setPartnerId] = useState("");
  const [discount, setDiscount] = useState("0");
  const [lines, setLines] = useState<Line[]>([
    { description: "", quantity: "1", unit_price: "0", item_type: "consultation" },
  ]);

  const invoices = useRows(["invoices", date], () =>
    supabase
      .from("invoices")
      .select(
        "id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, patients(full_name, mrn), partners(name)",
      )
      .eq("invoice_date", date)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const patients = useRows(["patients-lite"], () =>
    supabase.from("patients").select("id, full_name, mrn").is("deleted_at", null).limit(500),
  );
  const partners = useRows(["partners"], () =>
    supabase.from("partners").select("id, name, discount_percent").is("deleted_at", null),
  );

  const subtotal = lines.reduce((sum, l) => sum + Number(l.quantity || 0) * Number(l.unit_price || 0), 0);
  const net = Math.max(subtotal - Number(discount || 0), 0);

  const create = useSave(
    async () => {
      const invoiceNumber = await rpc<string>("next_invoice_number");
      const { data: inv, error } = await supabase
        .from("invoices")
        .insert({
          invoice_number: invoiceNumber,
          patient_id: patientId,
          partner_id: partnerId || null,
          invoice_date: date,
          total_amount: subtotal,
          discount_amount: Number(discount) || 0,
          net_amount: net,
          paid_amount: 0,
          status: "unpaid",
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);
      const items = lines
        .filter((l) => l.description)
        .map((l) => ({
          invoice_id: inv.id,
          description: l.description,
          item_type: l.item_type,
          quantity: Number(l.quantity) || 1,
          unit_price: Number(l.unit_price) || 0,
          total_price: (Number(l.quantity) || 1) * (Number(l.unit_price) || 0),
        }));
      if (items.length) {
        const { error: iErr } = await supabase.from("invoice_items").insert(items);
        if (iErr) throw new Error(iErr.message);
      }
      return inv.id as string;
    },
    {
      invalidate: [["invoices", date]],
      successMessage: t("saved"),
      onDone: (id) => {
        setOpen(false);
        setLines([{ description: "", quantity: "1", unit_price: "0", item_type: "consultation" }]);
        setDiscount("0");
        if (typeof id === "string") void navigate({ to: "/billing/$invoiceId", params: { invoiceId: id } });
      },
    },
  );

  const rows = (invoices.data ?? []) as Row[];
  const totalNet = rows.reduce((sum, r) => sum + n(r, "net_amount"), 0);
  const totalPaid = rows.reduce((sum, r) => sum + n(r, "paid_amount"), 0);

  if (invoices.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("billing")} subtitle={formatDate(date)}>
        <Input type="date" dir="ltr" value={date} onChange={(e) => setDate(e.target.value)} className="w-40" />
        <ExportButtons rows={rows} filename={`roshan-invoices-${date}`} />
        {can("billing.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("new_invoice")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] max-w-3xl overflow-y-auto">
              <DialogHeader>
                <DialogTitle>{t("new_invoice")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label={`${t("patient")} *`}>
                    <Select value={patientId} onValueChange={setPatientId}>
                      <SelectTrigger>
                        <SelectValue placeholder={t("search")} />
                      </SelectTrigger>
                      <SelectContent className="max-h-72">
                        {((patients.data ?? []) as Row[]).map((p) => (
                          <SelectItem key={s(p, "id")} value={s(p, "id")}>
                            {s(p, "full_name")} — {s(p, "mrn")}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                  <Field label={t("partners")}>
                    <Select value={partnerId} onValueChange={setPartnerId}>
                      <SelectTrigger>
                        <SelectValue placeholder={t("cash")} />
                      </SelectTrigger>
                      <SelectContent>
                        {((partners.data ?? []) as Row[]).map((p) => (
                          <SelectItem key={s(p, "id")} value={s(p, "id")}>
                            {s(p, "name")}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                </div>

                <div className="space-y-2">
                  {lines.map((l, idx) => (
                    <div key={idx} className="grid gap-2 rounded-md border p-2 sm:grid-cols-5">
                      <Input
                        className="sm:col-span-2"
                        placeholder={t("description")}
                        value={l.description}
                        onChange={(e) =>
                          setLines(lines.map((x, i) => (i === idx ? { ...x, description: e.target.value } : x)))
                        }
                      />
                      <Select
                        value={l.item_type}
                        onValueChange={(v) => setLines(lines.map((x, i) => (i === idx ? { ...x, item_type: v } : x)))}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="consultation">{t("consultation_fee")}</SelectItem>
                          <SelectItem value="lab">{t("laboratory")}</SelectItem>
                          <SelectItem value="pharmacy">{t("pharmacy")}</SelectItem>
                          <SelectItem value="procedure">{t("procedure")}</SelectItem>
                          <SelectItem value="other">{t("other")}</SelectItem>
                        </SelectContent>
                      </Select>
                      <Input
                        type="number"
                        dir="ltr"
                        min={1}
                        placeholder={t("quantity")}
                        value={l.quantity}
                        onChange={(e) =>
                          setLines(lines.map((x, i) => (i === idx ? { ...x, quantity: e.target.value } : x)))
                        }
                      />
                      <div className="flex gap-2">
                        <Input
                          type="number"
                          dir="ltr"
                          min={0}
                          placeholder={t("unit_price")}
                          value={l.unit_price}
                          onChange={(e) =>
                            setLines(lines.map((x, i) => (i === idx ? { ...x, unit_price: e.target.value } : x)))
                          }
                        />
                        <Button variant="ghost" size="icon" onClick={() => setLines(lines.filter((_, i) => i !== idx))}>
                          <Trash2 className="size-4" />
                        </Button>
                      </div>
                    </div>
                  ))}
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() =>
                      setLines([...lines, { description: "", quantity: "1", unit_price: "0", item_type: "other" }])
                    }
                  >
                    <Plus className="size-4" /> {t("add")}
                  </Button>
                </div>

                <div className="grid gap-4 sm:grid-cols-3">
                  <Field label={t("subtotal")}>
                    <Input readOnly dir="ltr" value={money(subtotal, currency)} />
                  </Field>
                  <Field label={t("discount")}>
                    <Input type="number" dir="ltr" min={0} value={discount} onChange={(e) => setDiscount(e.target.value)} />
                  </Field>
                  <Field label={t("net")}>
                    <Input readOnly dir="ltr" value={money(net, currency)} />
                  </Field>
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!patientId || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={invoices.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <StatCard label={t("invoices")} value={String(rows.length)} />
        <StatCard label={t("net")} value={money(totalNet, currency)} />
        <StatCard label={t("outstanding")} value={money(totalNet - totalPaid, currency)} />
      </div>

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("invoice_number")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("net")}</TableHead>
                  <TableHead>{t("paid")}</TableHead>
                  <TableHead>{t("balance")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((inv) => (
                  <TableRow key={s(inv, "id")}>
                    <TableCell dir="ltr" className="font-mono text-xs">
                      {s(inv, "invoice_number")}
                    </TableCell>
                    <TableCell className="font-medium">{s(rel(inv, "patients"), "full_name")}</TableCell>
                    <TableCell>{money(n(inv, "net_amount"), currency)}</TableCell>
                    <TableCell>{money(n(inv, "paid_amount"), currency)}</TableCell>
                    <TableCell>{money(n(inv, "net_amount") - n(inv, "paid_amount"), currency)}</TableCell>
                    <TableCell>
                      <StatusBadge status={s(inv, "status")} />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      <Button asChild size="sm">
                        <Link to="/billing/$invoiceId" params={{ invoiceId: s(inv, "id") }}>
                          {t("open")}
                        </Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
