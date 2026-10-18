# تدقيق Supabase الأمني والمعماري — Roshan Health Hub

> **التاريخ:** 2026-10-18 · **المشروع الحي:** `jewzonxplxhogqrnhosl` (PostgreSQL 17.6) · **النطاق:** مراجعة متقاطعة للوثيقتين السابقتين مقابل الكود وقاعدة البيانات الحية.
> **يكمّل:** [`ROSHAN_DEEP_RESEARCH_AND_ROADMAP.md`](./ROSHAN_DEEP_RESEARCH_AND_ROADMAP.md) و[`ROSHAN_SOURCE_CODE_COMPARISON.md`](./ROSHAN_SOURCE_CODE_COMPARISON.md) و[`SUPABASE_ADVISOR_TRIAGE_2026-10-18.md`](./SUPABASE_ADVISOR_TRIAGE_2026-10-18.md).
> **طريقة العمل:** كل ما في القاعدة الحية قُرئ بـ SELECT فقط (لم يُنفَّذ أي تعديل). كل SQL مقترح هنا **توصية غير مُطبَّقة**؛ يُجرَّب أولاً على فرع/بيئة PG17 معزولة.

## 0. الملخص التنفيذي

1. **الوضع الأمني الفعلي أقوى مما توحي به تحذيرات المستشار:** الدوال الـ22 (22 توقيعاً قابلاً للتنفيذ من `authenticated`) كلها `SECURITY DEFINER` مع `search_path=""`، ولا يملك `anon` ولا `PUBLIC` صلاحية تنفيذها، وكلها تتحقق من الصلاحية (`app_has_perm`) و21 منها تتحقق من المستخدم النشط. التحذير 0029 هنا **وصف لعقد RPC مقصود**، لا ثغرة؛ سحب `EXECUTE` عن `authenticated` سيعطّل التطبيق بالكامل.
2. **الثغرات الحقيقية ليست في الـ22 تحذيراً بل حولها** (القسم 3): مسار صرف قديم لا يزال مفتوحاً (`fn_dispense_prescription`)، كتابة مباشرة على `lab_order_items` و`medical_certificates` حتى تطبيق Phase 30، مساعدات الهوية تتجاهل `deleted_at`، لا قيد تفرّد على مطالبات التأمين لكل فاتورة، ولا قيد تفرّد على `patients.national_id`.
3. **الترحيلات:** السجل الحي فيه **109** إدخالات (آخرها `20261018065708`)، بينما وثائق المستودع تقول 97 (و93 و79) — **الوثائق متأخرة بـ12+ إدخالاً**، و30 إدخالاً جاء بعد 2026-10-15. لا يوجد مجلد `supabase/` ولا خط أساس (baseline) قابل لإعادة التشغيل. الخطة في القسم 5.
4. **المنطق السريري هو الفجوة الأكبر التي أغفلها التقرير السابق** (القسم 2): لا آلة حالات للمختبر في القاعدة، شهادة طبية بلا ربط بزيارة وبلا تحقق من أن المُصدِر طبيب، وإنهاء الاستشارة كتابتان منفصلتان من المتصفح.

## 1. ما أصاب فيه التقرير السابق وما فاته

**أصاب فيه:** تشخيص أن الهجرات غير قابلة لإعادة البناء؛ نمط RPC-only للكتابات المالية والسريرية (Phase 19/27/28/29/30)؛ ضرورة فحص كل توقيع بدل السحب الشامل؛ الحذر من نقل `pg_trgm` دون بيئة اختبار؛ ملاحظة أن لا مقارنة مع أنظمة مبنية على Supabase.

**فاته أو لم يتعمق فيه:**

| # | الموضوع | الحقيقة المتحقق منها |
|---|---|---|
| 1 | FORCE RLS على 44/56 جدولاً | ليس فجوة فعلية: مالك الدوال `postgres` (BYPASSRLS)، فـ FORCE على الجداول الـ12 المتبقية شكلي. الحماية الفعلية = حدود `GRANT` + سياسات + RPC. |
| 2 | أثر `pg_trgm` في `public` | الأثر الحقيقي: دوال الامتداد (~40) قابلة للاستدعاء من `anon` عبر PostgREST. في `db/` و`src/` لا استخدام لـ `similarity()` أو عامل `%` (فقط فهرس `gin_trgm_ops` على `patients.full_name`)، والفهرس يعمل بـ operator class لا بـ `search_path`. النقل مرجّح أن يكون آمناً — بشرط فحص `docs/recovered-migrations/sql` أيضاً وتجربته على فرع. |
| 3 | `fn_dispense_prescription(uuid)` القديمة | لا تزال قابلة للتنفيذ من `authenticated` (Phase 17 غير مطبّق حياً)، وتسمح بصرف مخزون **بلا فاتورة**. |
| 4 | DML المباشر على `lab_order_items` و`medical_certificates` | مفتوح حتى Phase 30 (مشروط بنشر الواجهة). |
| 5 | مساعدات الهوية | `private.current_app_user_id` و`private.app_has_perm` لا يفحصان `users.deleted_at`، ولا `ORDER BY` مع `LIMIT 1`. |
| 6 | `insurance_claims` | لا قيد تفرّد لكل `invoice_id` → مطالبات مكررة ممكنة. |
| 7 | `patients.national_id` | غير فريد → تكرار سجلات مرضى. |
| 8 | دقة المبالغ | `post_cashbox_entry` و`post_supplier_payment` بلا فحص (منتهٍ/منزلتان عشريتان) بخلاف `post_expense` و`update_insurance_claim_status`. |
| 9 | عدم تعديل الصندوق | يعتمد على GUC `roshan.cashbox_write` — هش لأن أي دالة definer أخرى تضبطه تتجاوز الحماية. |
| 10 | حالات المختبر/الوصفات | لا قيود CHECK على أعمدة `status` → آلات الحالات غير مفروضة في القاعدة. |
| 11 | جدول idempotency | `private.billing_rpc_idempotency` مفتاحه `request_id` عالمي وغير مرتبط بالفرع (الحماية الفعلية: مقارنة `actor_id` والحمولة). |
| 12 | سياسة `stock_movements_select` | `TO public` (ليست `authenticated`). |
| 13 | Storage / Realtime | فارغان تماماً (0 buckets، 0 جداول في `supabase_realtime`) → لا مسار آمن لتقارير المختبر/الشهادات ولا إشعارات. |

## 2. المنطق السريري والفوترة والصيدلية والمختبر (من الكود الحي)

**المختبر.** `src/lib/lab-workflow.ts` يعرّف خمس مراحل (`ordered → sample_collected → in_progress → completed → verified`) لكنها **عرض فقط**. الدالة الحية `complete_lab_order_item(uuid)` (Phase 28) تضبط `status='completed'` مباشرة دون: التحقق من الحالة السابقة، اشتراط وجود نتيجة، ولا يوجد مسار RPC لمرحلة `verified` (المراجعة بتوقيع شخص ثانٍ). أي مستخدم بصلاحية `lab.update` في الفرع يمكنه إكمال بند بلا نتيجة، أو إعادة إكمال بند مُحقَّق. وفي `isAbnormalLabResult` القيمة `0` تُعامل كـ«حد غير مضبوط» (`low !== 0`)، فلا يمكن التعبير عن حد أدنى فعلي صفر — عرض فقط لكنه قد يُخفي شذوذاً.

**الشهادات الطبية.** `create_medical_certificate` تضع `doctor_id` = أي مستخدم يحمل `certificates.create`، دون التحقق أنه طبيب، ودون ربط بزيارة (`visit_id`)، ودون ترقيم أو منع تعديل بعد الإصدار أو سحب. التشخيص نص حر. الشهادة وثيقة ذات أثر قانوني؛ تحتاج: ربطاً بزيارة، تحقق دور الطبيب، رقماً تسلسلياً، وعدم قابلية للتعديل مع سجل إلغاء.

**الاستشارة.** في `ConsultationPage.tsx` إنهاء الزيارة كتابتان منفصلتان من المتصفح: `visits.update(status='completed')` ثم `queue_tickets.update(...)`. فشل الثانية بعد نجاح الأولى يترك تذكرة طابور مفتوحة لزيارة مكتملة. لا فحص لطلبات مختبر/وصفات معلّقة قبل الإنهاء. التوصية: RPC واحد `complete_visit_atomic(p_visit_id)` يقفل الزيارة ويُغلق التذكرة ويفحص المعلّقات في معاملة واحدة. (قراءتي لهذا الملف ركزت على مواضع الكتابة والفوترة؛ لم أراجع كل التبويبات سطراً بسطر.)

**الفوترة.** المسار المُنشِئ للفواتير (`create_billing_invoice_atomic` بنسخته ذات `p_request_id`، و`post_invoice_payment` بـ `_idempotency_key`) ناضج: قفل، idempotency، مقارنة حمولة. الخطر المتبقي في **الواجهة**: يجب توليد `request_id`/`idempotency_key` مرة لكل *نية مستخدم* لا لكل نقرة أو إعادة محاولة (لم أتحقق من مواقع الاستدعاء). وفي `src/lib/db.ts` المساعدات (`rpc`, `useSave`) لا تفرض ذلك. كما أن `useSettings` يقرأ كل `system_settings` من العميل — يجب التأكد أن الجدول لا يحوي أسراراً.

**التأمين.** `update_insurance_claim_status` نموذجية (صلاحية + فرع + آلة حالات + مبلغ محدود)، لكن لا يوجد تفرّد لكل فاتورة ولا فحص تجاوز مجموع المطالبات لقيمة الفاتورة عبر مطالبات متعددة (راجع القسم 4، البند 3).

**الصيدلية.** `fn_dispense_prescription_with_invoice` هو المسار الصحيح؛ القديم `fn_dispense_prescription` يجب إغلاقه (Phase 17). `fn_receive_pharmacy_batch_atomic` فيه idempotency وقفل. غائب كلياً: فحوص أمان دوائي (حساسية، تكرار علاجي، تفاعلات) — فجوة سريرية لا أمنية.

**Phase 20/28 (مقروءان فعلياً):** Phase 20 يضيف تحققاً من تطابق مريض/زيارة وفشل مغلق للفرع الفارغ، ويسحب `anon/PUBLIC` عن المساعدات — نمط سليم. Phase 28 يطابق السلوك الموصوف أعلاه.

## 3. مقارنة مع Supabase الفعلي (ما تحقّقتُ منه فقط)

| المصدر | ما يوصي به/يفعله | موقع Roshan |
|---|---|---|
| [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) | «A security definer function in an exposed schema is callable over the Data API»؛ `search_path = ''` على كل definer؛ لفّ `auth.uid()` بـ `(select ...)`؛ مفتاح secret يتجاوز RLS فقط بلا توكن مستخدم | Roshan **ملتزم**: `search_path=""` على الـ22، مساعدات في `private`، نمط `(SELECT app_has_perm(..))`. الاختلاف: الدوال العامة الـ47 في `public` (مكشوفة) — مقبول كعقد RPC موثّق. |
| [Basejump](https://github.com/usebasejump/basejump) (migration الحسابات) | مساعدات definer في schema غير مكشوف مع `GRANT EXECUTE` صريح لـ authenticated؛ دوال API في `public`؛ مشغّل يحمي الحقول الحساسة | Roshan **أشد**: Basejump يثبّت `search_path = public` (لا `''`)، ولا `REVOKE` صريح في الملف المفحوص، وبعض دواله بلا `search_path`. Roshan فيه REVOKE/GRANT صريحان وحرّاس super_admin. |
| [Storage access control](https://supabase.com/docs/guides/storage/security/access-control) | RLS على `storage.objects`؛ لا رفع بلا سياسة؛ `storage.foldername(name)` لمجلد المالك؛ الرفع يحتاج INSERT فقط والـ upsert يحتاج SELECT وUPDATE | Roshan بلا buckets؛ التصميم في القسم 6. |
| [Realtime Authorization](https://supabase.com/docs/guides/realtime/authorization) | قنوات خاصة `private: true` + تعطيل الوصول العام؛ سياسات على `realtime.messages` عبر `realtime.topic()`؛ الصلاحيات تُقيَّم عند الانضمام وتُخزَّن حتى انتهاء JWT؛ Postgres Changes تحترم RLS | Roshan بلا Realtime؛ التصميم في القسم 6. |
| [CLI workflows](https://supabase.com/docs/guides/local-development/cli-workflows) | `db pull` الأول ينشئ baseline («This migration is your baseline»)؛ `db reset` يعيد التشغيل من الصفر؛ `db push --dry-run`؛ `db diff` ضد shadow | أساس خطة القسم 5. |

**قيود صريحة على بحثي:** بحث الويب لم يُرجع مشاريع OSS طبية/Enterprise إضافية ذات جودة قابلة للتحقق، وانقطع فحص بيانات مستودعات أخرى (Makerkit وغيره) بسبب حد الجلسة. لذلك **لم أستشهد بأي مشروع لم أفحص ملفه فعلاً**. أمر `supabase migration squash` لم أجد له توثيقاً في الصفحة المفحوصة، فالخطة لا تعتمد عليه. أنصح بجولة لاحقة على: Supabase examples الرسمية، ومستودعات SaaS متعددة المستأجرين بـ pgTAP، قبل تبنّي أي نمط إضافي.

## 4. جدول تدقيق دوال SECURITY DEFINER الـ22

**قاعدة عامة (تحققت منها حياً):** جميعها `search_path=""`، `anon`=لا، `authenticated`=نعم. النسخ القديمة (بلا `request_id`) من `create_billing_invoice_atomic` و`create_lab_order_with_invoice_atomic` سبق سحب `authenticated` عنها؛ التحذيران الباقيان لنسختي `request_id`. **لا تسحب `authenticated`** عن أي منها: الواجهة تستدعيها عبر PostgREST.

**قالب دقة المبلغ** (يُدرَج في بداية الدالة بعد فحص الصلاحية؛ مأخوذ من `update_insurance_claim_status`؛ اجلب النص الكامل بـ `select pg_get_functiondef('public.<fn>(<args>)'::regprocedure)` ثم `CREATE OR REPLACE` بدون المساس بالباقي):

```sql
IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity')
   OR _amount <= 0 OR _amount <> round(_amount, 2) THEN
  RAISE EXCEPTION 'amount must be finite, positive, with at most two decimals' USING ERRCODE = '22023';
END IF;
```

| # | الدالة (التوقيع) | الوظيفة | الخطر الحالي (من فحص الجسم) | التعديل المطلوب |
|---|---|---|---|---|
| 1 | `complete_lab_order_item(uuid)` | إكمال بند فحص | **متوسط (منطقي):** لا فحص حالة سابقة، لا اشتراط نتيجة، لا مرحلة verified | داخل الدالة قبل `UPDATE`: `IF NOT EXISTS (SELECT 1 FROM public.lab_order_items WHERE id=p_order_item_id AND status IN ('ordered','sample_collected','in_progress') AND deleted_at IS NULL) THEN RAISE EXCEPTION 'invalid lab status transition' USING ERRCODE='22023'; END IF;` + اشتراط وجود عمود النتيجة (تحقق من اسم العمود في المخطط). ثم `ALTER TABLE public.lab_order_items ADD CONSTRAINT lab_item_status_chk CHECK (status IN ('ordered','sample_collected','in_progress','completed','verified')) NOT VALID;` ثم `VALIDATE CONSTRAINT`. دالة `verify_lab_order_item` منفصلة بصلاحية `lab.verify` وتمنع أن يكون المُحقِّق هو المُكمِل. |
| 2 | `create_billing_invoice_atomic(…, p_request_id)` | إنشاء فاتورة بـ idempotency | منخفض. صلاحية + قفل + مقارنة حمولة/فاعل. جدول idempotency عالمي غير مقيّد بالفرع؛ رسالة «key reused» تكشف وجود المفتاح (oracle طفيف) | لا تعديل ضروري. اختياري: وظيفة تنظيف دورية لصفوف `private.billing_rpc_idempotency` الأقدم من 30 يوماً. |
| 3 | `create_insurance_claim(uuid,uuid,jsonb,text)` | إنشاء مطالبة تأمين | **متوسط:** لا تفرّد لكل فاتورة؛ لا فحص لمجموع المطالبات مقابل الفاتورة | بعد فحص التكرار: `SELECT invoice_id, count(*) FROM public.insurance_claims WHERE deleted_at IS NULL GROUP BY 1 HAVING count(*)>1;` فإن خلا: `CREATE UNIQUE INDEX CONCURRENTLY insurance_claims_one_open_per_invoice ON public.insurance_claims(invoice_id) WHERE deleted_at IS NULL AND status NOT IN ('rejected');` وإلا فاعالج التكرارات يدوياً أولاً. |
| 4 | `create_lab_order_with_invoice_atomic(…, p_request_id)` | طلب مختبر + فاتورة | منخفض. نفس نمط #2 | لا تعديل. |
| 5 | `create_medical_certificate(uuid,text,date,date)` | إصدار شهادة | **متوسط (قانوني/سريري):** `doctor_id` = أي حامل للصلاحية؛ بلا visit_id، بلا ترقيم، بلا قيد مدة | تحقق من دور المُصدِر: `IF NOT EXISTS (SELECT 1 FROM public.users u JOIN public.roles r ON r.id=u.role_id WHERE u.id=v_user_id AND r.code IN ('doctor','super_admin')) THEN RAISE EXCEPTION 'only a doctor may issue certificates' USING ERRCODE='42501'; END IF;` + سقف مدة (`p_end_date - p_start_date <= 90`) + إضافة عمود `visit_id` اختياري وفحص `v.patient_id = p_patient_id`. |
| 5b | (سؤال قبل التنفيذ) | | | `SELECT r.code, count(*) FROM public.role_permissions rp JOIN public.roles r ON r.id=rp.role_id JOIN public.permissions p ON p.id=rp.permission_id WHERE p.code='certificates.create' GROUP BY 1;` — إن حملها غير الأطباء فالبند 5 إلزامي. |
| 6 | `create_patient_atomic(text,text,date,text,text)` | تسجيل مريض | **متوسط:** `national_id` غير فريد؛ قفل استشاري موجود | بعد فحص التكرار: `CREATE UNIQUE INDEX CONCURRENTLY patients_national_id_uq ON public.patients(national_id) WHERE national_id IS NOT NULL AND national_id <> '' AND deleted_at IS NULL;` (جزئي لأن الرقم الوطني كثيراً ما يكون غائباً في السودان). |
| 7 | `create_prescription_atomic(uuid,boolean,jsonb)` | إنشاء وصفة | منخفض أمنياً؛ **فجوة سريرية:** لا حساسية/تكرار/تفاعلات/جرعة | لا SQL أمني. أضف جدول `patient_allergies` وفحصاً تحذيرياً (soft-stop) قبل الحفظ — مرحلة منتج. |
| 8 | `create_visit_consultation_invoice_atomic(uuid,date)` | فاتورة كشف | منخفض. لا فحص فرع صريح في جسمها؛ يُفوَّض إلى `private.create_or_append_visit_invoice_atomic` | **تحقق** (لا تعدّل): اختبار تراجعي بمستخدم فرع ب على زيارة فرع أ يجب أن يفشل. إن نجح فأضف `IF NOT private.app_has_visit_branch_access(p_visit_id)` (اسم المساعد حسب الموجود فعلاً). |
| 9 | `fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric)` | حساب التغطية | منخفض (حساب + صلاحية + فرع) | أضف فحص دقة `_gross_amount` بالقالب أعلاه إن لم يكن موجوداً. |
| 10 | `fn_dispense_prescription(uuid)` | **قديمة:** صرف بلا فاتورة | **عالٍ:** استنزاف مخزون بلا إيراد | طبّق `db/roshan_phase17_revoke_legacy_dispense_rpc.sql`: `REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid) FROM PUBLIC, anon, authenticated;` **شرط مسبق:** `grep -rn "fn_dispense_prescription\b" src` لا يُرجع شيئاً غير `_with_invoice`. |
| 11 | `fn_dispense_prescription_with_invoice(uuid,boolean)` | الصرف الصحيح مع فاتورة | منخفض؛ أقفال موجودة؛ بلا `request_id` | اختبار تزامن: نقرتان متزامنتان يجب أن تُصرفا مرة واحدة (حالة الوصفة تُقفل `FOR UPDATE`). |
| 12 | `fn_receive_pharmacy_batch_atomic(…)` | استلام دفعة | منخفض (idempotency + قفل + فرع) | لا تعديل. |
| 13 | `get_my_app_profile()` | ملف المستخدم الحالي | منخفض (بلا صلاحية بالتصميم؛ تعيد بيانات المستدعي فقط) | تأكد أنها تستخدم `private.current_app_user_id()` (بعد إصلاح deleted_at أدناه). |
| 14 | `get_visit_form_options()` | خيارات نموذج الزيارة | منخفض (صلاحية + فرع) | لا تعديل. |
| 15 | `post_cashbox_entry(…)` | قيد صندوق | **متوسط:** لا فحص دقة المبلغ؛ GUC للتجاوز | القالب أعلاه على `_amount`. |
| 16 | `post_expense(…)` | مصروف | منخفض (الدقة أُصلحت في ترحيلات 20261017) | لا تعديل. |
| 17 | `post_insurance_claim_payment(…)` | دفعة مطالبة | منخفض (قفل + فرع) | تحقق أن مجموع الدفعات ≤ `approved_amount` (اختبار). |
| 18 | `post_invoice_payment(…, _idempotency_key)` | دفعة فاتورة | منخفض (idempotency + قفل) | لا تعديل. |
| 19 | `post_supplier_bill(…)` | فاتورة مورد | منخفض–متوسط: لا قفل/idempotency ظاهر | `SELECT conname FROM pg_constraint WHERE conrelid='public.supplier_bills'::regclass AND contype='u';` فإن غاب تفرّد `(supplier_id, invoice_number)`: `CREATE UNIQUE INDEX CONCURRENTLY supplier_bills_supplier_invoice_uq ON public.supplier_bills(supplier_id, invoice_number) WHERE deleted_at IS NULL;` (تأكد من اسم الجدول والعمود أولاً). |
| 20 | `post_supplier_payment(…)` | دفعة مورد | **متوسط:** لا فحص دقة | القالب أعلاه على `_amount`. |
| 21 | `reverse_cashbox_entry(uuid,text)` | عكس قيد | متوسط: يضبط GUC للتجاوز (هش) | اجعل GUC محلياً للمعاملة `set_config('roshan.cashbox_write','on',true)` وتأكد أنه يُعاد لـ `off` في النهاية؛ الأفضل استبدال GUC بعمود `reversal_of` وسياسة مشغّل تسمح فقط بإدراج صف عكسي. |
| 22 | `update_insurance_claim_status(…)` | تغيير حالة مطالبة | منخفض: صلاحية + فرع (`app_has_claim_branch`) + آلة حالات + مبلغ محدود | لا تعديل. هي النموذج المرجعي لبقية الدوال. |

### إصلاح مساعدات الهوية (مهم، يؤثر على كل الدوال)

```sql
CREATE OR REPLACE FUNCTION private.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
  SELECT u.id FROM public.users u
  WHERE u.auth_user_id = auth.uid()
    AND COALESCE(u.active, true) = true
    AND u.deleted_at IS NULL
  ORDER BY u.id LIMIT 1
$$;
-- وفي private.app_has_perm أضف: AND u.deleted_at IS NULL داخل EXISTS
CREATE UNIQUE INDEX CONCURRENTLY users_auth_user_active_uq
  ON public.users(auth_user_id) WHERE deleted_at IS NULL AND auth_user_id IS NOT NULL;
```
(قبل التطبيق: `SELECT auth_user_id, count(*) FROM public.users WHERE deleted_at IS NULL GROUP BY 1 HAVING count(*)>1;` يجب أن يكون فارغاً. وحافظ على نفس خصائص الدالة الحالية — اجلبها بـ `pg_get_functiondef` وعدّل الشرط فقط.)

### حارس CI يمنع تراجع الوضع (يفشل إذا رجع شيء غير مقصود)

```sql
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','private') AND p.prosecdef
  AND ( coalesce(p.proconfig::text,'') NOT LIKE '%search_path=%'
        OR has_function_privilege('anon', p.oid, 'execute')
        OR EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                   WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE') );
-- المتوقع: صفر صفوف (باستثناء دوال pg_trgm حتى تُنقل)
```

## 5. خطة توحيد الترحيلات الـ109

**الحقيقة الحالية:** السجل الحي 109 (من `20260818162003` إلى `20261018065708`). `docs/recovered-migrations` يغطي 79 إدخالاً (74 ملف SQL + المنقّح)؛ و`db/` يغطي الأحدث. لا baseline، ولا `supabase/migrations`. أقدم إدخال حي ليس بداية المخطط — **المخطط الأصلي قبل `20260818` غير موجود في أي مستودع**، فإعادة تشغيل السلسلة من الصفر مستحيلة نظرياً. لذا الحل = **baseline من القاعدة الحية** لا إعادة تشغيل التاريخ.

1. **تجميد وجرد (يوم 1).** اعتبر السجل الحي مصدر الحقيقة. أنتج `docs/migrations/ledger-manifest.json` (version, name, SHA-256 للنص، المسار المصدر) للإدخالات الـ109، وحدّث `DB_MIGRATION_RECONCILIATION.md` (تقول 97).
2. **Baseline.** من آلة بها `pg_dump` 17: `pg_dump --schema-only --no-owner --no-privileges --schema=public --schema=private` ثم **أضف GRANT/REVOKE صراحة** (لأن `--no-privileges` يحذفها) عبر `pg_dump` بدونه أو عبر سكربت يُصدّر `proacl/relacl`. الناتج: `supabase/migrations/20261018000000_baseline.sql`. لا تحتوي أي بيانات.
3. **فصل البيانات المرجعية.** `supabase/seed.sql` يحوي فقط `roles`, `permissions`, `role_permissions`, الإعدادات غير السرية. **لا هويات ولا بريد/UUID** (الترحيل المنقّح `20260818191254` يبقى خارج السلسلة).
4. **الامتدادات.** في baseline: `CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;` ليطابق الحي الآن. نقله إلى `extensions` ترحيل لاحق مستقل (`ALTER EXTENSION pg_trgm SET SCHEMA extensions;`) بعد اختباره على فرع وفحص أن لا استدعاء `similarity()` غير مؤهَّل في `recovered-migrations/sql`.
5. **تسوية السجل الحي** (على staging أولاً): تعليم الـ109 القديمة كـ`reverted` وتعليم baseline كـ`applied` عبر `supabase migration repair` (أمر أعرفه من CLI لكن لم أتحقق منه في هذه الجلسة — راجع `supabase migration repair --help`). لا تُنفَّذ على الإنتاج قبل نجاح الخطوة 6.
6. **التحقق (CI على PG17).** (أ) `supabase start` أو PG17 + أدوار `anon/authenticated/service_role` + مخطط `auth` مبسّط يوفّر `auth.uid()`؛ (ب) `supabase db reset` ينجح؛ (ج) مقارنة المخطط المُعاد بناؤه بالحي: `pg_dump --schema-only` للطرفين، تطبيع، `diff` يجب أن يكون فارغاً (أو قائمة استثناءات مكتوبة)؛ (د) تشغيل `db/tests/*` + اختبار مصفوفة دور×عملية (anon/receptionist/doctor/lab_tech/pharmacist/admin × عمليات RPC الـ22 وDML المباشر) + حارس CI في القسم 4.
7. **ترتيب الترحيلات المعلّقة فوق baseline:** (1) Phase 17 (سحب الصرف القديم) → (2) إصلاح الهوية و`deleted_at` → (3) قيود التفرّد (القسم 4: #3, #6, #19) بعد تنظيف التكرارات → (4) قيود CHECK للحالات `NOT VALID` ثم `VALIDATE` → (5) Phase 30 **بعد** نشر الواجهة التي لا تكتب مباشرة → (6) نقل pg_trgm.
8. **انضباط مستقبلي:** كل تغيير = ملف واحد في `supabase/migrations` بطابع زمني؛ ممنوع التطبيق الحي عبر لوحة SQL؛ كل PR يشغّل (6).

## 6. تصميم Storage وRealtime (مقترح؛ غير مطبّق)

**Storage — تقارير المختبر والشهادات والمرفقات.**
- Buckets خاصة: `lab-reports`, `medical-certificates`, `clinical-attachments` (`public=false`).
- مسار الكائن: `{branch_id}/{patient_id}/{uuid}.pdf`؛ سياسة القراءة على `storage.objects` تستخدم `(storage.foldername(name))[1]::uuid` مع `private.app_has_branch_access(...)` و`(select private.app_has_perm('lab.view'))` — نفس مساعدات RLS الحالية، دون منطق جديد.
- **الكتابة لا تتم من العميل مباشرة:** رفع عبر Edge Function (service key) أو توقيع رفع قصير العمر، ثم RPC `register_attachment(...)` يسجّل صف `clinical_attachments` (RPC-only كبقية الجداول). الشهادة PDF تُولَّد بعد الإصدار وتُخزَّن غير قابلة للاستبدال (لا سياسة UPDATE/DELETE).
- التنزيل بـ signed URL قصير الأجل (دقائق). ملاحظة: صفحة التوثيق المفحوصة لم تغطّ signed URLs؛ راجع صفحتها قبل التنفيذ.

**Realtime — عيادة ↔ مختبر ↔ صيدلية.**
- قنوات خاصة `private:true` بأسماء `branch:{branch_id}:lab|pharmacy|clinic`، مع تعطيل الوصول العام، وسياسة SELECT على `realtime.messages` تستند إلى `realtime.topic()` وفحص الفرع والصلاحية.
- بديل أبسط موثّق: Postgres Changes على `lab_order_items` و`prescriptions` (تحترم RLS) بعد إضافتهما إلى publication `supabase_realtime` (الآن فارغ).
- تحذير موثّق: الصلاحيات تُخزَّن عند الانضمام؛ سحب دور مستخدم لا يقطع قناته حتى انتهاء JWT → اجعل عمر JWT قصيراً. إرسال Broadcast من قاعدة البيانات (`realtime.broadcast_changes`) **لم أتحقق منه** في الصفحة المفحوصة.
- تجنّب: الاعتماد على `refetchInterval` الحالي كبديل دائم للإشعارات.

## 7. ما يُنفَّذ فوراً (مرتّب)

1. **Phase 17** (سحب `fn_dispense_prescription`) بعد grep الواجهة — أعلى خطراً وأرخص تنفيذاً.
2. **إصلاح `deleted_at`** في مساعدات الهوية + فهرس التفرّد (القسم 4).
3. **RPC `complete_visit_atomic`** بدل الكتابتين من `ConsultationPage.tsx`.
4. **قالب الدقة** على `post_cashbox_entry` و`post_supplier_payment`.
5. **تشديد الشهادات** (دور طبيب + ربط زيارة + ترقيم).
6. **تفرّد** مطالبات التأمين والرقم الوطني بعد فحص التكرارات.
7. **نشر الواجهة ثم Phase 30.**
8. **baseline + CI PG17** (القسم 5) — يفتح الطريق لكل ما سبق بأمان.
9. تحقق يدوي من **Leaked password protection** في لوحة Auth (لا يُقرأ من SQL).

## 8. حدود هذا التدقيق

- لم أنفّذ أي تعديل حي؛ ولم أُجرِ بعدُ اختبار إعادة بناء PG17 فعلياً.
- قراءة `ConsultationPage.tsx` ركّزت على الكتابة والفوترة؛ لم أراجع مواقع استدعاء RPC لإثبات توليد مفاتيح idempotency صحيحة.
- أسماء بعض الأعمدة/المساعدات في SQL المقترح (نتيجة المختبر، `app_has_visit_branch_access`, `supplier_bills`) تحتاج تأكيداً بالمخطط قبل التنفيذ — أُشير لها في موضعها.
- المقارنة مع مشاريع OSS محدودة بما تحقّقتُ منه (انظر القسم 3).
