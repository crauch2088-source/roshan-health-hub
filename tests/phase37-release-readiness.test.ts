import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("clinical attachment uploader exposes labelled controls, localized direction and live status", () => {
  const uploader = read("../src/components/clinical-attachment-uploader.tsx");
  assert.match(uploader, /htmlFor="clinical-attachment-file"/);
  assert.match(uploader, /id="clinical-attachment-file"/);
  assert.match(uploader, /aria-label=\{arabic \? "اختيار ملف المرفق السريري"/);
  assert.match(uploader, /dir=\{arabic \? "rtl" : "ltr"\}/);
  assert.match(uploader, /type="file"[\s\S]*dir="ltr"/);
  assert.match(uploader, /aria-busy=\{busy\}/);
  assert.match(uploader, /role="alert" aria-live="assertive"/);
  assert.match(uploader, /role="status" aria-live="polite"/);
  assert.match(uploader, /تم رفع المرفق بنجاح/);
  assert.match(uploader, /رفع الملفات الخاص معطل/);
});

test("lab screen keeps medical values LTR and communicates clinical warnings accessibly", () => {
  const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
  assert.match(lab, /dir="ltr"/);
  assert.match(lab, /role="status"[\s\S]*aria-live="polite"/);
  assert.match(lab, /role="alert"/);
  assert.match(lab, /لا توجد مديات مرجعية معتمدة لبعض الفحوص/);
  assert.match(lab, /راجع القيم وسياق المريض قبل اعتماد النتائج/);
  assert.match(lab, /<ClinicalAttachmentUploader/);
  assert.match(lab, /perm="lab.read"/);
});

test("medical certificate UI preserves authenticated access, Arabic wording and LTR identifiers", () => {
  const certificates = read("../src/routes/_authenticated/certificates.tsx");
  assert.match(certificates, /perm="certificates.read"/);
  assert.match(certificates, /dir="ltr"/);
  assert.match(certificates, /تم إصدار الشهادة/);
  assert.match(certificates, /اختر الزيارة المرتبطة بالشهادة/);
  assert.match(certificates, /<ClinicalAttachmentUploader/);
  assert.match(certificates, /window\.print\(\)/);
});

test("consultation workflow exposes accessible tabs, errors, LTR clinical identifiers and clear Arabic states", () => {
  const consultation = read("../src/features/clinic/consultation/ConsultationPage.tsx");
  assert.match(consultation, /dir="auto"/);
  assert.match(consultation, /role="tablist"/);
  assert.match(consultation, /aria-label=/);
  assert.match(consultation, /aria-controls=/);
  assert.match(consultation, /role="alert"/);
  assert.match(consultation, /dir="ltr"/);
  assert.match(consultation, /تم إنشاء الفاتورة/);
  assert.match(consultation, /تم إنهاء الزيارة/);
});

test("queue, pharmacy and billing keep machine-readable values LTR and retain labelled status controls", () => {
  const queue = read("../src/routes/_authenticated/queue.tsx");
  const pharmacy = read("../src/routes/_authenticated/pharmacy.tsx");
  const billing = read("../src/routes/_authenticated/billing.tsx");
  assert.match(queue, /dir="ltr"/);
  assert.match(queue, /aria-label=/);
  assert.match(queue, /الطابور فارغ حالياً/);
  assert.match(pharmacy, /dir="ltr"/);
  assert.match(pharmacy, /aria-label=/);
  assert.match(pharmacy, /فاتورة الزيارة/);
  assert.match(billing, /dir="ltr"/);
  assert.match(billing, /aria-label=/);
  assert.match(billing, /فاتورة مستقلة/);
});
