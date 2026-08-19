import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import {
  ArrowLeft,
  Check,
  ChevronDown,
  Clock3,
  Plus,
  Search,
  Stethoscope,
  Trash2,
  X,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
  SectionTitle,
  StatusBadge,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
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
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";

import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import {
  calcAge,
  calcBmi,
  calcEdd,
  calcGestationalDays,
  formatDate,
  formatDateTime,
  formatGestationalAge,
} from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import {
  CHRONIC_CONDITIONS,
  DOSAGE_FORMS,
  FORM_DEFAULT_ROUTE,
  ROUTES,
  parseChronic,
  serializeChronic,
} from "@/features/clinic/consultation/constants";
import type { RxItem } from "@/features/clinic/consultation/types";

/**
 * Vitals are colour-coded against simple adult reference ranges so the
 * doctor's eye is drawn to anything abnormal. This is a visual aid only —
 * it never blocks saving and is not a clinical protocol.
 */
const vitalSeverity = (
  type: "spo2" | "sbp" | "temp" | "pulse" | "rr",
  raw: unknown,
): "normal" | "warning" | "critical" => {
  const value = Number(raw);
  if (!Number.isFinite(value) || !raw) return "normal";

  if (type === "spo2") {
    if (value < 90) return "critical";
    if (value < 94) return "warning";
  }

  if (type === "sbp") {
    if (value < 90 || value > 180) return "critical";
    if (value < 100 || value > 160) return "warning";
  }

  if (type === "temp") {
    if (value > 39.5) return "critical";
    if (value > 38.5) return "warning";
  }

  if (type === "pulse") {
    if (value > 130 || value < 40) return "critical";
    if (value > 100 || value < 50) return "warning";
  }

  if (type === "rr") {
    if (value > 30) return "critical";
    if (value > 24) return "warning";
  }

  return "normal";
};

const vitalClass = (
  severity: ReturnType<typeof vitalSeverity>,
) => {
  if (severity === "critical") {
    return "border-destructive bg-destructive/10 text-destructive ring-1 ring-destructive/30";
  }
  if (severity === "warning") {
    return "border-amber-500 bg-amber-50 text-amber-700 ring-1 ring-amber-300";
  }
  return "";
};

export const Route = createFileRoute(
  "/_authenticated/clinic_/$visitId",
)({
  head: () => ({
    meta: [
      {
        title: "Consultation — ROSHAN Medical Center",
      },
      {
        name: "description",
        content:
          "Clinical consultation workspace for ROSHAN Medical Center.",
      },
    ],
  }),
  component: Consultation,
});

type QuickOption = {
  en: string;
  ar: string;
};

const QUICK_COMPLAINTS: QuickOption[] = [
  { en: "Fever", ar: "حمى" },
  { en: "Cough", ar: "سعال" },
  { en: "Sore throat", ar: "التهاب الحلق" },
  { en: "Headache", ar: "صداع" },
  { en: "Abdominal pain", ar: "ألم البطن" },
  { en: "Vomiting", ar: "قيء" },
  { en: "Diarrhea", ar: "إسهال" },
  { en: "Back pain", ar: "ألم الظهر" },
  { en: "Chest pain", ar: "ألم الصدر" },
  { en: "Shortness of breath", ar: "ضيق التنفس" },
  { en: "Dizziness", ar: "دوخة" },
  { en: "URTI symptoms", ar: "أعراض عدوى الجهاز التنفسي العلوي" },
  { en: "Dysuria", ar: "عسر التبول" },
  { en: "Pregnancy follow-up", ar: "متابعة الحمل" },
];

const QUICK_HPI: QuickOption[] = [
  {
    en: "No significant past history.",
    ar: "لا يوجد تاريخ مرضي مهم.",
  },
  {
    en: "Symptoms started recently.",
    ar: "بدأت الأعراض حديثًا.",
  },
  {
    en: "No known drug allergies.",
    ar: "لا توجد حساسية دوائية معروفة.",
  },
  {
    en: "No history of similar attacks.",
    ar: "لا يوجد تاريخ لنوبات مشابهة.",
  },
  {
    en: "Symptoms are worsening.",
    ar: "الأعراض في تزايد.",
  },
  {
    en: "Symptoms are improving.",
    ar: "الأعراض في تحسن.",
  },
  {
    en: "No associated red-flag symptoms reported.",
    ar: "لا توجد أعراض إنذارية مصاحبة حسب الإفادة.",
  },
];

const QUICK_EXAM: QuickOption[] = [
  {
    en: "General condition: stable.",
    ar: "الحالة العامة: مستقرة.",
  },
  {
    en: "Patient is conscious and oriented.",
    ar: "المريض واعٍ ومدرك.",
  },
  {
    en: "No respiratory distress.",
    ar: "لا توجد علامات ضيق تنفسي.",
  },
  {
    en: "Chest: clear bilaterally.",
    ar: "الصدر: أصوات تنفسية طبيعية ثنائيًا.",
  },
  {
    en: "Heart: normal S1/S2.",
    ar: "القلب: S1/S2 طبيعيان.",
  },
  {
    en: "Abdomen: soft and non-tender.",
    ar: "البطن: لين وغير مؤلم.",
  },
  {
    en: "No focal neurological deficit.",
    ar: "لا يوجد عجز عصبي بؤري.",
  },
  {
    en: "No peripheral edema.",
    ar: "لا توجد وذمة طرفية.",
  },
];

const QUICK_ASSESSMENT: QuickOption[] = [
  { en: "Acute viral infection", ar: "عدوى فيروسية حادة" },
  { en: "URTI", ar: "عدوى الجهاز التنفسي العلوي" },
  { en: "Acute gastroenteritis", ar: "التهاب معدة وأمعاء حاد" },
  { en: "Acute bronchitis", ar: "التهاب شعب هوائية حاد" },
  { en: "Tension headache", ar: "صداع توتري" },
  { en: "Dyspepsia", ar: "عسر هضم" },
  { en: "UTI", ar: "التهاب المسالك البولية" },
  { en: "Low back pain", ar: "ألم أسفل الظهر" },
];

const QUICK_PLAN: QuickOption[] = [
  {
    en: "Supportive treatment and symptomatic management.",
    ar: "علاج داعم وعلاج للأعراض.",
  },
  {
    en: "Hydration and adequate oral fluids.",
    ar: "الإكثار من السوائل والترطيب.",
  },
  {
    en: "Rest and follow-up if symptoms worsen.",
    ar: "الراحة والمتابعة إذا ساءت الأعراض.",
  },
  {
    en: "Return immediately if red-flag symptoms develop.",
    ar: "العودة فورًا عند ظهور أي أعراض إنذارية.",
  },
  {
    en: "Follow up as needed.",
    ar: "المراجعة عند الحاجة.",
  },
];

const DOSES = [
  "250 mg",
  "500 mg",
  "1 g",
  "5 mg",
  "10 mg",
  "20 mg",
  "40 mg",
  "50 mg",
  "100 mg",
  "200 mg",
  "400 mg",
  "600 mg",
  "1 tablet",
  "2 tablets",
  "5 mL",
  "10 mL",
];

const FREQUENCIES = [
  "Once daily",
  "Twice daily",
  "Three times daily",
  "Four times daily",
  "Every 4 hours",
  "Every 6 hours",
  "Every 8 hours",
  "Every 12 hours",
  "At night",
  "As needed",
];

const DURATIONS = [
  "1 day",
  "2 days",
  "3 days",
  "5 days",
  "7 days",
  "10 days",
  "14 days",
  "Until improved",
  "As needed",
];

function Consultation() {
  const { visitId } = useParams({
    from: "/_authenticated/clinic_/$visitId",
  });

  const { t, lang } = useLang();
  const { can, user } = useAuth();
  const isArabic = lang === "ar";

  const [vitals, setVitals] = useState<Row>({});
  const [clinicalNote, setClinicalNote] = useState<Row>({});
  const [selectedChronic, setSelectedChronic] = useState<string[]>([]);
  const [chronicOther, setChronicOther] = useState("");
  const [labSel, setLabSel] = useState<string[]>([]);
  const [labSearch, setLabSearch] = useState("");
  const [labCategory, setLabCategory] = useState("all");

  const [rx, setRx] = useState<RxItem[]>([]);
  const [rxExternal, setRxExternal] = useState(false);

  // IMPORTANT: search state is now independent for every prescription row.
  const [medicineSearch, setMedicineSearch] =
    useState<Record<number, string>>({});

  const [showMoreVitals, setShowMoreVitals] = useState(false);

  const visitQ = useRows(["visit", visitId], () =>
    supabase
      .from("visits")
      .select(
        "id, visit_number, visit_date, status, patient_id, doctor_id, patients(id, full_name, mrn, gender, date_of_birth, blood_group), departments(name, name_ar)",
      )
      .eq("id", visitId)
      .limit(1),
  );

  const visit = ((visitQ.data ?? []) as Row[])[0];
  const patient = rel(visit, "patients");
  const patientId = s(patient, "id");
  const isFemale = s(patient, "gender") === "female";

  const vitalsQ = useRows(["vitals", visitId], () =>
    supabase
      .from("vitals")
      .select("*")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .limit(1),
  );

  const clinicalNoteQ = useRows(
    ["clinical-note", visitId],
    () =>
      supabase
        .from("clinical_notes")
        .select("*")
        .eq("visit_id", visitId)
        .is("deleted_at", null)
        .limit(1),
  );

  const testsQ = useRows(["lab-tests"], () =>
    supabase
      .from("lab_tests")
      .select("id, name, name_ar, price, category, active")
      .eq("active", true)
      .is("deleted_at", null)
      .order("name"),
  );

  const medsQ = useRows(["medicines"], () =>
    supabase
      .from("medicines")
      .select(
        "id, name, generic_name, brand_name, strength, dosage_form, unit",
      )
      .eq("active", true)
      .is("deleted_at", null)
      .order("name"),
  );

  const ordersQ = useRows(["visit-labs", visitId], () =>
    supabase
      .from("lab_orders")
      .select(
        "id, status, created_at, lab_order_items(id, status, price, lab_tests(name, name_ar))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const rxQ = useRows(["visit-rx", visitId], () =>
    supabase
      .from("prescriptions")
      .select(
        "id, status, is_external, created_at, prescription_items(id, dosage, dose, dosage_form, route, instructions, frequency, duration, quantity, medicines(name, generic_name, brand_name))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  const historyQ = useRows(
    ["clinical-history", patientId],
    () =>
      supabase
        .from("clinical_notes")
        .select(
          "id, created_at, chief_complaint, assessment, visit_id, visits!inner(patient_id)",
        )
        .eq("visits.patient_id", patientId)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(20),
    {
      enabled: Boolean(patientId),
    },
  );

  useEffect(() => {
    const row = ((vitalsQ.data ?? []) as Row[])[0];

    if (row) {
      setVitals(row);
    }
  }, [vitalsQ.data]);

  useEffect(() => {
    const row = ((clinicalNoteQ.data ?? []) as Row[])[0];

    if (row) {
      setClinicalNote(row);
      const parsed = parseChronic(
        s(row, "past_medical_history"),
      );
      setSelectedChronic(parsed.selected);
      setChronicOther(parsed.other);
    }
  }, [clinicalNoteQ.data]);

  const bmi = calcBmi(
    Number(s(vitals, "weight")),
    Number(s(vitals, "height")),
  );

  const currentSbp =
    s(vitals, "systolic_bp") ||
    s(vitals, "bp_systolic") ||
    s(vitals, "blood_pressure").split("/")[0]?.trim() ||
    "";

  const gestDays = calcGestationalDays(
    s(clinicalNote, "lmp"),
  );

  const appendText = (field: string, value: string) => {
    const current = s(clinicalNote, field);

    const next = current.trim()
      ? `${current.trim()} ${value}`
      : value;

    setClinicalNote({
      ...clinicalNote,
      [field]: next,
    });
  };

  const setChiefComplaint = (option: QuickOption) => {
    setClinicalNote({
      ...clinicalNote,
      chief_complaint: isArabic ? option.ar : option.en,
    });
  };

  const filteredTests = useMemo(() => {
    const tests = (testsQ.data ?? []) as Row[];
    const query = labSearch.trim().toLowerCase();

    return tests.filter((test) => {
      const name = s(test, "name").toLowerCase();
      const nameAr = s(test, "name_ar").toLowerCase();
      const category = s(test, "category").toLowerCase();

      const matchesSearch =
        !query ||
        name.includes(query) ||
        nameAr.includes(query);

      const matchesCategory =
        labCategory === "all" ||
        category === labCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    });
  }, [testsQ.data, labSearch, labCategory]);

  const labCategories = useMemo(() => {
    const values = new Set<string>();

    for (const test of (testsQ.data ?? []) as Row[]) {
      const category = s(test, "category");

      if (category) {
        values.add(category);
      }
    }

    return Array.from(values);
  }, [testsQ.data]);

  const allMedicines = useMemo(
    () => ((medsQ.data ?? []) as Row[]),
    [medsQ.data],
  );

  const toggleLab = (id: string) => {
    setLabSel((current) =>
      current.includes(id)
        ? current.filter((x) => x !== id)
        : [...current, id],
    );
  };

  const addPrescription = () => {
    setRx((current) => [
      ...current,
      {
        medicine_id: "",
        dosage: "",
        dosage_form: "",
        route: "",
        frequency: "",
        duration: "",
        quantity: "1",
        instructions: "",
      },
    ]);
  };

  const updateRx = (
    index: number,
    patch: Partial<RxItem>,
  ) => {
    setRx((current) =>
      current.map((item, i) =>
        i === index
          ? { ...item, ...patch }
          : item,
      ),
    );
  };

  const removeRx = (index: number) => {
    setRx((current) =>
      current.filter((_, i) => i !== index),
    );

    setMedicineSearch((current) => {
      const next: Record<number, string> = {};

      Object.entries(current).forEach(
        ([key, value]) => {
          const oldIndex = Number(key);

          if (oldIndex < index) {
            next[oldIndex] = value;
          } else if (oldIndex > index) {
            next[oldIndex - 1] = value;
          }
        },
      );

      return next;
    });
  };

  /*
   * ============================================================
   * VITALS
   * ============================================================
   */

  const saveVitals = useSave(
    async () => {
      const weight =
        Number(s(vitals, "weight")) || null;

      const height =
        Number(s(vitals, "height")) || null;

      const calculatedBmi = calcBmi(
        Number(s(vitals, "weight")),
        Number(s(vitals, "height")),
      );

      /*
       * BP is a UI value only.
       * Database receives numeric systolic/diastolic values.
       */
      const bpValue =
        s(vitals, "blood_pressure").trim();

      let systolicBp: number | null = null;
      let diastolicBp: number | null = null;

      if (bpValue.includes("/")) {
        const [sys, dia] = bpValue.split("/");

        systolicBp =
          Number(sys?.trim()) || null;

        diastolicBp =
          Number(dia?.trim()) || null;
      } else {
        systolicBp =
          Number(s(vitals, "systolic_bp")) ||
          Number(s(vitals, "bp_systolic")) ||
          null;

        diastolicBp =
          Number(s(vitals, "diastolic_bp")) ||
          Number(s(vitals, "bp_diastolic")) ||
          null;
      }

      const payload = {
        visit_id: visitId,
        patient_id: patientId,

        temperature:
          Number(s(vitals, "temperature")) || null,

        pulse:
          Number(s(vitals, "pulse")) || null,

        respiratory_rate:
          Number(s(vitals, "respiratory_rate")) || null,

        systolic_bp: systolicBp,
        diastolic_bp: diastolicBp,

        bp_systolic: systolicBp,
        bp_diastolic: diastolicBp,

        weight,
        height,

        bmi: calculatedBmi ?? null,

        spo2:
          Number(s(vitals, "spo2")) || null,

        lmp:
          s(vitals, "lmp") || null,

        edd:
          s(vitals, "edd") || null,

        gestational_age_days:
          Number(
            s(vitals, "gestational_age_days"),
          ) || null,

        recorded_by: user?.id ?? null,
      };

      const existing =
        ((vitalsQ.data ?? []) as Row[])[0];

      if (existing) {
        const { error } = await supabase
          .from("vitals")
          .update(payload)
          .eq("id", s(existing, "id"));

        if (error) {
          throw new Error(error.message);
        }
      } else {
        const { error } = await supabase
          .from("vitals")
          .insert(payload);

        if (error) {
          throw new Error(error.message);
        }
      }

      return null;
    },
    {
      invalidate: [["vitals", visitId]],
      successMessage: t("saved"),
    },
  );

  /*
   * ============================================================
   * CLINICAL NOTE
   * ============================================================
   *
   * IMPORTANT:
   * Saving a note does NOT complete the visit anymore.
   * Completion must be a separate workflow.
   */

  const saveClinicalNote = useSave(
    async () => {
      const lmp = s(clinicalNote, "lmp");

      const gestationalDays =
        calcGestationalDays(lmp);

      const edd = calcEdd(lmp);

      const payload = {
        visit_id: visitId,

        doctor_id:
          user?.id ?? null,

        created_by:
          user?.id ?? null,

        updated_by:
          user?.id ?? null,

        chief_complaint:
          s(clinicalNote, "chief_complaint") ||
          null,

        history_present_illness:
          s(
            clinicalNote,
            "history_present_illness",
          ) ||
          s(clinicalNote, "hpi") ||
          null,

        hpi:
          s(clinicalNote, "hpi") ||
          s(
            clinicalNote,
            "history_present_illness",
          ) ||
          null,

        examination:
          s(clinicalNote, "examination") ||
          null,

        assessment:
          s(clinicalNote, "assessment") ||
          null,

        plan:
          s(clinicalNote, "plan") ||
          null,

        allergy_history:
          s(
            clinicalNote,
            "allergy_history",
          ) || null,

        past_medical_history:
          serializeChronic(
            selectedChronic,
            chronicOther,
          ) ||
          s(
            clinicalNote,
            "past_medical_history",
          ) ||
          null,

        lmp:
          lmp || null,

        edd:
          edd || null,

        gestational_age_days:
          gestationalDays ?? null,
      };

      const existing =
        ((clinicalNoteQ.data ?? []) as Row[])[0];

      if (existing) {
        const { error } = await supabase
          .from("clinical_notes")
          .update(payload)
          .eq("id", s(existing, "id"));

        if (error) {
          throw new Error(error.message);
        }
      } else {
        const { error } = await supabase
          .from("clinical_notes")
          .insert(payload);

        if (error) {
          throw new Error(error.message);
        }
      }

      return null;
    },
    {
      invalidate: [
        ["clinical-note", visitId],
        ["visit", visitId],
        ["clinical-history", patientId],
      ],
      successMessage: t("saved"),
    },
  );

  /*
   * ============================================================
   * LAB ORDERS
   * ============================================================
   */

  const orderLabs = useSave(
    async () => {
      const selectedLabIds = Array.from(
        new Set(
          labSel.filter(Boolean),
        ),
      );

      if (selectedLabIds.length === 0) {
        throw new Error(
          isArabic
            ? "اختر فحصًا واحدًا على الأقل."
            : "Select at least one laboratory test.",
        );
      }

      const { data: order, error } =
        await supabase
          .from("lab_orders")
          .insert({
            visit_id: visitId,
            patient_id: patientId,
            ordered_by: user?.id ?? null,
            created_by: user?.id ?? null,
            status: "ordered",
            priority: "normal",
          })
          .select("id")
          .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!order) {
        throw new Error(
          "Failed to create laboratory order.",
        );
      }

      const items = selectedLabIds.map(
        (testId) => {
          const test = (
            (testsQ.data ?? []) as Row[]
          ).find(
            (row) =>
              s(row, "id") === testId,
          );

          return {
            order_id: order.id,
            test_id: testId,
            price: n(test, "price"),
            status: "pending",
            created_by: user?.id ?? null,
          };
        },
      );

      if (items.length === 0) {
        throw new Error(
          isArabic
            ? "لم يتم اختيار فحوصات صالحة."
            : "No valid laboratory tests selected.",
        );
      }

      const { error: itemError } =
        await supabase
          .from("lab_order_items")
          .insert(items);

      if (itemError) {
        throw new Error(itemError.message);
      }

      return null;
    },
    {
      invalidate: [
        ["visit-labs", visitId],
        ["lab-orders"],
      ],
      successMessage: t("saved"),
      onDone: () => setLabSel([]),
    },
  );

  /*
   * ============================================================
   * PRESCRIPTIONS
   * ============================================================
   */

  const saveRx = useSave(
    async () => {
      const validItems = rx.filter(
        (item) => Boolean(item.medicine_id),
      );

      if (validItems.length === 0) {
        throw new Error(
          isArabic
            ? "يجب اختيار دواء واحد على الأقل."
            : "Select at least one medicine.",
        );
      }

      const { data: pres, error } =
        await supabase
          .from("prescriptions")
          .insert({
            visit_id: visitId,
            patient_id: patientId,

            prescribed_by:
              user?.id ?? null,

            doctor_id:
              user?.id ?? null,

            prescription_type:
              rxExternal
                ? "external"
                : "internal",

            is_external:
              rxExternal,

            status:
              rxExternal
                ? "external"
                : "pending",

            created_by:
              user?.id ?? null,
          })
          .select("id")
          .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!pres) {
        throw new Error(
          "Failed to create prescription.",
        );
      }

      const items = validItems.map(
        (item) => {
          const medicine =
            allMedicines.find(
              (m) =>
                s(m, "id") ===
                item.medicine_id,
            );

          return {
            prescription_id: pres.id,

            medicine_id:
              item.medicine_id,

            medication_name:
              s(medicine, "name") ||
              s(medicine, "generic_name") ||
              null,

            dose:
              item.dosage || null,

            dosage:
              item.dosage || null,

            dosage_form:
              item.dosage_form || null,

            route:
              item.route || null,

            instructions:
              item.instructions || null,

            frequency:
              item.frequency || null,

            duration:
              item.duration || null,

            quantity:
              Number(item.quantity) || 1,

            created_by:
              user?.id ?? null,
          };
        },
      );

      const { error: itemError } =
        await supabase
          .from("prescription_items")
          .insert(items);

      if (itemError) {
        throw new Error(itemError.message);
      }

      return null;
    },
    {
      invalidate: [
        ["visit-rx", visitId],
        ["pharmacy-queue"],
      ],
      successMessage: t("saved"),
      onDone: () => {
        setRx([]);
        setRxExternal(false);
        setMedicineSearch({});
      },
    },
  );

  /*
   * ============================================================
   * COMPLETE VISIT
   * ============================================================
   *
   * Separate from "Save".
   */

  const completeVisit = useSave(
    async () => {
      const complaint =
        s(
          clinicalNote,
          "chief_complaint",
        ).trim();

      const assessment =
        s(
          clinicalNote,
          "assessment",
        ).trim();

      if (!complaint && !assessment) {
        throw new Error(
          isArabic
            ? "أدخل الشكوى أو التشخيص قبل إنهاء الزيارة."
            : "Enter the complaint or assessment before completing the visit.",
        );
      }

      const { error } = await supabase
        .from("visits")
        .update({
          status: "completed",
          completed_at:
            new Date().toISOString(),
          updated_by:
            user?.id ?? null,
        })
        .eq("id", visitId);

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["visit", visitId]],
      successMessage: isArabic
        ? "تم إنهاء الزيارة."
        : "Visit completed.",
    },
  );

  if (visitQ.isLoading) {
    return <Loading />;
  }

  if (!visit) {
    return <Empty label={t("no_data")} />;
  }

  return (
    <div className="space-y-4 pb-10">
      {/* ======================================================
          PATIENT HEADER
      ======================================================= */}

      <PageHeader
        title={s(patient, "full_name")}
        subtitle={`${t("mrn")}: ${s(
          patient,
          "mrn",
        )} · ${t("age")}: ${
          calcAge(
            s(patient, "date_of_birth"),
          ) ?? "—"
        } · ${t(
          s(patient, "gender"),
        )} · ${formatDate(
          s(visit, "visit_date"),
        )}`}
      >
        <StatusBadge status={s(visit, "status")} />

        <Button
          asChild
          variant="outline"
          size="sm"
        >
          <Link to="/clinic">
            <ArrowLeft className="size-4" />
            {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox
        error={
          visitQ.error ??
          vitalsQ.error ??
          clinicalNoteQ.error ??
          testsQ.error ??
          medsQ.error ??
          ordersQ.error ??
          rxQ.error ??
          historyQ.error
        }
      />

      {/* ======================================================
          PATIENT STRIP
      ======================================================= */}

      <Card>
        <CardContent className="flex flex-wrap items-center gap-2 p-3 text-sm">
          <div className="rounded-md bg-muted px-3 py-1.5">
            <strong>MRN:</strong>{" "}
            {s(patient, "mrn")}
          </div>

          {s(patient, "blood_group") ? (
            <div className="rounded-md bg-muted px-3 py-1.5">
              <strong>BG:</strong>{" "}
              {s(patient, "blood_group")}
            </div>
          ) : null}

          <div className="rounded-md bg-muted px-3 py-1.5">
            <strong>
              {t("visit_number")}:
            </strong>{" "}
            {s(visit, "visit_number")}
          </div>

          <div className="ml-auto flex items-center gap-2 text-muted-foreground">
            <Stethoscope className="size-4" />
            {isArabic
              ? "مساحة عمل الطبيب"
              : "Doctor workspace"}
          </div>
        </CardContent>
      </Card>

      {/* ======================================================
          WORKSPACE
      ======================================================= */}

      <Tabs defaultValue="emr">
        <TabsList className="sticky top-0 z-10 mb-4 flex h-auto w-full flex-wrap justify-start gap-1 bg-background/95 p-1 backdrop-blur">
          <TabsTrigger value="emr">
            {t("clinical_notes")}
          </TabsTrigger>

          <TabsTrigger value="vitals">
            {t("vitals")}
          </TabsTrigger>

          <TabsTrigger value="labs">
            {t("laboratory")}

            {labSel.length > 0 ? (
              <span className="ml-1 rounded-full bg-primary px-1.5 text-[10px] text-primary-foreground">
                {labSel.length}
              </span>
            ) : null}
          </TabsTrigger>

          <TabsTrigger value="rx">
            {t("prescription")}

            {rx.length > 0 ? (
              <span className="ml-1 rounded-full bg-primary px-1.5 text-[10px] text-primary-foreground">
                {rx.length}
              </span>
            ) : null}
          </TabsTrigger>

          <TabsTrigger value="history">
            {t("history")}
          </TabsTrigger>
        </TabsList>

        {/* ====================================================
            CLINICAL NOTE
        ===================================================== */}

        <TabsContent value="emr">
          <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_280px]">
            <Card>
              <CardContent className="space-y-5 p-4">
                <div>
                  <SectionTitle>
                    {t("chief_complaint")}
                  </SectionTitle>

                  <div className="mb-2 flex flex-wrap gap-2">
                    {QUICK_COMPLAINTS.map(
                      (option) => {
                        const value =
                          isArabic
                            ? option.ar
                            : option.en;

                        const active =
                          s(
                            clinicalNote,
                            "chief_complaint",
                          ) === value;

                        return (
                          <Button
                            key={option.en}
                            type="button"
                            size="sm"
                            variant={
                              active
                                ? "default"
                                : "outline"
                            }
                            onClick={() =>
                              setChiefComplaint(
                                option,
                              )
                            }
                          >
                            {value}
                          </Button>
                        );
                      },
                    )}
                  </div>

                  <Textarea
                    rows={2}
                    placeholder={
                      isArabic
                        ? "أو اكتب الشكوى عند الحاجة..."
                        : "Or enter the complaint manually..."
                    }
                    value={s(
                      clinicalNote,
                      "chief_complaint",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        chief_complaint:
                          e.target.value,
                      })
                    }
                  />
                </div>

                <div>
                  <SectionTitle>
                    {t("history")}
                  </SectionTitle>

                  <div className="mb-2 flex flex-wrap gap-2">
                    {QUICK_HPI.map(
                      (option) => {
                        const value =
                          isArabic
                            ? option.ar
                            : option.en;

                        return (
                          <Button
                            key={option.en}
                            type="button"
                            size="sm"
                            variant="outline"
                            onClick={() =>
                              appendText(
                                "history_present_illness",
                                value,
                              )
                            }
                          >
                            + {value}
                          </Button>
                        );
                      },
                    )}
                  </div>

                  <Textarea
                    rows={4}
                    placeholder={
                      isArabic
                        ? "HPI..."
                        : "History of presenting illness..."
                    }
                    value={
                      s(
                        clinicalNote,
                        "history_present_illness",
                      ) ||
                      s(
                        clinicalNote,
                        "hpi",
                      )
                    }
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        history_present_illness:
                          e.target.value,
                        hpi: e.target.value,
                      })
                    }
                  />
                </div>

                <div>
                  <SectionTitle>
                    {t("examination")}
                  </SectionTitle>

                  <div className="mb-2 flex flex-wrap gap-2">
                    {QUICK_EXAM.map(
                      (option) => {
                        const value =
                          isArabic
                            ? option.ar
                            : option.en;

                        return (
                          <Button
                            key={option.en}
                            type="button"
                            size="sm"
                            variant="outline"
                            onClick={() =>
                              appendText(
                                "examination",
                                value,
                              )
                            }
                          >
                            + {value}
                          </Button>
                        );
                      },
                    )}
                  </div>

                  <Textarea
                    rows={4}
                    placeholder={
                      isArabic
                        ? "الفحص السريري..."
                        : "Clinical examination..."
                    }
                    value={s(
                      clinicalNote,
                      "examination",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        examination:
                          e.target.value,
                      })
                    }
                  />
                </div>

                <div className="grid gap-5 lg:grid-cols-2">
                  <div>
                    <SectionTitle>
                      {t("diagnosis")}
                    </SectionTitle>

                    <div className="mb-2 flex flex-wrap gap-2">
                      {QUICK_ASSESSMENT.map(
                        (option) => {
                          const value =
                            isArabic
                              ? option.ar
                              : option.en;

                          return (
                            <Button
                              key={option.en}
                              type="button"
                              size="sm"
                              variant="outline"
                              onClick={() =>
                                appendText(
                                  "assessment",
                                  value,
                                )
                              }
                            >
                              + {value}
                            </Button>
                          );
                        },
                      )}
                    </div>

                    <Textarea
                      rows={4}
                      value={s(
                        clinicalNote,
                        "assessment",
                      )}
                      placeholder={
                        isArabic
                          ? "التقييم / التشخيص..."
                          : "Assessment / diagnosis..."
                      }
                      onChange={(e) =>
                        setClinicalNote({
                          ...clinicalNote,
                          assessment:
                            e.target.value,
                        })
                      }
                    />
                  </div>

                  <div>
                    <SectionTitle>
                      {t("treatment_plan")}
                    </SectionTitle>

                    <div className="mb-2 flex flex-wrap gap-2">
                      {QUICK_PLAN.map(
                        (option) => {
                          const value =
                            isArabic
                              ? option.ar
                              : option.en;

                          return (
                            <Button
                              key={option.en}
                              type="button"
                              size="sm"
                              variant="outline"
                              onClick={() =>
                                appendText(
                                  "plan",
                                  value,
                                )
                              }
                            >
                              + {value}
                            </Button>
                          );
                        },
                      )}
                    </div>

                    <Textarea
                      rows={4}
                      value={s(
                        clinicalNote,
                        "plan",
                      )}
                      placeholder={
                        isArabic
                          ? "الخطة..."
                          : "Plan..."
                      }
                      onChange={(e) =>
                        setClinicalNote({
                          ...clinicalNote,
                          plan: e.target.value,
                        })
                      }
                    />
                  </div>
                </div>

                <div className="grid gap-4 md:grid-cols-2">
                  <Field label={t("allergies")}>
                    <Input
                      placeholder={
                        isArabic
                          ? "لا توجد حساسية معروفة"
                          : "No known allergies"
                      }
                      value={s(
                        clinicalNote,
                        "allergy_history",
                      )}
                      onChange={(e) =>
                        setClinicalNote({
                          ...clinicalNote,
                          allergy_history:
                            e.target.value,
                        })
                      }
                    />
                  </Field>

                  <Field
                    label={t("chronic_conditions")}
                  >
                    <div className="space-y-2 rounded-lg border p-3">
                      <div className="grid gap-2 sm:grid-cols-2">
                        {CHRONIC_CONDITIONS.map(
                          (condition) => {
                            const checked =
                              selectedChronic.includes(
                                condition.en,
                              );
                            return (
                              <label
                                key={condition.en}
                                className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-muted"
                              >
                                <Checkbox
                                  checked={checked}
                                  onCheckedChange={(
                                    value,
                                  ) => {
                                    setSelectedChronic(
                                      (current) =>
                                        Boolean(value)
                                          ? current.includes(
                                              condition.en,
                                            )
                                            ? current
                                            : [
                                                ...current,
                                                condition.en,
                                              ]
                                          : current.filter(
                                              (x) =>
                                                x !==
                                                condition.en,
                                            ),
                                    );
                                  }}
                                />
                                <span className="text-sm">
                                  {isArabic
                                    ? condition.ar
                                    : condition.en}
                                </span>
                              </label>
                            );
                          },
                        )}
                      </div>

                      <Input
                        value={chronicOther}
                        placeholder={
                          isArabic
                            ? "أخرى (اذكرها)..."
                            : "Other (specify)..."
                        }
                        onChange={(e) =>
                          setChronicOther(
                            e.target.value,
                          )
                        }
                      />
                    </div>
                  </Field>
                </div>

                {isFemale ? (
                  <Card className="border-dashed">
                    <CardContent className="space-y-4 p-4">
                      <SectionTitle>
                        {t("obstetrics")}
                      </SectionTitle>

                      <div className="grid gap-4 sm:grid-cols-3">
                        <Field label={t("lmp")}>
                          <Input
                            type="date"
                            dir="ltr"
                            value={s(
                              clinicalNote,
                              "lmp",
                            ).slice(0, 10)}
                            onChange={(e) =>
                              setClinicalNote({
                                ...clinicalNote,
                                lmp: e.target.value,
                              })
                            }
                          />
                        </Field>

                        <Field label={t("edd")}>
                          <Input
                            dir="ltr"
                            readOnly
                            value={
                              calcEdd(
                                s(
                                  clinicalNote,
                                  "lmp",
                                ),
                              ) ?? ""
                            }
                          />
                        </Field>

                        <Field
                          label={t(
                            "gestational_age",
                          )}
                        >
                          <Input
                            readOnly
                            value={formatGestationalAge(
                              gestDays,
                              lang,
                            )}
                          />
                        </Field>
                      </div>
                    </CardContent>
                  </Card>
                ) : null}

                {can("emr.create") ? (
                  <div className="sticky bottom-3 z-10 flex flex-wrap justify-end gap-2">
                    <Button
                      size="lg"
                      variant="outline"
                      disabled={
                        saveClinicalNote.isPending ||
                        completeVisit.isPending
                      }
                      onClick={() =>
                        saveClinicalNote.mutate(
                          undefined as never,
                        )
                      }
                    >
                      <Check className="size-4" />
                      {saveClinicalNote.isPending
                        ? t("saving")
                        : t("save")}
                    </Button>

                    <Button
                      size="lg"
                      disabled={
                        saveClinicalNote.isPending ||
                        completeVisit.isPending
                      }
                      onClick={async () => {
                        await saveClinicalNote.mutateAsync(
                          undefined as never,
                        );

                        completeVisit.mutate(
                          undefined as never,
                        );
                      }}
                    >
                      <Check className="size-4" />
                      {completeVisit.isPending
                        ? isArabic
                          ? "جاري الإنهاء..."
                          : "Completing..."
                        : isArabic
                          ? "حفظ وإنهاء الزيارة"
                          : "Save & Complete"}
                    </Button>
                  </div>
                ) : null}
              </CardContent>
            </Card>

            <Card className="h-fit xl:sticky xl:top-20">
              <CardContent className="space-y-4 p-4">
                <SectionTitle>
                  {isArabic
                    ? "ملخص سريع"
                    : "Quick summary"}
                </SectionTitle>

                <div className="space-y-2 text-sm">
                  <div className="rounded-md border p-3">
                    <div className="text-xs text-muted-foreground">
                      {t("chief_complaint")}
                    </div>

                    <div className="mt-1 font-medium">
                      {s(
                        clinicalNote,
                        "chief_complaint",
                      ) || "—"}
                    </div>
                  </div>

                  <div className="rounded-md border p-3">
                    <div className="text-xs text-muted-foreground">
                      {t("diagnosis")}
                    </div>

                    <div className="mt-1 font-medium">
                      {s(
                        clinicalNote,
                        "assessment",
                      ) || "—"}
                    </div>
                  </div>

                  <div className="rounded-md border p-3">
                    <div className="text-xs text-muted-foreground">
                      {t("bmi")}
                    </div>

                    <div className="mt-1 font-medium">
                      {bmi ?? "—"}
                    </div>
                  </div>
                </div>

                <div className="rounded-md bg-muted p-3 text-xs text-muted-foreground">
                  <Clock3 className="mb-1 size-4" />
                  {isArabic
                    ? "يمكن حفظ الملاحظات دون إنهاء الزيارة."
                    : "Notes can be saved without completing the visit."}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ====================================================
            VITALS
        ===================================================== */}

        <TabsContent value="vitals">
          <Card>
            <CardContent className="space-y-5 p-4">
              {[
                vitalSeverity("spo2", s(vitals, "spo2")),
                vitalSeverity("sbp", currentSbp),
                vitalSeverity("temp", s(vitals, "temperature")),
                vitalSeverity("pulse", s(vitals, "pulse")),
                vitalSeverity(
                  "rr",
                  s(vitals, "respiratory_rate"),
                ),
              ].some((severity) => severity !== "normal") ? (
                <div className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800">
                  <strong>
                    {isArabic
                      ? "تنبيه العلامات الحيوية: "
                      : "Vital-sign alert: "}
                  </strong>
                  {isArabic
                    ? "توجد قيمة خارج النطاق الطبيعي — يرجى المراجعة السريرية."
                    : "One or more vital signs are outside the normal range — please review clinically."}
                </div>
              ) : null}

              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <Field label={t("temperature")}>
                  <Input
                    className={vitalClass(
                      vitalSeverity(
                        "temp",
                        s(vitals, "temperature"),
                      ),
                    )}
                    type="number"
                    dir="ltr"
                    step="0.1"
                    inputMode="decimal"
                    placeholder="36.8"
                    value={s(
                      vitals,
                      "temperature",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        temperature:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("pulse")}>
                  <Input
                    className={vitalClass(
                      vitalSeverity(
                        "pulse",
                        s(vitals, "pulse"),
                      ),
                    )}
                    type="number"
                    dir="ltr"
                    inputMode="numeric"
                    placeholder="80"
                    value={s(vitals, "pulse")}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        pulse: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("blood_pressure")}>
                  <Input
                    className={vitalClass(
                      vitalSeverity("sbp", currentSbp),
                    )}
                    dir="ltr"
                    inputMode="numeric"
                    placeholder="120/80"
                    value={
                      s(
                        vitals,
                        "blood_pressure",
                      ) ||
                      (s(
                        vitals,
                        "systolic_bp",
                      ) ||
                        s(
                          vitals,
                          "bp_systolic",
                        ) ||
                        s(
                          vitals,
                          "diastolic_bp",
                        ) ||
                        s(
                          vitals,
                          "bp_diastolic",
                        )
                        ? `${s(
                            vitals,
                            "systolic_bp",
                          ) || s(
                            vitals,
                            "bp_systolic",
                          )}/${s(
                            vitals,
                            "diastolic_bp",
                          ) || s(
                            vitals,
                            "bp_diastolic",
                          )}`
                        : "")
                    }
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        blood_pressure:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("spo2")}>
                  <Input
                    className={vitalClass(
                      vitalSeverity(
                        "spo2",
                        s(vitals, "spo2"),
                      ),
                    )}
                    type="number"
                    dir="ltr"
                    inputMode="numeric"
                    placeholder="98"
                    value={s(vitals, "spo2")}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        spo2: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("weight")}>
                  <Input
                    type="number"
                    dir="ltr"
                    step="0.1"
                    inputMode="decimal"
                    placeholder="70"
                    value={s(
                      vitals,
                      "weight",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        weight: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("height")}>
                  <Input
                    type="number"
                    dir="ltr"
                    step="0.1"
                    inputMode="decimal"
                    placeholder="170"
                    value={s(
                      vitals,
                      "height",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        height: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("bmi")}>
                  <Input
                    readOnly
                    dir="ltr"
                    value={bmi ?? ""}
                  />
                </Field>

                <Field
                  label={t(
                    "respiratory_rate",
                  )}
                >
                  <Input
                    className={vitalClass(
                      vitalSeverity(
                        "rr",
                        s(vitals, "respiratory_rate"),
                      ),
                    )}
                    type="number"
                    dir="ltr"
                    inputMode="numeric"
                    placeholder="16"
                    value={s(
                      vitals,
                      "respiratory_rate",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        respiratory_rate:
                          e.target.value,
                      })
                    }
                  />
                </Field>
              </div>

              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() =>
                  setShowMoreVitals(
                    (value) => !value,
                  )
                }
              >
                {showMoreVitals ? (
                  <>
                    <X className="size-4" />
                    {isArabic
                      ? "إخفاء الحقول الإضافية"
                      : "Hide additional fields"}
                  </>
                ) : (
                  <>
                    <ChevronDown className="size-4" />
                    {isArabic
                      ? "حقول إضافية"
                      : "Additional fields"}
                  </>
                )}
              </Button>

              {showMoreVitals ? (
                <div className="grid gap-4 border-t pt-4 sm:grid-cols-2">
                  <Field
                    label={
                      isArabic
                        ? "سكر الدم"
                        : "Blood sugar"
                    }
                  >
                    <Input
                      type="number"
                      dir="ltr"
                      inputMode="decimal"
                      value={s(
                        vitals,
                        "blood_sugar",
                      )}
                      onChange={(e) =>
                        setVitals({
                          ...vitals,
                          blood_sugar:
                            e.target.value,
                        })
                      }
                    />
                  </Field>

                  <Field label={t("notes")}>
                    <Textarea
                      rows={2}
                      value={s(
                        vitals,
                        "notes",
                      )}
                      onChange={(e) =>
                        setVitals({
                          ...vitals,
                          notes:
                            e.target.value,
                        })
                      }
                    />
                  </Field>
                </div>
              ) : null}

              {can("vitals.create") ? (
                <div className="flex justify-end">
                  <Button
                    size="lg"
                    disabled={
                      saveVitals.isPending
                    }
                    onClick={() =>
                      saveVitals.mutate(
                        undefined as never,
                      )
                    }
                  >
                    <Check className="size-4" />
                    {saveVitals.isPending
                      ? t("saving")
                      : t("save")}
                  </Button>
                </div>
              ) : null}
            </CardContent>
          </Card>
        </TabsContent>

        {/* ====================================================
            LABORATORY
        ===================================================== */}

        <TabsContent value="labs">
          <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
            <Card>
              <CardContent className="space-y-4 p-4">
                <div className="flex items-center justify-between gap-2">
                  <SectionTitle>
                    {t("order_tests")}
                  </SectionTitle>

                  {labSel.length > 0 ? (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        setLabSel([])
                      }
                    >
                      <X className="size-4" />
                      {isArabic
                        ? "مسح"
                        : "Clear"}
                    </Button>
                  ) : null}
                </div>

                <div className="relative">
                  <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />

                  <Input
                    className="pl-9"
                    placeholder={
                      isArabic
                        ? "ابحث عن الفحص..."
                        : "Search laboratory test..."
                    }
                    value={labSearch}
                    onChange={(e) =>
                      setLabSearch(
                        e.target.value,
                      )
                    }
                  />
                </div>

                <div className="flex flex-wrap gap-2">
                  <Button
                    type="button"
                    size="sm"
                    variant={
                      labCategory === "all"
                        ? "default"
                        : "outline"
                    }
                    onClick={() =>
                      setLabCategory("all")
                    }
                  >
                    {isArabic
                      ? "الكل"
                      : "All"}
                  </Button>

                  {labCategories.map(
                    (category) => (
                      <Button
                        key={category}
                        type="button"
                        size="sm"
                        variant={
                          labCategory ===
                          category
                            ? "default"
                            : "outline"
                        }
                        onClick={() =>
                          setLabCategory(
                            category,
                          )
                        }
                      >
                        {category}
                      </Button>
                    ),
                  )}
                </div>

                {labSel.length > 0 ? (
                  <div className="rounded-md bg-primary/5 p-3 text-sm">
                    <strong>
                      {labSel.length}
                    </strong>{" "}
                    {isArabic
                      ? "فحص محدد"
                      : "test(s) selected"}
                  </div>
                ) : null}

                <div className="max-h-[430px] space-y-1 overflow-y-auto rounded-md border p-2">
                  {filteredTests.map(
                    (test) => {
                      const id = s(test, "id");
                      const selected =
                        labSel.includes(id);

                      const name =
                        isArabic
                          ? s(
                              test,
                              "name_ar",
                            ) ||
                            s(
                              test,
                              "name",
                            )
                          : s(
                              test,
                              "name",
                            );

                      /*
                       * IMPORTANT:
                       * Checkbox is no longer nested inside
                       * an interactive button.
                       */
                      return (
                        <div
                          key={id}
                          className={`flex w-full items-center gap-3 rounded-md p-3 transition ${
                            selected
                              ? "bg-primary/10"
                              : "hover:bg-muted"
                          }`}
                        >
                          <Checkbox
                            checked={selected}
                            onCheckedChange={() =>
                              toggleLab(id)
                            }
                          />

                          <button
                            type="button"
                            className="flex flex-1 items-center gap-3 text-left"
                            onClick={() =>
                              toggleLab(id)
                            }
                          >
                            <span className="flex-1 text-sm">
                              {name}
                            </span>

                            {n(
                              test,
                              "price",
                            ) > 0 ? (
                              <span className="text-xs text-muted-foreground">
                                {n(
                                  test,
                                  "price",
                                )}
                              </span>
                            ) : null}
                          </button>
                        </div>
                      );
                    },
                  )}

                  {filteredTests.length ===
                  0 ? (
                    <Empty
                      label={
                        isArabic
                          ? "لا توجد نتائج"
                          : "No tests found"
                      }
                    />
                  ) : null}
                </div>

                {can("lab.create") ? (
                  <div className="flex justify-end">
                    <Button
                      size="lg"
                      disabled={
                        labSel.length === 0 ||
                        orderLabs.isPending
                      }
                      onClick={() =>
                        orderLabs.mutate(
                          undefined as never,
                        )
                      }
                    >
                      <Plus className="size-4" />
                      {orderLabs.isPending
                        ? t("saving")
                        : `${t(
                            "order_tests",
                          )} ${
                            labSel.length
                              ? `(${labSel.length})`
                              : ""
                          }`}
                    </Button>
                  </div>
                ) : null}
              </CardContent>
            </Card>

            <Card className="h-fit">
              <CardContent className="p-4">
                <SectionTitle>
                  {t("laboratory")}
                </SectionTitle>

                {(
                  (ordersQ.data ?? []) as Row[]
                ).length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="space-y-2">
                    {(
                      (ordersQ.data ??
                        []) as Row[]
                    ).map((order) => (
                      <li
                        key={s(
                          order,
                          "id",
                        )}
                        className="rounded-md border p-3"
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-sm font-medium">
                            {(
                              (order[
                                "lab_order_items"
                              ] as Row[]) ??
                              []
                            )
                              .map(
                                (item) => {
                                  const test =
                                    rel(
                                      item,
                                      "lab_tests",
                                    );

                                  return isArabic
                                    ? s(
                                        test,
                                        "name_ar",
                                      ) ||
                                        s(
                                          test,
                                          "name",
                                        )
                                    : s(
                                        test,
                                        "name",
                                      );
                                },
                              )
                              .join(", ")}
                          </span>

                          <StatusBadge
                            status={s(
                              order,
                              "status",
                            )}
                          />
                        </div>

                        <Button
                          asChild
                          variant="ghost"
                          size="sm"
                          className="mt-2"
                        >
                          <Link
                            to="/lab/$orderId"
                            params={{
                              orderId:
                                s(
                                  order,
                                  "id",
                                ),
                            }}
                          >
                            {t("open")}
                          </Link>
                        </Button>
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ====================================================
            PRESCRIPTION
        ===================================================== */}

        <TabsContent value="rx">
          <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
            <Card>
              <CardContent className="space-y-4 p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <SectionTitle>
                    {t("prescription")}
                  </SectionTitle>

                  <Button
                    type="button"
                    onClick={
                      addPrescription
                    }
                  >
                    <Plus className="size-4" />
                    {isArabic
                      ? "دواء"
                      : "Medicine"}
                  </Button>
                </div>

                {rx.length === 0 ? (
                  <div className="rounded-lg border border-dashed p-8 text-center">
                    <div className="mb-3 text-sm text-muted-foreground">
                      {isArabic
                        ? "أضف دواء إلى الوصفة"
                        : "Add a medicine to start the prescription."}
                    </div>

                    <Button
                      type="button"
                      variant="outline"
                      onClick={
                        addPrescription
                      }
                    >
                      <Plus className="size-4" />
                      {isArabic
                        ? "إضافة دواء"
                        : "Add medicine"}
                    </Button>
                  </div>
                ) : null}

                <div className="space-y-3">
                  {rx.map(
                    (
                      item,
                      index,
                    ) => {
                      const currentSearch =
                        medicineSearch[
                          index
                        ] ?? "";

                      const filteredMedicines =
                        allMedicines.filter(
                          (medicine) => {
                            const query =
                              currentSearch
                                .trim()
                                .toLowerCase();

                            if (!query) {
                              return true;
                            }

                            return [
                              s(
                                medicine,
                                "name",
                              ),
                              s(
                                medicine,
                                "generic_name",
                              ),
                              s(
                                medicine,
                                "brand_name",
                              ),
                              s(
                                medicine,
                                "strength",
                              ),
                              s(
                                medicine,
                                "dosage_form",
                              ),
                            ]
                              .join(" ")
                              .toLowerCase()
                              .includes(
                                query,
                              );
                          },
                        );

                      const selectedMedicine =
                        allMedicines.find(
                          (medicine) =>
                            s(
                              medicine,
                              "id",
                            ) ===
                            item.medicine_id,
                        );

                      return (
                        <Card
                          key={`${index}-${item.medicine_id}`}
                          className="border"
                        >
                          <CardContent className="space-y-3 p-3">
                            <div className="flex items-center justify-between">
                              <span className="text-sm font-medium">
                                {isArabic
                                  ? `دواء ${
                                      index +
                                      1
                                    }`
                                  : `Medicine ${
                                      index +
                                      1
                                    }`}
                              </span>

                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                onClick={() =>
                                  removeRx(
                                    index,
                                  )
                                }
                              >
                                <Trash2 className="size-4" />
                              </Button>
                            </div>

                            <div className="relative">
                              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />

                              <Input
                                className="pl-9"
                                placeholder={
                                  isArabic
                                    ? "ابحث عن الدواء..."
                                    : "Search medicine..."
                                }
                                value={
                                  selectedMedicine
                                    ? s(
                                        selectedMedicine,
                                        "name",
                                      )
                                    : currentSearch
                                }
                                onChange={(
                                  e,
                                ) => {
                                  const value =
                                    e.target
                                      .value;

                                  setMedicineSearch(
                                    (
                                      current,
                                    ) => ({
                                      ...current,
                                      [index]:
                                        value,
                                    }),
                                  );

                                  if (
                                    item.medicine_id
                                  ) {
                                    updateRx(
                                      index,
                                      {
                                        medicine_id:
                                          "",
                                      },
                                    );
                                  }
                                }}
                              />

                              {!selectedMedicine ||
                              currentSearch ? (
                                <div className="mt-1 max-h-56 overflow-y-auto rounded-md border bg-background shadow">
                                  {filteredMedicines
                                    .slice(
                                      0,
                                      40,
                                    )
                                    .map(
                                      (
                                        medicine,
                                      ) => (
                                        <button
                                          type="button"
                                          key={s(
                                            medicine,
                                            "id",
                                          )}
                                          className="flex w-full flex-col px-3 py-2 text-left hover:bg-muted"
                                          onClick={() => {
                                            updateRx(
                                              index,
                                              {
                                                medicine_id:
                                                  s(
                                                    medicine,
                                                    "id",
                                                  ),
                                              },
                                            );

                                            setMedicineSearch(
                                              (
                                                current,
                                              ) => ({
                                                ...current,
                                                [index]:
                                                  "",
                                              }),
                                            );
                                          }}
                                        >
                                          <span className="text-sm font-medium">
                                            {s(
                                              medicine,
                                              "name",
                                            )}
                                          </span>

                                          <span className="text-xs text-muted-foreground">
                                            {[
                                              s(
                                                medicine,
                                                "generic_name",
                                              ),
                                              s(
                                                medicine,
                                                "strength",
                                              ),
                                              s(
                                                medicine,
                                                "dosage_form",
                                              ),
                                            ]
                                              .filter(
                                                Boolean,
                                              )
                                              .join(
                                                " · ",
                                              )}
                                          </span>
                                        </button>
                                      ),
                                    )}

                                  {filteredMedicines.length ===
                                  0 ? (
                                    <div className="p-3 text-center text-xs text-muted-foreground">
                                      {isArabic
                                        ? "لا توجد أدوية مطابقة"
                                        : "No matching medicines"}
                                    </div>
                                  ) : null}
                                </div>
                              ) : null}
                            </div>

                            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
                              <Select
                                value={
                                  item.dosage
                                }
                                onValueChange={(
                                  value,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      dosage:
                                        value,
                                    },
                                  )
                                }
                              >
                                <SelectTrigger>
                                  <SelectValue
                                    placeholder={
                                      isArabic
                                        ? "الجرعة"
                                        : "Dose"
                                    }
                                  />
                                </SelectTrigger>

                                <SelectContent>
                                  {DOSES.map(
                                    (dose) => (
                                      <SelectItem
                                        key={
                                          dose
                                        }
                                        value={
                                          dose
                                        }
                                      >
                                        {
                                          dose
                                        }
                                      </SelectItem>
                                    ),
                                  )}
                                </SelectContent>
                              </Select>

                              <Select
                                value={
                                  item.dosage_form
                                }
                                onValueChange={(
                                  value,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      dosage_form:
                                        value,
                                      route:
                                        item.route ||
                                        FORM_DEFAULT_ROUTE[
                                          value
                                        ] ||
                                        "",
                                    },
                                  )
                                }
                              >
                                <SelectTrigger>
                                  <SelectValue
                                    placeholder={
                                      isArabic
                                        ? "الشكل الدوائي"
                                        : "Dosage form"
                                    }
                                  />
                                </SelectTrigger>

                                <SelectContent>
                                  {DOSAGE_FORMS.map(
                                    (form) => (
                                      <SelectItem
                                        key={
                                          form.en
                                        }
                                        value={
                                          form.en
                                        }
                                      >
                                        {isArabic
                                          ? form.ar
                                          : form.en}
                                      </SelectItem>
                                    ),
                                  )}
                                </SelectContent>
                              </Select>

                              <Select
                                value={
                                  item.route
                                }
                                onValueChange={(
                                  value,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      route:
                                        value,
                                    },
                                  )
                                }
                              >
                                <SelectTrigger>
                                  <SelectValue
                                    placeholder={
                                      isArabic
                                        ? "طريقة الإعطاء"
                                        : "Route"
                                    }
                                  />
                                </SelectTrigger>

                                <SelectContent>
                                  {ROUTES.map(
                                    (route) => (
                                      <SelectItem
                                        key={
                                          route.en
                                        }
                                        value={
                                          route.en
                                        }
                                      >
                                        {isArabic
                                          ? route.ar
                                          : route.en}
                                      </SelectItem>
                                    ),
                                  )}
                                </SelectContent>
                              </Select>

                              <Select
                                value={
                                  item.frequency
                                }
                                onValueChange={(
                                  value,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      frequency:
                                        value,
                                    },
                                  )
                                }
                              >
                                <SelectTrigger>
                                  <SelectValue
                                    placeholder={
                                      isArabic
                                        ? "التكرار"
                                        : "Frequency"
                                    }
                                  />
                                </SelectTrigger>

                                <SelectContent>
                                  {FREQUENCIES.map(
                                    (
                                      frequency,
                                    ) => (
                                      <SelectItem
                                        key={
                                          frequency
                                        }
                                        value={
                                          frequency
                                        }
                                      >
                                        {
                                          frequency
                                        }
                                      </SelectItem>
                                    ),
                                  )}
                                </SelectContent>
                              </Select>

                              <Select
                                value={
                                  item.duration
                                }
                                onValueChange={(
                                  value,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      duration:
                                        value,
                                    },
                                  )
                                }
                              >
                                <SelectTrigger>
                                  <SelectValue
                                    placeholder={
                                      isArabic
                                        ? "المدة"
                                        : "Duration"
                                    }
                                  />
                                </SelectTrigger>

                                <SelectContent>
                                  {DURATIONS.map(
                                    (
                                      duration,
                                    ) => (
                                      <SelectItem
                                        key={
                                          duration
                                        }
                                        value={
                                          duration
                                        }
                                      >
                                        {
                                          duration
                                        }
                                      </SelectItem>
                                    ),
                                  )}
                                </SelectContent>
                              </Select>
                            </div>

                            <div className="flex items-center gap-2">
                              <span className="text-sm text-muted-foreground">
                                {isArabic
                                  ? "الكمية"
                                  : "Quantity"}
                              </span>

                              <Input
                                className="w-24"
                                type="number"
                                min={1}
                                dir="ltr"
                                value={
                                  item.quantity
                                }
                                onChange={(
                                  e,
                                ) =>
                                  updateRx(
                                    index,
                                    {
                                      quantity:
                                        e
                                          .target
                                          .value,
                                    },
                                  )
                                }
                              />
                            </div>

                            <Input
                              value={
                                item.instructions
                              }
                              placeholder={
                                isArabic
                                  ? "تعليمات إضافية (مثال: بعد الأكل)"
                                  : "Additional instructions (e.g. after food)"
                              }
                              onChange={(e) =>
                                updateRx(index, {
                                  instructions:
                                    e.target
                                      .value,
                                })
                              }
                            />
                          </CardContent>
                        </Card>
                      );
                    },
                  )}
                </div>

                {rx.length > 0 ? (
                  <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-4">
                    <label className="flex items-center gap-2 text-sm">
                      <Checkbox
                        checked={
                          rxExternal
                        }
                        onCheckedChange={(
                          value,
                        ) =>
                          setRxExternal(
                            Boolean(
                              value,
                            ),
                          )
                        }
                      />

                      {t(
                        "external_prescription",
                      )}
                    </label>

                    {can(
                      "prescriptions.create",
                    ) ? (
                      <Button
                        size="lg"
                        disabled={
                          rx.every(
                            (item) =>
                              !item.medicine_id,
                          ) ||
                          saveRx.isPending
                        }
                        onClick={() =>
                          saveRx.mutate(
                            undefined as never,
                          )
                        }
                      >
                        <Check className="size-4" />

                        {saveRx.isPending
                          ? t(
                              "saving",
                            )
                          : t("save")}
                      </Button>
                    ) : null}
                  </div>
                ) : null}
              </CardContent>
            </Card>

            <Card className="h-fit">
              <CardContent className="p-4">
                <SectionTitle>
                  {t("history")}
                </SectionTitle>

                {(
                  (rxQ.data ?? []) as Row[]
                ).length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="space-y-2">
                    {(
                      (rxQ.data ??
                        []) as Row[]
                    ).map(
                      (
                        prescription,
                      ) => (
                        <li
                          key={s(
                            prescription,
                            "id",
                          )}
                          className="rounded-md border p-3"
                        >
                          <div className="flex items-center justify-between gap-2">
                            <span className="text-xs text-muted-foreground">
                              {formatDateTime(
                                s(
                                  prescription,
                                  "created_at",
                                ),
                              )}
                            </span>

                            <StatusBadge
                              status={s(
                                prescription,
                                "status",
                              )}
                            />
                          </div>

                          <div className="mt-2 text-sm">
                            {(
                              (prescription[
                                "prescription_items"
                              ] as Row[]) ??
                              []
                            )
                              .map(
                                (
                                  item,
                                ) => {
                                  const medicine =
                                    rel(
                                      item,
                                      "medicines",
                                    );

                                  return [
                                    s(
                                      medicine,
                                      "name",
                                    ),
                                    s(
                                      item,
                                      "dosage",
                                    ) ||
                                      s(
                                        item,
                                        "dose",
                                      ),
                                    s(
                                      item,
                                      "frequency",
                                    ),
                                    s(
                                      item,
                                      "duration",
                                    ),
                                  ]
                                    .filter(
                                      Boolean,
                                    )
                                    .join(
                                      " · ",
                                    );
                                },
                              )
                              .join(
                                " / ",
                              )}
                          </div>
                        </li>
                      ),
                    )}
                  </ul>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ====================================================
            HISTORY
        ===========