import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Plus, Trash2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import {
  Empty,
  ErrorBox,
  ExportButtons,
  Field,
  Loading,
  PageHeader,
  StatCard,
  StatusBadge,
  PermissionGate,
} from "@/components/kit";
import { PatientPicker, type PickedPatient } from "@/components/patient-picker";
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
import { listenForQuickAction } from "@/lib/quick-actions";
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { validateInvoiceDraft } from "@/lib/invoice-validation";
import { supabase } from "@/lib/supabase";
import { useBranchRealtime } from "@/lib/realtime";

export const Route = createFileRoute("/_authenticated/billing")({
  head: () => ({
    meta: [
      { title: "Billing — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Create invoices, record payments and track outstanding balances.",
      },
      { property: "og:title", content: "Billing — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Create invoices, record payments and track outstanding balances.",
      },
    ],
  }),
  component: BillingPage,
});

type Line = { description: string; quantity: string; unit_price: string; item_type: string };

function BillingPage() {
  return (
    <PermissionGate perm="billing.read">
      <BillingPageInner />
    </PermissionGate>
  );
}

function BillingPageInner() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const navigate = useNavigate();
  const [date, setDate] = useState(todayISO());
  const pendingInvoiceRequestRef = useRef<{ fingerprint: string; id: string } | null>(null);
  const [open, setOpen] = useState(false);
  const [patientId, setPatientId] = useState("");
  const [selectedPatient, setSelectedPatient] = useState<PickedPatient | null>(null);
  const [visitId, setVisitId] = useState("");
  const [standaloneInvoice, setStandaloneInvoice] = useState(false);
  const [separateInvoice, setSeparateInvoice] = useState(false);
  const [partnerId, setPartnerId] = useState("");
  const [discount, setDiscount] = useState("0");
  const [lines, setLines] = useState<Line[]>([
    { description: "", quantity: "1", unit_price: "0", item_type: "other" },
  ]);

  useEffect(
    () =>
      listenForQuickAction("new_invoice", () => {
        if (!can("billing.create")) return;
        pendingInvoiceRequestRef.current = null;
        setPatientId("");
        setSelectedPatient(null);
        setVisitId("");
        setStandaloneInvoice(false);
        setSeparateInvoice(false);
        setPartnerId("");
        setDiscount("0");
        setLines([{ description: "", quantity: "1", unit_price: "0", item_type: "other" }]);
        setOpen(true);
      }),
    [can],
  );

  const invoices = useRows(["invoices", date], () =>
    supabase
      .from("invoices")
      .select(
        "id, branch_id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, patients(full_name, mrn), partners(name)",
      )
      .eq("invoice_date", date)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const realtimeBranchId = s(((invoices.data ?? []) as Row[])[0] as Row | undefined, "branch_id") || null;
  useBranchRealtime(realtimeBranchId);

  const partners = useRows(["partners"], () =>
    supabase.from("partners").select("id, name, discount_percent").is("deleted_at", null),
  );

  const visits = useRows(["billing-patient-visits", patientId], () =>
    supabase
      .from("visits")
      .select("id, created_at, status")
      .eq("patient_id", patientId || "00000000-0000-0000-0000-000000000000")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(50),
  );

  const subtotal = lines.reduce(
    (sum, l) => sum + Number(l.quantity || 0) * Number(l.unit_price || 0),
    0,
  );
  const net = Math.max(subtotal - Number(discount || 0), 0);

  const create = useSave(
    async () => {
      if (!patientId) throw new Error("Select a patient.");
      if (!visitId && !standaloneInvoice) {
        throw new Error("Choose a visit or explicitly select a standalone invoice.");
      }
      const validated = validateInvoiceDraft(lines, discount);
      const items = validated.lines.map((line) => ({
        item_name: line.description,
        item_type: line.item_type,
        quantity: line.quantity,
        unit_price: line.unit_price,
      }));
      const separate = standaloneInvoice || separateInvoice;
      const fingerprint = JSON.stringify({
        patientId,
        visitId: visitId || null,
        partnerId: partnerId || null,
        date,
        discount: validated.discount,
        items,
        separate,
      });
      if (pendingInvoiceRequestRef.current?.fingerprint !== fingerprint) {
        pendingInvoiceRequestRef.current = { fingerprint, id: crypto.randomUUID() };
      }
      const requestId = pendingInvoiceRequestRef.current.id;
      const { data: invoiceId, error } = await supabase.rpc("create_billing_invoice_atomic", {
        p_patient_id: patientId,
        p_visit_id: visitId || null,
        p_partner_id: partnerId || null,
        p_invoice_date: date,
        p_discount: validated.discount,
        p_items: items,
        p_separate_invoice: separate,
        p_request_id: requestId,
      });
      if (error) throw new Error(error.message);
      if (typeof invoiceId !== "string" || !invoiceId) {
        throw new Error("The database did not return the created invoice ID.");
      }
      pendingInvoiceRequestRef.current = null;
      return invoiceId;
    },
    {
      invalidate: [["invoices", date], ["consultation-invoice"]],
      successMessage: t("saved"),
      onDone: (id) => {
        setOpen(false);
        setSelectedPatient(null);
        setPatientId("");
        setVisitId("");
        setStandaloneInvoice(false);
        setSeparateInvoice(false);
        setLines([{ description: "", quantity: "1", unit_price: "0", item_type: "other" }]);
        setDiscount("0");
        if (typeof id === "string")
          void navigate({ to: "/billing/$invoiceId", params: { invoiceId: id } });
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
        <Input
          type="date"
          dir="ltr"
          aria-label={lang === "ar" ? "تاريخ الفواتير" : "Invoice date"}
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className="w-40"
        />
        <ExportButtons rows={rows} filename={`roshan-invoices-${date}`} />
        {can("billing.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("new_invoice") || "فاتورة جديدة"}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] max-w-3xl overflow-y-auto">
              <DialogHeader>
                <DialogTitle>{t("new_invoice") || "فاتورة جديدة"}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label={`${t("patient")} *`}>
                    <PatientPicker
                      value={selectedPatient}
                      onSelect={(p) => {
                        setSelectedPatient(p);
                        setPatientId(p?.id ?? "");
                        setVisitId("");
                        setStandaloneInvoice(false);
                        setSeparateInvoice(false);
                      }}
                    />
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
                  <Field
                    label={
                      lang === "ar" ? "الزيارة / سياق الفاتورة *" : "Visit / invoice context *"
                    }
                  >
                    <Select
                      value={standaloneInvoice ? "standalone" : visitId || "choose"}
                      onValueChange={(value) => {
                        if (value === "standalone") {
                          setStandaloneInvoice(true);
                          setVisitId("");
                          setSeparateInvoice(false);
                        } else if (value === "choose") {
                          setStandaloneInvoice(false);
                          setVisitId("");
                          setSeparateInvoice(false);
                        } else {
                          setStandaloneInvoice(false);
                          setVisitId(value);
                          setSeparateInvoice(false);
                        }
                      }}
                    >
                      <SelectTrigger>
                        <SelectValue
                          placeholder={
                            lang === "ar"
                              ? "اختر الزيارة أو فاتورة مستقلة"
                              : "Choose a visit or standalone invoice"
                          }
                        />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="choose" disabled>
                          {lang === "ar" ? "اختر الزيارة" : "Choose a visit"}
                        </SelectItem>
                        {((visits.data ?? []) as Row[]).map((visit) => (
                          <SelectItem key={s(visit, "id")} value={s(visit, "id")}>
                            {formatDate(s(visit, "created_at"))} · {s(visit, "status")}
                          </SelectItem>
                        ))}
                        <SelectItem value="standalone">
                          {lang === "ar"
                            ? "فاتورة مستقلة (بدون زيارة)"
                            : "Standalone invoice (no visit)"}
                        </SelectItem>
                      </SelectContent>
                    </Select>
                  </Field>
                </div>
                {visitId ? (
                  <label className="flex items-center gap-2 rounded-md border px-3 py-2 text-sm">
                    <input
                      type="checkbox"
                      className="size-4 accent-primary"
                      checked={separateInvoice}
                      onChange={(event) => setSeparateInvoice(event.target.checked)}
                    />
                    <span>
                      {lang === "ar"
                        ? "إنشاء فاتورة منفصلة بدل الإضافة إلى فاتورة الزيارة الأساسية"
                        : "Create a separate invoice instead of appending to the primary visit invoice"}
                    </span>
                  </label>
                ) : null}
                {visitId && !separateInvoice ? (
                  <p className="text-xs text-muted-foreground">
                    {lang === "ar"
                      ? "عند الإضافة إلى فاتورة زيارة موجودة، اترك الخصم صفراً؛ تغيير خصم الفاتورة يتطلب فاتورة منفصلة."
                      : "When appending to an existing visit invoice, leave discount at zero. Changing the invoice-level discount requires a separate invoice."}
                  </p>
                ) : null}

                <div className="space-y-2">
                  {lines.map((l, idx) => (
                    <div key={idx} className="grid gap-2 rounded-md border p-2 sm:grid-cols-5">
                      <Input
                        className="sm:col-span-2"
                        placeholder={t("description")}
                        value={l.description}
                        onChange={(e) =>
                          setLines(
                            lines.map((x, i) =>
                              i === idx ? { ...x, description: e.target.value } : x,
                            ),
                          )
                        }
                      />
                      <Select
                        value={l.item_type}
                        onValueChange={(v) =>
                          setLines(lines.map((x, i) => (i === idx ? { ...x, item_type: v } : x)))
                        }
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
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
                          setLines(
                            lines.map((x, i) =>
                              i === idx ? { ...x, quantity: e.target.value } : x,
                            ),
                          )
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
                            setLines(
                              lines.map((x, i) =>
                                i === idx ? { ...x, unit_price: e.target.value } : x,
                              ),
                            )
                          }
                        />
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setLines(lines.filter((_, i) => i !== idx))}
                        >
                          <Trash2 className="size-4" />
                        </Button>
                      </div>
                    </div>
                  ))}
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() =>
                      setLines([
                        ...lines,
                        { description: "", quantity: "1", unit_price: "0", item_type: "other" },
                      ])
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
                    <Input
                      type="number"
                      dir="ltr"
                      min={0}
                      value={discount}
                      onChange={(e) => setDiscount(e.target.value)}
                    />
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
                <Button
                  disabled={!patientId || (!visitId && !standaloneInvoice) || create.isPending}
                  onClick={() => create.mutate(undefined as never)}
                >
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={invoices.error ?? partners.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <StatCard label={t("invoices")} value={String(rows.length)} />
        <StatCard label={t("net")} value={money(totalNet, currency)} />
        <StatCard label={t("outstanding")} value={money(totalNet - totalPaid, currency)} />
      </div>

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty
              title={t("no_data")}
              description={
                lang === "ar" ? "لا فواتير في هذا النطاق." : "No invoices in this range."
              }
            />
          ) : (
            <Table density="compact">
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
                    <TableCell className="font-medium">
                      {s(rel(inv, "patients"), "full_name")}
                    </TableCell>
                    <TableCell>{money(n(inv, "net_amount"), currency)}</TableCell>
                    <TableCell>{money(n(inv, "paid_amount"), currency)}</TableCell>
                    <TableCell>
                      {money(n(inv, "net_amount") - n(inv, "paid_amount"), currency)}
                    </TableCell>
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
