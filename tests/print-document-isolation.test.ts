import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const read = (path) => readFileSync(join(root, path), "utf8");

test("certificate print action selects and prints exactly one persisted certificate", () => {
  const source = read("src/routes/_authenticated/certificates.tsx");
  assert.match(source, /printingCertificateId/);
  assert.match(source, /rows\.find\(\(row\) => s\(row, "id"\) === printingCertificateId\)/);
  assert.match(source, /handlePrintCertificate\(s\(c, "id"\)\)/);
  assert.match(source, /flushSync/);
  assert.doesNotMatch(source, /onClick=\{\(\) => window\.print\(\)\}/);
  assert.match(source, /afterprint/);
  assert.match(source, /print-only/);
  assert.match(source, /certificateBranchId\(selected\)/);
  assert.match(source, /deleted_at/);
  assert.match(source, /print-target-scope-active/);
  assert.match(source, /id="medical-certificate-print-document"/);
  assert.match(source, /!certificateBranchId\(c\)/);
});

test("invoice print boundary excludes all non-document controls and uses canonical center settings", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(source, /print-document-root/);
  assert.match(source, /targetId="invoice-print-document"/);
  assert.match(source, /canPrintInvoice/);
  assert.match(source, /invoicePatientBranchMismatch/);
  assert.match(source, /branch_id, deleted_at, patients\(id, full_name, mrn, phone, branch_id, deleted_at\)/);
  assert.match(source, /className="no-print space-y-4"/);
  assert.match(source, /settings\["center_name"\]/);
  assert.match(source, /settings\["center_name_ar"\]/);
  assert.match(source, /settings\["address"\]/);
  assert.match(source, /settings\["phone"\]/);
  assert.doesNotMatch(source, /settings\["clinic_(name|address|phone)"\]/);
  const printRoot = source.slice(
    source.indexOf("print-document-root"),
    source.indexOf("</Card>", source.indexOf("print-document-root")),
  );
  assert.match(printRoot, /s\(invoice, "invoice_number"\)/);
  assert.match(printRoot, /s\(patient, "full_name"\)/);
  assert.match(printRoot, /settings\["invoice_footer"\]/);
});

test("print-only certificate content is hidden on screen and displayed only for print", () => {
  const css = read("src/styles.css");
  const kit = read("src/components/kit.tsx");
  assert.match(kit, /scoped\?: boolean/);
  assert.match(kit, /print-scope-active/);
  assert.match(css, /body\.print-target-scope-active \.print-document-root\.print-target-active/);
  assert.match(css, /\.print-only\s*\{[^}]*display:\s*none/s);
  assert.match(css, /@media print[\s\S]*?\.print-only\s*\{[^}]*display:\s*block/s);
  assert.match(css, /body\.print-scope-active \*\s*\{[^}]*visibility:\s*hidden/s);
  assert.match(
    css,
    /body\.print-scope-active \.print-document-root,\s*body\.print-scope-active \.print-document-root \*/,
  );
});

test("prescription print action reads only the selected persisted order and blocks incomplete copies", () => {
  const source = read("src/features/clinic/consultation/components/PrescriptionTab.tsx");
  assert.match(source, /buildPrescriptionPrintModel\(savedPrescription, visitBranch\)/);
  assert.match(source, /\.eq\("branch_id", visitBranch\)/);
  assert.match(source, /lastSavedPrescriptionId/);
  assert.match(source, /\.eq\("visit_id", visitId\)/);
  assert.match(source, /\.eq\("patient_id", patient\)/);
  assert.match(source, /prescriptionPrintModel\?\.complete/);
  assert.match(source, /targetId="prescription-print-document"/);
  assert.match(source, /savedPrescriptionQ\.error/);
  assert.doesNotMatch(source, /window\.print\(\)/);
});

test("scoped prescription printing isolates one print-document-root target", () => {
  const kit = read("src/components/kit.tsx");
  const css = read("src/styles.css");
  assert.match(kit, /targetId\?: string/);
  assert.match(kit, /print-target-active/);
  assert.match(css, /body\.print-target-scope-active \.print-document-root\.print-target-active/);
  assert.match(
    css,
    /body\.print-target-scope-active \.print-document-root\.print-target-active,\s*body\.print-target-scope-active \.print-document-root\.print-target-active \*/,
  );
});

test("clinical document print stylesheet explicitly requests A4 paper", () => {
  const css = read("src/styles.css");
  const pageRule = css.match(/@page\s*\{([^}]*)\}/s);
  assert.ok(pageRule, "clinical print stylesheet must define a page rule");
  assert.match(pageRule[1], /(?:^|\s)size:\s*A4\s*;/);
  assert.match(pageRule[1], /margin:\s*12mm\s*;/);
});
