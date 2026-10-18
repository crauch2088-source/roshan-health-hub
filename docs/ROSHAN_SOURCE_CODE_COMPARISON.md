# مقارنة الكود الفعلي: خمسة مشاريع صحية مقابل Roshan

**تاريخ الفحص:** 2026-10-18  
**المستودع المستهدف:** https://github.com/crauch2088-source/roshan-health-hub  
**الغرض:** تحليل ملفات فعلية وأنماط قابلة للتكييف؛ لا يعني ذلك أن الأنظمة الخارجية تستخدم Supabase. لا تنسخ كودًا مرخصًا إلى Roshan قبل مراجعة الترخيص.

## 1. Medplum — React/TypeScript والوصول إلى البيانات الصحية

المستودع: https://github.com/medplum/medplum (Apache-2.0)

الملفات المقروءة:
- [usePatientSummaryData.ts](https://github.com/medplum/medplum/blob/main/packages/react-hooks/src/usePatientSummaryData/usePatientSummaryData.ts)
- [accesspolicy.ts](https://github.com/medplum/medplum/blob/main/packages/server/src/fhir/accesspolicy.ts)
- [Access Policies](https://github.com/medplum/medplum/blob/main/packages/docs/docs/access/access-policies.md)

**ما يميزه:** hook ملخص المريض يبني مفاتيح بحث مستقرة، يزيل تكرار الاستعلامات، ويشغل عمليات مستقلة بالتوازي باستخدام `Promise.allSettled` كي لا يفشل الملخص كله بسبب قسم واحد. طبقة الوصول تحول سياق المصادقة والعضوية والسياسة إلى repository محدود الصلاحيات.

مثال حقيقي من صيغة السياسة في وثائق Medplum:
```json
{
  "resourceType": "AccessPolicy",
  "resource": [
    { "resourceType": "Patient", "readonly": true }
  ]
}
```

**المقابل في Roshan:** `src/lib/db.ts` و`src/lib/paging.ts`، `src/features/clinic/consultation/ConsultationPage.tsx`، `src/lib/auth.ts` و`src/components/kit/PermissionGate`، وسياسات SQL في `db/roshan_phase1_migration.sql` وملفات عزل الفروع.

**التوصية:** ملخص سريري بأقسام مستقلة، ومفاتيح cache مستقرة، وإظهار خطأ القسم الفاشل مع استمرار الأقسام الأخرى. يجب إفراغ بيانات المريض السابق عند تبديل المريض/المستخدم. لا تنقل سياسة Medplum مباشرة إلى RLS؛ فالتطبيق يطبق الوصول في طبقة API/FHIR.

## 2. OpenEMR — صلاحيات ACL دقيقة

المستودع: https://github.com/openemr/openemr

الملفات المقروءة:
- [PatientFilter ACL setup](https://github.com/openemr/openemr/blob/master/interface/modules/zend_modules/module/PatientFilter/acl/acl_setup.php)
- [PatientFilter ACL upgrade](https://github.com/openemr/openemr/blob/master/interface/modules/zend_modules/module/PatientFilter/acl/acl_upgrade.php)

**ما يميزه:** تعريف قسم ACL وصلاحيات دقيقة لفلترة الحقول والـhooks والمعاملات، وربطها بامتيازات الأطباء عبر API صلاحيات بدل توزيع منطق الأدوار على صفحات الواجهة. ملف الإعداد يحمي نفسه من التشغيل خارج مسار الإعداد.

**المقابل في Roshan:** `src/components/kit/PermissionGate`، `src/lib/auth.ts`، `db/roshan_phase1_migration.sql`، `db/roshan_phase21_patient_registration_privileges.sql`، `db/roshan_phase28_clinical_child_write_rpcs.sql`، واختبارات `db/tests/*_integration.sql`.

**التوصية:** يجب أن تتطابق الصلاحية بين UI gate وRPC وRLS/grants. أضف اختبارًا يستدعي RPC مباشرة بمستخدم بلا إذن لإثبات أن إخفاء الزر ليس حدًا أمنيًا.

## 3. OpenMRS Core — تحقق الخدمة والمعاملات واتساق الزيارة

المستودع: https://github.com/openmrs/openmrs-core

الملفات المقروءة:
- [PatientServiceImpl.java](https://github.com/openmrs/openmrs-core/blob/master/api/src/main/java/org/openmrs/api/impl/PatientServiceImpl.java)
- [EncounterServiceImpl.java](https://github.com/openmrs/openmrs-core/blob/master/api/src/main/java/org/openmrs/api/impl/EncounterServiceImpl.java)
- [Encounter.java](https://github.com/openmrs/openmrs-core/blob/master/api/src/main/java/org/openmrs/Encounter.java)

**ما يميزه:** طبقة الخدمة تستخدم معاملات، وتتحقق من امتيازات تعديل الزيارة، وتنسق بين Encounter والملاحظات التابعة. يوضح الكود ضرورة إبقاء المريض المشار إليه في الملاحظات متسقًا مع المريض في الزيارة.

**المقابل في Roshan:** `db/roshan_phase21_patient_registration_atomicity.sql`، `db/roshan_phase20_clinical_child_branch_isolation.sql`، `db/roshan_parent_branch_isolation.sql`، `db/roshan_phase7_atomic_prescription.sql`، `db/roshan_phase8_atomic_invoice.sql`، و`src/features/clinic/consultation/ConsultationPage.tsx`.

**التوصية:** أضف اختبارات تمنع ربط زيارة بمريض مختلف حتى لو كان المعرّفان صالحين. اختبر UPDATE الذي يغيّر `patient_id` أو `visit_id`، وليس INSERT فقط. يجب أن تكون آثار إلغاء الزيارة على الأوامر التابعة صريحة ومدققة.

## 4. Frappe Health — تعريف المجال ودورة حياة المستند

المستودع: https://github.com/8848digital/health (GPL-3.0؛ لا تنقل الكود دون مراجعة الترخيص)

الملفات المقروءة:
- [patient.json](https://github.com/8848digital/health/blob/develop/healthcare/healthcare/doctype/patient/patient.json)
- [patient_encounter.py](https://github.com/8848digital/health/blob/develop/healthcare/healthcare/doctype/patient_encounter/patient_encounter.py)
- [patient_appointment.json](https://github.com/8848digital/health/blob/develop/healthcare/healthcare/doctype/patient_appointment/patient_appointment.json)
- [hooks.py](https://github.com/8848digital/health/blob/develop/healthcare/hooks.py)

**ما يميزه:** ملفات JSON تصف حقول المريض والموعد والبحث والحقول المطلوبة/للقراءة فقط. دورة حياة PatientEncounter تتحقق من المدخلات، وتنشئ طلبات الخدمة والدواء عند الإرسال، وتحدّث حالة الموعد، وتلغي الطلبات التابعة عند الإلغاء. كما تُربط أحداث المستندات بالسجل الطبي والفواتير وتذكيرات المواعيد.

**المقابل في Roshan:** `db/roshan_phase1_migration.sql`، `src/features/clinic/consultation/ConsultationPage.tsx`، `src/routes/_authenticated/clinic_.$visitId.tsx`، `src/features/clinic/consultation/components/LaboratoryTab.tsx` و`PrescriptionTab.tsx`.

**التوصية:** وثّق انتقالات حالة الزيارة/المختبر، واجعل الانتقالات غير الصحيحة مستحيلة من جهة الخادم. اختبر آثار الإلغاء على الوصفات والتحاليل والفواتير. لا توجد Edge Functions منشورة في Supabase المتصل بحسب الفحص السابق؛ لا تفترض وجود scheduler دون إثباته.

## 5. Bahmni — تحويل نتائج المختبر إلى نموذج عرض

المستودع: https://github.com/Bahmni/openmrs-module-bahmniapps

الملفات المقروءة:
- [labTestsProvider.js](https://github.com/Bahmni/openmrs-module-bahmniapps/blob/master/ui/app/clinical/consultation/services/labTestsProvider.js)
- [labResultsMapper.js](https://github.com/Bahmni/openmrs-module-bahmniapps/blob/master/ui/app/clinical/consultation/mappers/labResultsMapper.js)
- [patientDashboardLabOrdersController.js](https://github.com/Bahmni/openmrs-module-bahmniapps/blob/master/ui/app/clinical/dashboard/controllers/patientDashboardLabOrdersController.js)

**ما يميزه:** provider يجلب مفاهيم التحاليل والأقسام، ثم يحول mapper ملاحظات المختبر إلى نتائج وملاحظات متداخلة. الملف يتضمن أيضًا TODO وافتراضات عن أسماء المفاهيم؛ لذا نقتبس فصل المصدر عن العرض، لا الكود حرفيًا.

**المقابل في Roshan:** `src/routes/_authenticated/lab_.$orderId.tsx`، `src/lib/lab-workflow.ts`، `src/features/clinic/consultation/components/LaboratoryTab.tsx`، وترحيلات/RPC المختبر.

**التوصية:** أضف mapper واحدًا typed لنتائج المختبر. نموذج مقترح:
```ts
type LabValue =
  | { kind: "numeric"; value: number; unit: string; lower?: number; upper?: number }
  | { kind: "text"; value: string }
  | { kind: "coded"; code: string; display: string }
  | { kind: "group"; children: LabValue[] };
```
ميّز غياب النتيجة عن الصفر والقيمة غير الرقمية، ولا تعرض النص/القيمة الفارغة بوصفها غير طبيعية. لا تغيّر schema قبل جرد أنواع `lab_parameters.data_type` والبيانات الموجودة.

## 6. لماذا لا توجد مقارنة مباشرة لـSupabase migrations/functions؟

هذه المستودعات لا تستخدم بنية `supabase/migrations` و`supabase/functions` نفسها:
- Medplum: PostgreSQL + TypeScript API/FHIR + Bots.
- OpenEMR: PHP + SQL + ACL.
- OpenMRS: Java/Spring/Hibernate.
- Frappe Health: Python/DocTypes/hooks/scheduler.
- Bahmni: JavaScript client لـOpenMRS API.

المقارنة الصحيحة هي مقارنة المسؤولية والضمان الأمني، لا اسم الملف. شجرة Roshan الحالية لا تعرض مجلد `supabase/`; ملفات المصدر SQL في `db/` و`docs/recovered-migrations/`. يجب حسم مصدر الترحيلات القياسي قبل إنشاء مجلد ثانٍ بالتوازي.

## 7. تعديلات كود ومخطط مقترحة وجاهزة للتنفيذ

لم تُطبّق هذه التغييرات على قاعدة الإنتاج في هذه الجولة؛ هذه خطة تنفيذ محددة بمسارات واختبارات.

### P0-A — توسيع اختبارات عزل الفروع والروابط
الملفات: `db/roshan_phase20_clinical_child_branch_isolation.sql`، `db/tests/clinical_child_branch_isolation_fixture.sql`، `db/tests/clinical_child_branch_isolation_integration.sql`، `db/tests/prescription_lab_child_branch_isolation_integration.sql`.

اختبر parent من الفرع A وchild من B، ثم الفرع نفسه مع مريض مختلف، واختبر UPDATE الذي يغيّر `patient_id` أو `visit_id`. المتوقع رفض بـ`42501` أو constraint violation. أضف حالة مستخدم بلا صلاحية مع فرع صحيح. استخدم helpers الموجودة.

### P0-B — إغلاق بوابة Phase 30 بعد التحقق من النشر
الملفات: `db/roshan_phase28_clinical_child_write_rpcs.sql`، `db/roshan_phase29_clinical_child_rpc_only_writes.sql`، `db/roshan_phase30_clinical_child_rpc_only_writes.sql`، `src/routes/_authenticated/lab_.$orderId.tsx` ومسار الشهادات.

أثبت أن الواجهة المنشورة تستخدم RPC `complete_lab_order_item` و`create_medical_certificate` قبل سحب الكتابة المباشرة. اختبر المستخدم المخول، والمستخدم بلا صلاحية، والفرع الآخر، وعدم وجود DML مباشر من المتصفح.

### P1-C — ملخص سريري بأقسام مستقلة
الملفات: `src/features/clinic/consultation/ConsultationPage.tsx` و`src/lib/db.ts`.

استخدم TanStack Query الحالي واجمع أقسام المريض/الحساسيات/الزيارات/التحاليل بالتوازي، مع فشل جزئي واضح:
```ts
const settled = await Promise.allSettled(sectionLoaders.map((load) => load()));
return settled.map((item) =>
  item.status === "fulfilled"
    ? { state: "ready" as const, data: item.value }
    : { state: "error" as const, data: null }
);
```
هذا نمط مختصر للتكييف، وليس تنفيذًا جاهزًا للصق دون أنواع ومعالجة أخطاء. لا تخفِ 401/403/42501، وأفرغ بيانات المريض السابق عند تبديله.

### P1-D — تحقق الوصفة داخل RPC
الملفات: `src/features/clinic/consultation/components/PrescriptionTab.tsx`، `src/lib/prescription-draft.ts`، `db/roshan_phase7_atomic_prescription.sql`، `db/tests/prescription_rpc_integration.sql`.

تحقق في Postgres من الجرعة والتكرار والطريق والمدة والكمية وربط الوصفة بالمريض والزيارة والفرع؛ لا تثق بواجهة المستخدم. لا تنشئ جرعات أطفال تلقائية دون بروتوكول معتمد ومراجعة الطبيب. اختبر رفض الحمولة غير الصالحة ومنع تكرار الوصفة عند إعادة الإرسال.

### P1-E — انتقالات حالة المختبر على الخادم
الملفات: `src/lib/lab-workflow.ts`، `db/roshan_phase28_clinical_child_write_rpcs.sql` واختبارات RPC.

اختبر منع الرجوع من `verified` إلى `in_progress` دون صلاحية تصحيح واضحة. سجل المنفذ والوقت وسبب التصحيح، وتأكد أن تحديث النتيجة وحالة الطلب عملية متسقة.

### P2-F — قاموس البيانات ومصدر SQL القياسي
الملفات: `db/roshan_phase1_migration.sql`، `db/roshan_phase20_clinical_child_branch_isolation.sql`، `docs/DB_MIGRATION_RECONCILIATION.md`، `docs/recovered-migrations/manifest.json`.

وثّق لكل جدول المالك والمفتاح الأب والفرع وسياسة الحذف وRPC الكتابة. أضف CI يرفض ملف SQL بلا ترتيب/وصف/اختبار. لا تنشئ `supabase/migrations` بالتوازي قبل حسم المصدر القياسي.

### P2-G — FHIR export تدريجي
ملف تصميم مقترح: `docs/FHIR_EXPORT_MAPPING.md`. ابدأ بربط Patient ← `patients`، Encounter ← `visits`، Observation ← `vitals`/نتائج المختبر، MedicationRequest ← `prescriptions`، DiagnosticReport ← نتائج المختبر. وثّق الوحدات والتوقيت ومعرفات المصدر والفرع. لا تستبدل schema الحالية قبل وجود تكامل فعلي.

## 8. حدود الجولة والاحتياجات الإضافية

- تمت قراءة ملفات فعلية من خمسة مستودعات ومقارنتها بمسارات Roshan المحددة.
- لم تُنسخ ملفات خارجية إلى التطبيق، ولم تُنشأ migration أو Edge Function، ولم تُعدّل قاعدة الإنتاج.
- لا نحتاج أداة MCP إضافية لقراءة الكود العام. الوصول إلى إعدادات Auth الخاصة أو تشغيل E2E داخل جلسة مصادق عليها أو PostgreSQL نظيف يتطلب إتاحة البيئة إن لم تكن متصلة؛ لا يلزم بالضرورة اشتراك مدفوع.
