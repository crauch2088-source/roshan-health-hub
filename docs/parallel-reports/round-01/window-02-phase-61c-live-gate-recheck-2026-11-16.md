# Parallel Engineering — Window 02
## Round 04 Follow-up: Phase 61C Live Gate Recheck

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review date:** 2026-11-16
- **Target:** [PR #250 — Phase 61C pharmacist-only atomic dispense](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- **Candidate head:** `c43c0258eb80760191b1b523128ddcb2c7537344`
- **Current main:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **PR #250:** Open, Draft, unmerged, mergeable
- **Review mode:** Fresh GitHub metadata/review/CI inspection and SELECT-only SQL against hosted QA and Production.
- **Change boundary:** Documentation-only report. No code, SQL, migration, grant, hosted data, PR approval, merge, or deployment changes.

> **Instruction/template status:** `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` remain unavailable on current main and the PR #250 branch. This report follows the structure of the preceding Window 02 reports and does not claim to have used the unavailable template. `AGENTS.md` and `.specify/memory/constitution.md` were rechecked.

## 1. Executive result

**Decision: HOLD — Phase 61C remains unapplied to QA and Production.**

The fresh database read confirms that the security boundary PR #250 is intended to establish is still absent from both hosted environments. The exact candidate remains green across its 11 PR-triggered workflow runs, but the independent second-person SQL/security review is still missing. Two new review submissions were added on 2026-11-16; both are owner-authored COMMENTED notes, not independent approval.

No production action is justified by this evidence. The next meaningful gate is an independent reviewer followed by a controlled QA-only migration and authenticated role-switch/PostgREST acceptance.

## 2. Current PR and review state

GitHub metadata read on 2026-11-16:

| PR | State | Draft | Merged | Head |
|---|---|---:|---:|---|
| [#250 Phase 61C](https://github.com/crauch2088-source/roshan-health-hub/pull/250) | Open | Yes | No | `c43c0258eb80760191b1b523128ddcb2c7537344` |
| [#262 Window 02 Round 01](https://github.com/crauch2088-source/roshan-health-hub/pull/262) | Open | Yes | No | `1e763aa95784c750b3170c13afe10d89e155f295` |
| [#272 Window 02 Round 02](https://github.com/crauch2088-source/roshan-health-hub/pull/272) | Open | Yes | No | `56664f48f9528075d41e5c007c42cd55155a5169` |
| [#281 Window 02 Round 03](https://github.com/crauch2088-source/roshan-health-hub/pull/281) | Open | Yes | No | `25857402f0263505e44b1dc46e46cca142c55409` |

PR #250 has two submitted review records, both authored by `crauch2088-source`, both state `COMMENTED`. There are zero inline review threads and no requested reviewers. The new comments are useful owner-agent evidence, but they do not satisfy independent review.

### New owner-authored evidence on 2026-11-16

1. A read-only live recheck states QA has Phase 61B but not Phase 61C; Production has neither Phase 61B nor Phase 61C. Both public dispense entry points remain EXECUTE-callable by authenticated API roles. The note explicitly preserves the HOLD boundary.
2. A QA-only SELECT check of the Phase 61B helper against the three active QA account claims records:
   - Admin: denied prescription create, correction request and correction resolve.
   - Doctor: allowed prescription create and correction resolve; denied correction request.
   - Pharmacist: allowed correction request; denied prescription create and correction resolve; has both `pharmacy.update` and `billing.create`.
   
   This is useful Phase 61B helper evidence only. It does not execute either dispense RPC, does not validate Phase 61C, and is not a substitute for authenticated PostgREST/JWT role-switch testing.

## 3. Exact-head CI and branch freshness

For candidate `c43c0258eb80760191b1b523128ddcb2c7537344`:

- All 11 PR-triggered workflow runs are completed with conclusion `success`.
- The Phase 61 PostgreSQL 17 workflow passed.
- Full CI passed.
- The CI policy intentionally skips the canonical PG17 baseline replay/authenticated clinical acceptance job. That skipped gate is not a pass.
- The combined commit-status endpoint exposes only the Vercel status context; it must not be mistaken for the complete workflow result.

Evidence:
- [Phase 61/61B/61C PostgreSQL 17](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968360)
- [Full CI](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968433)
- [Phase 49–50 critical path](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968352)

Branch comparison against current main:

- Candidate: 62 commits ahead, 5 commits behind.
- The five commits between the PR merge base `f8c8b2d1767643561599764405b4cdbfd4db2c79` and current main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` add only `docs/GEMINI_AUDIT_RECONCILIATION_2026-11-15.md` and `docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md`.
- No functional SQL/application change was found in those five intervening main commits. The PR is nevertheless behind and should be synchronized through the repository's normal non-rewriting branch policy before merge readiness.

## 4. Fresh SELECT-only hosted database verification

One batched catalog/ledger query was executed separately against QA and Production. It returned server version, recent migration ledger rows, target phase rows, SECURITY DEFINER/search_path attributes, and effective EXECUTE privileges. No DDL/DML or session role mutation was used.

### QA — PostgreSQL 17.11

Migration ledger:
- Phase 57: `20261104065852`
- Phase 57B: `20261111215510`
- Phase 61: `20261111223309`
- Phase 58: `20261112061219`
- Phase 59: `20261112061251`
- Phase 61B: `20261113232719`
- Phase 61C: absent

Function boundary:
- `private.app_has_role_permission(text[],text)` exists.
- `private.fn_dispense_prescription_with_invoice_unchecked(uuid,boolean)` exists.
- Both public dispense functions are SECURITY DEFINER with an empty fixed search_path.
- `authenticated` has EXECUTE on both public functions.
- `authenticator` has EXECUTE on `public.atomic_pharmacy_dispense(uuid,boolean,uuid)`; it does not have EXECUTE on the invoice-linked public function.
- `anon` has no EXECUTE on either public function.
- Phase 61C is not applied; the atomic public wrapper remains the pre-61C implementation.

### Production — PostgreSQL 17.6

Migration ledger:
- Latest recorded migration: `20261102232941`.
- No Phase 57, 57B, 58, 59, 61, 61B or 61C migration rows were returned.

Function boundary:
- `private.app_has_role_permission(text[],text)` is absent.
- `private.fn_dispense_prescription_with_invoice_unchecked(uuid,boolean)` is absent.
- Both public dispense functions are SECURITY DEFINER with an empty fixed search_path.
- `authenticated` and `authenticator` have EXECUTE on both public dispense functions.
- `anon` has no EXECUTE on either public function.
- Neither public entry point has the Phase 61B/61C canonical pharmacist role boundary.

### Interpretation

The database grants alone do not prove a successful exploit by an ordinary JWT caller; the relevant function-body authorization checks and PostgREST role-switch behavior must also be evaluated. However, the live catalog confirms that authenticated API callers can reach both public SECURITY DEFINER entry points at the SQL privilege layer, while the current Production and QA function bodies do not yet contain the Phase 61C canonical pharmacist gate on the atomic entry point.

Production is further behind QA: a Phase 61B → 61C-only rollout would not be safe because the current Production private implementation and Phase 57/57B integrity guards are absent.

## 5. Release and migration implications

The evidence-backed dependency chain remains:

1. Reconcile exact source provenance and migration-version history.
2. Phase 57 — quantity-required guard.
3. Phase 57B — free-text/external-prescription integrity guard.
4. Phase 61B — private invoice-linked implementation and pharmacist role boundary.
5. Phase 61C — canonical pharmacist wrappers for both public dispensing entry points.
6. On disposable PostgreSQL 17, replay the integrated sequence and prove idempotent reapplication, denial-before-side-effects, pharmacist success, branch isolation and concurrency.
7. After independent review, apply to QA only under a controlled release gate; verify before/after ACLs and authenticated PostgREST role behavior.
8. Production remains separately gated by full migration reconciliation, verified current encrypted backup/restore, and owner/operational release criteria.

The 2026-11-15 mainline audit records that the latest manual encrypted Production backup attempt failed preflight because neither `SUPABASE_DB_ACCESS_TOKEN` nor `SUPABASE_DB_PASSWORD` was configured in the backup-runner repository. That record reports no new artifact or restore rehearsal from that attempt. This Round 04 review did not rerun the backup workflow and did not access or request secrets.

## 6. Required next actions

### P0 — independent review
Obtain a genuine second-person PostgreSQL/security review of the full Phase 61B/61C dependency, migration SQL, public and private RPCs, grants, callers, idempotency payload and no-side-effect tests. Do not count owner-authored comments or this assistant review as independent approval.

### P0 — authenticated QA acceptance
After independent review, run a controlled QA-only migration and authenticated PostgREST/JWT role tests proving:
- canonical pharmacist allowed on both dispense entry points;
- Doctor, Admin, Super Admin and legacy_pharmacist denied before idempotency or business side effects;
- denied attempts leave stock, stock movements, prescriptions, invoices, invoice items, payments and cashbox unchanged;
- pharmacist replay remains idempotent, including changed `p_separate_invoice` payload rejection;
- branch isolation and concurrent execution remain correct.

### P0 — Production dependency and recovery gate
Do not apply Phase 57/57B/61B/61C to Production until exact source provenance, migration ordering/collisions, full forward delta, backup and isolated restore are independently reconciled and verified.

### P1 — test replay completeness
Retain the Round 03 finding that the dedicated Phase 61 workflow must replay Phase 57 and 57B before 61B/61C, with source-payload provenance and explicit nested implementation assertions.

## 7. Change and safety record

- This review performed GitHub metadata/CI inspection and SELECT-only SQL against QA and Production.
- No source SQL, application code, tests, workflows, migration files, grants, RLS, Auth, Storage, or hosted business data changed.
- No migration was applied to QA or Production.
- PR #250 was not approved, marked ready, merged, or deployed.
- Earlier Window 02 reports were not overwritten.
- This report is documentation-only and is submitted through a separate Draft PR.

## 8. Evidence pointers

- [PR #250 — Phase 61C](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- [PR #262 — Round 01 report](https://github.com/crauch2088-source/roshan-health-hub/pull/262)
- [PR #272 — Round 02 report](https://github.com/crauch2088-source/roshan-health-hub/pull/272)
- [PR #281 — Round 03 report](https://github.com/crauch2088-source/roshan-health-hub/pull/281)
- [Current mainline release audit](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md)
- [Exact-head Phase 61 PostgreSQL 17 workflow](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968360)
- [Exact-head full CI](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968433)
