import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const prescriptionTab = read("../src/features/clinic/consultation/components/PrescriptionTab.tsx");
const labTab = read("../src/features/clinic/consultation/components/LaboratoryTab.tsx");
const labDetail = read("../src/routes/_authenticated/lab_.$orderId.tsx");
const certificates = read("../src/routes/_authenticated/certificates.tsx");
const phase28 = read("../db/roshan_phase28_clinical_child_write_rpcs.sql");
const phase29 = read("../db/roshan_phase29_clinical_child_rpc_only_writes.sql");

function collectSourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return collectSourceFiles(path);
    return /\.(ts|tsx)$/.test(entry.name) ? [path] : [];
  });
}
const srcRoot = fileURLToPath(new URL("../src/", import.meta.url));
const sourceText = collectSourceFiles(srcRoot)
  .map((path) => readFileSync(path, "utf8"))
  .join("\n");
const directDml = (table: string) =>
  new RegExp('\\.from\\("' + table + '"\\)\\s*\\.(?:insert|update|delete|upsert)\\b', "s");

test("prescriptions and lab orders are created through atomic RPCs", () => {
  assert.match(prescriptionTab, /supabase\.rpc\(["']create_prescription_atomic["']/);
  assert.match(labTab, /supabase\.rpc\(["']create_lab_order_with_invoice_atomic["']/);
  assert.doesNotMatch(sourceText, directDml("prescriptions"));
  assert.doesNotMatch(sourceText, directDml("prescription_items"));
  assert.doesNotMatch(sourceText, directDml("lab_order_items"));
});

test("lab completion and medical certificates use validated RPCs", () => {
  assert.match(labDetail, /supabase\.rpc\(["']complete_lab_order_item["']/);
  assert.match(certificates, /supabase\.rpc\(["']create_medical_certificate["']/);
  assert.doesNotMatch(sourceText, directDml("medical_certificates"));
  assert.doesNotMatch(sourceText, directDml("patient_discounts"));
  assert.doesNotMatch(sourceText, directDml("insurance_prior_authorizations"));
});

test("phase 28 supplies RPCs and phase 29 retires direct client DML", () => {
  assert.match(phase28, /CREATE OR REPLACE FUNCTION public\.complete_lab_order_item/);
  assert.match(phase28, /CREATE OR REPLACE FUNCTION public\.create_medical_certificate/);
  assert.match(phase29, /ON TABLE public\.prescriptions/);
  assert.match(phase29, /public\.medical_certificates/);
  assert.match(phase29, /public\.patient_discounts/);
  assert.match(phase29, /public\.insurance_prior_authorizations/);
});
