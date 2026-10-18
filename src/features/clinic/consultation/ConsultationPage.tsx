import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2, Receipt } from "lucide-react";
import { buttonVariants, Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Loading, StatusBadge } from "@/components/kit";
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { ClinicalNoteTab } from "./components/ClinicalNoteTab";
import { VitalsTab } from "./components/VitalsTab";
import { LaboratoryTab } from "./components/LaboratoryTab";
import { PrescriptionTab } from "./components/PrescriptionTab";
import { HistoryTab } from "./components/HistoryTab";

export function ConsultationPage({ visitId }: { visitId: string }) {
  const { lang } = useLang();
  const { currency } = useSettings();
  const [tab, setTab] = useState("note");
  const [noteDirty, setNoteDirty] = useState(false);
  const [reviewChecks, setReviewChecks] = useState<Record<string, boolean>>({
    identity: false,
    history: false,
    vitals: false,
    plan: false,
  });
  const changeTab = (nextTab: string) => {
    if (tab === "note" && noteDirty && nextTab !== "note") {
      const message =
        lang === "ar"
          ? "لديك تغييرات غير محفوظة في الملاحظات السريرية. هل تريد مغادرة القسم وفقدان هذه التغييرات؟"
          : "You have unsaved clinical note changes. Leave this section and discard them?";
      if (!window.confirm(message)) return;
      setNoteDirty(false);
    }
    setTab(nextTab);
  };
  const visitQ = useRows<Row[]>(["consultation-visit", visitId], () =>
    supabase
      .from("visits")
      .select(
        "id,visit_number,status,visit_date,patient_id,doctor_id,department_id,consultation_fee,patients(id,full_name,mrn,gender,date_of_birth),departments(name,name_ar),users!visits_doctor_id_fkey(full_name)",
      )
      .eq("id", visitId)
      .limit(1),
  );
  const visit = (visitQ.data ?? [])[0] as Row | undefined;
  const patient = rel(visit, "patients");
  const finish = useSave(
    async () => {
      const { error } = await supabase.rpc("complete_visit_atomic", {
        p_visit_id: visitId,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [
        ["consultation-visit", visitId],
        ["clinic-visits"],
        ["visits"],
        ["queue"],
        ["patient-visits"],
        ["patient-snapshot-visits"],
      ],
      successMessage: lang === "ar" ? "تم إنهاء الزيارة" : "Visit completed",
    },
  );

  // Visit -> Billing integration. visits.tsx already auto-creates an invoice
  // (linked via invoices.visit_id) at the moment the visit is created, IF a
  // consultation fee was set then. This just surfaces that link here, and —
  // only if no primary invoice exists yet for this visit_id — offers a safe way to
  // create one. Secondary invoices are intentional exceptions and must never hide
  // the visit’s consolidated primary invoice.
  const invoiceQ = useRows<Row[]>(
    ["consultation-invoice", visitId],
    () =>
      supabase
        .from("invoices")
        .select("id,invoice_number,net_amount,paid_amount,status")
        .eq("visit_id", visitId)
        .eq("is_primary", true)
        .is("deleted_at", null)
        .limit(1),
    { enabled: Boolean(visitId) },
  );
  const existingInvoice = (invoiceQ.data ?? [])[0] as Row | undefined;

  const createInvoice = useSave(
    async () => {
      if (!visit) throw new Error("Visit not loaded");
      const fee = n(visit, "consultation_fee");
      if (fee <= 0)
        throw new Error(
          lang === "ar"
            ? "رسوم الاستشارة غير محددة أو صفر"
            : "Consultation fee is not set or is zero",
        );
      const { error } = await supabase.rpc("create_visit_consultation_invoice_atomic", {
        p_visit_id: visitId,
        p_invoice_date: new Date().toISOString().slice(0, 10),
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["consultation-invoice", visitId], ["invoices"]],
      successMessage: lang === "ar" ? "تم إنشاء الفاتورة" : "Invoice created",
    },
  );

  if (!visit)
    return (
      <div className="p-6">
        {visitQ.isLoading ? (
          <Loading />
        ) : lang === "ar" ? (
          "لم يتم العثور على الزيارة"
        ) : (
          "Visit not found"
        )}
      </div>
    );
  const reviewItems = [
    {
      key: "identity",
      ar: "تأكد من هوية المريض والزيارة",
      en: "Confirm patient and visit identity",
    },
    {
      key: "history",
      ar: "راجع الحساسية والأدوية والتاريخ المهم",
      en: "Review allergies, medicines and relevant history",
    },
    {
      key: "vitals",
      ar: "راجع العلامات الحيوية عند الحاجة",
      en: "Review vitals when clinically indicated",
    },
    {
      key: "plan",
      ar: "راجع الطلبات والوصفة وخطة المتابعة",
      en: "Review orders, prescription and follow-up plan",
    },
  ];
  const reviewCount = Object.values(reviewChecks).filter(Boolean).length;

  const tabs = [
    { key: "note", ar: "الملاحظات", en: "Clinical note" },
    { key: "vitals", ar: "العلامات الحيوية", en: "Vitals" },
    { key: "labs", ar: "المختبر", en: "Laboratory" },
    { key: "prescription", ar: "الوصفة", en: "Prescription" },
    { key: "history", ar: "السجل السابق", en: "History" },
  ] as const;
  return (
    <div className="mx-auto max-w-[1440px] space-y-5" dir="auto">
      <div className="flex flex-wrap items-center gap-3">
        <Link to="/clinic" className={buttonVariants({ variant: "outline", size: "sm" })}>
          <ArrowLeft className="size-4" /> {lang === "ar" ? "العيادة" : "Clinic"}
        </Link>
        <div className="ms-auto flex flex-wrap items-center gap-2">
          <StatusBadge status={s(visit, "status")} />

          {/* Billing — three honest states: loading, existing invoice (link to it,
           never create a second one), or none yet (offer to create one from
           the consultation fee already on the visit). */}
          {invoiceQ.isLoading ? null : existingInvoice ? (
            <Link
              to="/billing/$invoiceId"
              params={{ invoiceId: s(existingInvoice, "id") }}
              className={buttonVariants({ variant: "outline", size: "sm" })}
              title={
                lang === "ar"
                  ? "عرض الفاتورة المرتبطة بهذه الزيارة"
                  : "View the invoice linked to this visit"
              }
            >
              <Receipt className="size-4" /> {money(n(existingInvoice, "net_amount"), currency)} ·{" "}
              {s(existingInvoice, "status")}
            </Link>
          ) : n(visit, "consultation_fee") > 0 ? (
            <Button
              variant="outline"
              size="sm"
              onClick={() => createInvoice.mutate(undefined as never)}
              disabled={createInvoice.isPending}
              title={
                lang === "ar" ? "إنشاء فاتورة لهذه الزيارة" : "Create an invoice for this visit"
              }
            >
              <Receipt className="size-4" /> {lang === "ar" ? "إنشاء فاتورة" : "Create invoice"}
            </Button>
          ) : null}

          {s(visit, "status") !== "completed" && (
            <Button
              size="sm"
              onClick={() => finish.mutate(undefined as never)}
              disabled={finish.isPending}
            >
              <CheckCircle2 className="size-4" />
              {lang === "ar" ? "إنهاء الزيارة" : "Finish visit"}
            </Button>
          )}
        </div>
      </div>
      <Card className="roshan-patient-context overflow-hidden">
        <CardContent className="grid gap-4 p-4 sm:grid-cols-2 sm:p-5 lg:grid-cols-5">
          <div className="min-w-0">
            <div className="roshan-field-label">{lang === "ar" ? "المريض" : "Patient"}</div>
            <div className="truncate text-base font-bold tracking-tight">
              {s(patient, "full_name") || "—"}
            </div>
            <div
              className="mt-1 inline-flex rounded-md bg-background/80 px-2 py-0.5 font-mono text-xs text-muted-foreground"
              dir="ltr"
            >
              {s(patient, "mrn") || "—"}
            </div>
          </div>
          <div>
            <div className="roshan-field-label">
              {lang === "ar" ? "العمر / الجنس" : "Age / Sex"}
            </div>
            <div className="font-semibold">
              {calcAge(s(patient, "date_of_birth")) ?? "—"} · {s(patient, "gender") || "—"}
            </div>
          </div>
          <div>
            <div className="roshan-field-label">
              {lang === "ar" ? "رقم الزيارة" : "Visit number"}
            </div>
            <div className="font-mono text-base font-bold" dir="ltr">
              {s(visit, "visit_number") || "—"}
            </div>
          </div>
          <div>
            <div className="roshan-field-label">{lang === "ar" ? "القسم" : "Department"}</div>
            <div>
              {lang === "ar"
                ? s(rel(visit, "departments"), "name_ar") || s(rel(visit, "departments"), "name")
                : s(rel(visit, "departments"), "name")}
            </div>
          </div>
          <div>
            <div className="roshan-field-label">{lang === "ar" ? "الطبيب" : "Doctor"}</div>
            <div>{s(rel(visit, "users"), "full_name") || "—"}</div>
          </div>
        </CardContent>
      </Card>
      <details className="roshan-surface px-4 py-3">
        <summary className="flex cursor-pointer list-none flex-wrap items-center justify-between gap-2 text-sm font-semibold outline-none focus-visible:ring-2 focus-visible:ring-ring">
          <span>
            {lang === "ar" ? "مراجعة سريرية سريعة (اختيارية)" : "Quick clinical review (optional)"}
          </span>
          <span className="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-bold text-primary">
            {reviewCount}/4
          </span>
        </summary>
        <p className="mt-2 text-xs leading-relaxed text-muted-foreground">
          {lang === "ar"
            ? "تذكير محلي فقط: لا تُحفظ هذه العلامات ولا تمنع إنهاء الزيارة أو التعامل مع الطوارئ."
            : "Local reminder only: these checks are not saved and never block visit completion or emergency care."}
        </p>
        <div className="mt-3 grid gap-2 sm:grid-cols-2">
          {reviewItems.map((item) => (
            <label
              key={item.key}
              className="flex min-h-10 items-start gap-2 rounded-lg border border-border/70 bg-background/60 p-2.5 text-sm"
            >
              <input
                type="checkbox"
                checked={reviewChecks[item.key]}
                onChange={(event) =>
                  setReviewChecks((current) => ({ ...current, [item.key]: event.target.checked }))
                }
                className="mt-0.5 size-4 shrink-0 accent-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              />
              <span>{lang === "ar" ? item.ar : item.en}</span>
            </label>
          ))}
        </div>
      </details>
      <div className="roshan-surface p-1.5">
        <div
          className="flex gap-1 overflow-x-auto"
          role="tablist"
          aria-label={lang === "ar" ? "أقسام ملف الزيارة" : "Visit chart sections"}
        >
          {tabs.map((item, index) => (
            <button
              key={item.key}
              id={`tab-${item.key}`}
              type="button"
              role="tab"
              aria-selected={tab === item.key}
              aria-controls={`panel-${item.key}`}
              tabIndex={tab === item.key ? 0 : -1}
              onClick={() => changeTab(item.key)}
              onKeyDown={(event) => {
                const backwards = event.key === "ArrowLeft" || event.key === "ArrowUp";
                const forwards = event.key === "ArrowRight" || event.key === "ArrowDown";
                const targetIndex =
                  event.key === "Home"
                    ? 0
                    : event.key === "End"
                      ? tabs.length - 1
                      : backwards
                        ? (index - 1 + tabs.length) % tabs.length
                        : forwards
                          ? (index + 1) % tabs.length
                          : -1;
                if (targetIndex >= 0) {
                  event.preventDefault();
                  const next = tabs[targetIndex];
                  if (next) {
                    changeTab(next.key);
                    document.getElementById(`tab-${next.key}`)?.focus();
                  }
                }
              }}
              className="roshan-tab shrink-0 px-4 py-2.5 text-sm font-semibold text-muted-foreground"
            >
              {lang === "ar" ? item.ar : item.en}
            </button>
          ))}
        </div>
      </div>
      <section
        id={`panel-${tab}`}
        role="tabpanel"
        aria-labelledby={`tab-${tab}`}
        tabIndex={0}
        className="min-w-0 outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-offset-2"
      >
        {tab === "note" && <ClinicalNoteTab visitId={visitId} onDirtyChange={setNoteDirty} />}
        {tab === "vitals" && <VitalsTab visitId={visitId} />}
        {tab === "labs" && <LaboratoryTab visitId={visitId} />}
        {tab === "prescription" && <PrescriptionTab visitId={visitId} />}
        {tab === "history" && <HistoryTab visitId={visitId} />}
      </section>
    </div>
  );
}
