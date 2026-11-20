import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";

import {
  DataPanel,
  Empty,
  ErrorBox,
  ExportButtons,
  InitialAvatar,
  NoResults,
  PageHeader,
  PageSkeleton,
  PermissionGate,
  SearchField,
  SectionTitle,
  StatusBadge,
  Toolbar,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { PharmacyCorrectionRequest } from "@/components/prescription-correction";
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
import { formatDateTime, money } from "@/lib/medical";
import { dispensePrescriptionFefo, type DispenseResultRow } from "@/lib/pharmacy";
import { parseDispenseQuantity } from "@/lib/pharmacy-quantity";
import { supabase } from "@/lib/supabase";
import { useBranchRealtime } from "@/lib/realtime";
import { QUARANTINE_DISPOSITIONS, RETURN_CONDITIONS, cancelDispenseBeforeHandover, confirmPharmacyHandover, recordPostHandoverReturn, resolveQuarantineDisposition, type QuarantinedDisposition, type ReturnCondition } from "@/lib/pharmacy-lifecycle";

export const Route = createFileRoute("/_authenticated/pharmacy")({
  head: () => ({
    meta: [
      { title: "Pharmacy — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Dispense prescriptions using FEFO batch stock and bill medicines.",
      },
      { property: "og:title", content: "Pharmacy — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Dispense prescriptions using FEFO batch stock and bill medicines.",
      },
    ],
  }),
  component: PharmacyPage,
});

const STATUSES = ["pending", "dispensed", "cancelled", "external", "all"];

function PharmacyPage() {
  return (
    <PermissionGate perm="pharmacy.read">
      <PharmacyPageInner />
    </PermissionGate>
  );
}

function PharmacyPageInner() {
  const { t, lang } = useLang();
  // pharmacy.manage/pharmacy.dispense were never real permission codes (see
  // Phase 3 write-up) — the actual DB-level RLS on pharmacy_inventory,
  // medicines and stock_movements already keys off pharmacy.create/update,
  // so the UI now checks the same codes instead of two dangling ones.
  const { can, user } = useAuth();
  const isPharmacist = ["pharmacist", "legacy_pharmacist"].includes(user?.role_code ?? "");
  const canDispense = can("pharmacy.update") && isPharmacist;
  const canRequestCorrection = can("pharmacy.correction.request") && isPharmacist;
  const { currency } = useSettings();
  const [status, setStatus] = useState("pending");
  const [search, setSearch] = useState("");
  const [dispenseDetail, setDispenseDetail] = useState<Record<string, DispenseResultRow[]>>({});
  const [separateInvoiceFor, setSeparateInvoiceFor] = useState<Record<string, boolean>>({});
  // Retain a request UUID after network failure so retry replays the same DB operation.
  const [dispenseRequestIds, setDispenseRequestIds] = useState<Record<string, string>>({});

  const list = useRows(
    ["pharmacy-queue", status],
    () => {
      let q = supabase
        .from("prescriptions")
        .select(
          "id, branch_id, status, created_at, handed_over_at, handed_over_by, is_external, patients(full_name, mrn), users(full_name), prescription_items(id, quantity, medication_name, dosage, frequency, duration, medicine_id, deleted_at, medicines(name, selling_price, stock_quantity))",
        )
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(200);
      if (status !== "all") q = q.eq("status", status);
      return q;
    },
    { refetchInterval: 20000, keepPrevious: true },
  );

  const dispense = useSave<{
    prescriptionId: string;
    separateInvoice: boolean;
    requestId: string;
  }>(
    async ({ prescriptionId, separateInvoice, requestId }) => {
      if (!canDispense) throw new Error("Not authorized");
      const result = await dispensePrescriptionFefo(prescriptionId, separateInvoice, requestId);
      setDispenseDetail((prev) => ({ ...prev, [prescriptionId]: result }));
      setDispenseRequestIds((current) => {
        const next = { ...current };
        delete next[prescriptionId];
        return next;
      });
      return result;
    },
    {
      invalidate: [
        ["pharmacy-queue"],
        ["medicines"],
        ["inventory"],
        ["pharmacy-batches"],
        ["invoices"],
        ["consultation-invoice"],
      ],
      successMessage: t("dispensed"),
    },
  );
  const [cancelRequestIds, setCancelRequestIds] = useState<Record<string, string>>({}); const [returnRequestIds, setReturnRequestIds] = useState<Record<string, string>>({}); const [cancelReasons, setCancelReasons] = useState<Record<string, string>>({}); const [returnForms, setReturnForms] = useState<Record<string, { medicineId: string; batchId: string; quantity: string; condition: ReturnCondition; reason: string }>>({}); const [quarantineForms, setQuarantineForms] = useState<Record<string, { disposition: QuarantinedDisposition; notes: string }>>({}); const inventoryBatches = useRows(["pharmacy-batches"], () => supabase.from("pharmacy_inventory").select("id, medicine_id, batch_number, expiry_date, quantity, medicines(id, name)").order("expiry_date", { ascending: true }).limit(200), { keepPrevious: true }); const quarantineQueue = useRows(["pharmacy-quarantine"], () => supabase.from("pharmacy_return_quarantine").select("id, return_id, medicine_id, batch_id, quantity, condition, status, disposition, notes, created_at, medicines(id, name)").eq("status", "quarantined").order("created_at", { ascending: false }).limit(100), { refetchInterval: 20000, keepPrevious: true }); const PHASE62_INVALIDATE: string[][] = [["pharmacy-queue"], ["pharmacy-quarantine"], ["medicines"], ["inventory"], ["pharmacy-batches"], ["invoices"], ["consultation-invoice"]];
  const confirmHandover = useSave<string, unknown>(async (prescriptionId) => { if (!canDispense) throw new Error("Not authorized"); return confirmPharmacyHandover(prescriptionId); }, { invalidate: PHASE62_INVALIDATE, successMessage: lang === "ar" ? "تم تأكيد تسليم الوصفة" : "Handover confirmed" }); const cancelBeforeHandover = useSave<{ prescriptionId: string; reason: string }, unknown>(async ({ prescriptionId, reason }) => { if (!canDispense) throw new Error("Not authorized"); const idempotencyKey = cancelRequestIds[prescriptionId] ?? crypto.randomUUID(); setCancelRequestIds((prev) => (prev[prescriptionId] === idempotencyKey ? prev : { ...prev, [prescriptionId]: idempotencyKey })); const result = await cancelDispenseBeforeHandover({ prescriptionId, reason, idempotencyKey }); setCancelRequestIds((current) => { const next = { ...current }; delete next[prescriptionId]; return next; }); setCancelReasons((current) => { const next = { ...current }; delete next[prescriptionId]; return next; }); return result; }, { invalidate: PHASE62_INVALIDATE, successMessage: lang === "ar" ? "تم إلغاء الصرف قبل التسليم" : "Dispense cancelled before handover" }); const postHandoverReturn = useSave<{ prescriptionId: string; medicineId: string; batchId: string; quantity: number; condition: ReturnCondition; reason: string }, unknown>(async ({ prescriptionId, medicineId, batchId, quantity, condition, reason }) => { if (!canDispense) throw new Error("Not authorized"); const idempotencyKey = returnRequestIds[prescriptionId] ?? crypto.randomUUID(); setReturnRequestIds((prev) => (prev[prescriptionId] === idempotencyKey ? prev : { ...prev, [prescriptionId]: idempotencyKey })); const result = await recordPostHandoverReturn({ prescriptionId, medicineId, batchId, quantity, condition, reason, idempotencyKey }); setReturnRequestIds((current) => { const next = { ...current }; delete next[prescriptionId]; return next; }); setReturnForms((current) => { const next = { ...current }; delete next[prescriptionId]; return next; }); return result; }, { invalidate: PHASE62_INVALIDATE, successMessage: lang === "ar" ? "تم تسجيل مرتجع ما بعد التسليم" : "Post-handover return recorded" }); const resolveQuarantine = useSave<{ quarantineId: string; disposition: QuarantinedDisposition; notes: string }, unknown>(async ({ quarantineId, disposition, notes }) => { if (!canDispense) throw new Error("Not authorized"); const result = await resolveQuarantineDisposition({ quarantineId, disposition, notes: notes.trim() || null }); setQuarantineForms((current) => { const next = { ...current }; delete next[quarantineId]; return next; }); return result; }, { invalidate: PHASE62_INVALIDATE, successMessage: lang === "ar" ? "تم حسم الحجر الدوائي" : "Quarantine disposition resolved" }); const isPhase62Pending = confirmHandover.isPending || cancelBeforeHandover.isPending || postHandoverReturn.isPending || resolveQuarantine.isPending;
  
  const realtimeBranchId =
    s(((list.data ?? []) as Row[])[0] as Row | undefined, "branch_id") || null;
  useBranchRealtime(realtimeBranchId);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return ((list.data ?? []) as Row[]).filter((p) => {
      if (!q) return true;
      const patient = rel(p, "patients");
      const items = (p["prescription_items"] as Row[]) ?? [];
      const meds = items.map((i) => s(rel(i, "medicines"), "name")).join(" ");
      return `${s(patient, "full_name")} ${s(patient, "mrn")} ${meds}`.toLowerCase().includes(q);
    });
  }, [list.data, search]);
  if (list.isLoading) return <PageSkeleton />;
  const filtered = search.trim() !== "" || status !== "pending";

  return (
    <div>
      <PageHeader title={t("pharmacy")} subtitle={t("dispense_queue")}>
        <ExportButtons rows={rows} filename="roshan-prescriptions" />
      </PageHeader>

      <Toolbar className="mb-4">
        <SearchField
          value={search}
          onChange={setSearch}
          placeholder={t("search")}
          label={t("search")}
        />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="h-11 w-full sm:w-44" aria-label={t("status")}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUSES.map((x) => (
              <SelectItem key={x} value={x}>
                {t(x)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </Toolbar>

      <ErrorBox error={list.error} />

      {rows.length === 0 && filtered ? (
        <NoResults
          onClear={() => {
            setSearch("");
            setStatus("pending");
          }}
        />
      ) : rows.length === 0 ? (
        <Empty
          title={t("no_data")}
          description={lang === "ar" ? "لا وصفات مطابقة." : "No matching prescriptions."}
        />
      ) : (
        <div className="grid gap-4">
          {rows.map((p) => {
            const items = ((p["prescription_items"] as Row[]) ?? []).filter(
              (item) => item["deleted_at"] == null,
            );
            const quantityFor = (item: Row) => parseDispenseQuantity(item["quantity"]);
            const hasInvalidQuantity = items.some((item) => quantityFor(item) === null);
            const hasUnlinkedItem = items.some((item) => !s(item, "medicine_id"));
            const hasExternalPrescription = p["is_external"] === true;
            const hasDispenseBlocker =
              hasInvalidQuantity || hasUnlinkedItem || hasExternalPrescription;
            const total = hasDispenseBlocker
              ? null
              : items.reduce(
                  (sum, item) =>
                    sum + (quantityFor(item) ?? 0) * n(rel(item, "medicines"), "selling_price"),
                  0,
                );
            const usedBatches = dispenseDetail[s(p, "id")];
            return (
              <DataPanel key={s(p, "id")}>
                <div className="p-4">
                  <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <InitialAvatar name={s(rel(p, "patients"), "full_name")} />
                      <div className="min-w-0">
                        <p className="truncate font-semibold">
                          {s(rel(p, "patients"), "full_name")}
                        </p>
                        <p className="break-words text-xs text-muted-foreground">
                          {s(rel(p, "patients"), "mrn")} · {formatDateTime(s(p, "created_at"))} ·{" "}
                          {s(rel(p, "users"), "full_name")}
                        </p>
                      </div>
                    </div>
                    <div className="flex w-full items-center justify-between gap-2 sm:w-auto sm:justify-end">
                      <StatusBadge status={s(p, "status")} />
                      {canDispense && s(p, "status") === "pending" ? (
                        <>
                          {can("billing.create") ? (
                            <Button
                              type="button"
                              size="sm"
                              variant={separateInvoiceFor[s(p, "id")] ? "secondary" : "outline"}
                              aria-pressed={Boolean(separateInvoiceFor[s(p, "id")])}
                              onClick={() => {
                                const prescriptionId = s(p, "id");
                                setSeparateInvoiceFor((current) => ({
                                  ...current,
                                  [prescriptionId]: !current[prescriptionId],
                                }));
                                setDispenseRequestIds((current) => {
                                  const next = { ...current };
                                  delete next[prescriptionId];
                                  return next;
                                });
                              }}
                            >
                              {separateInvoiceFor[s(p, "id")]
                                ? lang === "ar"
                                  ? "فاتورة منفصلة"
                                  : "Separate invoice"
                                : lang === "ar"
                                  ? "فاتورة الزيارة"
                                  : "Visit invoice"}
                            </Button>
                          ) : null}
                          <Button
                            disabled={dispense.isPending || hasDispenseBlocker}
                            onClick={() => {
                              const prescriptionId = s(p, "id");
                              const requestId =
                                dispenseRequestIds[prescriptionId] ?? crypto.randomUUID();
                              setDispenseRequestIds((current) => ({
                                ...current,
                                [prescriptionId]: requestId,
                              }));
                              dispense.mutate({
                                prescriptionId,
                                separateInvoice: Boolean(separateInvoiceFor[prescriptionId]),
                                requestId,
                              });
                            }}
                          >
                            {t("dispense")}
                          </Button>
                        </>
                      ) : null}
                    </div>
                  </div>
                  <SectionTitle>{t("medicines")}</SectionTitle>
                  {hasExternalPrescription ? (
                    <p
                      role="alert"
                      className="mb-3 rounded-md border border-amber-500/40 p-3 text-sm text-amber-700"
                    >
                      {t("external_prescription_internal_stock_blocked")}
                    </p>
                  ) : null}
                  {hasInvalidQuantity ? (
                    <p
                      role="alert"
                      className="mb-3 rounded-md border border-destructive/40 p-3 text-sm text-destructive"
                    >
                      {lang === "ar"
                        ? "توجد كمية مفقودة أو غير صالحة. أوقفنا الصرف حتى يراجع الطبيب الوصفة ويصحح الكمية."
                        : "A prescribed quantity is missing or invalid. Dispensing is blocked until the prescriber corrects it."}
                    </p>
                  ) : null}
                  {hasUnlinkedItem ? (
                    <p
                      role="alert"
                      className="mb-3 rounded-md border border-destructive/40 p-3 text-sm text-destructive"
                    >
                      {lang === "ar"
                        ? "تحتوي الوصفة على دواء غير مرتبط بدليل الأدوية. يجب ربطه بدواء نشط قبل الصرف."
                        : "This prescription contains a medicine not linked to the active catalogue. Link it before dispensing."}
                    </p>
                  ) : null}
                  {canRequestCorrection &&
                  s(p, "status") === "pending" &&
                  !hasExternalPrescription &&
                  items.some((item) => !s(item, "medicine_id")) ? (
                    <div className="mb-3 space-y-2 rounded-md border border-primary/20 bg-primary/5 p-3">
                      <p className="text-sm font-medium">
                        {lang === "ar"
                          ? "يمكنك طلب توضيح الطبيب للبنود غير المرتبطة."
                          : "You can ask the responsible prescriber to clarify unlinked items."}
                      </p>
                      {items
                        .filter((item) => !s(item, "medicine_id"))
                        .map((item) => (
                          <div
                            key={s(item, "id")}
                            className="flex flex-wrap items-center justify-between gap-2 rounded-md border bg-card p-2"
                          >
                            <span className="min-w-0 text-sm">
                              {s(item, "medication_name") ||
                                (lang === "ar" ? "دواء غير محدد" : "Unspecified medicine")}
                            </span>
                            <PharmacyCorrectionRequest
                              itemId={s(item, "id")}
                              itemLabel={s(item, "medication_name")}
                              lang={lang}
                            />
                          </div>
                        ))}
                    </div>
                  ) : null}
                  <ul className="divide-y rounded-md border md:hidden">
                    {items.map((i) => {
                      const quantity = quantityFor(i);
                      const lineTotal =
                        quantity === null || !s(i, "medicine_id")
                          ? null
                          : quantity * n(rel(i, "medicines"), "selling_price");
                      return (
                        <li
                          key={s(i, "id")}
                          className="flex items-start justify-between gap-3 p-2.5 text-sm"
                        >
                          <div className="min-w-0 space-y-0.5">
                            <p className="font-medium">
                              {s(rel(i, "medicines"), "name") || s(i, "medication_name") || "—"}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {[s(i, "dosage"), s(i, "frequency"), s(i, "duration")]
                                .filter(Boolean)
                                .join(" · ") || "—"}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {t("quantity")}{" "}
                              <span dir="ltr">
                                {quantity === null
                                  ? lang === "ar"
                                    ? "غير محددة"
                                    : "Missing"
                                  : quantity}
                              </span>{" "}
                              · {t("stock")}{" "}
                              <span dir="ltr">{n(rel(i, "medicines"), "stock_quantity")}</span>
                            </p>
                          </div>
                          <span className="shrink-0 font-semibold">
                            {lineTotal === null ? "—" : money(lineTotal, currency)}
                          </span>
                        </li>
                      );
                    })}
                  </ul>
                  <div className="hidden md:block">
                    <Table density="compact">
                      <TableHeader>
                        <TableRow>
                          <TableHead>{t("medicines")}</TableHead>
                          <TableHead>{t("dosage")}</TableHead>
                          <TableHead>{t("quantity")}</TableHead>
                          <TableHead>{t("stock")}</TableHead>
                          <TableHead>{t("total")}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {items.map((i) => {
                          const quantity = quantityFor(i);
                          const lineTotal =
                            quantity === null || !s(i, "medicine_id")
                              ? null
                              : quantity * n(rel(i, "medicines"), "selling_price");
                          return (
                            <TableRow key={s(i, "id")}>
                              <TableCell className="font-medium">
                                {s(rel(i, "medicines"), "name") || s(i, "medication_name") || "—"}
                              </TableCell>
                              <TableCell>
                                {[s(i, "dosage"), s(i, "frequency"), s(i, "duration")]
                                  .filter(Boolean)
                                  .join(" · ") || "—"}
                              </TableCell>
                              <TableCell dir="ltr">
                                {quantity === null
                                  ? lang === "ar"
                                    ? "غير محددة"
                                    : "Missing"
                                  : quantity}
                              </TableCell>
                              <TableCell dir="ltr">
                                {n(rel(i, "medicines"), "stock_quantity")}
                              </TableCell>
                              <TableCell>
                                {lineTotal === null ? "—" : money(lineTotal, currency)}
                              </TableCell>
                            </TableRow>
                          );
                        })}
                      </TableBody>
                    </Table>
                  </div>
                  <p className="mt-2 text-end text-sm font-semibold">
                    {t("total")}: {total === null ? "—" : money(total, currency)}
                  </p>

                  {usedBatches && usedBatches.length > 0 ? (
                    <div className="mt-4 rounded-lg border bg-accent/30 p-3">
                      <SectionTitle>{t("batches_used")}</SectionTitle>
                      <Table density="compact">
                        <TableHeader>
                          <TableRow>
                            <TableHead>{t("medicines")}</TableHead>
                            <TableHead>{t("batch_number")}</TableHead>
                            <TableHead>{t("expiry_date")}</TableHead>
                            <TableHead>{t("quantity_dispensed")}</TableHead>
                            <TableHead>{t("remaining_quantity")}</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {usedBatches.map((row, idx) => (
                            <TableRow key={`${row.item_id}-${row.batch_id ?? "legacy"}-${idx}`}>
                              <TableCell className="font-medium">{row.medicine_name}</TableCell>
                              <TableCell dir="ltr">
                                {row.batch_number ?? t("legacy_stock")}
                              </TableCell>
                              <TableCell dir="ltr">{row.expiry_date ?? "—"}</TableCell>
                              <TableCell dir="ltr">{row.quantity_dispensed}</TableCell>
                              <TableCell dir="ltr">{row.batch_quantity_remaining ?? "—"}</TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </div>
                  ) : null} {s(p, "status") === "dispensed" ? (<div className="mt-3 border-t border-border/60 pt-3 space-y-3">{!s(p, "handed_over_at") ? (<div className="flex flex-wrap items-center gap-2"><Button size="sm" disabled={!canDispense || isPhase62Pending} onClick={() => confirmHandover.mutate(pid)}>{lang === "ar" ? "\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062a\u0633\u0644\u064a\u0645" : "Confirm Handover"}</Button><input type="text" className="min-w-[200px] flex-1 rounded-md border border-input bg-background px-2.5 py-1 text-xs" placeholder={lang === "ar" ? "\u0633\u0628\u0628 \u0627\u0644\u0625\u0644\u063a\u0627\u0621" : "Cancellation reason"} value={cancelReasons[pid] ?? ""} disabled={!canDispense || isPhase62Pending} onChange={(e) => setCancelReasons((prev) => ({ ...prev, [pid]: e.target.value }))} /><Button size="sm" variant="destructive" disabled={!canDispense || isPhase62Pending || !(cancelReasons[pid] ?? "").trim()} onClick={() => cancelBeforeHandover.mutate({ prescriptionId: pid, reason: (cancelReasons[pid] ?? "").trim() })}>{lang === "ar" ? "\u0625\u0644\u063a\u0627\u0621 \u0642\u0628\u0644 \u0627\u0644\u062a\u0633\u0644\u064a\u0645" : "Cancel Before Handover"}</Button></div>) : ((() => { const rf = returnForms[pid] ?? { medicineId: s(items[0] ?? {}, "medicine_id"), batchId: "", quantity: "1", condition: "unopened_intact" as ReturnCondition, reason: "" }; const matchingBatches = (inventoryBatches.data ?? []).filter((b) => !rf.medicineId || s(b, "medicine_id") === rf.medicineId); return (<div className="space-y-2"><div className="text-xs text-muted-foreground">{lang === "ar" ? `\u062a\u0645 \u0627\u0644\u062a\u0633\u0644\u064a\u0645: ${formatDateTime(s(p, "handed_over_at"), lang)}` : `Handed over: ${formatDateTime(s(p, "handed_over_at"), lang)}`}</div><div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-5"><Select value={rf.medicineId} disabled={!canDispense || isPhase62Pending} onValueChange={(v) => setReturnForms((prev) => ({ ...prev, [pid]: { ...rf, medicineId: v, batchId: "" } }))}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "\u0627\u0644\u062f\u0648\u0627\u0621" : "Medicine"} /></SelectTrigger><SelectContent>{items.filter((it) => s(it, "medicine_id")).map((it) => (<SelectItem key={s(it, "id")} value={s(it, "medicine_id")}>{s(rel(it, "medicines"), "name") || s(it, "medicine_id")}</SelectItem>))}</SelectContent></Select><Select value={rf.batchId} disabled={!canDispense || isPhase62Pending} onValueChange={(v) => setReturnForms((prev) => ({ ...prev, [pid]: { ...rf, batchId: v } }))}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "\u0627\u0644\u062a\u0634\u063a\u064a\u0644\u0629" : "Batch"} /></SelectTrigger><SelectContent>{matchingBatches.map((b) => (<SelectItem key={s(b, "id")} value={s(b, "id")}>{`${s(b, "batch_number") || s(b, "id")} (${s(b, "expiry_date") || "-"})`}</SelectItem>))}</SelectContent></Select><input type="number" min={1} className="rounded-md border border-input bg-background px-2.5 py-1 text-xs" placeholder={lang === "ar" ? "\u0627\u0644\u0643\u0645\u064a\u0629" : "Qty"} value={rf.quantity} disabled={!canDispense || isPhase62Pending} onChange={(e) => setReturnForms((prev) => ({ ...prev, [pid]: { ...rf, quantity: e.target.value } }))} /><Select value={rf.condition} disabled={!canDispense || isPhase62Pending} onValueChange={(v) => setReturnForms((prev) => ({ ...prev, [pid]: { ...rf, condition: v as ReturnCondition } }))}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent>{RETURN_CONDITIONS.map((c) => (<SelectItem key={c} value={c}>{c}</SelectItem>))}</SelectContent></Select><input type="text" className="rounded-md border border-input bg-background px-2.5 py-1 text-xs" placeholder={lang === "ar" ? "\u0633\u0628\u0628 \u0627\u0644\u0645\u0631\u062a\u062c\u0639" : "Return reason"} value={rf.reason} disabled={!canDispense || isPhase62Pending} onChange={(e) => setReturnForms((prev) => ({ ...prev, [pid]: { ...rf, reason: e.target.value } }))} /></div><Button size="sm" variant="outline" disabled={!canDispense || isPhase62Pending || !rf.medicineId || !rf.batchId || !(Number(rf.quantity) > 0) || !rf.reason.trim()} onClick={() => postHandoverReturn.mutate({ prescriptionId: pid, medicineId: rf.medicineId, batchId: rf.batchId, quantity: Number(rf.quantity), condition: rf.condition, reason: rf.reason.trim() })}>{lang === "ar" ? "\u062a\u0633\u062c\u064a\u0644 \u0645\u0631\u062a\u062c\u0639" : "Record Post-Handover Return"}</Button></div>); })())}</div>) : null}
                  
                </div>
              </DataPanel>
            );
          })}
        </div>
      )}{/*q*/}<DataPanel title={lang === "ar" ? "قائمة الحجر الصحي للمرتجعات" : "Return Quarantine Queue"}>{quarantineQueue.error ? <ErrorBox error={quarantineQueue.error} /> : quarantineQueue.isLoading ? <PageSkeleton /> : (quarantineQueue.data ?? []).length === 0 ? <Empty title={lang === "ar" ? "لا توجد عناصر في الحجر الصحي" : "No quarantined returns"} description={lang === "ar" ? "ستظهر المرتجعات المحجوزة هنا للمراجعة والبت فيها." : "Quarantined returned items will appear here for disposition review."} /> : <div className="divide-y divide-border">{(quarantineQueue.data ?? []).map((q) => { const qid = s(q, "id"); const cond = s(q, "condition"); const canRestock = cond === "unopened_intact"; const qf = quarantineForms[qid] ?? { disposition: (canRestock ? "approved_restock" : "destroyed_writeoff") as QuarantinedDisposition, notes: "" }; const effectiveDisposition: QuarantinedDisposition = !canRestock && qf.disposition === "approved_restock" ? "destroyed_writeoff" : qf.disposition; return (<div key={qid} className="flex flex-col gap-2 py-3 sm:flex-row sm:items-center sm:justify-between"><div className="space-y-1"><div className="flex flex-wrap items-center gap-2"><span className="font-medium text-sm">{rel(q, "medicines", "name") || s(q, "medicine_id")}</span><span className="inline-flex items-center rounded-md bg-secondary px-2 py-0.5 text-xs font-medium text-secondary-foreground">{lang === "ar" ? `الكمية: ${n(q, "quantity")}` : `Qty: ${n(q, "quantity")}`}</span><span className="inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-medium">{cond}</span><StatusBadge status={s(q, "status")} /></div><div className="text-xs text-muted-foreground">{lang === "ar" ? `تاريخ الحجر: ${formatDateTime(s(q, "created_at"), lang)}` : `Quarantined: ${formatDateTime(s(q, "created_at"), lang)}`}</div></div><div className="flex flex-wrap items-center gap-2"><Select value={effectiveDisposition} disabled={!canDispense || isPhase62Pending} onValueChange={(v) => setQuarantineForms((prev) => ({ ...prev, [qid]: { ...qf, disposition: v as QuarantinedDisposition } }))}><SelectTrigger className="w-[210px] h-8 text-xs"><SelectValue /></SelectTrigger><SelectContent>{QUARANTINE_DISPOSITIONS.map((d) => (<SelectItem key={d} value={d} disabled={d === "approved_restock" && !canRestock}>{d === "approved_restock" ? (lang === "ar" ? "إعادة للمخزون (سليم)" : "Approve Restock") : d === "destroyed_writeoff" ? (lang === "ar" ? "إتلاف وشطب" : "Destroy / Write-off") : (lang === "ar" ? "إرجاع للمورد" : "Return to Supplier")}</SelectItem>))}</SelectContent></Select><input type="text" className="h-8 w-[200px] rounded-md border border-input bg-background px-2.5 text-xs" value={qf.notes} disabled={!canDispense || isPhase62Pending} placeholder={lang === "ar" ? "ملاحظات القرار" : "Disposition notes"} onChange={(e) => setQuarantineForms((prev) => ({ ...prev, [qid]: { ...qf, notes: e.target.value } }))} /><Button size="sm" variant="outline" disabled={!canDispense || isPhase62Pending || (effectiveDisposition === "approved_restock" && !canRestock)} onClick={() => resolveQuarantine.mutate({ quarantineId: qid, disposition: effectiveDisposition, notes: qf.notes })}>{lang === "ar" ? "حسم الحجر الصحي" : "Resolve Quarantine"}</Button></div></div>); })}</div>}</DataPanel>
      
    </div>
  );
}
