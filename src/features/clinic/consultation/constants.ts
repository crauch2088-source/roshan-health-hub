/**
 * Static clinical option lists for the consultation workspace.
 *
 * These are UI catalogues / pick-lists only. They are NOT protocols,
 * recommendations or default patient data — nothing here is written to the
 * database unless the doctor actively selects it.
 */
import type { QuickOption } from "./types";

export const QUICK_COMPLAINTS: QuickOption[] = [
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

export const QUICK_HPI: QuickOption[] = [
  { en: "No significant past history.", ar: "لا يوجد تاريخ مرضي مهم." },
  { en: "Symptoms started recently.", ar: "بدأت الأعراض حديثًا." },
  { en: "No known drug allergies.", ar: "لا توجد حساسية دوائية معروفة." },
  { en: "No history of similar attacks.", ar: "لا يوجد تاريخ لنوبات مشابهة." },
  { en: "Symptoms are worsening.", ar: "الأعراض في تزايد." },
  { en: "Symptoms are improving.", ar: "الأعراض في تحسن." },
  {
    en: "No associated red-flag symptoms reported.",
    ar: "لا توجد أعراض إنذارية مصاحبة حسب الإفادة.",
  },
];

export const QUICK_EXAM: QuickOption[] = [
  { en: "General condition: stable.", ar: "الحالة العامة: مستقرة." },
  { en: "Patient is conscious and oriented.", ar: "المريض واعٍ ومدرك." },
  { en: "No respiratory distress.", ar: "لا توجد علامات ضيق تنفسي." },
  { en: "Chest: clear bilaterally.", ar: "الصدر: أصوات تنفسية طبيعية ثنائيًا." },
  { en: "Heart: normal S1/S2.", ar: "القلب: S1/S2 طبيعيان." },
  { en: "Abdomen: soft and non-tender.", ar: "البطن: لين وغير مؤلم." },
  { en: "No focal neurological deficit.", ar: "لا يوجد عجز عصبي بؤري." },
  { en: "No peripheral edema.", ar: "لا توجد وذمة طرفية." },
];

export const QUICK_ASSESSMENT: QuickOption[] = [
  { en: "Acute viral infection", ar: "عدوى فيروسية حادة" },
  { en: "URTI", ar: "عدوى الجهاز التنفسي العلوي" },
  { en: "Acute gastroenteritis", ar: "التهاب معدة وأمعاء حاد" },
  { en: "Acute bronchitis", ar: "التهاب شعب هوائية حاد" },
  { en: "Tension headache", ar: "صداع توتري" },
  { en: "Dyspepsia", ar: "عسر هضم" },
  { en: "UTI", ar: "التهاب المسالك البولية" },
  { en: "Low back pain", ar: "ألم أسفل الظهر" },
];

export const QUICK_PLAN: QuickOption[] = [
  {
    en: "Supportive treatment and symptomatic management.",
    ar: "علاج داعم وعلاج للأعراض.",
  },
  { en: "Hydration and adequate oral fluids.", ar: "الإكثار من السوائل والترطيب." },
  {
    en: "Rest and follow-up if symptoms worsen.",
    ar: "الراحة والمتابعة إذا ساءت الأعراض.",
  },
  {
    en: "Return immediately if red-flag symptoms develop.",
    ar: "العودة فورًا عند ظهور أي أعراض إنذارية.",
  },
  { en: "Follow up as needed.", ar: "المراجعة عند الحاجة." },
];

/* ------------------------------------------------------------------ */
/* Chronic conditions                                                  */
/* ------------------------------------------------------------------ */

/** `en` is the canonical stored token — do not rename existing entries. */
export const CHRONIC_CONDITIONS: QuickOption[] = [
  { en: "Hypertension", ar: "ارتفاع ضغط الدم" },
  { en: "Diabetes mellitus", ar: "داء السكري" },
  { en: "Bronchial asthma", ar: "الربو الشعبي" },
  { en: "COPD", ar: "مرض الانسداد الرئوي المزمن" },
  { en: "Ischemic heart disease", ar: "مرض القلب الإقفاري" },
  { en: "Heart failure", ar: "قصور القلب" },
  { en: "Chronic kidney disease", ar: "مرض الكلى المزمن" },
  { en: "Epilepsy", ar: "الصرع" },
  { en: "Thyroid disease", ar: "أمراض الغدة الدرقية" },
  { en: "Dyslipidemia", ar: "اضطراب الدهون" },
  { en: "Chronic liver disease", ar: "مرض الكبد المزمن" },
  { en: "Sickle cell disease", ar: "فقر الدم المنجلي" },
];

export const OTHER_PREFIX = "Other:";

/** Parses a stored free-text/legacy value into selected codes + free text. */
export function parseChronic(value: string): { selected: string[]; other: string } {
  const parts = value
    .split(/[,،;/\n]+/)
    .map((part) => part.trim())
    .filter(Boolean);

  const selected: string[] = [];
  const rest: string[] = [];

  for (const part of parts) {
    if (part.toLowerCase().startsWith(OTHER_PREFIX.toLowerCase())) {
      rest.push(part.slice(OTHER_PREFIX.length).trim());
      continue;
    }

    const match = CHRONIC_CONDITIONS.find(
      (condition) =>
        condition.en.toLowerCase() === part.toLowerCase() || condition.ar === part,
    );

    if (match) {
      if (!selected.includes(match.en)) selected.push(match.en);
    } else {
      rest.push(part);
    }
  }

  return { selected, other: rest.filter(Boolean).join(", ") };
}

/** Serialises the selector back into a readable, legacy-safe text value. */
export function serializeChronic(selected: string[], other: string): string {
  const parts = [...selected];
  const trimmed = other.trim();
  if (trimmed) parts.push(`${OTHER_PREFIX} ${trimmed}`);
  return parts.join(", ");
}

/* ------------------------------------------------------------------ */
/* Prescription pick-lists                                             */
/* ------------------------------------------------------------------ */

export const CUSTOM_VALUE = "__custom__";

export const DOSES = [
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

export const FREQUENCIES: QuickOption[] = [
  { en: "Once daily", ar: "مرة يوميًا" },
  { en: "Twice daily", ar: "مرتين يوميًا" },
  { en: "Three times daily", ar: "ثلاث مرات يوميًا" },
  { en: "Four times daily", ar: "أربع مرات يوميًا" },
  { en: "Every 4 hours", ar: "كل 4 ساعات" },
  { en: "Every 6 hours", ar: "كل 6 ساعات" },
  { en: "Every 8 hours", ar: "كل 8 ساعات" },
  { en: "Every 12 hours", ar: "كل 12 ساعة" },
  { en: "At night", ar: "ليلًا" },
  { en: "As needed", ar: "عند الحاجة" },
];

export const DURATIONS: QuickOption[] = [
  { en: "1 day", ar: "يوم" },
  { en: "2 days", ar: "يومان" },
  { en: "3 days", ar: "3 أيام" },
  { en: "5 days", ar: "5 أيام" },
  { en: "7 days", ar: "7 أيام" },
  { en: "10 days", ar: "10 أيام" },
  { en: "14 days", ar: "14 يومًا" },
  { en: "Until improved", ar: "حتى التحسن" },
  { en: "As needed", ar: "عند الحاجة" },
];

export const DOSAGE_FORMS: QuickOption[] = [
  { en: "Tablet", ar: "قرص" },
  { en: "Capsule", ar: "كبسولة" },
  { en: "Syrup", ar: "شراب" },
  { en: "Suspension", ar: "معلق" },
  { en: "Solution", ar: "محلول" },
  { en: "Drops", ar: "قطرات" },
  { en: "Cream", ar: "كريم" },
  { en: "Ointment", ar: "مرهم" },
  { en: "Gel", ar: "جل" },
  { en: "Lotion", ar: "لوشن" },
  { en: "Suppository", ar: "تحميلة" },
  { en: "Injection", ar: "حقن" },
  { en: "Inhaler", ar: "بخاخ" },
  { en: "Nebules", ar: "جلسات استنشاق" },
];

export const ROUTES: QuickOption[] = [
  { en: "Oral", ar: "فموي" },
  { en: "IV", ar: "وريدي" },
  { en: "IM", ar: "عضلي" },
  { en: "SC", ar: "تحت الجلد" },
  { en: "SL", ar: "تحت اللسان" },
  { en: "Topical", ar: "موضعي" },
  { en: "Inhaled", ar: "استنشاق" },
  { en: "Nasal", ar: "أنفي" },
  { en: "Ophthalmic", ar: "عيني" },
  { en: "Otic", ar: "أذني" },
  { en: "Rectal", ar: "شرجي" },
  { en: "Vaginal", ar: "مهبلي" },
];

/** Suggested (not enforced) route for a dosage form. */
export const FORM_DEFAULT_ROUTE: Record<string, string> = {
  Tablet: "Oral",
  Capsule: "Oral",
  Syrup: "Oral",
  Suspension: "Oral",
  Solution: "Oral",
  Drops: "Ophthalmic",
  Cream: "Topical",
  Ointment: "Topical",
  Gel: "Topical",
  Lotion: "Topical",
  Suppository: "Rectal",
  Injection: "IM",
  Inhaler: "Inhaled",
  Nebules: "Inhaled",
};

/** Normalises a `medicines.dosage_form` / `unit` value onto our list. */
export function matchDosageForm(value: string): string {
  const query = value.trim().toLowerCase();
  if (!query) return "";
  const hit = DOSAGE_FORMS.find(
    (form) => form.en.toLowerCase() === query || form.ar === value.trim(),
  );
  if (hit) return hit.en;
  const partial = DOSAGE_FORMS.find((form) => query.includes(form.en.toLowerCase()));
  return partial?.en ?? "";
}

/* ------------------------------------------------------------------ */
/* Laboratory: routine panel matching                                  */
/* ------------------------------------------------------------------ */

/**
 * Codes / names treated as the Sudanese outpatient "Routine" panel.
 * Matching is done on `lab_tests.code` OR `lab_tests.name`, so the existing
 * catalogue categories are never rewritten.
 */
export const ROUTINE_LAB_MATCHERS = [
  "cbc",
  "complete blood count",
  "twbc",
  "wbc",
  "hb",
  "haemoglobin",
  "hemoglobin",
  "plt",
  "platelets",
  "mp",
  "malaria parasite",
  "mrdt",
  "malaria rdt",
  "ua",
  "urine",
  "urinalysis",
  "gue",
  "upt",
  "pt",
  "pregnancy test",
  "rbs",
  "glu",
  "blood glucose",
  "fbs",
  "creat",
  "creatinine",
  "urea",
  "alt",
  "ast",
];

export function isRoutineTest(code: string, name: string): boolean {
  const c = code.trim().toLowerCase();
  const n = name.trim().toLowerCase();
  return ROUTINE_LAB_MATCHERS.some((matcher) => c === matcher || n === matcher);
}