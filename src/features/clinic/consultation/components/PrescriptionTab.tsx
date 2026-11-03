import { useState } from "react";
import {
  buildMedicineSearchFilter,
  createEmptyPrescriptionDraft,
  createPrescriptionDraftForMedicine,
  editPrescriptionName,
  validatePrescriptionDrafts,
  type PrescriptionDraft,
} from "@/lib/prescription-draft";
import { sanitizeTerm, useDebounced } from "@/lib/search";
import { Button } from "@/components/ui/button";
import { PrintButton } from "@/components/kit";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { n, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import { calcAge, formatDateTime } from "@/lib/medical";
import { buildPrescriptionPrintModel } from "@/lib/print/prescription";
import { DOSAGE_FORMS, FREQUENCIES, ROUTES, DURATIONS } from "../constants";

export function PrescriptionTab({ visitId }: { visitId: string }) {
  const { lang } = useLang();
  const { settings } = useSettings();
  const [lastSavedPrescription, setLastSavedPrescription] = useState<{
    visitId: string;
    id: string;
  } | null>(null);
  const lastSavedPrescriptionId =
    lastSavedPrescription?.visitId === visitId ? lastSavedPrescription.id : null;
  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () =>
    supabase
      .from("visits")
      .select("id,patient_id,doctor_id,patients(id,full_name,date_of_birth)")
      .eq("id", visitId)
      .limit(1),
  );
  const patientRow = rel((visitQ.data ?? [])[0], "patients");
  const patient = s(patientRow, "id");
  const patientAge = calcAge(s(patientRow, "date_of_birth"));
  const ageVerificationNeeded =
    Boolean(patient) && patientAge == null && !visitQ.isLoading && !visitQ.error;
  const vitalsQ = useRows<Row[]>(["clinic-vitals-weight", visitId], () =>
    supabase
      .from("vitals")
      .select("weight,created_at")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(1),
  );
  const patientWeight = n((vitalsQ.data ?? [])[0], "weight");
  const savedPrescriptionQ = useRows<Row[]>(
    ["prescription-print", visitId, lastSavedPrescriptionId],
    () =>
      supabase
        .from("prescriptions")
        .select(
          "id,created_at,status,is_external,notes,patients(full_name,mrn,deleted_at),users(full_name),prescription_items(id,medication_name,dose,route,frequency,duration,quantity,dosage_form,instructions,deleted_at)",
        )
        .eq("id", lastSavedPrescriptionId ?? "")
        .eq("visit_id", visitId)
        .eq("patient_id", patient)
        .is("deleted_at", null)
        .limit(1),
    { enabled: Boolean(lastSavedPrescriptionId) },
  );
  const savedPrescription = (savedPrescriptionQ.data ?? [])[0] as Row | undefined;
  const prescriptionPrintModel = buildPrescriptionPrintModel(savedPrescription);
  const isPediatric = patientAge != null && patientAge < 18;
  const pediatricWeightMissing =
    isPediatric && !vitalsQ.isLoading && !vitalsQ.error && patientWeight <= 0;
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search, 300);
  const cleanSearch = sanitizeTerm(debouncedSearch);
  const medicineFilter = buildMedicineSearchFilter(debouncedSearch);
  const medsQ = useRows<Row[]>(
    ["medicines-search", medicineFilter ?? ""],
    () => {
      let query = supabase
        .from("medicines")
        .select("id,name,generic_name,brand_name,strength,dosage_form,selling_price,stock_quantity")
        .eq("active", true)
        .is("deleted_at", null)
        .order("name")
        .limit(30);
      if (medicineFilter) query = query.or(medicineFilter);
      return query;
    },
    { enabled: Boolean(medicineFilter) },
  );
  const [form, setForm] = useState<PrescriptionDraft>(createEmptyPrescriptionDraft);
  const [items, setItems] = useState<PrescriptionDraft[]>([]);
  const [external, setExternal] = useState(false);
  const isKnownDosageForm = DOSAGE_FORMS.some((option) => option.value === form.dosage_form);
  const isKnownFrequency = FREQUENCIES.some((option) => option.value === form.frequency);
  const isKnownDuration = DURATIONS.some((option) => option.value === form.duration);
  const isKnownRoute = ROUTES.some((option) => option.value === form.route);
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
      const validation = validatePrescriptionDrafts(items);
      if (validation) {
        const messages = {
          empty: lang === "ar" ? "أضف دواءً واحداً على الأقل" : "Add at least one medicine",
          "missing-name": lang === "ar" ? "أدخل اسم كل دواء" : "Enter a name for every medicine",
          "missing-dose":
            lang === "ar" ? "أكمل الجرعة لكل دواء" : "Complete the dose for every medicine",
          "missing-frequency":
            lang === "ar"
              ? "أكمل تكرار الاستخدام لكل دواء"
              : "Complete the frequency for every medicine",
          "missing-duration":
            lang === "ar" ? "أكمل مدة العلاج لكل دوا