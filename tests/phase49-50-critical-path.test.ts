import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
const read=(path:string)=>readFileSync(new URL(path,import.meta.url),"utf8");
const p49=read("../db/roshan_phase49_atomic_pharmacy_dispense.sql");
const p50=read("../db/roshan_phase50_clinical_visit_bill_completion.sql");
const sql=read("../db/tests/phase49_50_critical_path_assertions.sql");
const workflow=read("../.github/workflows/ci-phase49-50-critical-path.yml");
const pharmacy=read("../src/lib/pharmacy.ts");
const route=read("../src/routes/_authenticated/pharmacy.tsx");
const audit=read("../db/reports/audit_aggregate_query.sql");

test("pharmacy RPC is idempotent and branch/expiry safe",()=>{
 assert.match(p49,/CREATE TABLE IF NOT EXISTS private\.pharmacy_dispense_idempotency/);
 assert.match(p49,/CREATE OR REPLACE FUNCTION public\.atomic_pharmacy_dispense/);
 assert.match(p49,/FOR UPDATE/);
 assert.match(p49,/v_existing_payload IS DISTINCT FROM v_payload/);
 assert.match(p49,/result_payload=v_result|result_payload = v_result/);
 assert.match(p49,/fn_dispense_prescription_with_invoice/);
 assert.match(p49,/inv\.expiry_date IS NOT NULL/);
 assert.match(p49,/inv\.branch_id = v_patient_branch/);
 assert.match(pharmacy,/atomic_pharmacy_dispense/);
 assert.match(pharmacy,/p_request_id: requestId/);
 assert.match(route,/crypto\.randomUUID\(\)/);
 assert.match(route,/dispenseRequestIds/);
});
test("stock movement ledger is browser read-only and branch-scoped",()=>{
 assert.match(p49,/REVOKE ALL ON TABLE public\.stock_movements FROM PUBLIC, authenticated/);
 assert.match(p49,/GRANT SELECT ON TABLE public\.stock_movements TO authenticated/);
 assert.match(p49,/CREATE POLICY stock_movements_select[\s\S]*TO authenticated/);
 assert.match(p49,/private\.app_has_branch_access\(stock_movements\.branch_id\)/);
});
test("visit completion bills first and aligns queue timestamps",()=>{
 assert.match(p50,/create_visit_consultation_invoice_atomic/);
 assert.match(p50,/FOR UPDATE OF v,p/);
 assert.match(p50,/visit_patient_branch_mismatch/);
 assert.match(p50,/UPDATE public\.visits/);
 assert.match(p50,/UPDATE public\.queue_tickets/);
 assert.match(p50,/completed_at=v_completed_at/);
 assert.match(p50,/complete_visit_atomic\(p_visit_id uuid\)/);
 assert.match(sql,/idempotent retry did not replay the exact two FEFO batch movements/);
 assert.match(sql,/expired-only medicine was dispensed/);
 assert.match(sql,/consultation and pharmacy invoice totals did not reconcile/);
 assert.match(sql,/visit and queue completion states\/timestamps are inconsistent/);
});
test("audit aggregate exposes counts, not raw clinical snapshots",()=>{
 assert.match(audit,/count\(\*\) AS event_count/);
 assert.match(audit,/count\(DISTINCT s\.record_id\)/);
 assert.doesNotMatch(audit,/SELECT\s+.*old_data|SELECT\s+.*new_data/i);
});
test("critical path runs on disposable PostgreSQL 17 only",()=>{
 assert.match(workflow,/image: postgres:17/);
 assert.match(workflow,/db\/baseline\/0000_roshan_pg17_baseline_v112\.sql/);
 assert.match(workflow,/phase49_50_critical_path_assertions\.sql/);
 assert.doesNotMatch(workflow,/jewzonxplxhogqrnhosl|SUPABASE_SERVICE_ROLE_KEY|DATABASE_URL/);
});
