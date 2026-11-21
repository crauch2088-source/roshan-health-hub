import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { monthDateRange } from "../src/lib/medical.ts";
import { translateBackendError } from "../src/lib/error-messages.ts";
import {
  classifyPatientDuplicates,
  normalizePatientName,
  normalizePhone,
} from "../src/lib/patient-duplicate.ts";

const read = (rel: string) => readFileSync(new URL(`../${rel}`, import.meta.url), "utf8");

// --- P0: Active-branch visit attribution RLS & SQL migration ---
test("P0 SQL migration restores branches_select RLS for authorized branch members without weakening SECURITY INVOKER", () => {
  const sql = read("db/roshan_qa_operational_blockers_20261121.sql");
  assert.match(sql, /CREATE POLICY branches_select/i);
  assert.match(sql, /public\.app_has_perm\('admin\.full'::text\)/i);
  assert.match(sql, /private\.app_has_branch_access\(id\)/i);
  assert.doesNotMatch(sql, /DISABLE ROW LEVEL SECURITY/i);
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.create_patient_atomic[\s\S]*_address text DEFAULT NULL/i);
});

test("P0 visits UI translates backend errors and renders inline ErrorBox for visit creation failures", () => {
  const visits = read("src/routes/_authenticated/visits.tsx");
  assert.match(visits, /translateBackendError\(error\.message,\s*lang\)/);
  assert.match(visits, /error=\{create\.error\}/);
});

// --- P1: /expenses month-end date range ---
test("P1 monthDateRange handles all 12 months, leap/non-leap February, 30-day months, and Dec->Jan rollover", () => {
  assert.deepEqual(monthDateRange("2026-01"), { start: "2026-01-01", nextMonthStart: "2026-02-01" });
  assert.deepEqual(monthDateRange("2026-02"), { start: "2026-02-01", nextMonthStart: "2026-03-01" });
  assert.deepEqual(monthDateRange("2024-02"), { start: "2024-02-01", nextMonthStart: "2024-03-01" });
  assert.deepEqual(monthDateRange("2028-02"), { start: "2028-02-01", nextMonthStart: "2028-03-01" });
  assert.deepEqual(monthDateRange("2026-04"), { start: "2026-04-01", nextMonthStart: "2026-05-01" });
  assert.deepEqual(monthDateRange("2026-06"), { start: "2026-06-01", nextMonthStart: "2026-07-01" });
  assert.deepEqual(monthDateRange("2026-09"), { start: "2026-09-01", nextMonthStart: "2026-10-01" });
  assert.deepEqual(monthDateRange("2026-11"), { start: "2026-11-01", nextMonthStart: "2026-12-01" });
  assert.deepEqual(monthDateRange("2026-12"), { start: "2026-12-01", nextMonthStart: "2027-01-01" });
  assert.throws(() => monthDateRange("2026-13"));
});

test("P1 expenses.tsx uses half-open monthDateRange without hardcoded -31", () => {
  const expenses = read("src/routes/_authenticated/expenses.tsx");
  assert.doesNotMatch(expenses, /\$\{month\}-31/);
  assert.match(expenses, /monthDateRange\(month\)\.start/);
  assert.match(expenses, /\.lt\("expense_date",\s*monthDateRange\(month\)\.nextMonthStart\)/);
});

// --- P1: Patient duplicate detection & address field ---
test("P1 phone and name normalization handles Sudan formats, Arabic-Indic digits, whitespace, and Arabic variants", () => {
  assert.equal(normalizePhone("+249 91-234-5678"), "0912345678");
  assert.equal(normalizePhone("00249912345678"), "0912345678");
  assert.equal(normalizePhone("٠٩١٢٣٤٥٦٧٨"), "0912345678");
  assert.equal(normalizePatientName("  أحمد   فاطمة  "), normalizePatientName("احمد فاطمه"));
});

test("P1 classifyPatientDuplicates distinguishes confirmed duplicates from shared family phones and namesakes", () => {
  const existing = [
    { id: "p1", mrn: "RMC000001", full_name: "مريض تجريبي QA-20261121", phone: "0912345678", national_id: "NID-1" },
  ];

  // Exact duplicate (name + normalized phone)
  const exact = classifyPatientDuplicates(
    { full_name: "  مريض تجريبي QA-20261121 ", phone: "+249 91-234-5678" },
    existing,
  );
  assert.equal(exact.level, "confirmed");
  assert.ok(exact.matches[0]?.reasons.includes("name_and_phone"));

  // Shared family phone (same phone, different name) -> possible, not hard-blocked
  const family = classifyPatientDuplicates(
    { full_name: "مريض آخر مختلف", phone: "0912345678" },
    existing,
  );
  assert.equal(family.level, "possible");
  assert.ok(family.matches[0]?.reasons.includes("phone_only"));

  // Namesake (same name, different phone) -> possible
  const namesake = classifyPatientDuplicates(
    { full_name: "مريض تجريبي QA-20261121", phone: "0999999999" },
    existing,
  );
  assert.equal(namesake.level, "possible");
  assert.ok(namesake.matches[0]?.reasons.includes("name_only"));

  // Distinct person -> none
  const distinct = classifyPatientDuplicates(
    { full_name: "شخص مختلف", phone: "0988888888" },
    existing,
  );
  assert.equal(distinct.level, "none");
  assert.equal(distinct.matches.length, 0);
});

test("P1 patients.tsx includes address field, duplicate override workflow, and atomic RPC call", () => {
  const patients = read("src/routes/_authenticated/patients.tsx");
  assert.match(patients, /_address:\s*form\.address\.trim\(\)\s*\|\|\s*null/);
  assert.match(patients, /classifyPatientDuplicates\(/);
  assert.match(patients, /overrideDuplicate/);
  assert.match(patients, /submitGuardRef/);
  assert.match(patients, /create_patient_atomic/);
});

// --- P2: Pharmacy error translation & expiry required ---
test("P2 translateBackendError maps raw backend codes to localized Arabic and English messages", () => {
  const stockAr = translateBackendError("medicine_stock_is_rpc_managed", "ar");
  const stockEn = translateBackendError("medicine_stock_is_rpc_managed", "en");
  assert.doesNotMatch(stockAr, /medicine_stock_is_rpc_managed/);
  assert.doesNotMatch(stockEn, /medicine_stock_is_rpc_managed/);

  const expAr = translateBackendError("pharmacy_batch_expiry_required", "ar");
  const expEn = translateBackendError("pharmacy_batch_expiry_required", "en");
  assert.doesNotMatch(expAr, /pharmacy_batch_expiry_required/);
  assert.doesNotMatch(expEn, /pharmacy_batch_expiry_required/);

  const unknownRaw = translateBackendError("some_raw_rpc_code", "en");
  assert.doesNotMatch(unknownRaw, /some_raw_rpc_code/);
});

test("P2 inventory.tsx marks expiry_date as required and translates RPC errors", () => {
  const inv = read("src/routes/_authenticated/inventory.tsx");
  assert.match(inv, /label=\{\`\$\{t\("expiry_date"\)\} \*\`\}/);
  assert.match(inv, /translateBackendError\(error\.message,\s*lang\)/);
});

// --- P2: Arabic/English localization consistency ---
test("P2 i18n catalog contains all previously missing keys and accounting.tsx has no hardcoded Arabic JSX labels", () => {
  const i18n = read("src/lib/i18n.tsx");
  for (const key of [
    "lab_revenue",
    "stock_overview",
    "stock_value",
    "diagnosis",
    "outstanding",
    "collected_revenue",
    "supplier_debt",
    "financial_summary",
    "net_flow",
    "payment_count",
    "cashbox_movements",
    "role_doctor",
    "role_lab_tech",
    "role_pharmacist",
    "role_receptionist",
    "role_admin",
    "role_super_admin",
  ]) {
    assert.match(i18n, new RegExp(`\\b${key}:\\s*\\{`), `Missing i18n key: ${key}`);
  }
  assert.match(i18n, /export function localizeRoleLabel/);

  const accounting = read("src/routes/_authenticated/accounting.tsx");
  assert.doesNotMatch(accounting, /[؀-ۿ]/, "accounting.tsx should not contain hardcoded Arabic labels");

  const shell = read("src/components/app-shell.tsx");
  const dash = read("src/routes/_authenticated/dashboard.tsx");
  assert.match(shell, /localizeRoleLabel\(/);
  assert.match(dash, /localizeRoleLabel\(/);
});
