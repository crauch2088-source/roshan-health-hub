import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { useRows, useSave, type Row, s } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import { QUICK_ASSESSMENT, QUICK_COMPLAINTS, QUICK_EXAM, QUICK_HPI, QUICK_PLAN } from "../constants";

const FIELDS = [
  ["chief_complaint", "الشكوى الرئيسية / Chief complaint", 2],
  ["hpi", "تاريخ المرض الحالي / HPI", 4],
  ["past_medical_history", "التاريخ المرضي السابق / PMH", 3],
  ["drug_history", "الأدوية الحالية / Drug history", 3],
  ["allergy_history", "الحساسيات / Allergies", 2],
  ["examination", "الفحص السريري / Examination", 4],
  ["assessment", "التقييم / Assessment", 3],
  ["plan", "الخطة / Plan", 4],
] as const;

function appendText(current: string, value: string) {
  if (!value) return current;
  if (!current.trim()) return value;
  const existing = current.split(/\n+/).map((x) => x.trim()).filter(Boolean);
  if (existing.includes(value)) return current;
  return `${current.trim()}\n${value}`;
}

function QuickChips({ items, lang, onPick }: { items: { en: string; ar: string }[]; lang: string; onPick: (value: string) => void }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {items.map((item) => {
        const label = lang === "ar" ? item.ar : item.en;
        return <Button key={`${item.en}-${item.ar}`} type="button" size="sm" variant="outline" className="h-8 text-xs" onClick={() => onPick(label)}>{label}</Button>;
      })}
    </div>
  );
}

export function ClinicalNoteTab({ visitId }: { visitId: string }) {
  const { user } = useAuth();
  const { lang } = useLang();
  const [form, setForm] = useState<Record<string, string>>({});
  const [diagnosisSearch, setDiagnosisSearch] = useState("");

  const noteQ = useRows<Row[]>(["clinical-note", visitId], () => supabase.from("clinical_notes").select("*").eq("visit_id", visitId).is("deleted_at", null).order("created_at", { ascending: false }).limit(1));
  const diagnosesQ = useRows<Row[]>(["diagnoses", visitId], () => supabase.from("diagnoses").select("*").eq("visit_id", visitId).is("deleted_at", null).order("created_at"));

  useEffect(() => {
    const r = ((noteQ.data ?? []) as Row[])[0];
    if (r) setForm(r);
  }, [noteQ.data]);

  const save = useSave(async () => {
    const existing = ((noteQ.data ?? []) as Row[])[0];
    const payload = {
      visit_id: visitId,
      chief_complaint: form.chief_complaint || null,
      hpi: form.hpi || null,
      past_medical_history: form.past_medical_history || null,
      drug_history: form.drug_history || null,
      allergy_history: form.allergy_history || null,
      examination: form.examination || null,
      assessment: form.assessment || null,
      plan: form.plan || null,
      doctor_id: user?.id ?? null,
      updated_by: user?.id ?? null,
    };
    const q = existing
      ? supabase.from("clinical_notes").update(payload).eq("id", s(existing, "id"))
      : supabase.from("clinical_notes").insert({ ...payload, created_by: user?.id ?? null });
    const { error } = await q;
    if (error) throw new Error(error.message);
    return null;
  }, { invalidate: [["clinical-note", visitId]], successMessage: lang === "ar" ? "تم حفظ الملاحظات" : "Clinical note saved" });

  const addDiagnosis = useSave(async () => {
    const name = (form.new_diagnosis || "").trim();
    if (!name) throw new Error(lang === "ar" ? "أدخل التشخيص" : "Enter a diagnosis");
    const { error } = await supabase.from("diagnoses").insert({
      visit_id: visitId,
      diagnosis_name: name,
      icd10_code: form.icd10 || null,
      diagnosis_type: "clinical",
      is_primary: ((diagnosesQ.data ?? []) as Row[]).length === 0,
      doctor_id: user?.id ?? null,
      created_by: user?.id ?? null,
    });
    if (error) throw new Error(error.message);
    setForm({ ...form, new_diagnosis: "", icd10: "" });
    return null;
  }, { invalidate: [["diagnoses", visitId]], successMessage: lang === "ar" ? "تم حفظ التشخيص" : "Diagnosis saved" });

  const set = (key: string, value: string) => setForm((prev) => ({ ...prev, [key]: value }));
  const diagnoses = (diagnosesQ.data ?? []) as Row[];
  const filteredDiagnoses = useMemo(() => {
    const term = diagnosisSearch.trim().toLowerCase();
    if (!term) return diagnoses;
    return diagnoses.filter((d) => `${s(d, "diagnosis_name")} ${s(d, "icd10_code")}`.toLowerCase().includes(term));
  }, [diagnoses, diagnosisSearch]);

  return (
    <div className="space-y-5" dir="auto">
      <Card>
        <CardHeader><CardTitle className="text-base">{lang === "ar" ? "التقييم السريري السريع" : "Rapid clinical documentation"}</CardTitle></CardHeader>
        <CardContent className="space-y-4 p-4">
          {FIELDS.map(([key, label, rows]) => (
            <div key={key} className="space-y-2">
              <label className="text-sm font-medium">{label}</label>
              {key === "chief_complaint" && <QuickChips items={QUICK_COMPLAINTS} lang={lang} onPick={(v) => set(key, appendText(form[key] ?? "", v))} />}
              {key === "hpi" && <QuickChips items={QUICK_HPI} lang={lang} onPick={(v) => set(key, appendText(form[key] ?? "", v))} />}
              {key === "examination" && <QuickChips items={QUICK_EXAM} lang={lang} onPick={(v) => set(key, appendText(form[key] ?? "", v))} />}
              {key === "assessment" && <QuickChips items={QUICK_ASSESSMENT} lang={lang} onPick={(v) => set(key, appendText(form[key] ?? "", v))} />}
              {key === "plan" && <QuickChips items={QUICK_PLAN} lang={lang} onPick={(v) => set(key, appendText(form[key] ?? "", v))} />}
              <Textarea value={form[key] ?? ""} onChange={(e) => set(key, e.target.value)} rows={rows} placeholder={lang === "ar" ? "يمكنك الاختيار من الأزرار أعلاه أو الكتابة يدويًا..." : "Pick quick phrases above or type freely..."} />
            </div>
          ))}
          <div className="flex justify-end"><Button disabled={save.isPending} onClick={() => save.mutate(undefined as never)}>{save.isPending ? (lang === "ar" ? "جاري الحفظ..." : "Saving...") : (lang === "ar" ? "حفظ الملاحظات" : "Save note")}</Button></div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="text-base">{lang === "ar" ? "التشخيصات" : "Diagnoses"}</CardTitle></CardHeader>
        <CardContent className="space-y-4 p-4">
          <div className="grid gap-2 sm:grid-cols-[1fr_180px_auto]">
            <Input placeholder={lang === "ar" ? "التشخيص" : "Diagnosis"} value={form.new_diagnosis ?? ""} onChange={(e) => set("new_diagnosis", e.target.value)} />
            <Input dir="ltr" placeholder="ICD-10" value={form.icd10 ?? ""} onChange={(e) => set("icd10", e.target.value)} />
            <Button variant="outline" disabled={addDiagnosis.isPending} onClick={() => addDiagnosis.mutate(undefined as never)}>{lang === "ar" ? "إضافة" : "Add"}</Button>
          </div>
          {diagnoses.length > 3 && <Input value={diagnosisSearch} onChange={(e) => setDiagnosisSearch(e.target.value)} placeholder={lang === "ar" ? "بحث داخل تشخيصات الزيارة" : "Search visit diagnoses"} />}
          <div className="space-y-2">
            {filteredDiagnoses.map((d) => <div key={s(d, "id")} className="flex items-center justify-between rounded-lg border p-3"><div><div className="font-medium">{s(d, "diagnosis_name")}</div>{s(d, "icd10_code") && <div className="text-xs text-muted-foreground" dir="ltr">{s(d, "icd10_code")}</div>}</div>{s(d, "is_primary") === "true" && <span className="rounded-full bg-primary/10 px-2 py-1 text-xs text-primary">{lang === "ar" ? "أساسي" : "Primary"}</span>}</div>)}
            {!diagnoses.length && <div className="text-sm text-muted-foreground">{lang === "ar" ? "لا توجد تشخيصات بعد" : "No diagnoses yet"}</div>}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
