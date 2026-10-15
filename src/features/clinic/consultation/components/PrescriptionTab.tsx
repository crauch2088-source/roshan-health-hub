import { useState } from "react";
import {
  createEmptyPrescriptionDraft,
  createPrescriptionDraftForMedicine,
  type PrescriptionDraft,
} from "@/lib/prescription-draft";
import { sanitizeTerm, useDebounced } from "@/lib/search";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import { DOSES, DOSAGE_FORMS, FREQUENCIES, ROUTES, DURATIONS } from "../constants";

export function PrescriptionTab({ visitId }: { visitId: string }) {
  const { lang } = useLang();
  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () =>
    supabase
      .from("visits")
      .select("id,patient_id,doctor_id,patients(id,full_name)")
      .eq("id", visitId)
      .limit(1),
  );
  const patient = s(rel((visitQ.data ?? [])[0], "patients"), "id");
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search, 300);
  const cleanSearch = sanitizeTerm(debouncedSearch);
  const medsQ = useRows<Row[]>(
    ["medicines-search", cleanSearch],
    () => {
      let query = supabase
        .from("medicines")
        .select("id,name,generic_name,brand_name,strength,dosage_form,selling_price,stock_quantity")
        .eq("active", true)
        .is("deleted_at", null)
        .order("name")
        .limit(30);
      if (cleanSearch.length >= 2) {
        query = query.or(
          `name.ilike.%${cleanSearch}%,generic_name.ilike.%${cleanSearch}%,brand_name.ilike.%${cleanSearch}%,strength.ilike.%${cleanSearch}%`,
        );
      }
      return query;
    },
    { enabled: cleanSearch.length !== 1 },
  );
  const [form, setForm] = useState<PrescriptionDraft>(createEmptyPrescriptionDraft);
  const [items, setItems] = useState<PrescriptionDraft[]>([]);
  const [external, setExternal] = useState(false);
  const medicines = (medsQ.data ?? []) as Row[];
  const filtered = medicines;
  const chooseMedicine = (id: string) => {
    const m = medicines.find((x) => s(x, "id") === id);
    if (!m) return;
    const next = createPrescriptionDraftForMedicine({
      id,
      name: s(m, "name"),
      generic_name: s(m, "generic_name"),
      dosage_form: s(m, "dosage_form"),
    });
    setForm(next);
    setSearch(next.name);
  };
  const add = () => {
    if (!form.name.trim() && !form.medicine_id) return;
    setItems((current) => [...current, { ...form }]);
    setForm(createEmptyPrescriptionDraft());
    setSearch("");
  };
  const save = useSave(
    async () => {
      if (!patient) throw new Error(lang === "ar" ? "المريض غير موجود" : "Patient not found");
      if (!items.length)
        throw new Error(lang === "ar" ? "أضف دواءً واحداً على الأقل" : "Add at least one medicine");
      const payload = items.map((item) => ({
        medicine_id: item.medicine_id || null,
        medication_name: item.name.trim(),
        dose: item.dose,
        frequency: item.frequency,
        duration: item.duration,
        quantity: Number(item.quantity),
        instructions: item.instructions,
        dosage_form: item.dosage_form,
        route: item.route,
      }));
      const { error } = await supabase.rpc("create_prescription_atomic", {
        p_visit_id: visitId,
        p_is_external: external,
        p_items: payload,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [
        ["patient-rx", patient],
        ["prescriptions", visitId],
      ],
      successMessage: lang === "ar" ? "تم حفظ الوصفة" : "Prescription saved",
      onDone: () => {
        setItems([]);
        setForm(createEmptyPrescriptionDraft());
        setSearch("");
        setExternal(false);
      },
    },
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {lang === "ar" ? "الوصفة الطبية" : "Prescription"}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 p-4">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={external}
            onChange={(e) => setExternal(e.target.checked)}
          />
          {lang === "ar"
            ? "وصفة خارجية / لن تُصرف من صيدلية المركز"
            : "External prescription / not dispensed by center"}
        </label>
        <div className="relative">
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={
              lang === "ar"
                ? "ابحث باسم الدواء أو المادة أو القوة"
                : "Search medicine, generic or strength"
            }
          />
          {search.trim().length === 1 && (
            <p role="status" className="mt-1 text-xs text-muted-foreground">
              {lang === "ar"
                ? "اكتب حرفين على الأقل للبحث"
                : "Type at least 2 characters to search"}
            </p>
          )}
          {medsQ.isLoading && cleanSearch.length >= 2 && (
            <p role="status" className="mt-1 text-xs text-muted-foreground">
              {lang === "ar" ? "جارٍ البحث عن الأدوية..." : "Searching medicines..."}
            </p>
          )}
          {medsQ.error && (
            <p role="alert" className="mt-1 text-xs text-destructive">
              {lang === "ar"
                ? "تعذر تحميل نتائج الأدوية. حاول مجدداً."
                : "Could not load medicines. Please try again."}
            </p>
          )}
          {search.trim().length >= 2 &&
            !medsQ.isLoading &&
            !medsQ.error &&
            filtered.length === 0 && (
            <p role="status" className="mt-1 text-xs text-muted-foreground">
              {lang === "ar" ? "لا توجد أدوية مطابقة" : "No matching medicines"}
            </p>
          )}
          {search.trim() && search !== form.name && filtered.length > 0 && (
            <div className="absolute z-20 mt-1 max-h-64 w-full overflow-auto rounded-lg border bg-popover p-1 shadow-lg">
              {filtered.map((m) => (
                <button
                  type="button"
                  key={s(m, "id")}
                  className="flex w-full items-center justify-between rounded-md px-3 py-2 text-start text-sm hover:bg-muted"
                  onClick={() => chooseMedicine(s(m, "id"))}
                >
                  <span>
                    <span className="font-medium">{s(m, "name") || s(m, "generic_name")}</span>
                    {s(m, "strength") && (
                      <span className="ms-2 text-xs text-muted-foreground">{s(m, "strength")}</span>
                    )}
                  </span>
                  <span className="text-xs text-muted-foreground">
                    {s(m, "stock_quantity") || "0"}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder={lang === "ar" ? "اسم الدواء" : "Medication name"}
          />
          <Select
            value={form.dosage_form || "custom"}
            onValueChange={(v) => setForm({ ...form, dosage_form: v === "custom" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder={lang === "ar" ? "الشكل الدوائي" : "Dosage form"} />
            </SelectTrigger>
            <SelectContent>
              {DOSAGE_FORMS.map((x) => (
                <SelectItem key={x.value} value={x.value}>
                  {lang === "ar" ? x.labelAr : x.label}
                </SelectItem>
              ))}
              <SelectItem value="custom">{lang === "ar" ? "إدخال يدوي" : "Custom"}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-3 sm:grid-cols-4">
          <Select
            value={form.dose || "custom"}
            onValueChange={(v) => setForm({ ...form, dose: v === "custom" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder={lang === "ar" ? "الجرعة" : "Dose"} />
            </SelectTrigger>
            <SelectContent>
              {DOSES.map((x) => (
                <SelectItem key={x.value} value={x.value}>
                  {lang === "ar" ? x.labelAr : x.label}
                </SelectItem>
              ))}
              <SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem>
            </SelectContent>
          </Select>
          <Select
            value={form.frequency || "custom"}
            onValueChange={(v) => setForm({ ...form, frequency: v === "custom" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder={lang === "ar" ? "التكرار" : "Frequency"} />
            </SelectTrigger>
            <SelectContent>
              {FREQUENCIES.map((x) => (
                <SelectItem key={x.value} value={x.value}>
                  {lang === "ar" ? x.labelAr : x.label}
                </SelectItem>
              ))}
              <SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem>
            </SelectContent>
          </Select>
          <Select
            value={form.duration || "custom"}
            onValueChange={(v) => setForm({ ...form, duration: v === "custom" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder={lang === "ar" ? "المدة" : "Duration"} />
            </SelectTrigger>
            <SelectContent>
              {DURATIONS.map((x) => (
                <SelectItem key={x.value} value={x.value}>
                  {lang === "ar" ? x.labelAr : x.label}
                </SelectItem>
              ))}
              <SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem>
            </SelectContent>
          </Select>
          <Input
            dir="ltr"
            type="number"
            min="1"
            value={form.quantity}
            onChange={(e) => setForm({ ...form, quantity: e.target.value })}
            placeholder={lang === "ar" ? "الكمية" : "Qty"}
          />
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Select
            value={form.route || "custom"}
            onValueChange={(v) => setForm({ ...form, route: v === "custom" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder={lang === "ar" ? "طريق الإعطاء" : "Route"} />
            </SelectTrigger>
            <SelectContent>
              {ROUTES.map((x) => (
                <SelectItem key={x.value} value={x.value}>
                  {lang === "ar" ? x.labelAr : x.label}
                </SelectItem>
              ))}
              <SelectItem value="custom">{lang === "ar" ? "يدوي" : "Custom"}</SelectItem>
            </SelectContent>
          </Select>
          <Input
            value={form.instructions}
            onChange={(e) => setForm({ ...form, instructions: e.target.value })}
            placeholder={lang === "ar" ? "تعليمات إضافية" : "Instructions"}
          />
        </div>
        <Button variant="outline" type="button" onClick={add}>
          + {lang === "ar" ? "إضافة للروشتة" : "Add to prescription"}
        </Button>
        {items.length > 0 && (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/30">
                  <th className="p-2 text-start">{lang === "ar" ? "الدواء" : "Drug"}</th>
                  <th className="p-2 text-start">{lang === "ar" ? "الجرعة" : "Dose"}</th>
                  <th className="p-2 text-start">{lang === "ar" ? "التكرار" : "Frequency"}</th>
                  <th className="p-2 text-start">{lang === "ar" ? "المدة" : "Duration"}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {items.map((i, index) => (
                  <tr key={`${i.medicine_id}-${index}`} className="border-b last:border-0">
                    <td className="p-2">{i.name}</td>
                    <td className="p-2">{i.dose || "—"}</td>
                    <td className="p-2">{i.frequency || "—"}</td>
                    <td className="p-2">{i.duration || "—"}</td>
                    <td className="p-2 text-end">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setItems(items.filter((_, x) => x !== index))}
                      >
                        {lang === "ar" ? "حذف" : "Remove"}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="flex justify-end">
          <Button
            disabled={save.isPending || !items.length}
            onClick={() => save.mutate(undefined as never)}
          >
            {save.isPending
              ? lang === "ar"
                ? "جاري الحفظ..."
                : "Saving..."
              : lang === "ar"
                ? "حفظ الوصفة"
                : "Save prescription"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
function rel(row: Row | undefined, key: string): Row {
  const x = row?.[key];
  return (Array.isArray(x) ? x[0] : x) || {};
}
