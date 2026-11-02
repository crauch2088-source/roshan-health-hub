import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { isValidReportingRange } from "../src/lib/reporting.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = read("../db/roshan_phase52_reporting_analytics.sql");
const assertions = read("../db/tests/phase52_reporting_analytics_assertions.sql");
const workflow = read("../.github/workflows/ci-phase52-reporting-analytics.yml");
const route = read("../src/routes/_authenticated/reports.tsx");

test("reporting range accepts valid inclusive periods up to 366 days", () => {
  assert.equal(isValidReportingRange("2026-01-01", "2026-12-31"), true);
  assert.equal(isValidReportingRange("2026-02-01", "2026-02-01"), true);
  assert.equal(isValidReportingRange("2026-02-30", "2026-03-01"), false);
  assert.equal(isValidReportingRange("2026-03-02", "2026-03-01"), false);
  assert.equal(isValidReportingRange("2025-01-01", "2026-01-02"), false);
  assert.equal(isValidReportingRange("not-a-date", "2026-03-01"), false);
});

test("Phase 52 reporting RPC is read-only, bounded, branch-aware and RLS-preserving", () => {
  assert.match(migration, /RETURNS jsonb[\s\S]*LANGUAGE plpgsql[\s\S]*STABLE[\s\S]*SECURITY INVOKER/);
  assert.match(migration, /SET search_path TO ''/);
  assert.match(migration, /private\.app_has_perm\('reports\.read'\)/);
  assert.match(migration, /private\.app_has_branch_access\(p_branch_id\)/);
  assert.match(migration, /\x27coverage\x27, pg_catalog\.jsonb_build_object/);
  assert.match(migration, /\x27insurance\x27, private\.app_has_perm\(\x27insurance\.read\x27\)/);
  assert.match(migration, /p_to_date - p_from_date\) > 365/);
  assert.match(migration, /Africa\/Khartoum/);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.get_reporting_analytics\(date, date, uuid\) FROM PUBLIC, anon, service_role/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.get_reporting_analytics\(date, date, uuid\) TO authenticated/);
  assert.doesNotMatch(migration, /INSERT INTO|UPDATE public\.|DELETE FROM/);
  assert.doesNotMatch(migration, /patients\.full_name|clinical_notes|old_data|new_data/);
  assert.match(assertions, /SECURITY INVOKER/);
  assert.match(assertions, /anon unexpectedly executed Phase 52 reporting RPC/);
});

test("Reports page uses bounded aggregate RPC and never exports raw visit rows", () => {
  assert.match(route, /isValidReportingRange\(from, to\)/);
  assert.match(route, /supabase\.rpc\("get_reporting_analytics"/);
  assert.match(route, /p_branch_id: null/);
  assert.match(route, /ExportButtons rows=\{summaryRows\}/);
  assert.match(route, /monthlyRows/);
  assert.match(route, /if \(report\.isLoading\) return <Loading \/>/);
  assert.doesNotMatch(route, /\.from\("visits"\)/);
  assert.doesNotMatch(route, /\.from\("diagnoses"\)/);
  assert.doesNotMatch(route, /\.from\("lab_order_items"\)/);
});

test("Phase 52 PG17 workflow replays Phase 49-51 prerequisites on disposable schema", () => {
  assert.match(workflow, /image: postgres:17/);
  for (const path of [
    "db/baseline/0000_roshan_pg17_baseline_v112.sql",
    "db/roshan_phase49_atomic_pharmacy_dispense.sql",
    "db/roshan_phase50_clinical_visit_bill_completion.sql",
    "db/roshan_phase51_public_setup_required_anon.sql",
    "db/roshan_phase52_reporting_analytics.sql",
    "db/tests/phase52_reporting_analytics_assertions.sql",
  ]) assert.ok(workflow.includes(path), path);
  assert.doesNotMatch(workflow, /jewzonxplxhogqrnhosl|hopfohcnrtbiqjkgeukz|SUPABASE_SERVICE_ROLE_KEY/);
});
