import { useMemo, useState } from "react";
import { StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useAuth } from "@/lib/auth";
import { b, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDateTime } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { DOSES, DOSAGE_FORMS, FREQUENCIES, ROUTES, DURATIONS } from "../constants";

type Med = { medicine_id: string; name: string; dose: string; frequency: string; duration: string; quantity: string; instructions: string; dosage_form: string; route: string };

export function PrescriptionTab({ visitId }: { visitId: string }) {
  const { user } = useAuth();
  const { lang } = useLang();
  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () => supabase.from("visits").select("id,patient_id,doctor_id,patients(id,full_name)").eq("id", visitId).limit(1));
  const patient = s(rel((visitQ.data ?? [])[0], "patients"), "id");
  const medsQ = useRows<Row[]>(["medicines-search"], () => supabase.from("medicines").select("id,name,generic_name,brand_name,strength,dosage_form,selling_price,stock_quantity").eq("active", true).is("deleted_at", null).order("name").limit(500));
  // Same query shape the Pharmacy dispense queue already uses, scoped to
  // this visit. Without this, a doctor prescribing here had no way to see
  // a prescription already written earlier in the same visit - risking a
  // duplicate prescription and, once dispensed, a duplicate charge.
  const existingRxQ = useRows<Row[]>(["clinic-prescriptions", visitId], () =>
    supabase
      .from("prescriptions")
      .select("id, status, created_at, is_external, prescription_items(id, quantity, dosage, frequency, duration, medicines(name))")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );
  const existingRx = (existingRxQ.data ?? []) as Row[];
  const [form, setForm] = useState<Med>({ medicine_id: "", name: "", dose: "", frequency: "", duration: "", quantity: "1", instructions: "", dosage_form: "", route: "" });
  const [items, setItems] = useState<Med[]>([]);
  const [external, setExternal] = useState(false);
  const [search, setSearch] = useState("");
  const medicines = (medsQ.data ?? []) as Row[];
  const filtered = useMemo(() => { const q = search.trim().toLowerCase(); if (!q) return medicines.slice(0, 30); return medicines.filter((m) => `${s(m, "name")} ${s(m, "generic_name")} ${s(m, "brand_name")} ${s(m, "strength")}`.toLowerCase().includes(q)).slice(0, 30); }, [medicines, search]);
  const chooseMedicine = (id: string) => { const m = medicines.find((x) => s(x, "id") === id); const formName = m ? s(m, "name") || s(m, "generic_name") : ""; const dosageForm = m ? s(m, "dosage_form") : ""; const defaultRoute = dosageForm.toLowerCase().includes("tablet") || dosageForm.toLowerCase().includes("capsule") || dosageForm.toLowerCase().includes("syrup") ? "Oral" : ""; setForm((p) => ({ ...p, medicine_id: id, name: formName, dosage_form: dosageForm, route: defaultRoute })); setSearch(formName); };
  const add = () => { if (!form.name.trim() && !form.medicine_id) return; setItems((current) => [...current, { ...form }]); setForm({ ...form, medicine_id: "", name: "", quantity: "1", instructions: "" }); setSearch(""); };
  const save = useSave(async () => {
    if (!patient) throw new Error(lang === "ar" ? "المريض غير موجود" : "Patient not found");
    if (!items.length) throw new Error(lang === "ar" ? "أضف دواءً واحداً على الأقل" : "Add at least one medicine");
    const { data: rx, error } = await supabase.from("prescriptions").insert({ patient_id: patient, visit_id: visitId, prescribed_by: user?.id ?? null, doctor_id: user?.id ?? null, prescription_type: external ? "external" : "internal", is_external: external, status: "pending", created_by: user?.id ?? null }).select("id").single();
    if (error) throw new Error(error.message);
    const rows = items.map((i) => ({ prescription_id: rx.id, medicine_id: i.medicine_id || null, medication_name: i.name, dose: i.dose || null, dosage: i.dose || null, frequency: i.frequency || null, duration: i.duration || null, dosage_form: i.dosage_form || null, route: i.route || null, quantity: Number(i.quantity) || 1, instructions: i.instructions || null, unit_price: i.medicine_id ? Number(((medsQ.data ?? []) as Row[]).find((m) => s(m, "id") === i.medicine_id)?.["selling_price"]) || 0 : 0, created_by: user?.id ?? null }));
    const { error: e } = await supabase.from("prescription_items").insert(rows); if (e) throw new Error(e.message); return null;
  }, { invalidate: [["patient-rx", patient], ["prescriptions", visitId]], successMessage: lang === "ar" ? "تم حفظ الوصفة" : "Prescription saved" });

  return <div className="space-y-4">
    {existingRx.length > 0 && (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">
            {lang === "ar" ? "وصفات سابقة لهذه الزيارة" : "Prescriptions already written this visit"}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 p-4 pt-0">
          {existingRx.map((rx) => {
            const rxItems = (rx["prescription_items"] as Row[]) ?? [];
            const names = rxItems.map((i) => s(rel(i, "medicines"), "name") || "—").join(", ");
            return (
              <div key={s(rx, "id")} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border p-3 text-sm">
                <div className="min-w-0">
                  <div className="truncate font-medium">{names || "—"}</div>
                  <div className="text-xs text-muted-foreground" dir="ltr">
                    {formatDateTime(s(rx, "created_at"))}
                    {b(rx, "is_external") ? ` · ${lang === "ar" ? "خارجية" : "external"}` : ""}
                  </div>
                </div>
                <StatusBadge status={s(rx, "status")} />
              </div>
            );
          })}
        </CardContent>
      </Card>
    )}
    <Card><CardHeader><CardTitle className="text-base">{lang === "ar" ? "الوصفة الطبية" : "Prescription"}</CardTitle></CardHeader><CardContent className="space-y-4 p-4">
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={external} onChange={(e) => setExternal(e.target.checked)} />{lang === "ar" ? "وصفة خارجية / لن تُصرف من صيدلية المركز" : "External prescription / not dispensed by center"}</label>
    <div className="relative"><Input value={search} onChange={(e) => setSearch(e.target.value)} placeholder={lang === "ar" ? "ابحث باسم الدواء أو المادة أو القوة" : "Search medicine, generic or strength"} />{search && filtered.length > 0 && <div className="absolute z-20 mt-1 max-h-64 w-full overflow-auto rounded-lg border bg-popover p-1 shadow-lg">{filtered.map((m) => <button type="button" key={s(m, "id")} className="flex w-full items-center justify-between rounded-md px-3 py-2 text-start text-sm hover:bg-muted" onClick={() => chooseMedicine(s(m, "id"))}><span><span className="font-medium">{s(m, "name") || s(m, "generic_name")}</span>{s(m, "strength") && <span className="ms-2 text-xs text-muted-foreground">{s(m, "strength")}</span>}</span><span className="text-xs text-muted-foreground">{s(m, "stock_quantity") || "0"}</span></button>)}</div>}</div>
    <div className="grid gap-3 sm:grid-cols-2"><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder={lang === "ar" ? "اسم الدواء" : "Medication name"} /><Select value={form.dosage_form || "custom"} onValueChange={(v) => setForm({ ...form, dosage_form: v === "custom" ? "" : v })}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "الشكل الدوائي" : "Dosage form"} /></SelectTrigger><SelectContent>{DOSAGE_FORMS.map((x) => <SelectItem key={x.value} value={x.value}>{lang === "ar" ? x.labelAr : x.label}</SelectItem>)}<SelectItem value="custom">{lang === "ar" ? "إدخال يدوي" : "Custom"}</SelectItem></SelectContent></Select></div>
    <div className="grid gap-3 sm:grid-cols-4"><Select value={form.dose || "custom"} onValueChange={(v) => setForm({ ...form, dose: v === "custom" ? "" : v })}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "الجرعة" : "Dose"} /></SelectTrigger><SelectContent>{DOSES.map((x) => <SelectItem key={x.value} value={x.value}>{lang === "ar" ? x.labelAr : x.label}</SelectItem>)}<SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem></SelectContent></Select><Select value={form.frequency || "custom"} onValueChange={(v) => setForm({ ...form, frequency: v === "custom" ? "" : v })}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "التكرار" : "Frequency"} /></SelectTrigger><SelectContent>{FREQUENCIES.map((x) => <SelectItem key={x.value} value={x.value}>{lang === "ar" ? x.labelAr : x.label}</SelectItem>)}<SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem></SelectContent></Select><Select value={form.duration || "custom"} onValueChange={(v) => setForm({ ...form, duration: v === "custom" ? "" : v })}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "المدة" : "Duration"} /></SelectTrigger><SelectContent>{DURATIONS.map((x) => <SelectItem key={x.value} value={x.value}>{lang === "ar" ? x.labelAr : x.label}</SelectItem>)}<SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem></SelectContent></Select><Input dir="ltr" type="number" min="1" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} placeholder={lang === "ar" ? "الكمية" : "Qty"} /></div>
    <div className="grid gap-3 sm:grid-cols-2"><Select value={form.route || "custom"} onValueChange={(v) => setForm({ ...form, route: v === "custom" ? "" : v })}><SelectTrigger><SelectValue placeholder={lang === "ar" ? "طريق الإعطاء" : "Route"} /></SelectTrigger><SelectContent>{ROUTES.map((x) => <SelectItem key={x.value} value={x.value}>{lang === "ar" ? x.labelAr : x.label}</SelectItem>)}<SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem></SelectContent></Select><Input value={form.instructions} onChange={(e) => setForm({ ...form, instructions: e.target.value })} placeholder={lang === "ar" ? "تعليمات إضافية" : "Instructions"} /></div>
    <Button variant="outline" type="button" onClick={add}>+ {lang === "ar" ? "إضافة للروشتة" : "Add to prescription"}</Button>
    {items.length > 0 && <div className="overflow-x-auto rounded-lg border"><table className="w-full text-sm"><thead><tr className="border-b bg-muted/30"><th className="p-2 text-start">{lang === "ar" ? "الدواء" : "Drug"}</th><th className="p-2 text-start">{lang === "ar" ? "الجرعة" : "Dose"}</th><th className="p-2 text-start">{lang === "ar" ? "التكرار" : "Frequency"}</th><th className="p-2 text-start">{lang === "ar" ? "المدة" : "Duration"}</th><th /></tr></thead><tbody>{items.map((i, index) => <tr key={`${i.medicine_id}-${index}`} className="border-b last:border-0"><td className="p-2">{i.name}</td><td className="p-2">{i.dose || "—"}</td><td className="p-2">{i.frequency || "—"}</td><td className="p-2">{i.duration || "—"}</td><td className="p-2 text-end"><Button variant="ghost" size="sm" onClick={() => setItems(items.filter((_, x) => x !== index))}>{lang === "ar" ? "حذف" : "Remove"}</Button></td></tr>)}</tbody></table></div>}
    <div className="flex justify-end"><Button disabled={save.isPending || !items.length} onClick={() => save.mutate(undefined as never)}>{save.isPending ? (lang === "ar" ? "جاري الحفظ..." : "Saving...") : (lang === "ar" ? "حفظ الوصفة" : "Save prescription")}</Button></div>
  </CardContent></Card>
  </div>;
}
function rel(row: Row | undefined, key: string): Row { const x = row?.[key]; return (Array.isArray(x) ? x[0] : x) || {}; }
