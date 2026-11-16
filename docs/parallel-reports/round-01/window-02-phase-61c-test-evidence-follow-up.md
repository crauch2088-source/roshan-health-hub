# Parallel Engineering — Window 02
## Round 03 Follow-up: Phase 61C Test Fidelity and Live Dispense Boundary

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review date:** 2026-11-16
- **Target:** [PR #250 — Phase 61C](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- **Candidate head:** `c43c0258eb80760191b1b523128ddcb2c7537344`
- **Current main:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **PR #250 state:** Open, Draft, unmerged
- **Review mode:** Read-only source, CI and live QA/Production SQL inspection. No database writes, migrations, grants, approvals, merges or deployments.

> **Instruction/template status:** `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` remain absent from current main and the reviewed PR head. This is a structured follow-up report and does not claim compliance with an unavailable template. The repository's `AGENTS.md`, `docs/AGENT_EXECUTION_PROTOCOL.md`, task-contract template, verification matrix and relevant security/orchestrator skills were inspected on the candidate branch.

## 1. Executive result

**Decision remains HOLD.** The Phase 61C wrapper design is materially stronger than the hosted pre-61C boundary, but the candidate still lacks an explicit Doctor-denial regression for dispensing, and its dedicated PG17 workflow does not replay the Phase 57/57B guarded dispensing implementation that is currently present in QA.

The successful exact-head checks are meaningful, but they do not close those evidence gaps or replace independent second-person SQL/security review and authenticated QA acceptance.

## 2. Current exact-head CI evidence

GitHub check-runs for exact candidate head `c43c0258eb80760191b1b523128ddcb2c7537344` report:

- **34 check runs total**
- **33 PASS**
- **1 SKIP** — “Canonical PG17 baseline replay and authenticated clinical acceptance”
- **0 FAIL**
- **12 PR-triggered workflow runs**, all concluded successfully.

Relevant exact-head workflows:
- [Phase 61 prescription correction roles/RLS/audit/no-side-effects — PostgreSQL 17](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968360)
- [Phase 49–50 pharmacy and clinical critical path — PostgreSQL 17](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968352)
- [Full CI](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968433)

The skipped canonical baseline/authenticated clinical acceptance check is not counted as a pass.

## 3. Additional test-coverage findings

### 3.1 Doctor denial is not explicitly tested for dispensing

The Phase 61C integration assertions directly test:
- Admin denial at `public.atomic_pharmacy_dispense`;
- Super Admin denial at `public.atomic_pharmacy_dispense`;
- legacy_pharmacist denial at both the atomic and direct invoice-linked public RPCs, including a synthetic case where broad permission bits are deliberately restored;
- canonical pharmacist success and idempotent replay;
- pharmacist denial when either required permission is missing.

A full-text inspection of `db/tests/phase61_prescription_correction_integration.sql` found no Doctor-specific dispense-denial assertion for either Phase 61C public wrapper. Doctor tests in that file concern prescription correction/authorization, not dispensing.

The source wrapper's allowlist is exactly `ARRAY['pharmacist']`, so the code path is expected to reject Doctor. This is a **test-coverage gap, not a demonstrated authorization bypass**.

**Required addition:** execute both public dispensing RPCs as a Doctor fixture with broad pharmacy/billing permissions (or an equivalent deliberately adversarial permission fixture), assert SQLSTATE 42501, and assert no idempotency, inventory, stock-movement, invoice, invoice-item, payment or cashbox rows were created or changed.

This corrects the earlier Round 01 report's statement that Doctor denial was included in the candidate role-boundary integration coverage. It was not explicitly present in the inspected Phase 61C integration SQL.

### 3.2 Phase 61 PG17 replay omits Phase 57 and Phase 57B

The changed workflow `.github/workflows/ci-phase61-prescription-correction.yml` replays the baseline, Phases 33/34, 36, 46, 48, 49 and 50, then Phase 61, 61B and 61C. It does **not** replay:
- `db/roshan_phase57_pharmacy_quantity_required_guard.sql`
- `db/roshan_phase57b_free_text_external_prescription_guard.sql`

This matters because Phase 61B moves the current invoice-linked dispense implementation into the private schema, and Phase 61C re-wraps that implementation. The SQL under test therefore needs to be validated with the same Phase 57/57B behavior expected in the QA upgrade path.

**Required addition:** replay the exact, provenance-verified Phase 57 and Phase 57B sources before Phase 61B/61C in the dedicated PG17 workflow, then assert that the nested private implementation still rejects NULL quantities, unlinked/free-text items and external prescriptions before any invoice or stock mutation. Preserve the existing source-payload/hash provenance; do not edit historical migration ledger rows.

## 4. Fresh read-only hosted SQL verification

A single batched read-only query was run separately against QA and Production on 2026-11-16.

### QA — PostgreSQL 17.11

Migration ledger contains:
- Phase 57: `20261104065852`
- Phase 57B: `20261111215510`
- Phase 61: `20261111223309`
- Phase 61B: `20261113232719`
- Phase 61C: absent

Function inspection:
- `private.fn_dispense_prescription_with_invoice_unchecked` exists.
- Its current private implementation has the Phase 57 NULL-quantity guard, no NULL-to-one fallback, and Phase 57B external/unlinked-item guards.
- Public legacy invoice-linked wrapper has the Phase 61B role guard.
- Public atomic dispense RPC still has the old broad permission gate; Phase 61C is not applied.
- Effective EXECUTE: authenticated can call both public wrappers; `authenticator` can still execute the public atomic RPC; `anon` and `service_role` are denied.

### Production — PostgreSQL 17.6

Migration ledger has no Phase 57/57B/61/61B/61C rows in the queried name set; the Phase 61B role helper and private unchecked invoice-linked implementation are absent.

Function inspection:
- Public atomic and invoice-linked dispense RPCs still use broad `app_has_perm` checks and have no canonical pharmacist role guard.
- The invoice-linked function still contains the legacy `COALESCE(pi.quantity,1)` fallback.
- NULL-quantity, external-prescription and unlinked/free-text guards are absent.
- Effective EXECUTE on both public RPCs is true for `authenticated` and `authenticator`; `anon` and `service_role` are denied.

These are live database read-backs, not inferences from the repository documentation. No rows or database objects were changed.

## 5. Production rollout implication

Phase 61C requires Phase 61B and wraps the private implementation that Phase 61B creates. But Phase 61B alone does not add the Phase 57/57B quantity and prescription-integrity behavior. Applying only 61B → 61C to current Production would close the role boundary while preserving the old private dispensing body.

The safe Production candidate sequence must therefore reconcile and test the full dependency chain:

1. Phase 57 quantity-required guard.
2. Phase 57B free-text/external-prescription guard.
3. Phase 61B private implementation move and role wrapper.
4. Phase 61C canonical pharmacist wrappers for both public dispense entry points.

This is a **planning sequence**, not authorization to apply any migration. Exact payload provenance, migration-version collisions, backup/decryption/restore, dependency review and separate release gates still apply. Production remains NO-GO.

## 6. Branch freshness

Comparing current main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` to PR #250 head `c43c0258eb80760191b1b523128ddcb2c7537344` reports:
- PR candidate: 62 commits ahead, 5 commits behind current main.
- The five intervening main commits are documentation-only, adding the Gemini and independent release-audit reconciliation records.
- No functional SQL delta was found in those five main commits; nevertheless, synchronize the PR branch with current main under the repository's normal non-rewriting branch policy before final merge readiness.

## 7. Independent-review and release status

The PR review records remain owner-authored comments, not a second-person approval. This follow-up is another read-only review by the same assistant workflow and **does not satisfy** the repository's independent reviewer requirement.

Keep PR #250 Draft. Do not apply Phase 61C to QA or Production until:
1. a genuine independent SQL/security reviewer has reviewed the complete diff, callers, tests and live evidence;
2. Doctor-denial and no-side-effect assertions are added;
3. the PG17 replay includes Phase 57/57B before Phase 61B/61C;
4. authenticated QA PostgREST/JWT role tests pass for pharmacist, Doctor, Admin, Super Admin and legacy_pharmacist;
5. branch isolation and dispensing concurrency evidence is complete;
6. the separate Production reconciliation and recovery gates pass.

## 8. Change record

- No source SQL, workflow, application code or migration files changed.
- No QA or Production DDL/DML, grants, RLS, Auth, Storage or business data changed.
- PR #250 was not approved, merged or modified.
- Earlier Window 02 reports were not overwritten.
- This report is documentation-only and is submitted in a separate PR.

## 9. Evidence pointers

- [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- [Exact-head Phase 61 PG17 workflow](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968360)
- [Exact-head Phase 49–50 workflow](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968352)
- [Phase 57 quantity guard source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase57_pharmacy_quantity_required_guard.sql)
- [Phase 57B prescription-integrity guard source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase57b_free_text_external_prescription_guard.sql)
- [Phase 61C migration](https://github.com/crauch2088-source/roshan-health-hub/blob/c43c0258eb80760191b1b523128ddcb2c7537344/db/roshan_phase61c_atomic_dispense_role_boundary.sql)
- [Round 01 report](./window-02-phase-61c-security-review.md)
- [Round 02 report](./window-02-phase-61c-release-boundary-follow-up.md)
