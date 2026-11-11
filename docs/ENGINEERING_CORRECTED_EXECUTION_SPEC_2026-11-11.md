# Roshan Health Hub — Corrected Engineering Execution Specification
**Date:** 2026-11-11  
**Basis:** Read-only inspection of current `main` at `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`, source SQL, tests, live Supabase migration ledgers and PR/check evidence.  
**Status:** Planning specification only — no implementation or hosted changes authorized by this document.

## 1. Executive decision

Do not execute the external Gemini/Claude worklist literally. Its useful outcomes are retained, but several proposed tasks are stale because the repository already contains the underlying architecture. In particular, do not create `public.medicine_batches`, do not replace the existing receipt path, and do not reimplement FEFO as a new stock subsystem.

The canonical inventory model is already:
- `public.pharmacy_inventory`: batch/lot records, quantities received/remaining, batch and expiry data, supplier, branch, receipt idempotency key.
- `public.stock_movements`: signed movement ledger with batch, reference, branch and actor attribution.
- `public.medicines.stock_quantity`: legacy aggregate maintained in tandem with batch movements; Phase 49 candidate SQL guards direct client edits and treats the aggregate as not branch-owned.
- `public.atomic_pharmacy_dispense(uuid,boolean,uuid)`: atomic, idempotent, branch-safe, expiry-safe, FEFO dispensing coupled to invoice creation.
- `public.fn_receive_pharmacy_batch_atomic(..., p_idempotency_key)`: atomic, idempotent receipt RPC with actor/branch/payload replay checks.

These are proven present in current source files, not a claim that every candidate migration is applied in both hosted projects. Hosted migration state remains split and must be treated separately.

## 2. Source-grounded inventory findings

### 2.1 Existing functionality — retain and test, do not duplicate

1. Inventory UI at `src/routes/_authenticated/inventory.tsx` already has Medicines, Batches and Suppliers tabs.
2. Batch UI reads `pharmacy_inventory`, shows expiry state, filters batches and invokes `fn_receive_pharmacy_batch_atomic`.
3. Receipt UI validates a positive whole-number quantity, expiry presence and monetary precision; it generates and passes a stable idempotency key.
4. Receipt SQL adds a partial unique index on `pharmacy_inventory.idempotency_key`, takes an advisory transaction lock, returns the prior batch for an identical actor/payload retry, and rejects key reuse with a different payload.
5. Dispensing uses `atomic_pharmacy_dispense`, not a new `medicine_batches` table. Its SQL enforces pharmacy and billing permissions, anchors stock selection to the patient's branch (including super-admin flows), excludes expired and unknown-expiry batches, consumes FEFO batches under row locks, creates invoice lines in the same transaction, and records an idempotent request result.
6. Existing PG17 critical-path assertions test FEFO order, expired/unknown-expiry rejection, replay without duplicate movement/invoice lines, rejection of a second key for an already-dispensed prescription, no-write rollback on rejected expiry, branch-scoped RLS, and no direct authenticated stock-table mutation.
7. Existing receipt tests include `tests/inventory-receive-rpc.test.ts` and PostgreSQL money-precision integration coverage.

### 2.2 Verified gaps / follow-up candidates

**P1 — inventory statistics are still client-aggregated.** The Medicines tab loads every non-deleted medicine's `stock_quantity`, `reorder_level`, and `cost_price` via `useRows`, then computes low-stock count and stock value in browser memory. This is a valid server-side aggregation candidate. Design must first define whether the authoritative statistic is the legacy medicine aggregate or the sum of branch-owned remaining batches; do not mix them or present a misleading cross-branch total. Return only aggregate values and scope them by the caller's branch/permissions. Avoid a new broad table read.

**P1 — batch screen is capped and locally filtered.** The batch query orders by expiry and applies `.limit(500)`; search, expiry status counts and filters operate on the returned client array. This can silently omit records beyond 500. Before changing it, determine expected batch volume and whether the UI should use server-side filtering/counts and pagination. Preserve branch RLS and expiry ordering.

**P1 — aggregate/batch reconciliation needs explicit invariant tests.** The existing model updates both batch remaining quantities and `medicines.stock_quantity`. Add tests for receipt, dispense, reversal/return/write-off paths, duplicate prescription lines, and reconciliation. Do not infer that the aggregate always equals the sum of all batches until the legacy-stock migration/compatibility policy is resolved; current Phase 49 deliberately recognizes that `medicines.stock_quantity` is not branch-owned and refuses it as a dispensing fallback.

**P2 — receiving path needs a current exact-head regression audit.** Verify that the UI call, SQL signature, unique idempotency index, RLS/ACL, branch attribution and monetary-precision checks all match the migration actually deployed in QA and Production. No rewrite is warranted absent a failing contract.

**P2 — stock movement completeness.** Inventory UI reads movement history by batch. Audit all mutation paths (receipt, dispense, reversal, return, writeoff and any remaining administrative adjustment) for one atomic ledger row, correct sign, reference, branch and actor. Any missing path should be fixed in the existing RPC/ledger model, not by a second inventory subsystem.

**P2 — pack verification is not established.** Repository code search found no `pack_verified` field. Do not add a bare boolean. If pack attestation is required operationally, define who verifies, timestamp, batch/receipt association, evidence, exception/rejection path and audit retention first; then add it to the existing receipt/batch workflow only if there is a real clinical/regulatory requirement.

## 3. Clinical safety workstream

Do not ship generic `mg/kg/day` automation. A safe medication decision-support specification must be medicine-specific and encode:
- dose basis (`mg/kg/dose`, `mg/kg/day`, units/kg/dose, etc.);
- age/weight eligibility and weight freshness;
- route, interval, duration and maximum single/daily dose;
- renal/hepatic adjustment where relevant;
- indication-specific regimens and contraindications;
- formulation/concentration conversion and rounding;
- source, edition/date, local formulary status and clinician override/audit.

Allergy checking must use structured allergen/substance data and clinically reviewed ingredient/class mappings, not free-text substring matching alone. Begin as a clinician-facing warning with explicit uncertainty and override capture; do not block treatment based on an unvalidated fuzzy match. Require pharmacist/clinician sign-off and synthetic regression cases before release.

## 4. Security / PostgreSQL rules

- Do not blanket-rewrite every `SECURITY DEFINER` function's `search_path`. Inspect the function body, schema CREATE privileges, object qualification, actor/permission checks, branch ownership and EXECUTE ACL individually. The existing hardening uses an empty search path with schema-qualified references for sensitive functions; preserve that pattern where verified.
- PostgreSQL's `PUBLIC` pseudo-role is an ACL grantee, not an ordinary row in `pg_roles`. Inspect ACL arrays and effective privileges, including inherited PUBLIC grants, anon/authenticated and role membership.
- Advisor warnings for SECURITY DEFINER are triage signals, not proof of exploitability. Do not revoke all authenticated RPC execution without dependency and authorization tests.
- Unused-index warnings do not justify bulk index deletion, especially before meaningful clinic workload exists.
- Keep the private dispense idempotency table inaccessible to browser roles; the SECURITY DEFINER RPC is its intended access boundary.

## 5. Payments / Bankak

No Bankak-specific unique-reference implementation was confirmed by this targeted repository search. This remains a discovery task, not an approved migration. First map the canonical payment table, payment RPCs, reversal model, reference normalization, provider/merchant scope, branch, transaction date and existing uniqueness constraints. Then specify duplicate semantics (same reference across different merchants/providers, reversals, manual cash, missing references) before designing a partial unique index or idempotency key. Tests must prove concurrent duplicate submissions cannot create two posted payments and that legitimate reversals/reconciliation remain possible. Keep SDG as the single clinic currency; do not add currency switching.

## 6. Keep-alive and backup

- Reject `0 */72 * * *` as a 72-hour schedule; cron hour fields do not represent a 72-hour interval.
- Do not claim that a periodic `SELECT 1` guarantees a free Supabase project cannot pause. Prefer a small real readiness/health check and monitor project status; follow current Supabase policy and avoid needless traffic.
- Distinguish an encrypted logical export from PITR. Before any Production migration: produce a fresh encrypted backup of database and required Storage/configuration artifacts, verify integrity, and complete an isolated restore rehearsal. A successful archive listing is not proof of a successful backup run or restore.
- No Production DDL/DML, Auth/ACL/Storage mutation or deployment promotion without a separately approved change window and explicit owner approval.

## 7. Corrected work order

| Order | Work item | Entry criteria | Exit evidence |
|---|---|---|---|
| 0 | Freeze current baseline | Exact main SHA, PR heads, CI, live migration ledgers recorded | One evidence bundle; no stale status copied forward |
| 1 | Reconcile PR #229 Phase 61 | Three current conflicts confirmed; preserve Phase 57/57B mainline behavior | Two-parent history-preserving merge commit on PR branch; exact-head CI/PG17 pass; remain Draft pending clinical review |
| 2 | Repair PR #211 Phase 58/59 | Re-read current diff and failed check logs; SDG-only invariant | Current-main reconciliation, focused type/lint/build and PG17 tests; no unrelated changes |
| 3 | Inventory regression audit | Read current Phase 49/57/57B source and test suite | Test matrix for receive/dispense/replay/expiry/branch/ledger/reversal; identify actual uncovered cases |
| 4 | Server-side inventory stats + batch pagination | Decide authoritative aggregation semantics and branch scope | Aggregate RPC/query tests, no PHI exposure, >500 batch pagination test, RTL/LTR UI tests |
| 5 | Bankak reference integrity | Map payment schema and reversal semantics | Approved data model, concurrency/idempotency tests, reconciliation workflow |
| 6 | Clinical CDS specification | Clinician + pharmacist formulary review | Drug-specific dosing/allergy rule catalogue, provenance, max-dose and override tests |
| 7 | UX/print/operational acceptance | Candidate code stable in QA | Real Android device, Arabic/English A4 print, six-role golden path, 3G/offline drill, staff sign-off |
| 8 | Controlled Production release | QA parity, fresh verified backup + restore, ACL review, rollback plan | Explicit owner approval, migration read-back, production smoke and documented rollback |

## 8. Work deliberately removed from the external plan

- Creating `public.medicine_batches` or any parallel stock table.
- Replacing `fn_receive_pharmacy_batch_atomic` with a generic client-side `addStock` mutation.
- Reimplementing FEFO or adding a second dispensing RPC without a demonstrated defect.
- Assuming `pack_verified` exists or adding it without a workflow definition.
- Applying one `search_path` setting mechanically to all SECURITY DEFINER functions.
- Treating 68% Engineering RC / 18% Operational Acceptance as validated percentages.
- Treating cron keep-alive as a no-pause guarantee.
- Bulk deletion of unused indexes or broad ACL changes based only on Advisor counts.
- Any Production migration, deployment promotion, or backup/restore claim without direct evidence and approval.

## 9. Verification limits and outstanding evidence

This was a source-level and metadata-level review. It did not execute the SQL against a disposable PostgreSQL instance, run the repository test suite, inspect every payment RPC, prove all movement paths are complete, or conduct physical clinic acceptance. The current live database ledgers confirm a split between Production and QA; candidate SQL on `main` must not be mistaken for deployed SQL. Exact percentages remain un-recomputed pending a weighted evidence ledger.

## 10. Source pointers

- `src/routes/_authenticated/inventory.tsx`
- `src/lib/pharmacy.ts`
- `db/roshan_pharmacy_batch_receipt_idempotency.sql`
- `db/roshan_pharmacy_batch_receipt_guards.sql`
- `db/roshan_phase49_atomic_pharmacy_dispense.sql`
- `db/roshan_phase57_pharmacy_quantity_required_guard.sql`
- `db/roshan_phase57b_free_text_external_prescription_guard.sql`
- `db/tests/phase49_50_critical_path_assertions.sql`
- `tests/inventory-receive-rpc.test.ts`
- `db/tests/pharmacy_batch_money_precision_integration.sql`
- `docs/RELEASE_GATE_RECHECK_2026-11-11.md`
