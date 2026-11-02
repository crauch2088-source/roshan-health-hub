# Phase 52 — Reporting & analytics foundation

**Status:** source candidate, not applied to QA or production.  
**Branch:** `feat/phase52-reporting-analytics-20261102`

## Scope delivered

- Bounded, branch-aware, read-only aggregate RPC `public.get_reporting_analytics(date,date,uuid)`.
- KPI totals for visits/completion/cancellation/consultation fees, payments, expenses/net cashflow, lab orders/items/revenue, insurance claim submitted/approved/paid totals, prescriptions, dispensed units and write-offs.
- Monthly visit, collection and expense series plus top-20 department, doctor, test and diagnosis breakdowns.
- `/reports` now consumes the aggregate RPC rather than downloading raw visit, diagnosis and lab-item rows for the report view. CSV export contains summary aggregates and monthly aggregate rows.
- Date range validation is inclusive and capped at 366 days. The SQL uses Africa/Khartoum calendar-day boundaries.
- Arabic/English labels for new metrics.

## Database contract

### Migration

`db/roshan_phase52_reporting_analytics.sql`

### RPC

`public.get_reporting_analytics(p_from_date date, p_to_date date, p_branch_id uuid DEFAULT NULL) RETURNS jsonb`

- Requires an authenticated Supabase identity and `reports.read`.
- Rejects null, reversed or over-366-day date windows.
- Validates explicitly requested branch access using `private.app_has_branch_access`.
- Runs as **STABLE SECURITY INVOKER** with an empty fixed `search_path`; underlying source-table RLS remains effective.
- EXECUTE: authenticated only. PUBLIC, anon and service_role are revoked.
- Returns aggregates only; no patient names/IDs, notes, invoice numbers, raw diagnoses linked to people, or row-level clinical payloads.
- No table, trigger or persistent data structure is added. No writes are performed.

### Response shape

```ts
{
  period: { from, to, branch_id },
  summary: {
    visits, completed_visits, cancelled_visits, consultation_revenue,
    payments_collected, operating_expenses, net_cashflow,
    lab_orders, lab_items, lab_revenue,
    insurance_claims, insurance_submitted, insurance_approved, insurance_paid,
    prescriptions, dispensed_prescriptions, dispensed_units, writeoff_units
  },
  monthly: [{ month, visits, payments, expenses }],
  by_department: [{ name, count }],
  by_doctor: [{ name, count }],
  by_test: [{ name, name_ar, count }],
  by_diagnosis: [{ name, count }]
}
```

## Source paths

- `src/lib/reporting.ts` — typed response and date-range guard.
- `src/routes/_authenticated/reports.tsx` — aggregate RPC, KPIs, monthly table and CSV exports.
- `src/lib/i18n.tsx` — Arabic/English labels.
- `tests/phase52-reporting-analytics.test.ts` — source contract and range regressions.
- `db/tests/phase52_reporting_analytics_assertions.sql` — PG17 function metadata/ACL/role-denial assertions.
- `.github/workflows/ci-phase52-reporting-analytics.yml` — isolated PostgreSQL 17 forward replay.

## Explicitly excluded

- Thermal/PDF receipt, invoice and prescription templates.
- Inter-branch pharmacy stock transfers.
- Insurance claim lifecycle, payer submission and denial management.
- Production/QA migration application.

These are separate workflows with different correctness and operational requirements. See the Phase 53–56 roadmap in `docs/MASTER_PLAN.md`.

## Release gate

Do not apply this candidate to either live database until:
1. Phase 49/50 are reconciled and tested against the actual schema; current ledgers show they are absent from both environments.
2. Phase 51 is reconciled: QA has it, production does not.
3. Exact-head PG17 and full GitHub CI pass.
4. Security review confirms all underlying source-table RLS policies and branch scope remain effective for reports.read users.
5. A logical backup, off-site copy and successful restore rehearsal are evidenced before production DDL.
6. Authenticated QA smoke test confirms totals against independently reconciled synthetic fixtures.

The current UI passes `p_branch_id: null`, leaving row visibility to RLS. The RPC supports an explicit branch argument for a future authorized branch selector; no new branch-picker UI is added in this phase.
