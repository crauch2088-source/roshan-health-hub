/** * Roshan clinic consultation quick options. * * Keep this file dependency-free: it is imported by the client bundle and * should contain only valid TypeScript data. Do not import types from another * module here; that previously caused the production build to fail in Vite. */
export type QuickOption = {
  value: string;
  label: string;
  labelAr?: string;
};

export const QUICK_COMPLAINTS: QuickOption[] = [
  { value: "fever", label: "Fever", labelAr: "حمى" },
  { value: "cough", label: "Cough", labelAr: "سعال" },
  { value: "headache", label: "Headache", labelAr: "صداع" },
  { value: "abdominal_pain", label: "Abdominal pain", labelAr: "ألم البطن" },
  { value: "chest_pain", label: "Chest pain", labelAr: "ألم الصدر" },
  { value: "back_pain", label: "Back pain", labelAr: "ألم الظهر" },
  { value: "vomiting", label: "Vomiting", labelAr: "قيء" },
  { value: "diarrhea", label: "Diarrhea", labelAr: "إسهال" },
  { value: "sore_throat", label: "Sore throat", labelAr: "التهاب/ألم الحلق" },
  { value: "shortness_of_breath", label: "Shortness of breath", labelAr: "ضيق التنفس" },
  { value: "dizziness", label: "Dizziness", labelAr: "دوخة" },
  { value: "fatigue", label: "Fatigue", labelAr: "إرهاق" },
  { value: "urinary_symptoms", label: "Urinary symptoms", labelAr: "أعراض بولية" },
  { value: "skin_rash", label: "Skin rash", labelAr: "طفح جلدي" },
  { value: "pregnancy_followup", label: "Pregnancy follow-up", labelAr: "متابعة الحمل" },
  { value: "routine_followup", label: "Routine follow-up", labelAr: "متابعة روتينية" },
];

export const QUICK_EXAMINATIONS: QuickOption[] = [
  { value: "general", label: "General examination", labelAr: "فحص عام" },
  { value: "respiratory", label: "Respiratory examination", labelAr: "فحص الجهاز التنفسي" },
  { value: "cardiovascular", label: "Cardiovascular examination", labelAr: "فحص القلب والدورة الدموية" },
  { value: "abdominal", label: "Abdominal examination", labelAr: "فحص البطن" },
  { value: "neurological", label: "Neurological examination", labelAr: "فحص عصبي" },
  { value: "ent", label: "ENT examination", labelAr: "فحص الأنف والأذن والحنجرة" },
  { value: "skin", label: "Skin examination", labelAr: "فحص الجلد" },
];

export const QUICK_FOLLOWUPS: QuickOption[] = [
  { value: "3_days", label: "Review in 3 days", labelAr: "مراجعة بعد 3 أيام" },
  { value: "1_week", label: "Review in 1 week", labelAr: "مراجعة بعد أسبوع" },
  { value: "2_weeks", label: "Review in 2 weeks", labelAr: "مراجعة بعد أسبوعين" },
  { value: "1_month", label: "Review in 1 month", labelAr: "مراجعة بعد شهر" },
  { value: "prn", label: "Review as needed", labelAr: "المراجعة عند الحاجة" },
];

export const COMMON_DIAGNOSES: QuickOption[] = [
  { value: "viral_uri", label: "Viral upper respiratory infection", labelAr: "عدوى فيروسية بالجهاز التنفسي العلوي" },
  { value: "acute_gastroenteritis", label: "Acute gastroenteritis", labelAr: "التهاب معدة وأمعاء حاد" },
  { value: "essential_hypertension", label: "Essential hypertension", labelAr: "ارتفاع ضغط الدم الأساسي" },
  { value: "type2_diabetes", label: "Type 2 diabetes mellitus", labelAr: "داء السكري النوع الثاني" },
  { value: "iron_deficiency_anemia", label: "Iron deficiency anemia", labelAr: "فقر الدم بعوز الحديد" },
  { value: "acute_bronchitis", label: "Acute bronchitis", labelAr: "التهاب الشعب الهوائية الحاد" },
  { value: "uti", label: "Urinary tract infection", labelAr: "التهاب المسالك البولية" },
  { value: "low_back_pain", label: "Low back pain", labelAr: "ألم أسفل الظهر" },
];

export const QUICK_DIAGNOSES = COMMON_DIAGNOSES;