import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";

export type Lang = "ar" | "en";

const dict: Record<string, { ar: string; en: string }> = {
  app_name: { ar: "مركز روشان الطبي", en: "Roshan Medical Center" },
  app_short: { ar: "روشان", en: "Roshan" },

  // auth
  sign_in: { ar: "تسجيل الدخول", en: "Sign in" },
  sign_out: { ar: "تسجيل الخروج", en: "Sign out" },
  email: { ar: "البريد الإلكتروني", en: "Email" },
  password: { ar: "كلمة المرور", en: "Password" },
  forgot_password: { ar: "نسيت كلمة المرور؟", en: "Forgot password?" },
  reset_password: { ar: "إعادة تعيين كلمة المرور", en: "Reset password" },
  send_reset_link: { ar: "إرسال رابط الاستعادة", en: "Send reset link" },
  new_password: { ar: "كلمة المرور الجديدة", en: "New password" },
  update_password: { ar: "تحديث كلمة المرور", en: "Update password" },
  first_run_setup: { ar: "التهيئة الأولى للنظام", en: "First-time setup" },
  create_super_admin: { ar: "إنشاء حساب المدير العام", en: "Create Super Admin" },
  setup_done: { ar: "تمت التهيئة", en: "Setup complete" },
  signup_disabled: {
    ar: "التسجيل العام مغلق. المدير العام فقط يمكنه إنشاء المستخدمين.",
    en: "Public signup is closed. Only the Super Admin creates users.",
  },

  // nav
  dashboard: { ar: "الرئيسية", en: "Dashboard" },
  patients: { ar: "المرضى", en: "Patients" },
  visits: { ar: "الزيارات", en: "Visits" },
  queue: { ar: "الطابور", en: "Queue" },
  appointments: { ar: "المواعيد", en: "Appointments" },
  clinic: { ar: "العيادة", en: "Clinic" },
  laboratory: { ar: "المختبر", en: "Laboratory" },
  lab_catalog: { ar: "إعداد التحاليل", en: "Test catalogue" },
  pharmacy: { ar: "الصيدلية", en: "Pharmacy" },
  inventory: { ar: "المخزون", en: "Inventory" },
  billing: { ar: "الفواتير", en: "Billing" },
  accounting: { ar: "المحاسبة", en: "Accounting" },
  expenses: { ar: "المصروفات", en: "Expenses" },
  partners: { ar: "الجهات المتعاقدة", en: "Partners" },
  reports: { ar: "التقارير", en: "Reports" },
  users: { ar: "المستخدمون", en: "Users" },
  settings: { ar: "الإعدادات", en: "Settings" },
  audit_log: { ar: "سجل التغييرات", en: "Audit log" },
  system_status: { ar: "حالة النظام", en: "System status" },
  followups: { ar: "المتابعات", en: "Follow-ups" },
  certificates: { ar: "الشهادات", en: "Certificates" },

  // common
  save: { ar: "حفظ", en: "Save" },
  saving: { ar: "جارٍ الحفظ…", en: "Saving…" },
  cancel: { ar: "إلغاء", en: "Cancel" },
  add: { ar: "إضافة", en: "Add" },
  edit: { ar: "تعديل", en: "Edit" },
  delete: { ar: "حذف", en: "Delete" },
  search: { ar: "بحث", en: "Search" },
  loading: { ar: "جارٍ التحميل…", en: "Loading…" },
  no_data: { ar: "لا توجد بيانات", en: "No records" },
  print: { ar: "طباعة", en: "Print" },
  export_excel: { ar: "تصدير Excel", en: "Export Excel" },
  export_pdf: { ar: "تصدير PDF", en: "Export PDF" },
  today: { ar: "اليوم", en: "Today" },
  total: { ar: "الإجمالي", en: "Total" },
  status: { ar: "الحالة", en: "Status" },
  actions: { ar: "إجراءات", en: "Actions" },
  notes: { ar: "ملاحظات", en: "Notes" },
  date: { ar: "التاريخ", en: "Date" },
  amount: { ar: "المبلغ", en: "Amount" },
  quantity: { ar: "الكمية", en: "Quantity" },
  price: { ar: "السعر", en: "Price" },
  name: { ar: "الاسم", en: "Name" },
  code: { ar: "الرمز", en: "Code" },
  category: { ar: "التصنيف", en: "Category" },
  none: { ar: "بدون", en: "None" },
  required: { ar: "مطلوب", en: "Required" },
  saved: { ar: "تم الحفظ", en: "Saved" },
  back: { ar: "رجوع", en: "Back" },
  previous: { ar: "السابق", en: "Previous" },
  next: { ar: "التالي", en: "Next" },
  page: { ar: "صفحة", en: "Page" },
  of: { ar: "من", en: "of" },

  // patient
  mrn: { ar: "الرقم الطبي", en: "MRN" },
  full_name: { ar: "الاسم الكامل", en: "Full name" },
  gender: { ar: "الجنس", en: "Gender" },
  male: { ar: "ذكر", en: "Male" },
  female: { ar: "أنثى", en: "Female" },
  dob: { ar: "تاريخ الميلاد", en: "Date of birth" },
  age: { ar: "العمر", en: "Age" },
  phone: { ar: "الهاتف", en: "Phone" },
  address: { ar: "العنوان", en: "Address" },
  occupation: { ar: "المهنة", en: "Occupation" },
  marital_status: { ar: "الحالة الاجتماعية", en: "Marital status" },
  blood_group: { ar: "فصيلة الدم", en: "Blood group" },
  national_id: { ar: "الرقم الوطني", en: "National ID" },
  new_patient: { ar: "مريض جديد", en: "New patient" },
  register_patient: { ar: "تسجيل مريض", en: "Register patient" },
  patient: { ar: "المريض", en: "Patient" },

  // visit
  new_visit: { ar: "زيارة جديدة", en: "New visit" },
  visit_type: { ar: "نوع الزيارة", en: "Visit type" },
  walk_in: { ar: "بدون موعد", en: "Walk-in" },
  scheduled: { ar: "بموعد", en: "Scheduled" },
  department: { ar: "القسم", en: "Department" },
  doctor: { ar: "الطبيب", en: "Doctor" },
  consultation_fee: { ar: "قيمة الاستشارة", en: "Consultation fee" },
  waiting: { ar: "في الانتظار", en: "Waiting" },
  in_progress: { ar: "قيد المعالجة", en: "In progress" },
  completed: { ar: "مكتملة", en: "Completed" },
  cancelled: { ar: "ملغاة", en: "Cancelled" },
  confirmed: { ar: "مؤكد", en: "Confirmed" },
  arrived: { ar: "حضر", en: "Arrived" },
  no_show: { ar: "لم يحضر", en: "No show" },
  queue_number: { ar: "رقم الطابور", en: "Queue no." },
  call_next: { ar: "نداء التالي", en: "Call next" },

  // emr
  vitals: { ar: "العلامات الحيوية", en: "Vitals" },
  clinical_notes: { ar: "الملاحظات السريرية", en: "Clinical notes" },
  diagnoses: { ar: "التشخيصات", en: "Diagnoses" },
  prescription: { ar: "الوصفة الطبية", en: "Prescription" },
  lab_orders: { ar: "طلبات المختبر", en: "Lab orders" },
  procedures: { ar: "الإجراءات", en: "Procedures" },
  bp: { ar: "ضغط الدم", en: "Blood pressure" },
  pulse: { ar: "النبض", en: "Pulse" },
  rr: { ar: "التنفس", en: "Resp. rate" },
  temperature: { ar: "الحرارة", en: "Temperature" },
  spo2: { ar: "تشبع الأكسجين", en: "SpO2" },
  weight: { ar: "الوزن", en: "Weight" },
  height: { ar: "الطول", en: "Height" },
  bmi: { ar: "كتلة الجسم", en: "BMI" },
  lmp: { ar: "آخر دورة (LMP)", en: "LMP" },
  edd: { ar: "الموعد المتوقع للولادة", en: "EDD" },
  gestational_age: { ar: "عمر الحمل", en: "Gestational age" },
  chief_complaint: { ar: "الشكوى الرئيسية", en: "Chief complaint" },
  hpi: { ar: "تفاصيل الشكوى", en: "History of presenting illness" },
  pmh: { ar: "التاريخ المرضي", en: "Past medical history" },
  psh: { ar: "التاريخ الجراحي", en: "Past surgical history" },
  drug_history: { ar: "تاريخ الأدوية", en: "Drug history" },
  allergy_history: { ar: "الحساسية", en: "Allergy history" },
  family_history: { ar: "التاريخ العائلي", en: "Family history" },
  social_history: { ar: "التاريخ الاجتماعي", en: "Social history" },
  examination: { ar: "الفحص", en: "Examination" },
  assessment: { ar: "التقييم", en: "Assessment" },
  plan: { ar: "الخطة", en: "Plan" },
  icd10: { ar: "رمز ICD-10", en: "ICD-10 code" },
  primary: { ar: "أساسي", en: "Primary" },
  secondary: { ar: "ثانوي", en: "Secondary" },
  medicine: { ar: "الدواء", en: "Medicine" },
  dosage: { ar: "الجرعة", en: "Dosage" },
  frequency: { ar: "التكرار", en: "Frequency" },
  duration: { ar: "المدة", en: "Duration" },
  instructions: { ar: "تعليمات", en: "Instructions" },
  external_pharmacy: { ar: "صيدلية خارجية", en: "External pharmacy" },
  internal_pharmacy: { ar: "صيدلية روشان", en: "Roshan pharmacy" },
  complete_visit: { ar: "إنهاء الزيارة", en: "Complete visit" },
  visit_locked: { ar: "الزيارة مكتملة — للقراءة فقط", en: "Visit completed — read only" },

  // lab
  sample: { ar: "العينة", en: "Sample" },
  collect_sample: { ar: "سحب العينة", en: "Collect sample" },
  enter_results: { ar: "إدخال النتائج", en: "Enter results" },
  verify: { ar: "اعتماد", en: "Verify" },
  verified: { ar: "معتمد", en: "Verified" },
  result: { ar: "النتيجة", en: "Result" },
  reference_range: { ar: "المعدل الطبيعي", en: "Reference range" },
  parameters: { ar: "المؤشرات", en: "Parameters" },
  unit: { ar: "الوحدة", en: "Unit" },
  test: { ar: "التحليل", en: "Test" },
  sample_type: { ar: "نوع العينة", en: "Sample type" },
  optional_note: {
    ar: "كل المؤشرات اختيارية — يمكن ترك أي حقل فارغاً",
    en: "All parameters are optional — any field may be left blank",
  },

  // pharmacy
  medicines: { ar: "الأدوية", en: "Medicines" },
  generic_name: { ar: "الاسم العلمي", en: "Generic name" },
  brand_name: { ar: "الاسم التجاري", en: "Brand name" },
  strength: { ar: "التركيز", en: "Strength" },
  dosage_form: { ar: "الشكل الدوائي", en: "Dosage form" },
  batch_number: { ar: "رقم التشغيلة", en: "Batch no." },
  expiry_date: { ar: "تاريخ الانتهاء", en: "Expiry date" },
  purchase_price: { ar: "سعر الشراء", en: "Purchase price" },
  cost_price: { ar: "سعر التكلفة", en: "Cost price" },
  selling_price: { ar: "سعر البيع", en: "Selling price" },
  in_stock: { ar: "المتوفر", en: "In stock" },
  stock: { ar: "المخزون", en: "Stock" },
  low_stock: { ar: "مخزون منخفض", en: "Low stock" },
  expiring: { ar: "قارب الانتهاء", en: "Expiring" },
  dispense: { ar: "صرف", en: "Dispense" },
  dispensed: { ar: "تم الصرف", en: "Dispensed" },
  reorder_level: { ar: "حد إعادة الطلب", en: "Reorder level" },
  receive_stock: { ar: "استلام مخزون", en: "Receive stock" },

  // billing
  invoice: { ar: "فاتورة", en: "Invoice" },
  invoices: { ar: "الفواتير", en: "Invoices" },
  invoice_number: { ar: "رقم الفاتورة", en: "Invoice no." },
  new_invoice: { ar: "فاتورة جديدة", en: "New invoice" },
  add_item: { ar: "إضافة بند", en: "Add item" },
  discount: { ar: "الخصم", en: "Discount" },
  subtotal: { ar: "المجموع", en: "Subtotal" },
  net: { ar: "الصافي", en: "Net" },
  paid: { ar: "المدفوع", en: "Paid" },
  balance: { ar: "المتبقي", en: "Balance" },
  payment: { ar: "الدفع", en: "Payment" },
  take_payment: { ar: "تسجيل دفعة", en: "Record payment" },
  payment_method: { ar: "طريقة الدفع", en: "Payment method" },
  cash: { ar: "نقداً", en: "Cash" },
  bankak: { ar: "بنكك", en: "Bankak" },
  unpaid: { ar: "غير مدفوعة", en: "Unpaid" },
  partial: { ar: "مدفوعة جزئياً", en: "Partial" },
  consultation: { ar: "استشارة", en: "Consultation" },
  revenue: { ar: "الإيرادات", en: "Revenue" },
  profit: { ar: "الأرباح", en: "Profit" },
  net_profit: { ar: "صافي الربح", en: "Net profit" },

  // dashboard
  patients_today: { ar: "مرضى اليوم", en: "Patients today" },
  visits_today: { ar: "زيارات اليوم", en: "Visits today" },
  appointments_today: { ar: "مواعيد اليوم", en: "Appointments today" },
  revenue_today: { ar: "إيرادات اليوم", en: "Revenue today" },
  expenses_today: { ar: "مصروفات اليوم", en: "Expenses today" },
  pending_lab: { ar: "طلبات مختبر معلقة", en: "Pending lab orders" },
  pending_pharmacy: { ar: "وصفات معلقة", en: "Pending prescriptions" },
  waiting_patients: { ar: "مرضى في الانتظار", en: "Waiting patients" },
  upcoming_appointments: { ar: "مواعيد قادمة", en: "Upcoming appointments" },
  daily_revenue: { ar: "الإيراد اليومي", en: "Daily revenue" },
  monthly_revenue: { ar: "الإيراد الشهري", en: "Monthly revenue" },
  visits_by_department: { ar: "الزيارات حسب القسم", en: "Visits by department" },
  lab_activity: { ar: "نشاط المختبر", en: "Laboratory activity" },
  pharmacy_activity: { ar: "نشاط الصيدلية", en: "Pharmacy activity" },
  upcoming_followups: { ar: "متابعات قادمة", en: "Upcoming follow-ups" },

  // settings
  system_configuration: {
    ar: "إعدادات النظام",
    en: "System configuration",
  },
  center_info: {
    ar: "معلومات المركز",
    en: "Center information",
  },
  center_name: {
    ar: "اسم المركز",
    en: "Center name",
  },
  center_name_ar: {
    ar: "اسم المركز بالعربية",
    en: "Center name (Arabic)",
  },
  currency: {
    ar: "العملة",
    en: "Currency",
  },
  tax_percent: {
    ar: "نسبة الضريبة %",
    en: "Tax %",
  },
  invoice_footer: {
    ar: "تذييل الفاتورة",
    en: "Invoice footer",
  },
  receipt_footer: {
    ar: "تذييل الإيصال",
    en: "Receipt footer",
  },
  language: {
    ar: "اللغة",
    en: "Language",
  },

  // misc
  role: { ar: "الدور", en: "Role" },
  active: { ar: "نشط", en: "Active" },
  inactive: { ar: "غير نشط", en: "Inactive" },
  no_permission: {
    ar: "لا تمتلك صلاحية الوصول لهذه الصفحة",
    en: "You do not have permission to view this page",
  },
  migration_needed: {
    ar: "النظام يحتاج تنفيذ ملف الترقية db/roshan_phase1_migration.sql على قاعدة البيانات",
    en: "The database migration db/roshan_phase1_migration.sql has not been applied yet",
  },
  certificate_type: { ar: "نوع الشهادة", en: "Certificate type" },
  medical_certificate: { ar: "شهادة طبية", en: "Medical certificate" },
  sick_leave: { ar: "إجازة مرضية", en: "Sick leave" },
  fitness: { ar: "شهادة لياقة", en: "Fitness certificate" },
  content: { ar: "النص", en: "Content" },
  valid_from: { ar: "من", en: "Valid from" },
  valid_to: { ar: "إلى", en: "Valid to" },
  attachments: { ar: "المرفقات", en: "Attachments" },
  file_url: { ar: "رابط الملف", en: "File URL" },
  reason: { ar: "السبب", en: "Reason" },
  due_date: { ar: "تاريخ المتابعة", en: "Follow-up date" },
  pending: { ar: "معلق", en: "Pending" },
  missed: { ar: "فائت", en: "Missed" },
  done: { ar: "منجز", en: "Done" },
  supplier: { ar: "المورد", en: "Supplier" },
  contact_person: { ar: "الشخص المسؤول", en: "Contact person" },
  discount_percent: { ar: "نسبة الخصم %", en: "Discount %" },
  agreement_notes: { ar: "ملاحظات الاتفاقية", en: "Agreement notes" },
  from_date: { ar: "من تاريخ", en: "From" },
  to_date: { ar: "إلى تاريخ", en: "To" },
  db_status: { ar: "حالة قاعدة البيانات", en: "Database status" },
  connected: { ar: "متصل", en: "Connected" },
  records: { ar: "سجلات", en: "records" },
};

type Ctx = {
  lang: Lang;
  dir: "rtl" | "ltr";
  t: (k: string) => string;
  toggle: () => void;
};

const LangCtx = createContext<Ctx | null>(null);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>("ar");

  useEffect(() => {
    const stored = window.localStorage.getItem("roshan-lang");

    if (stored === "en" || stored === "ar") {
      setLang(stored);
    }
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  }, [lang]);

  const toggle = useCallback(() => {
    setLang((prev) => {
      const next: Lang = prev === "ar" ? "en" : "ar";
      window.localStorage.setItem("roshan-lang", next);
      return next;
    });
  }, []);

  const t = useCallback(
    (k: string) => dict[k]?.[lang] ?? k,
    [lang],
  );

  return (
    <LangCtx.Provider
      value={{
        lang,
        dir: lang === "ar" ? "rtl" : "ltr",
        t,
        toggle,
      }}
    >
      {children}
    </LangCtx.Provider>
  );
}

export function useLang(): Ctx {
  const ctx = useContext(LangCtx);

  if (!ctx) {
    throw new Error("useLang must be used inside LanguageProvider");
  }

  return ctx;
}