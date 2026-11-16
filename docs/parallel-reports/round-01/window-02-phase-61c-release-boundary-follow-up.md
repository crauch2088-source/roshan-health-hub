# Parallel Engineering — Window 02
## Round 02 Follow-up: Phase 61C Hosted Release Boundary

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review date:** 2026-11-16
- **Primary target:** [PR #250 — Phase 61C](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- **Prior report:** [Round 01 — independent security review](./window-02-phase-61c-security-review.md)
- **Reviewed candidate head:** `c43c0258eb80760191b1b523128ddcb2c7537344`
- **Current main:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **PR #250 state:** Open, Draft, unmerged
- **Review mode:** Read-only repository / PR evidence re-check. No database writes, migrations, ACL changes, approvals, merges, or deployments.

> **Repository instruction discrepancy remains:** `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` were not found on current main in this round. This follow-up uses the same structured report convention and does not claim to comply with an unavailable template.

## 1. Purpose and delta

This is a continuation, not a repeat of the full Round 01 SQL review. It re-checks the live release boundary and PR review record after the earlier report was filed.

The repository main SHA is unchanged from Round 01. PR #250 remains on the same reviewed head and remains Draft. The PR's current discussion contains additional owner-submitted read-only evidence that sharpens the Production exposure statement and confirms that no independent second-person review has yet been supplied.

## 2. Current hosted boundary recorded in PR evidence

The 2026-11-16 read-only gate review attached to PR #250 records:

| Environment | Phase 61B | Phase 61C | Public atomic dispense ACL | Legacy invoice-linked RPC ACL |
|---|---|---|---|---|
| QA | Present | Absent | `authenticated` and `authenticator` can EXECUTE; `anon` denied | Phase 61B wrapper exists; role gate is present |
| Production | Absent | Absent | `authenticated` and `authenticator` can EXECUTE; `anon` denied | `authenticated` and `authenticator` can EXECUTE; `anon` denied |

The Production legacy RPC is `public.fn_dispense_prescription_with_invoice(uuid,boolean)`. The PR evidence states that Production has neither the Phase 61B helper nor the Phase 61B migration, so the Production legacy RPC is still on its older permission-based implementation. Phase 61C must not be treated as a standalone Production patch: the reviewed rollout prerequisite is Phase 61B followed by Phase 61C, after reconciliation and separate release approval.

The QA helper read-back using sampled active account claims found:
- Admin: false for the sampled prescription-create, correction-request, and correction-resolve checks.
- Doctor: true for prescription-create and correction-resolve, false for correction-request.
- Pharmacist: true for correction-request, false for prescription-create and correction-resolve; the pharmacist has both `pharmacy.update` and `billing.create`.

These QA checks were SELECT-only against the Phase 61B helper. They did **not** invoke either dispense RPC and do **not** prove Phase 61C behavior, since Phase 61C is absent from QA.

**Interpretation:** the function ACL makes these public SECURITY DEFINER entry points callable by authenticated API identities; it does not, by itself, prove a successful dispense or a bypass of an internal role check. The Production legacy function's older permission-only body and absent Phase 61B role wrapper are the material boundary that must be closed and verified before Production release.

## 3. Independent-review status

The GitHub PR reviews endpoint currently returns two submitted review records, both:
- authored by `crauch2088-source` (repository owner);
- state `COMMENTED`;
- attached to the exact candidate head `c43c0258eb80760191b1b523128ddcb2c7537344`.

They are owner verification comments, not independent second-person security approvals. No requested reviewers are recorded. Therefore the independent SQL/security review gate remains open.

## 4. PR #262 report-delivery status

The Round 01 report remains present at its recorded commit and was re-fetched successfully. PR #262 remains Open / Draft and unmerged. The workflow-run lookup for the documentation-only commit returned no PR-triggered workflow runs; its PR timeline records the Vercel deployment as ignored/skipped. This is not evidence of a failed code test and does not affect the security conclusions.

## 5. Decision and required next gates

**Decision remains HOLD — keep PR #250 Draft and do not apply Phase 61C to hosted QA or Production yet.**

Required sequence:
1. Obtain a genuine independent second-person SQL/security review of the Phase 61C migration and wrappers.
2. Complete the authorized QA-only Phase 61C migration gate, including pre/post ACL inspection and actual PostgREST/JWT role-switch tests for canonical pharmacist, Doctor, Admin, Super Admin, and legacy_pharmacist.
3. Prove denied roles have no idempotency, stock, invoice, payment, or ledger side effects.
4. Add explicit branch-isolation negative tests and a two-request concurrency test for the same prescription / final stock.
5. Reconcile Production migration history and relevant function definitions/ACLs. Production rollout must account for the Phase 61B prerequisite and the legacy invoice-linked RPC; do not apply Phase 61C alone.
6. Obtain separate authorization and human pharmacy/clinical acceptance before operational release.

## 6. Change record

- No source SQL or application code changed.
- No grants, RLS policies, functions, triggers, or migration files changed.
- No QA or Production DDL/DML, Auth, Storage, or clinical/financial data changed.
- PR #250 was not approved, merged, or modified.
- PR #262 was not merged or modified; this follow-up is a new documentation-only PR.
- No deployment was promoted.

## 7. Evidence pointers

- [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- [2026-11-16 live ACL / release-gate review comment](https://github.com/crauch2088-source/roshan-health-hub/pull/250#pullrequestreview-5915763537)
- [2026-11-16 QA helper read-back comment](https://github.com/crauch2088-source/roshan-health-hub/pull/250#pullrequestreview-5915777198)
- [Round 01 security review report](https://github.com/crauch2088-source/roshan-health-hub/blob/1e763aa95784c750b3170c13afe10d89e155f295/docs/parallel-reports/round-01/window-02-phase-61c-security-review.md)
