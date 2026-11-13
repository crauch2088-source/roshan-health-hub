import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { s, rel, useRows, useSave, type Row } from "@/lib/db";
import { supabase } from "@/lib/supabase";

type Language = "ar" | "en";

export function PharmacyCorrectionRequest({
  itemId,
  itemLabel,
  lang,
}: {
  itemId: string;
  itemLabel: string;
  lang: Language;
}) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const request = useSave<string>(
    async (value) => {
      const { data, error } = await supabase.rpc("request_prescription_item_correction", {
        p_prescription_item_id: itemId,
        p_reason: value,
      });
      if (error) throw new Error(error.message);
      return data as string;
    },
    {
      invalidate: [["pharmacy-queue"], ["prescription-corrections"]],
      successMessage:
        lang === "ar"
          ? "أُرسل طلب التصحيح إلى الطبيب المسؤول"
          : "Correction request sent to the responsible prescriber",
      onDone: () => {
        setOpen(false);
        setReason("");
      },
    },
  );

  const validReason = reason.trim().length >= 10 && reason.trim().length <= 1000;

  return (
    <>
      <Button type="button" size="sm" variant="outline" onClick={() => setOpen(true)}>
        {lang === "ar" ? "طلب تصحيح الوصفة" : "Request prescription correction"}
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent
          dir={lang === "ar" ? "rtl" : "ltr"}
          className="max-h-[90dvh] max-w-lg overflow-y-auto"
        >
          <DialogHeader>
            <DialogTitle>
              {lang === "ar" ? "طلب تصحيح بند دوائي" : "Request medicine-item correction"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="rounded-md border bg-muted/30 p-3 text-sm">
              <p className="font-semibold">
                {itemLabel || (lang === "ar" ? "دواء غير مرتبط" : "Unlinked medicine")}
              </p>
              <p className="mt-1 text-muted-foreground">
                {lang === "ar"
                  ? "سيُرسل الطلب إلى الطبيب المسؤول عن الوصفة، مع الاحتفاظ بالبند الأصلي."
                  : "The request goes to the responsible prescriber; the original item remains unchanged."}
              </p>
            </div>
            <label className="grid gap-1.5 text-sm font-medium">
              {lang === "ar"
                ? "سبب طلب التصحيح (10 أحرف على الأقل)"
                : "Reason for correction (at least 10 characters)"}
              <Textarea
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                rows={4}
                maxLength={1000}
                placeholder={
                  lang === "ar"
                    ? "اشرح ما يحتاج إلى توضيح أو تصحيح..."
                    : "Describe what needs clarification or correction..."
                }
              />
            </label>
            <p className="text-xs text-muted-foreground">
              {lang === "ar"
                ? "لا يؤدي طلب التصحيح إلى صرف الدواء أو إنشاء فاتورة أو تغيير المخزون."
                : "Requesting clarification does not dispense medicines, create invoices, or change stock."}
            </p>
          </div>
          <DialogFooter className="flex-col-reverse gap-2 sm:flex-row">
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              {lang === "ar" ? "إلغاء" : "Cancel"}
            </Button>
            <Button
              type="button"
              disabled={!validReason || request.isPending}
              onClick={() => request.mutate(reason.trim())}
            >
              {request.isPending
                ? lang === "ar"
                  ? "جارٍ الإرسال..."
                  : "Sending..."
                : lang === "ar"
                  ? "إرسال للطبيب"
                  : "Send to prescriber"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

type CorrectionForm = {
  medicineId: string;
  dose: string;
  frequency: string;
  duration: string;
  quantity: string;
  dosageForm: string;
  route: string;
  instructions: string;
  note: string;
};

const emptyCorrectionForm: CorrectionForm = {
  medicineId: "",
  dose: "",
  frequency: "",
  duration: "",
  quantity: "",
  dosageForm: "",
  route: "",
  instructions: "",
  note: "",
};

type CorrectionOrderItemForm = Omit<CorrectionForm, "note">;

const emptyCorrectionOrderItem = (): CorrectionOrderItemForm => ({
  medicineId: "",
  dose: "",
  frequency: "",
  duration: "",
  quantity: "",
  dosageForm: "",
  route: "",
  instructions: "",
});

function isCompleteReplacementOrder(items: CorrectionOrderItemForm[]): boolean {
  return (
    items.length > 0 &&
    items.every((item) => {
      const quantity = Number(item.quantity);
      return (
        Boolean(item.medicineId) &&
        Boolean(item.dose.trim()) &&
        Boolean(item.frequency.trim()) &&
        Boolean(item.duration.trim()) &&
        Boolean(item.dosageForm.trim()) &&
        Boolean(item.route.trim()) &&
        Number.isSafeInteger(quantity) &&
        quantity > 0 &&
        quantity <= 1_000_000
      );
    })
  );
}

export function PrescriberCorrectionInbox({ lang }: { lang: Language }) {
  const { can, user } = useAuth();
  const isClinicalPrescriber = ["doctor", "legacy_gp", "legacy_specialist", "legacy_dentist"].includes(
    user?.role_code ?? "",
  );
  const allowed = can("prescriptions.correction.resolve") && isClinicalPrescriber;
  const [selected, setSelected] = useState<Row | null>(null);
  const [action, setAction] = useState<"replace_item" | "reject" | "cancel_and_reissue">(
    "replace_item",
  );
  const [form, setForm] = useState<CorrectionForm>(emptyCorrectionForm);
  const [replacementOrderItems, setReplacementOrderItems] = useState<CorrectionOrderItemForm[]>([
    emptyCorrectionOrderItem(),
  ]);
  const canCreatePrescription = can("prescriptions.create") && isClinicalPrescriber;

  const requests = useRows<Row[]>(
    ["prescription-corrections"],
    () =>
      supabase
        .from("prescription_item_correction_requests")
        .select(
          "id, prescription_id, prescription_item_id, patient_id, visit_id, branch_id, reason, requested_at, item_snapshot, patients(full_name, mrn), visits(visit_number), prescription_items(medication_name, dose, dosage, frequency, duration, quantity)",
        )
        .eq("status", "pending")
        .order("requested_at", { ascending: true }),
    { enabled: allowed, refetchInterval: 30000 },
  );

  const catalogue = useRows<Row[]>(
    ["prescription-correction-catalogue"],
    () =>
      supabase
        .from("medicines")
        .select("id, name, generic_name")
        .is("deleted_at", null)
        .eq("active", true)
        .eq("is_active", true)
        .order("name", { ascending: true })
        .limit(500),
    { enabled: allowed },
  );

  const resolve = useSave<{
    requestId: string;
    action: "replace_item" | "reject" | "cancel_and_reissue";
    replacement: Record<string, unknown> | Record<string, unknown>[] | null;
    reason: string | null;
  }>(
    async ({ requestId, action: resolutionAction, replacement, reason }) => {
      const { data, error } = await supabase.rpc("resolve_prescription_item_correction", {
        p_request_id: requestId,
        p_action: resolutionAction,
        p_replacement: replacement,
        p_reason: reason,
      });
      if (error) throw new Error(error.message);
      return data;
    },
    {
      invalidate: [["prescription-corrections"], ["pharmacy-queue"], ["clinic-visits"], ["visits"]],
      successMessage: lang === "ar" ? "تم تسجيل قرار الطبيب" : "Prescriber decision recorded",
      onDone: () => {
        setSelected(null);
        setForm(emptyCorrectionForm);
        setReplacementOrderItems([emptyCorrectionOrderItem()]);
      },
    },
  );

  if (!allowed) return null;

  const openResolution = (
    request: Row,
    nextAction: "replace_item" | "reject" | "cancel_and_reissue",
  ) => {
    setSelected(request);
    setAction(nextAction);
    setForm(emptyCorrectionForm);
    setReplacementOrderItems([emptyCorrectionOrderItem()]);
  };

  const submitResolution = () => {
    if (!selected) return;
    if (action === "cancel_and_reissue") {
      if (!isCompleteReplacementOrder(replacementOrderItems)) return;
      resolve.mutate({
        requestId: s(selected, "id"),
        action,
        replacement: replacementOrderItems.map((item) => ({
          medicine_id: item.medicineId,
          dose: item.dose.trim(),
          frequency: item.frequency.trim(),
          duration: item.duration.trim(),
          quantity: Number(item.quantity),
          dosage_form: item.dosageForm.trim(),
          route: item.route.trim(),
          instructions: item.instructions.trim() || null,
        })),
        reason: form.note.trim() || null,
      });
      return;
    }
    if (action === "reject") {
      const reason = form.note.trim();
      if (reason.length < 10) return;
      resolve.mutate({ requestId: s(selected, "id"), action, replacement: null, reason });
      return;
    }

    const quantity = Number(form.quantity);
    if (
      !form.medicineId ||
      !form.dose.trim() ||
      !form.frequency.trim() ||
      !form.duration.trim() ||
      !Number.isSafeInteger(quantity) ||
      quantity <= 0 ||
      !form.dosageForm.trim() ||
      !form.route.trim()
    ) {
      return;
    }

    resolve.mutate({
      requestId: s(selected, "id"),
      action,
      replacement: {
        medicine_id: form.medicineId,
        dose: form.dose.trim(),
        frequency: form.frequency.trim(),
        duration: form.duration.trim(),
        quantity,
        dosage_form: form.dosageForm.trim(),
        route: form.route.trim(),
        instructions: form.instructions.trim() || null,
      },
      reason: form.note.trim() || null,
    });
  };

  const field = (
    key: keyof CorrectionForm,
    label: string,
    placeholder: string,
    type: string = "text",
  ) => (
    <label className="grid gap-1 text-sm font-medium">
      {label}
      <Input
        type={type}
        value={form[key]}
        onChange={(event) => setForm((current) => ({ ...current, [key]: event.target.value }))}
        placeholder={placeholder}
        min={type === "number" ? 1 : undefined}
        step={type === "number" ? 1 : undefined}
      />
    </label>
  );

  const orderField = (
    index: number,
    key: keyof CorrectionOrderItemForm,
    label: string,
    placeholder: string,
    type: string = "text",
  ) => (
    <label className="grid gap-1 text-sm font-medium">
      {label}
      <Input
        type={type}
        value={replacementOrderItems[index]?.[key] ?? ""}
        onChange={(event) =>
          setReplacementOrderItems((current) =>
            current.map((item, itemIndex) =>
              itemIndex === index ? { ...item, [key]: event.target.value } : item,
            ),
          )
        }
        placeholder={placeholder}
        min={type === "number" ? 1 : undefined}
        max={type === "number" ? 1_000_000 : undefined}
        step={type === "number" ? 1 : undefined}
      />
    </label>
  );

  const addReplacementOrderItem = () =>
    setReplacementOrderItems((current) => [...current, emptyCorrectionOrderItem()]);

  const removeReplacementOrderItem = (index: number) =>
    setReplacementOrderItems((current) =>
      current.length > 1 ? current.filter((_, itemIndex) => itemIndex !== index) : current,
    );

  const rows = (requests.data ?? []) as Row[];

  return (
    <section className="mb-5 space-y-3" aria-labelledby="prescriber-correction-heading">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 id="prescriber-correction-heading" className="text-lg font-bold">
            {lang === "ar" ? "طلبات تصحيح الوصفات" : "Prescription correction requests"}
          </h2>
          <p className="text-sm text-muted-foreground">
            {lang === "ar"
              ? "طلبات البنود غير المرتبطة بدليل الأدوية. صلاحية قاعدة البيانات تحدد الطلبات التي يمكنك رؤيتها."
              : "Unlinked medicine items awaiting your review. Database authorization limits this list to requests assigned to you."}
          </p>
        </div>
        <span className="rounded-full border px-3 py-1 text-sm tabular-nums">
          {rows.length} {lang === "ar" ? "معلّق" : "pending"}
        </span>
      </div>

      {requests.error ? (
        <p
          role="alert"
          className="rounded-md border border-destructive/40 p-3 text-sm text-destructive"
        >
          {requests.error.message}
        </p>
      ) : null}
      {requests.isLoading ? (
        <p className="rounded-md border p-4 text-sm text-muted-foreground">
          {lang === "ar" ? "جارٍ تحميل الطلبات..." : "Loading requests..."}
        </p>
      ) : rows.length === 0 ? (
        <div className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">
          {lang === "ar"
            ? "لا توجد طلبات تصحيح معلّقة."
            : "There are no pending correction requests."}
        </div>
      ) : (
        <div className="grid gap-3">
          {rows.map((request) => {
            const patient = rel(request, "patients");
            const item = rel(request, "prescription_items");
            const visit = rel(request, "visits");
            return (
              <article key={s(request, "id")} className="rounded-lg border bg-card p-3 sm:p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0 space-y-1">
                    <p className="font-semibold">{s(patient, "full_name") || "—"}</p>
                    <p className="text-xs text-muted-foreground">
                      <bdi dir="ltr">{s(patient, "mrn") || "—"}</bdi>
                      {" · "}
                      {lang === "ar" ? "الزيارة" : "Visit"}{" "}
                      <bdi dir="ltr">{s(visit, "visit_number") || "—"}</bdi>
                    </p>
                    <p className="text-sm">
                      <strong>
                        {s(item, "medication_name") ||
                          (lang === "ar" ? "دواء غير محدد" : "Unspecified medicine")}
                      </strong>
                      {" · "}
                      {[s(item, "dose"), s(item, "frequency"), s(item, "duration")]
                        .filter(Boolean)
                        .join(" · ") || "—"}
                    </p>
                    <p className="whitespace-pre-wrap text-sm text-muted-foreground">
                      {s(request, "reason")}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {lang === "ar" ? "وقت الطلب" : "Requested"}:{" "}
                      <bdi dir="ltr">{new Date(s(request, "requested_at")).toLocaleString()}</bdi>
                    </p>
                  </div>
                  <div className="flex w-full flex-wrap gap-2 sm:w-auto">
                    <Button
                      type="button"
                      size="sm"
                      onClick={() => openResolution(request, "replace_item")}
                    >
                      {lang === "ar" ? "تصحيح البند" : "Correct item"}
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => openResolution(request, "reject")}
                    >
                      {lang === "ar" ? "رفض الطلب" : "Reject request"}
                    </Button>
                    {canCreatePrescription ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onClick={() => openResolution(request, "cancel_and_reissue")}
                      >
                        {lang === "ar"
                          ? "إلغاء الوصفة وإصدار وصفة كاملة"
                          : "Cancel and reissue full prescription"}
                      </Button>
                    ) : null}
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      )}

      <Dialog
        open={Boolean(selected)}
        onOpenChange={(open) => {
          if (!open) setSelected(null);
        }}
      >
        <DialogContent
          dir={lang === "ar" ? "rtl" : "ltr"}
          className="max-h-[90dvh] overflow-y-auto sm:max-w-2xl"
        >
          <DialogHeader>
            <DialogTitle>
              {action === "reject"
                ? lang === "ar"
                  ? "رفض طلب التصحيح"
                  : "Reject correction request"
                : action === "cancel_and_reissue"
                  ? lang === "ar"
                    ? "إلغاء الوصفة وإصدار وصفة بديلة كاملة"
                    : "Cancel and reissue a complete prescription"
                  : lang === "ar"
                    ? "تصحيح بند الوصفة"
                    : "Correct prescription item"}
            </DialogTitle>
          </DialogHeader>
          {action === "replace_item" ? (
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1 text-sm font-medium sm:col-span-2">
                {lang === "ar"
                  ? "اختر الدواء من الدليل النشط"
                  : "Select an active catalogue medicine"}
                <Select
                  value={form.medicineId}
                  onValueChange={(value) =>
                    setForm((current) => ({ ...current, medicineId: value }))
                  }
                >
                  <SelectTrigger className="h-11">
                    <SelectValue placeholder={lang === "ar" ? "اختر دواءً" : "Choose a medicine"} />
                  </SelectTrigger>
                  <SelectContent>
                    {((catalogue.data ?? []) as Row[]).map((medicine) => (
                      <SelectItem key={s(medicine, "id")} value={s(medicine, "id")}>
                        {s(medicine, "name") || s(medicine, "generic_name")}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </label>
              {field("dose", lang === "ar" ? "الجرعة" : "Dose", "e.g. 500 mg")}
              {field("frequency", lang === "ar" ? "التكرار" : "Frequency", "e.g. BID")}
              {field("duration", lang === "ar" ? "المدة" : "Duration", "e.g. 5 days")}
              {field(
                "quantity",
                lang === "ar" ? "الكمية الموصوفة" : "Prescribed quantity",
                "e.g. 10",
                "number",
              )}
              {field(
                "dosageForm",
                lang === "ar" ? "الشكل الصيدلاني" : "Dosage form",
                "e.g. tablet",
              )}
              {field("route", lang === "ar" ? "طريق الإعطاء" : "Route", "e.g. oral")}
              <label className="grid gap-1 text-sm font-medium sm:col-span-2">
                {lang === "ar" ? "تعليمات إضافية" : "Additional instructions"}
                <Textarea
                  rows={2}
                  value={form.instructions}
                  onChange={(event) =>
                    setForm((current) => ({ ...current, instructions: event.target.value }))
                  }
                />
              </label>
              <label className="grid gap-1 text-sm font-medium sm:col-span-2">
                {lang === "ar" ? "ملاحظة للطبيب (اختيارية)" : "Prescriber note (optional)"}
                <Textarea
                  rows={2}
                  value={form.note}
                  onChange={(event) =>
                    setForm((current) => ({ ...current, note: event.target.value }))
                  }
                />
              </label>
            </div>
          ) : action === "reject" ? (
            <label className="grid gap-1.5 text-sm font-medium">
              {lang === "ar"
                ? "سبب الرفض (10 أحرف على الأقل)"
                : "Reason for rejection (at least 10 characters)"}
              <Textarea
                rows={4}
                maxLength={1000}
                value={form.note}
                onChange={(event) =>
                  setForm((current) => ({ ...current, note: event.target.value }))
                }
              />
            </label>
          ) : (
            <div className="grid gap-4">
              <p className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm">
                {lang === "ar"
                  ? "سيُلغى الطلب الأصلي بالكامل ويُنشأ طلب بديل في الزيارة نفسها. أعد إدخال جميع البنود؛ لا تُنسخ جرعات أو تعليمات تلقائياً."
                  : "The original prescription will be cancelled and a complete replacement created for the same visit. Re-enter every item; no doses or instructions are copied automatically."}
              </p>
              {replacementOrderItems.map((item, index) => (
                <div key={index} className="grid gap-3 rounded-lg border p-3 sm:grid-cols-2">
                  <div className="flex items-center justify-between gap-2 sm:col-span-2">
                    <h3 className="text-sm font-semibold">
                      {lang === "ar" ? `البند ${index + 1}` : `Item ${index + 1}`}
                    </h3>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      disabled={replacementOrderItems.length <= 1}
                      onClick={() => removeReplacementOrderItem(index)}
                    >
                      {lang === "ar" ? "حذف البند" : "Remove item"}
                    </Button>
                  </div>
                  <label className="grid gap-1 text-sm font-medium sm:col-span-2">
                    {lang === "ar" ? "الدواء من الدليل النشط" : "Active catalogue medicine"}
                    <Select
                      value={item.medicineId}
                      onValueChange={(value) =>
                        setReplacementOrderItems((current) =>
                          current.map((entry, itemIndex) =>
                            itemIndex === index ? { ...entry, medicineId: value } : entry,
                          ),
                        )
                      }
                    >
                      <SelectTrigger className="h-11">
                        <SelectValue
                          placeholder={lang === "ar" ? "اختر دواءً" : "Choose a medicine"}
                        />
                      </SelectTrigger>
                      <SelectContent>
                        {((catalogue.data ?? []) as Row[]).map((medicine) => (
                          <SelectItem key={s(medicine, "id")} value={s(medicine, "id")}>
                            {s(medicine, "name") || s(medicine, "generic_name")}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </label>
                  {orderField(index, "dose", lang === "ar" ? "الجرعة" : "Dose", "e.g. 500 mg")}
                  {orderField(
                    index,
                    "frequency",
                    lang === "ar" ? "التكرار" : "Frequency",
                    "e.g. BID",
                  )}
                  {orderField(
                    index,
                    "duration",
                    lang === "ar" ? "المدة" : "Duration",
                    "e.g. 5 days",
                  )}
                  {orderField(
                    index,
                    "quantity",
                    lang === "ar" ? "الكمية" : "Quantity",
                    "e.g. 10",
                    "number",
                  )}
                  {orderField(
                    index,
                    "dosageForm",
                    lang === "ar" ? "الشكل الدوائي" : "Dosage form",
                    "e.g. tablet",
                  )}
                  {orderField(
                    index,
                    "route",
                    lang === "ar" ? "طريق الإعطاء" : "Route",
                    "e.g. oral",
                  )}
                  <label className="grid gap-1 text-sm font-medium sm:col-span-2">
                    {lang === "ar" ? "تعليمات إضافية" : "Additional instructions"}
                    <Textarea
                      rows={2}
                      value={item.instructions}
                      onChange={(event) =>
                        setReplacementOrderItems((current) =>
                          current.map((entry, itemIndex) =>
                            itemIndex === index
                              ? { ...entry, instructions: event.target.value }
                              : entry,
                          ),
                        )
                      }
                    />
                  </label>
                </div>
              ))}
              <Button type="button" variant="outline" onClick={addReplacementOrderItem}>
                {lang === "ar" ? "إضافة دواء آخر" : "Add another medicine"}
              </Button>
              <label className="grid gap-1.5 text-sm font-medium">
                {lang === "ar" ? "ملاحظة للطبيب (اختيارية)" : "Prescriber note (optional)"}
                <Textarea
                  rows={2}
                  value={form.note}
                  onChange={(event) =>
                    setForm((current) => ({ ...current, note: event.target.value }))
                  }
                />
              </label>
            </div>
          )}
          <p className="text-xs text-muted-foreground">
            {lang === "ar"
              ? "لن يؤدي هذا الإجراء إلى صرف الدواء أو تعديل المخزون أو إنشاء فاتورة. أدخل الجرعة والتكرار والمدة يدوياً؛ لا توجد استنتاجات آلية."
              : "This action does not dispense, change stock, or create an invoice. Enter dose, frequency and duration manually; no regimen is inferred."}
          </p>
          <DialogFooter className="flex-col-reverse gap-2 sm:flex-row">
            <Button type="button" variant="outline" onClick={() => setSelected(null)}>
              {lang === "ar" ? "إلغاء" : "Cancel"}
            </Button>
            <Button
              type="button"
              disabled={
                resolve.isPending ||
                (action === "reject"
                  ? form.note.trim().length < 10
                  : action === "replace_item"
                    ? !form.medicineId ||
                      !form.dose.trim() ||
                      !form.frequency.trim() ||
                      !form.duration.trim() ||
                      !Number.isSafeInteger(Number(form.quantity)) ||
                      Number(form.quantity) <= 0 ||
                      !form.dosageForm.trim() ||
                      !form.route.trim()
                    : !isCompleteReplacementOrder(replacementOrderItems))
              }
              onClick={submitResolution}
            >
              {resolve.isPending
                ? lang === "ar"
                  ? "جارٍ الحفظ..."
                  : "Saving..."
                : action === "reject"
                  ? lang === "ar"
                    ? "تأكيد الرفض"
                    : "Confirm rejection"
                  : action === "cancel_and_reissue"
                    ? lang === "ar"
                      ? "إلغاء الأصل وإصدار البديل"
                      : "Cancel original and issue replacement"
                    : lang === "ar"
                      ? "حفظ التصحيح"
                      : "Save correction"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}
