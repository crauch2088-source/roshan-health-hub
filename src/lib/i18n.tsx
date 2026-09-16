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
  navigation: { ar: "التنقل", en: "Navigation" },
  skip_to_content: { ar: "الانتقال إلى المحتوى", en: "Skip to content" },

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
  finance_hub: { ar: "المركز المالي", en: "Finance Hub" },
  finance_hub_subtitle: { ar: "الخزنة، التحصيل، المستحقات وديون الموردين", en: "Cashbox, collections, receivables and supplier debts" },
  finance_overview: { ar: "نظرة عامة", en: "Overview" },
  cashbox: { ar: "الخزنة", en: "Cashbox" },
  receivables: { ar: "مستحقات العملاء", en: "Receivables" },
  suppliers_finance: { ar: "الموردون", en: "Suppliers" },
  supplier_payment: { ar: "دفعة مورد", en: "Supplier payment" },
  add_supplier: { ar: "إضافة مورد", en: "Add supplier" },
  new_supplier_bill: { ar: "فاتورة مورد جديدة", en: "New supplier bill" },
  cashbox_balance: { ar: "رصيد الخزنة", en: "Cashbox balance" },
  supplier_debt: { ar: "ديون الموردين", en: "Supplier debt" },
  cashbox_entry: { ar: "حركة خزنة", en: "Cashbox entry" },
  bank: { ar: "بنكي", en: "Bank" },
  reverse: { ar: "عكس القيد", en: "Reverse" },
  reversed: { ar: "معكوس", en: "Reversed" },
  reversal: { ar: "قيد عكسي", en: "Reversal" },
  reversal_reason: { ar: "سبب العكس", en: "Reversal reason" },
  reversal_reason_required: { ar: "سبب العكس مطلوب", en: "A reversal reason is required" },
  record_payment: { ar: "تسجيل دفعة", en: "Record payment" },
  total_billed: { ar: "إجمالي الفواتير", en: "Total billed" },
  total_paid: { ar: "إجمالي المدفوع", en: "Total paid" },
  paid_amount: { ar: "المبلغ المدفوع", en: "Paid amount" },
  description: { ar: "الوصف", en: "Description" },
  reference: { ar: "المرجع", en: "Reference" },
  income: { ar: "إيراد", en: "Income" },
  expense: { ar: "مصروف", en: "Expense" },
  manual: { ar: "يدوي", en: "Manual" },

  // insurance — Phase 5
  insurance: { ar: "التأمين", en: "Insurance" },
  insurance_subtitle: { ar: "شركات التأمين، الخطط، عضوية المرضى والمطالبات", en: "Companies, plans, patient membership, and claims" },
  insurance_companies: { ar: "شركات التأمين", en: "Insurance companies" },
  insurance_plans: { ar: "خطط التأمين", en: "Insurance plans" },
  patient_insurance: { ar: "تأمين المريض", en: "Patient insurance" },
  insurance_claims: { ar: "مطالبات التأمين", en: "Insurance claims" },
  deactivate: { ar: "إلغاء التفعيل", en: "Deactivate" },
  activate: { ar: "تفعيل", en: "Activate" },
  default_coverage_percent: { ar: "نسبة التغطية الافتراضية", en: "Default coverage %" },
  policy_number: { ar: "رقم الوثيقة", en: "Policy number" },
  member_number: { ar: "رقم العضوية", en: "Member number" },
  new_claim: { ar: "مطالبة جديدة", en: "New claim" },
  claim_number: { ar: "رقم المطالبة", en: "Claim number" },
  submitted: { ar: "تم الإرسال", en: "Submitted" },
  under_review: { ar: "قيد المراجعة", en: "Under review" },
  approved: { ar: "معتمدة", en: "Approved" },
  partially_approved: { ar: "معتمدة جزئياً", en: "Partially approved" },
  rejected: { ar: "مرفوضة", en: "Rejected" },
  pending_claims: { ar: "مطالبات قيد الانتظار", en: "Pending claims" },
  outstanding_insurance: { ar: "مستحقات التأمين", en: "Outstanding insurance" },
  approved_amount: { ar: "المبلغ المعتمد", en: "Approved amount" },
  covered_amount: { ar: "المبلغ المغطى", en: "Covered amount" },
  patient_amount: { ar: "مبلغ المريض", en: "Patient amount" },
  confirm_status_change: { ar: "تأكيد تغيير الحالة؟", en: "Confirm this status change?" },

  // Phase 6 — analytics
  analytics: { ar: "التحليلات", en: "Analytics" },
  analytics_subtitle: { ar: "اتجاهات الإيرادات، الصيدلية والأداء السريري", en: "Revenue, pharmacy, and clinical performance trends" },
  month: { ar: "الشهر", en: "Month" },
  revenue_12mo: { ar: "الإيرادات (12 شهراً)", en: "Revenue (12mo)" },
  expenses_12mo: { ar: "المصروفات (12 شهراً)", en: "Expenses (12mo)" },
  revenue_trends: { ar: "اتجاهات الإيرادات", en: "Revenue trends" },
  expense_trends: { ar: "اتجاهات المصروفات", en: "Expense trends" },
  insurance_revenue: { ar: "إيرادات التأمين", en: "Insurance revenue" },
  outstanding_receivables: { ar: "المستحقات المتبقية", en: "Outstanding receivables" },
  supplier_debt_analysis: { ar: "تحليل ديون الموردين", en: "Supplier debt analysis" },
  fefo_waste_units: { ar: "وحدات الهدر (FEFO)", en: "FEFO waste units" },
  expiry_forecast_value: { ar: "قيمة المخزون المعرض للانتهاء", en: "Expiry forecast value" },
  pharmacy_performance: { ar: "أداء الصيدلية", en: "Pharmacy performance" },
  fefo_waste_tracking: { ar: "تتبع الهدر (FEFO)", en: "FEFO waste tracking" },
  expiry_forecasting: { ar: "توقع انتهاء الصلاحية", en: "Expiry forecasting" },
  value_at_risk: { ar: "القيمة المعرضة للخطر", en: "Value at risk" },
  visits_12mo: { ar: "الزيارات (12 شهراً)", en: "Visits (12mo)" },
  appointments_12mo: { ar: "المواعيد (12 شهراً)", en: "Appointments (12mo)" },
  lab_revenue_12mo: { ar: "إيرادات المختبر (12 شهراً)", en: "Lab revenue (12mo)" },
  visit_trends: { ar: "اتجاهات الزيارات", en: "Visit trends" },
  doctor_productivity: { ar: "إنتاجية الأطباء", en: "Doctor productivity" },
  department_statistics: { ar: "إحصائيات الأقسام", en: "Department statistics" },
  appointment_analytics: { ar: "تحليلات المواعيد", en: "Appointment analytics" },
  laboratory_analytics: { ar: "تحليلات المختبر", en: "Laboratory analytics" },
  unassigned: { ar: "غير محدد", en: "Unassigned" },

  // Phase 7 — dashboard sections
  executive_summary: { ar: "الملخص التنفيذي", en: "Executive summary" },
  clinical_summary: { ar: "الملخص السريري", en: "Clinical summary" },
  pending_tasks: { ar: "مهام قيد الانتظار", en: "Pending tasks" },
  pharmacy_summary: { ar: "ملخص الصيدلية", en: "Pharmacy summary" },
  insurance_summary: { ar: "ملخص التأمين", en: "Insurance summary" },
  revenue_summary: { ar: "ملخص الإيرادات", en: "Revenue summary" },
  recent_activity: { ar: "النشاط الأخير", en: "Recent activity" },
  cash_in: { ar: "داخل الخزنة", en: "Cash in" },
  cash_out: { ar: "خارج الخزنة", en: "Cash out" },
  deposit: { ar: "إيداع", en: "Deposit" },
  withdrawal: { ar: "سحب", en: "Withdrawal" },
  invalid_amount: { ar: "أدخل مبلغاً صحيحاً أكبر من صفر", en: "Enter a valid amount greater than zero" },
  payment_exceeds_balance: { ar: "المبلغ يتجاوز الرصيد المستحق", en: "Payment exceeds the outstanding balance" },
  refresh: { ar: "تحديث", en: "Refresh" },
  type: { ar: "النوع", en: "Type" },
  expenses: { ar: "المصروفات", en: "Expenses" },
  partners: { ar: "الجهات المتعاقدة", en: "Partners" },
  reports: { ar: "التقارير", en: "Reports" },
  users: { ar: "المستخدمون", en: "Users" },
  settings: { ar: "الإعدادات", en: "Settings" },
  audit_log: { ar: "سجل التغييرات", en: "Audit log" },
  system_status: { ar: "حالة النظام", en: "System status" },
  followups: { ar: "المتابعات", en: "Follow-ups" },
  certificates: { ar: "الشهادات", en: "Certificates" },

  // nav groups (Phase 2)
  clinical: { ar: "السريري", en: "Clinical" },
  finance: { ar: "المالية", en: "Finance" },
  administration: { ar: "الإدارة", en: "Administration" },
  // nav groups (Phase 20) — the old "finance" group had grown to 8 items
  // mixing billing, accounting, reports, analytics and insurance together;
  // split into its own reporting group, and insurance/pharmacy/lab (each
  // previously a separate top-level group) now share one clinical-services
  // group, matching how those teams actually work day to day.
  clinical_services: { ar: "الخدمات السريرية", en: "Clinical services" },
  reporting: { ar: "التقارير", en: "Reporting" },

  // navigation shell (Phase 1 + 2)
  search_placeholder: { ar: "بحث عن مريض، زيارة، تحليل أو دواء…", en: "Search patients, visits, labs, medicines…" },
  search_everywhere: { ar: "بحث شامل", en: "Search everywhere" },
  no_results: { ar: "لا توجد نتائج", en: "No results found" },
  type_to_search: { ar: "ابدأ الكتابة للبحث…", en: "Start typing to search…" },
  recent_searches: { ar: "عمليات البحث الأخيرة", en: "Recent searches" },
  search_history: { ar: "سجل البحث", en: "Search history" },
  recent_pages: { ar: "الصفحات الأخيرة", en: "Recent pages" },
  clear: { ar: "مسح", en: "Clear" },
  favorites: { ar: "المفضلة", en: "Favorites" },
  pin: { ar: "تثبيت", en: "Pin" },
  unpin: { ar: "إلغاء التثبيت", en: "Unpin" },
  pages: { ar: "الصفحات", en: "Pages" },
  quick_actions: { ar: "إجراءات سريعة", en: "Quick actions" },
  new_patient: { ar: "مريض جديد", en: "New patient" },
  new_visit: { ar: "زيارة جديدة", en: "New visit" },
  new_lab_order: { ar: "طلب تحليل جديد", en: "New lab order" },
  new_lab_order_hint: {
    ar: "يجب إنشاء طلب التحليل من داخل زيارة نشطة. تم فتح قائمة الزيارات.",
    en: "Lab orders are created from inside an active visit. Opening the visits list.",
  },
  collapse_sidebar: { ar: "طي القائمة", en: "Collapse sidebar" },
  expand_sidebar: { ar: "توسيع القائمة", en: "Expand sidebar" },
  home: { ar: "الرئيسية", en: "Home" },
  patient_result: { ar: "مريض", en: "Patient" },
  visit_result: { ar: "زيارة", en: "Visit" },
  lab_result: { ar: "تحليل", en: "Lab test" },
  medicine_result: { ar: "دواء", en: "Medicine" },
  more: { ar: "المزيد", en: "More" },

  // common
  save: { ar: "حفظ", en: "Save" },
  saving: { ar: "جارٍ الحفظ…", en: "Saving…" },
  cancel: { ar: "إلغاء", en: "Cancel" },
  add: { ar: "إضافة", en: "Add" },
  open: { ar: "فتح", en: "Open" },
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
  register_patient: { ar: "تسجيل مريض", en: "Register patient" },
  patient: { ar: "المريض", en: "Patient" },
  search_patient_placeholder: { ar: "ابحث بالاسم أو الرقم الطبي أو الهاتف أو الرقم الوطني", en: "Search by name, MRN, phone or national ID" },
  add_new_patient: { ar: "إضافة مريض جديد", en: "Add new patient" },
  duplicate_patient_hint: {
    ar: "تأكد من عدم تسجيل هذا المريض من قبل قبل إنشاء سجل جديد.",
    en: "Double-check this patient isn't already registered before creating a new record.",
  },
  recent_patients: { ar: "مرضى حديثون", en: "Recent patients" },
  previous_visits: { ar: "الزيارات السابقة", en: "Previous visits" },
  last_visit: { ar: "آخر زيارة", en: "Last visit" },
  outstanding_balance: { ar: "الرصيد المستحق", en: "Outstanding balance" },

  // visit
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

  // pharmacy — Phase 3 batches/FEFO/suppliers
  batches: { ar: "التشغيلات", en: "Batches" },
  suppliers: { ar: "الموردون", en: "Suppliers" },
  purchase_history: { ar: "سجل المشتريات", en: "Purchase history" },
  quantity_received: { ar: "الكمية المستلمة", en: "Quantity received" },
  remaining_quantity: { ar: "الكمية المتبقية", en: "Remaining quantity" },
  manufacture_date: { ar: "تاريخ التصنيع", en: "Manufacture date" },
  invoice_reference: { ar: "رقم فاتورة المورد", en: "Invoice reference" },
  select_medicine: { ar: "اختر الدواء", en: "Select medicine" },
  invalid_quantity: { ar: "كمية غير صحيحة", en: "Invalid quantity" },
  legacy_receive_hint: {
    ar: "لتتبع كامل للتشغيلة وتاريخ الانتهاء، استخدم تبويب \"التشغيلات\" بدلاً من ذلك.",
    en: "For full batch and expiry tracking, use the Batches tab instead.",
  },
  all: { ar: "الكل", en: "All" },
  healthy: { ar: "سليم", en: "Healthy" },
  expiring_soon: { ar: "قارب على الانتهاء", en: "Expiring soon" },
  expired: { ar: "منتهي الصلاحية", en: "Expired" },
  expiring_medicines: { ar: "أدوية قاربت على الانتهاء", en: "Expiring medicines" },
  expired_medicines: { ar: "أدوية منتهية الصلاحية", en: "Expired medicines" },
  low_stock_medicines: { ar: "أدوية منخفضة المخزون", en: "Low stock medicines" },
  low_stock_batches: { ar: "تشغيلات منخفضة المخزون", en: "Low stock batches" },
  movement_history: { ar: "سجل الحركة", en: "Movement history" },
  batches_used: { ar: "التشغيلات المستخدمة", en: "Batches used" },
  quantity_dispensed: { ar: "الكمية المصروفة", en: "Quantity dispensed" },
  legacy_stock: { ar: "مخزون سابق (بدون تشغيلة)", en: "Legacy stock (no batch)" },
  name_required: { ar: "الاسم مطلوب", en: "Name is required" },
  purchase: { ar: "شراء", en: "Purchase" },
  adjustment: { ar: "تسوية", en: "Adjustment" },
  return: { ar: "إرجاع", en: "Return" },
  writeoff: { ar: "إتلاف", en: "Write-off" },
  expiry_report: { ar: "تقرير انتهاء الصلاحية", en: "Expiry report" },
  low_stock_report: { ar: "تقرير المخزون المنخفض", en: "Low stock report" },
  batch_inventory_report: { ar: "تقرير مخزون التشغيلات", en: "Batch inventory report" },
  pharmacy_expiry_threshold: { ar: "حد التنبيه لانتهاء الصلاحية (أيام)", en: "Expiry alert threshold (days)" },

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