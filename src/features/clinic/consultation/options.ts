export interface QuickOption {
  id: string;
  label: string;
  category?: string;
}

/** * Quick-pick clinical complaints used by the consultation screen. * Keep this file as the stable import target for ConsultationPage and * related components; it intentionally has no runtime dependencies. */
export const QUICK_COMPLAINTS: QuickOption[] = [
  { id: "headache", label: "صداع" },
  { id: "fever", label: "حمى / ارتفاع الحرارة" },
  { id: "cough", label: "سعال" },
  { id: "sore-throat", label: "التهاب الحلق" },
  { id: "dyspnea", label: "ضيق التنفس" },
  { id: "chest-pain", label: "ألم الصدر" },
  { id: "abdominal-pain", label: "ألم البطن" },
  { id: "vomiting", label: "قيء" },
  { id: "diarrhea", label: "إسهال" },
  { id: "dysuria", label: "عسر التبول" },
  { id: "back-pain", label: "ألم الظهر" },
  { id: "joint-pain", label: "ألم المفاصل" },
  { id: "dizziness", label: "دوخة / دوار" },
  { id: "fatigue", label: "إرهاق" },
  { id: "rash", label: "طفح جلدي" },
];

export const DOSES = [
  "نصف قرص",
  "قرص واحد",
  "قرصان",
  "5 مل",
  "10 مل",
  "15 مل",
  "20 مل",
];

export const FREQUENCIES = [
  "مرة يومياً",
  "مرتان يومياً",
  "3 مرات يومياً",
  "4 مرات يومياً",
  "كل 8 ساعات",
  "كل 12 ساعة",
  "عند اللزوم",
];

export const DURATIONS = [
  "يوم واحد",
  "3 أيام",
  "5 أيام",
  "7 أيام",
  "أسبوعان",
  "شهر",
];