# Roshan Health Hub — Verified Execution Ledger

Last verified: 2026-10-18 08:40 UTC
Repository: `crauch2088-source/roshan-health-hub`
Canonical production URL: https://roshan-health-hub.vercel.app/
Canonical Vercel project: `roshan-health-hub` (team `roshan45`)
Supabase project: `jewzonxplxhogqrnhosl`

## Measurement rules

This ledger intentionally tracks distinct, verifiable release outcomes rather than counting historical plan checkboxes. Each item is counted once. Weights are assigned by impact and risk; completed means evidence exists for the exact scope stated. Documentation is not counted as implementation. A blocked item is not complete. The overall percentage is **not yet published** because the full plan has not yet been reconciled into a deduplicated, weighted set of all workstreams; publishing a partial denominator as a project-wide percentage would be misleading.

## Current verified gates

| ID | Outcome | Weight | Status | Evidence / next gate |
|---|---|---:|---|---|
| DB-29 | Revoke direct DML on prescriptions, prescription_items, patient_discounts, insurance_prior_authorizations while preserving reads/RLS | 5 | Complete in production | Live ledger has 109 entries through `20261018065708_roshan_clinical_child_rpc_only_writes`; documented in `docs/DB_MIGRATION_RECONCILIATION.md`. |
| CI-CLINICAL | PostgreSQL 17 clinical child-RPC regression runs when the lab-completion/certificate frontend or related contract tests change | 4 | Workflow change merged; regression passed on tested SHA | [Commit 84c3d1f](https://github.com/crauch2088-source/roshan-health-hub/commit/84c3d1fcef1c6213367e59103204d9c0403fc7d5). Do not infer the full latest-main CI set from this result. |
| DB-30 | Revoke authenticated direct DML on lab_order_items and medical_certificates after RPC frontend is live and smoke-tested | 5 | Blocked / not applied | Live privilege read confirms authenticated INSERT/UPDATE/DELETE still granted on both tables. |
| REL-CANONICAL | Canonical alias serves the latest main with verified application behavior | 5 | Blocked | Current main `6446cd0c76dd71b94f09bd2dadbdffe92b74a489` has a failing Vercel status linking to build-rate-limit; newest READY production deployment observed is `5661f415a5f8ae888195e8a3f58c3f192ed86d4a`. |
| SMOKE-LAB | Synthetic-data end-to-end test of `complete_lab_order_item(uuid)` through the deployed frontend | 4 | Not yet verified | Must run after canonical deployment is current. |
| SMOKE-CERT | Synthetic-data end-to-end test of `create_medical_certificate(uuid,text,date,date)` through the deployed frontend | 4 | Not yet verified | Must run after canonical deployment is current. |
| SEC-ADVISOR | Individually classify SECURITY DEFINER Advisor findings and verify intended callers/authorization | 4 | In progress | Security Advisor currently reports 22 authenticated-callable SECURITY DEFINER findings; no blanket revocation. |
| EXT-PGTRGM | Evaluate moving `pg_trgm` out of `public` with extension/operator/dependency regression tests | 2 | Open / investigation only | Advisor reports one extension-in-public warning. No DDL applied. |
| PERF-INDEX | Review unused-index suggestions against schema, query plans, and workload before any removal | 3 | Open / investigation only | Performance Advisor reports 89 unused-index findings. No indexes dropped. |
| AUTH-LEAKED-PASSWORD | Verify compromised-password protection setting and document its live state | 2 | Open / needs direct setting verification | Advisor reports one warning; no setting change claimed. |
| MIGRATION-PARITY | Verify historical replay and persisted live SQL source parity | 4 | Open / partially evidenced | Ledger count and latest migration verified; full replay and persisted live SQL hash equality remain unproven. |

## Fresh live evidence (read-only)

- Supabase migration ledger: 109 entries, latest version `20261018065708`.
- `complete_lab_order_item(uuid)`: SECURITY DEFINER; fixed empty `search_path`; executable by `authenticated`, not `anon`.
- `create_medical_certificate(uuid,text,date,date)`: SECURITY DEFINER; fixed empty `search_path`; executable by `authenticated`, not `anon`.
- `authenticated` retains INSERT/UPDATE/DELETE on `lab_order_items` and `medical_certificates`; this is the expected pre-Phase-30 state.
- Vercel project metadata identifies the canonical project and verified domain `roshan-health-hub.vercel.app`; a READY deployment exists for commit `5661f415`, but that is not proof that the canonical alias serves the current main.
- Current-main combined status check reports Vercel failure with target URL indicating a build-rate limit. Do not retry deployment until the quota state is freshly checked.
- No production SQL/ACL change, new deployment, quota bypass, or paid upgrade was performed in this verification pass.

## Next actions (ordered)

1. Recheck current main and its exact-head CI checks; distinguish queued/running checks from completed checks.
2. Inspect the current Vercel quota/limit state and canonical alias after the documented reset; do not create another project or upgrade.
3. If deployment is permitted, deploy only through the existing canonical project and verify the official alias resolves to the expected commit.
4. Run both synthetic-data smoke tests through the deployed UI/API and collect evidence.
5. Only after both pass, apply Phase 30 using a reviewed migration with rollback instructions; then verify grants, RLS, function execution, and migration ledger.
6. Continue Advisor triage one finding class/function at a time with behavior tests; never bulk-revoke SECURITY DEFINER routines or drop unused indexes.
7. Reconcile all workstreams from `docs/MASTER_PLAN.md` into this ledger, deduplicate tasks, assign justified weights, and publish a percentage only after the denominator is complete.
