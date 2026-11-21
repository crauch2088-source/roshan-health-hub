import type { Lang } from "./i18n";

const ERROR_CATALOG: Array<{ match: RegExp; ar: string; en: string }> = [
  {
    match: /medicine_stock_is_rpc_managed/i,
    ar: "يُدار رصيد الدواء حصراً عبر استلام الدفعات وصرف الوصفات، ولا يمكن تعديله مباشرةً.",
    en: "Medicine stock is managed exclusively through batch receiving and dispensing workflows.",
  },
  {
    match: /pharmacy_batch_expiry_required/i,
    ar: "تاريخ انتهاء الدفعة مطلوب عند استلام كمية موجبة.",
    en: "Batch expiry date is required when receiving stock.",
  },
  {
    match: /visit branch must be active/i,
    ar: "تعذّر إنشاء الزيارة لأن الفرع المحدد غير نشط أو غير متاح لحسابك. راجع إدارة النظام.",
    en: "Cannot create visit because the assigned branch is inactive or unavailable for your account.",
  },
  {
    match: /visit branch must match the assigned patient branch/i,
    ar: "يجب أن يطابق فرع الزيارة الفرع المسجّل عليه المريض.",
    en: "Visit branch must match the patient's assigned branch.",
  },
  {
    match: /visit requires an authoritative branch/i,
    ar: "يتطلب إنشاء الزيارة فرعاً معتمداً ومرتبطاً بالحساب.",
    en: "Visit creation requires an authorized branch assignment.",
  },
  {
    match: /active patient not found for visit branch attribution/i,
    ar: "لم يُعثر على سجل مريض نشط لفتح الزيارة.",
    en: "Active patient record not found for this visit.",
  },
  {
    match: /user branch is not configured/i,
    ar: "حسابك غير مرتبط بفرع نشط. تواصل مع مدير النظام لإسناد الفرع.",
    en: "Your account is not assigned to an active branch. Contact system administration.",
  },
  {
    match: /not authorised|not authorized/i,
    ar: "ليس لديك صلاحية لتنفيذ هذا الإجراء.",
    en: "You are not authorized to perform this action.",
  },
  {
    match: /invalid quantity|quantity must be greater than zero/i,
    ar: "الكمية المدخلة غير صالحة؛ يجب أن تكون رقماً صحيحاً أكبر من الصفر.",
    en: "Invalid quantity; please enter a whole number greater than zero.",
  },
  {
    match: /insufficient stock/i,
    ar: "الرصيد المتاح في المخزون غير كافٍ لإتمام الصرف.",
    en: "Insufficient stock available to complete dispensing.",
  },
  {
    match: /expired/i,
    ar: "لا يمكن صرف دفعة منتهية الصلاحية.",
    en: "Expired pharmacy batches cannot be dispensed.",
  },
];

export function translateBackendError(rawMessage: string | null | undefined, lang: Lang): string {
  const text = String(rawMessage ?? "").trim();
  if (!text) {
    return lang === "ar" ? "حدث خطأ غير متوقع. حاول مرة أخرى." : "An unexpected error occurred. Please try again.";
  }
  for (const entry of ERROR_CATALOG) {
    if (entry.match.test(text)) {
      return entry[lang];
    }
  }
  if (/^[a-z][a-z0-9_]{3,}$/.test(text)) {
    return lang === "ar"
      ? "تعذّر إتمام العملية بسبب قاعدة تحقق في النظام. راجع البيانات المدخلة."
      : "Operation could not be completed due to a system validation rule. Please review your input.";
  }
  return text;
}
