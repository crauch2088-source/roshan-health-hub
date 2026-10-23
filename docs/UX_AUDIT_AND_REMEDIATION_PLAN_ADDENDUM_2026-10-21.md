# ملحق التحسين المتقدم — خطة تدقيق تجربة Roshan Health Hub
**التاريخ:** 2026-10-21  
**الغرض:** تقوية خطة `docs/UX_AUDIT_AND_REMEDIATION_MASTER_PLAN_2026-10-21.md` بآليات تتبع وقياس واختبار أكثر دقة. هذا الملحق مكمّل للخطة الرئيسية وليس دليلًا على أن التدقيق قد أُنجز.

## 1. سجل الافتراضات والقرارات

قبل الفحص، حوّل الافتراضات إلى عناصر قابلة للتحقق. استخدم الحالات `CONFIRMED`, `REJECTED`, `UNKNOWN`, `NOT APPLICABLE`.

| القرار | المطلوب إثباته |
|---|---|
| هوية النشر | SHA المصدر الحالي وSHA النشر المرتبط بالنطاق الرسمي؛ لا يُفترض التطابق |
| بيانات الاختبار | لا كتابة في قاعدة الإنتاج؛ كل E2E الذي يكتب يستخدم بيئة معزولة وبيانات اصطناعية |
| الأدوار | الحساب الإداري لا يثبت سلوك الطبيب أو الاستقبال أو المختبر أو الصيدلية |
| الفروع | اختبر الفرع النشط المعتمد؛ لا تفترض أن فرعًا آخر جاهز للتشغيل |
| التأمين | يبقى خارج نطاق التطوير الحالي ما لم يصدر قرار جديد |
| القواعد السريرية | لا تضف جرعات أو عتبات أو تحذيرات طبية دون مصدر ومراجعة سريرية |
| جلسة QA | سجل وجود جلسة مصرح بها وصلاحيتها دون حفظ أي كلمة مرور أو token |

أي عنصر `UNKNOWN` لا يمكن تحويله إلى PASS. يجب أن ينتج عنه فحص إضافي أو حالة BLOCKED مع خطوة واضحة لرفع العائق.

## 2. نموذج الأولوية القائم على المخاطر

قيّم كل عيب من 1 إلى 5 على ثلاثة محاور: **S** شدة العاقبة، **L** احتمال الحدوث، **E** مدى التعرض (عدد الأدوار/تكرار المهمة/اتساع البيانات). يمكن استخدام `S × L × E` لترتيب قائمة العمل فقط؛ لا يتجاوز قواعد P0/P1 في الخطة الرئيسية.

ارفع إلى مراجعة P0/P1 أي مشكلة قد تسبب:
- إسناد بيانات أو طلب إلى مريض/زيارة خاطئة.
- كشف بيانات صحية أو تجاوز صلاحيات.
- فقدًا صامتًا لملاحظة/نتيجة/وصفة أو إظهار نجاح غير حقيقي.
- تكرار دفعة أو فسادًا ماليًا أو خصم مخزون غير متسق.
- إرسال أمر سريري غير مقصود أو تكرار طلب حساس.

لا تعني قلة الدليل انخفاض الخطورة. سجّل مستوى الثقة في تقدير الاحتمال، وافصل الخطر المحتمل عن العيب المؤكد.

## 3. تتبع كل معيار إلى دليل

لكل شرط قبول، اربطه بملف مصدر، واختبار آلي أو خطوات اختبار يدوي، ومرجع دليل، وSHA محدد. استخدم حالة واحدة فقط:
- `PASS`: يوجد دليل يثبت السلوك.
- `FAIL`: أعيد إنتاج المشكلة.
- `BLOCKED`: يوجد عائق محدد وخطوة لرفعه.
- `NOT TESTED`: لم يُفحص بعد.
- `N/A`: لا ينطبق، مع مبرر.

حقول ملف تغطية مقترحة:

`route_path, component, role, permission, branch, language, direction, viewport_width, viewport_height, theme, browser, source_sha, deployment_sha, state, action, expected, observed, status, evidence_ref, defect_id, retest_sha, tested_at_utc`

لا تترك أي حالة فارغة. لا تستخدم «اختُبر التطبيق» كتغطية بديلة عن توثيق المسارات والأدوار واللغات والعروض.

## 4. تقليل انفجار مصفوفة الاختبار دون إضعاف السلامة

لا تختبر كل التركيبات الممكنة بالتساوي. اعتمد تغطية قائمة على المخاطر:
1. كل مسار: وصول مباشر، refresh، تحميل، فراغ، خطأ، والتسمية الصحيحة.
2. كل دور: المسارات والأفعال المسموحة، وعينة رفض للمحظور.
3. كل فعل حساس: سماح صحيح ورفض من الخادم/RPC/RLS حيث ينطبق.
4. كل شاشة أساسية: 320/360/390/430 CSS px، وRTL/LTR.
5. كل إصلاح: إعادة اختبار العيب الأصلي والسيناريو المجاور المتصل به.
6. يجوز استخدام pairwise للشاشات/التركيبات منخفضة المخاطر؛ لا تقلل التغطية الأساسية لهوية المريض، والأدوية، والنتائج، والصلاحيات، والمال.

## 5. تدقيق سريري أدق — دون إنشاء بروتوكولات جديدة

### هوية المريض
- يظهر معرف ثابت واضح (MRN أو المعرف المعتمد) وسياق المريض/الزيارة قبل أي إجراء مؤثر.
- لا يعتمد تمييز المرضى المتشابهين على الاسم وحده إذا توفر معرف آخر.
- الانتقال لمريض جديد يعيد تهيئة الزيارة والملاحظات والحوارات ونتائج البحث والـcache.
- تأكيدات الإجراءات الحساسة تسمي الكيان المستهدف، لا تستخدم «هل أنت متأكد؟» عامة فقط.

### الطلبات والنتائج
- تُعرض حالة الطلب ومصدره وتاريخه وارتباطه بالزيارة حسب عقد النظام.
- لا تظهر النتيجة «محفوظة» أو «متحققًا منها» قبل تأكيد الخادم.
- لا يُخلط بين قيمة صفرية وقيمة فارغة أو فشل تحميل.
- لا تعرض وحدة أو مجالًا مرجعيًا غير مطابق؛ لا تعتمد على اللون وحده لتوضيح القيم غير الطبيعية.
- إعادة المحاولة لا تنشئ طلبًا مكررًا إذا كان المسار يتطلب idempotency.
- لا تستحدث عتبات نتائج حرجة أو قواعد سريرية لمجرد استكمال الاختبار.

### الوصفات والصرف
- تحقق من عدم قطع اسم الدواء أو التركيز أو الشكل الصيدلاني أو الجرعة أو الطريق أو التكرار أو المدة أو الكمية حيث تتوفر.
- ميّز بين الأدوية المتشابهة والتركيزات المختلفة.
- فشل الصرف أو عدم كفاية المخزون لا يجوز أن يوحي بإتمام الصرف أو يترك خصمًا جزئيًا.
- لا تضف جرعات أو تنبيهات علاجية جديدة دون مصدر موثوق ومراجعة سريرية.

### الحفظ والإغلاق
- ميّز بين المسودة المحفوظة، والتوقيع/التحقق، وإنهاء الزيارة.
- لا يختفي عمل غير محفوظ عند التنقل أو انتهاء الجلسة دون تحذير مناسب.
- لا تستخدم بيانات مرضى حقيقية في لقطات أو traces أو سجلات الاختبار.

## 6. الشبكة غير المستقرة والتعافي

في بيئة اختبار فقط، اختبر:
- بطء القراءة: حالة تحميل واضحة وعدم عرض بيانات قديمة لسياق جديد.
- timeout: رسالة مفهومة وإعادة محاولة، دون spinner دائم.
- انقطاع أثناء الكتابة: عدم الادعاء بالنجاح قبل التأكيد؛ طريقة آمنة للتحقق من نتيجة العملية.
- استجابة قديمة بعد تغيير المريض/الفرع: ألا تستبدل السياق الحالي.
- الضغط المزدوج وإعادة المحاولة: عدم تكرار إجراء حساس.
- انتهاء الجلسة: عدم فقد المسودة بصمت أو إعادة إرسالها إلى مستخدم آخر.
- 401/403/409/422/429/5xx: رسالة مناسبة لا تكشف SQL أو stack trace أو أسرارًا.
- لا تدّع وجود offline mode ما لم يكن مدعومًا فعليًا، ولا تضف تخزينًا محليًا لبيانات صحية ضمن هذه المرحلة.

## 7. الأداء: قياس قبل وبعد

سجّل الجهاز/المتصفح/العرض/اللغة/الدور ونوع الشبكة. قِس زمن الوصول إلى محتوى مفهوم، زمن البحث وفتح الملف، طلبات الشبكة الفاشلة أو المكررة، أخطاء console، وتغير حجم bundle عند تعديل المكونات المشتركة إذا كانت أدوات القياس متاحة بالفعل.

لا تخترع أهدافًا رقمية دون baseline، ولا تضحِّ بصحة البيانات أو الذرية أو وضوح الأخطاء لتحسين رقم الأداء. لا تضف analytics تجمع بيانات صحية؛ أي telemetry يجب أن تكون محدودة وخالية من المعلومات الصحية الشخصية ومتوافقة مع السياسة الحالية.

## 8. خصوصية أدلة QA

- استخدم بيانات اصطناعية معلّمة بوضوح مثل `QA-ONLY`.
- افحص screenshot/trace/video/HAR قبل الرفع بحثًا عن cookies أو tokens أو Authorization headers أو MRN أو أسماء/أرقام حقيقية.
- لا ترفع HAR أو trace خامًا إلى Issue عامة؛ انشر دليلًا منقحًا أو احتفظ به في قناة خاصة مصرح بها.
- لا تسجل أجسام استجابات صحية أو محتوى النماذج في console.
- إذا تعذر تنقيح دليل حساس، لا ترفعه؛ وثّق النتيجة نصيًا بصورة آمنة.

## 9. Definition of Ready / Definition of Done

### قبل بدء إصلاح
- [ ] العيب قابل للإعادة أو المطلب محدد.
- [ ] المتوقع والفعلي والخطورة والنطاق موثقة.
- [ ] SHA المصدر والنشر والبيئة التي ظهر فيها العيب معروفة.
- [ ] اختبار رجوع أو طريقة تحقق محددة قبل تعديل الكود.
- [ ] لا يعتمد الإصلاح على توسيع صلاحية أو تغيير schema غير مصرح به.

### قبل إغلاق إصلاح
- [ ] عولج السبب الجذري.
- [ ] اختبار الرجوع يثبت السلوك المطلوب.
- [ ] نجحت اختبارات المسارات المتصلة ذات المخاطر.
- [ ] فُحصت اللغة/الاتجاه/العرض/الدور المتأثر.
- [ ] لم يتغير عقد RPC/RLS أو قواعد المجال دون مراجعة منفصلة.
- [ ] الدليل مرتبط بـSHA الصحيح.
- [ ] تحديث سجل العيوب والوثائق.
- [ ] لا يسمى العيب Verified قبل إعادة الاختبار؛ بعد الدمج فقط قد يبقى Fixed awaiting verification.

## 10. تقرير نهاية كل دفعة

لكل دفعة إصلاح سجّل: Batch ID، SHA البداية والنهاية، العيوب المغلقة والمفتوحة، السبب الجذري، الملفات المتغيرة، الاختبارات ونتائجها، الأدوار واللغات والمقاسات المعاد فحصها، أثر التغيير الجانبي وكيف استُبعد، حالة CI والنشر، العوائق، والحكم النهائي PASS/FAIL/BLOCKED.

## 11. المراجع الإضافية التي جرى التحقق منها

- **ONC 2025 SAFER Guides** (آخر تحديث للصفحة الجامعة 27 فبراير 2026): https://healthit.gov/clinical-quality-and-safety/safer-guides/  
  مرجع رسمي لسلامة السجلات، تحديد المريض، الطلبات، النتائج، التواصل، وإدارة تعطل النظام.
- **ONC 2025 SAFER — Patient Identification** (آخر تحديث 6 مايو 2026): https://healthit.gov/resources/2025-safer-guide-patient-identification/
- **ONC 2025 SAFER — Test Results Reporting and Follow-Up** (آخر تحديث 28 أبريل 2026): https://healthit.gov/resources/2025-safer-guide-test-results-reporting-and-follow-up/
- **ONC 2025 SAFER — Computerized Provider Order Entry with Decision Support** (آخر تحديث 28 أبريل 2026): https://healthit.gov/resources/2025-safer-guide-computerized-provider-order-entry-with-decision-support/
- **ONC 2025 SAFER — Contingency Planning** (آخر تحديث 6 مايو 2026): https://healthit.gov/resources/2025-safer-guide-contingency-planning/
- **W3C WCAG2Mobile**: https://www.w3.org/TR/wcag2mobile-22/ — توجيه معلوماتي لتطبيق WCAG 2.2 على تطبيقات الهاتف، بما فيها إعادة التدفق وأهداف اللمس وتقليل الإدخال المتكرر.
- **W3C — What's New in WCAG 2.2**: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- **AHRQ — Clinical Decision Support**: https://digital.ahrq.gov/health-it-tools-and-resources/clinical-decision-support-cds

هذه المراجع توجه الفحص ولا تثبت امتثال Roshan أو تمنحه شهادة قانونية/سريرية. أدلة ONC أمريكية وليست تصريحًا بتحقيق المتطلبات التنظيمية في السودان.

## 12. سجل التنقيح الإضافي

- **الجولة 4 — التتبع والمخاطر:** إضافة سجل الافتراضات، معيار الدليل، وطريقة تصنيف الخطورة.
- **الجولة 5 — التغطية والسريرية:** تقوية سيناريوهات هوية المريض، النتائج، الوصفات، والرفض الخلفي.
- **الجولة 6 — الاعتمادية والخصوصية:** إضافة الشبكة غير المستقرة، منع التكرار، خصوصية traces، وReady/Done.
- **الجولة 7 — القياس والتسليم:** فصل المقاييس المقاسة عن التقديرات، وإضافة قالب تقرير لكل دفعة.

هذه جولات تحسين للوثيقة فقط؛ لا تعني أن QA المرئي أو مراجعة الطبيب أو تدفقات E2E قد تمت.

## 13. أول جلسة تنفيذ مقترحة

1. ثبّت SHA الحالي لـ`main` وSHA النشر وحالة CI/PR.
2. استخرج routes الفعلية ومصادرها من الشجرة الحالية.
3. أنشئ سجل تغطية كل حالاته `NOT TESTED` افتراضيًا.
4. حدد المسارات والأفعال الحساسة ومصفوفة الدور/الفعل.
5. اختر أول عيوب قابلة للإعادة ورتبها P0 ثم P1.
6. افحص الاختبارات الموجودة قبل إضافة اعتماد/اختبار جديد.
7. لا تبدأ إصلاحات شكلية واسعة قبل تثبيت الجرد والهوية والدليل.

**معيار النجاح النهائي:** لا يوجد P0 مفتوح؛ لا توجد P1 غير معتمدة؛ كل route معروف له حالة؛ الأدلة صحيحة وخالية من البيانات الحساسة؛ وتكون النتيجة النهائية صريحة PASS أو BLOCKED، لا ادعاءً عامًا بأن «التطبيق مكتمل».


## 14. Reconciliation with current main — 2026-10-23

This is a dated state snapshot, not a claim that the UX release gate has passed.

- Reconciled against `main` at `75161cea594f5541fa31560aa144fc6b03638390` and the canonical production alias `https://roshan-health-hub.vercel.app/`.
- Phases 41 and 42 are merged; Phase 43's audit record is merged; Phase 44 public auth/setup fixes are merged. These code milestones do not by themselves close Issue #95.
- Phase 45 PR #101 remains open with a candidate fix for retry-safe visit/queue completion, plus CI-blocker fixes found while validating the latest source: npm lockfile synchronization, AI assistant TypeScript/prompt formatting, and recursive redaction of direct/internal identifiers from prompt context.
- Isolated PostgreSQL 17 assertions for queue retry repair and timestamp preservation passed on the pre-formatting-fix head. Exact-head CI and focused regression checks must pass on the final candidate SHA before the code milestone is accepted.
- The Phase 45 migration remains **candidate-only and unapplied to production**. No production test records, financial writes, or AI provider calls were used for these changes.
- The only remaining release gate that cannot be completed by source review/CI alone is the authorized comprehensive usability walkthrough: required viewport widths, RTL/LTR, authenticated clinical/role paths, and visual/keyboard evidence. Keep Issue #95 **BLOCKED** until that single end-of-work acceptance session is performed and documented; do not substitute source guards or CI for the human workflow check.
- User-requested execution sequence: finish all code-only work and automated validation first, then run one comprehensive acceptance session with the user/staff rather than repeating partial manual tests after every code change.


## 15. Current status after Phase 45 merge — 2026-10-23

- Phase 45 PR #101 was squash-merged to `main` as `d8f494be773ab766bf6781d4a8297a4d581153e7`. The merged changes include retry-safe visit/queue completion, npm lockfile synchronization, AI assistant TypeScript/lint repairs, and recursive prompt-identifier redaction.
- Exact-head CI passed, including PostgreSQL 17 clinical/security/migration replay suites, the focused insurance-claim UI validation workflow, and the Vercel preview check. Production deployment status was still pending at snapshot time.
- The Phase 45 migration is present in source but remains **unapplied to production**. Read-only Supabase ledger check still showed 115 applied migrations, latest `20261020232033_roshan_phase39_permissions_lab_catalog_and_audit_closure`; no Phase 45 migration or synthetic patient/financial rows were written.
- Issue #95 remains **BLOCKED**. Source-level and automated work is not equivalent to a staff usability acceptance. The outstanding acceptance evidence is the single comprehensive session covering the required viewport widths, RTL/LTR, authenticated clinical/role paths, and visual/keyboard behavior.
- The comprehensive manual session must use an isolated environment with suitable synthetic identities for any write workflow. Do not use production for synthetic clinical, lab, prescription, inventory, or financial transactions, and do not configure or call the AI gateway as part of this test without separate explicit approval.
