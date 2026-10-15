import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const sql = readFileSync(
  new URL("../db/roshan_phase13_consolidated_visit_invoice.sql", import.meta.url),
  "utf8",
);
const visits = readFileSync(
  new URL("../src/routes/_authenticated/visits.tsx", import.meta.url),
  "utf8",
);
const consultation = readFileSync(
  new URL("../src/features/clinic/consultation/ConsultationPage.tsx", import.meta.url),
  "utf8",
);
const laboratory = readFileSync(
  new URL("../src/features/clinic/consultation/components/LaboratoryTab.tsx", import.meta.url),
  "utf8",
);

test("visit invoice consolidation has explicit primary/secondary model and least-privilege RPCs", () => {
  assert.match(sql, /ADD COLUMN IF NOT EXISTS is_primary boolean NOT NULL DEFAULT true/);
  assert.match(sql, /CREATE UNIQUE INDEX uq_invoices_visit_id[\s\S]*is_primary IS TRUE/);
  assert.match(sql, /public\.app_has_perm\('visits\.create'\)/);
  assert.match(sql, /public\.app_has_perm\('lab\.create'\)/);
  assert.match(sql, /public\.app_has_perm\('billing\.create'\)/);
  assert.match(sql, /SET search_path TO ''/);
  assert.match(sql, /REVOKE ALL ON FUNCTION[\s\S]*FROM anon/);
});

test("visit and consultation invoice flows use atomic visit invoice RPC", () => {
  assert.match(visits, /rpc\(\s*"create_visit_consultation_invoice_atomic"/);
  assert.match(consultation, /rpc\(\s*"create_visit_consultation_invoice_atomic"/);
  assert.doesNotMatch(visits, /\.from\("invoices"\)\s*\n\s*\.insert/);
  assert.doesNotMatch(visits, /\.from\("invoice_items"\)\.insert/);
  assert.doesNotMatch(consultation, /\.from\("invoices"\)\s*\n\s*\.insert/);
  assert.doesNotMatch(consultation, /\.from\("invoice_items"\)\.insert/);
});

test("laboratory order and its invoice items share one transaction", () => {
  assert.match(laboratory, /rpc\(\s*"create_lab_order_with_invoice_atomic"/);
  assert.doesNotMatch(laboratory, /\.from\("invoices"\)\s*\n\s*\.insert/);
  assert.doesNotMatch(laboratory, /\.from\("invoice_items"\)\.insert/);
  assert.match(sql, /CREATE OR REPLACE FUNCTION private\.create_or_append_visit_invoice_atomic/);
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.create_visit_consultation_invoice_atomic/);
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.create_lab_order_with_invoice_atomic/);
});
