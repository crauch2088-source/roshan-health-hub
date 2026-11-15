# Roshan Health Hub — Execution Round Evidence
**Date:** 2026-11-15  
**Scope:** Ten-task engineering/release-readiness batch approved by the owner  
**Safety boundary:** No Production writes, hosted migrations, merges, deployment promotions, or real patient/financial transactions.

## Executive disposition

This round produced several exact-head green candidate PRs, direct read-only QA evidence, and a current backup-runner blocker. It did **not** complete the entire ten-task batch or make Roshan Production-ready. The application `main` branch and hosted Production database were not changed by this round.

- **Engineering Release Candidate (RC): 62%** — unchanged. Candidate work is not counted as released implementation until independently reviewed and merged through the approved gates.
- **Operational Acceptance: 15%** — unchanged. No authenticated staff workflow, Android printer, physical printer, or owner-side backup decryption/restore acceptance was completed.
- **Estimated remaining work:** approximately 1–2 focused engineering days for candidate review/reconciliation and QA release rehearsal, then 1–3 weeks for clinic/staff, Android/A4/thermal-printer, backup-owner and operational acceptance. These are planning estimates, not completion promises.

## Ten-task result

| # | Workstream | Result this round | Evidence / remaining gate |
|---:|---|---|---|
| 1 | Phase 61C atomic dispense role boundary | Candidate verified; not released | PR [#250](https://github.com/crauch2088-source/roshan-health-hub/pull/250), exact head `b1a6847c0bcc5ea86960d3fb5d8e57ccfa62029f`; all 11 PR workflows succeeded. A rollback-only authenticated QA smoke proved the current atomic RPC still lets Admin and Super Admin reach argument validation while rejecting Doctor. Phase 61C remains un-applied; independent SQL/security review and QA release rehearsal remain. |
| 2 | Phase 60 medicine catalogue write boundary | Candidate verified; not released | PR [#210](https://github.com/crauch2088-source/roshan-health-hub/pull/210), exact head `e53216a826474e3ae865ab9faeeab99926e0614f`; all 7 PR workflows succeeded. Rollback-only QA smoke confirmed direct price update is still possible for Pharmacist/Admin, while the existing stock aggregate trigger blocks direct stock changes. No hosted catalogue rows remain from the fixture. Independent review and QA acceptance remain. |
| 3 | Phase 55 private helper ACLs | Existing migration/test source revalidated | `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` and dedicated PG17 workflow/tests are already on main; Phase 55 is present in QA migration ledger. Production still has PUBLIC-effective EXECUTE on the two identified helpers. No Production ACL or migration change was made. |
| 4 | Phase 57 / 57B quantity and external/free-text dispense guards | Source and QA state revalidated | Both phases are applied in QA and their PostgreSQL 17 integration path is part of current CI. Neither phase is recorded in Production; Production still has three NULL-to-one fallbacks in the dispense function. Preserve the exact QA-proven source payloads; do not blind-replay or hand-edit migration history. |
| 5 | Prescription item completeness / authoring guard | Candidate implementation and PG17 tests passed | PR [#255](https://github.com/crauch2088-source/roshan-health-hub/pull/255) includes Phase 63 candidate SQL guard, requiring medication name, dose, frequency, duration, dosage form, route and positive whole quantity. It also removes default quantity 1 and route inference from form. Exact head `86134c0df686830db194fa7f29686a90f89f11ca`: all 8 PR workflows succeeded, including the dedicated Phase 63 PG17 integration, CI, TypeScript, lint and build. Candidate SQL has not been applied to hosted QA/Production. |
| 6 | Pediatric weight-based prescription safeguard | **Not complete — deliberately gated** | The UI now warns when age cannot be verified and when a pediatric visit lacks current weight. It does not yet enforce a server-side dose-basis rule. The medicine catalogue has no persisted, verified dose-basis metadata; the prescribing engine specifications prohibit assuming fixed vs mg/kg or inferring protocols. The next safe step is an explicit persisted dose-basis declaration (fixed / mg/kg/dose / mg/kg/day / unknown), encounter-weight enforcement in the authoritative RPC/trigger, and audited exception policy. Do not treat the current warning as a hard stop. |
| 7 | Phase 58/59 SDG currency and receipt provenance | QA deployment state corrected; UI candidate verified | PR [#181](https://github.com/crauch2088-source/roshan-health-hub/pull/181), exact head `a49e261b0661239c1e0a18f5734453010499f71c`, all 8 PR workflows succeeded. Read-only QA catalog confirms Phase 58 `20261112061219`, Phase 59 `20261112061251`, `invoices.currency_code`, `payments.currency_code`, and authenticated-only receipt status RPCs. An outdated PR note saying these were absent in QA was corrected. Production still lacks this rollout. |
| 8 | Saved prescription printing / PR #179 divergence | Safe rebase candidate created and verified | PR [#255](https://github.com/crauch2088-source/roshan-health-hub/pull/255) ports the saved-row print path onto current main rather than merging the heavily diverged PR #179. Print eligibility requires pending/dispensed state, complete saved clinical fields, and exact non-empty prescription/visit/patient branch binding. A NULL patient-branch review finding was fixed with a regression test and the thread resolved. Exact-head CI 8/8 passed. Android preview, A4/thermal printer and staff acceptance remain. PR #179 was not merged or rewritten. |
| 9 | Authenticated synthetic-role QA smoke | Partial, rollback-only SQL authorization smoke passed | Synthetic Doctor/Pharmacist/Admin/Super Admin and Pharmacist/Admin catalogue fixtures were created only inside rollback-only QA transactions. Follow-up reads confirmed zero fixture users and zero fixture medicine rows remained. No patient, prescription, inventory, invoice, payment or ledger transaction was created. Browser E2E with authenticated sessions and real role UI workflows remains outstanding. |
| 10 | Encrypted Production backup + restore rehearsal | **Blocked at credential preflight** | Manual workflow run [#43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) stopped before dump/backup. The Supabase CLI token and AGE recipient were present, but neither `SUPABASE_DB_ACCESS_TOKEN` nor `SUPABASE_DB_PASSWORD` was configured. The backup job was skipped; no new artifact or restore was produced. Owner must configure exactly one of those repository secrets before a new dispatch. No secret value was accessed or changed. |

## Direct QA smoke evidence

### Dispense RPC authorization
A transaction created four synthetic Auth/application users and set authenticated JWT claims for each role. Doctor was rejected by both the legacy invoice-linked RPC and the current atomic RPC. Pharmacist passed the role gate and then stopped at the deliberate NULL-argument guard. Admin and Super Admin were rejected by the legacy RPC but reached the NULL-argument guard in the current atomic RPC, proving the Phase 61C gap. The transaction was rolled back and a follow-up query confirmed no synthetic identities remained.

### Catalogue write boundary
A separate transaction created synthetic Pharmacist/Admin identities and one synthetic medicine. Both roles could update `selling_price` directly under the current broad table policy. Both direct `stock_quantity` updates were rejected by the existing `medicine_stock_is_rpc_managed` trigger. The transaction was rolled back; a follow-up query confirmed no synthetic Auth users, application users or medicine rows remained. This distinguishes the actual catalogue-field exposure from the already-protected stock aggregate.

## Candidate PRs and review state

- PR #250 — Phase 61C; Draft; exact-head CI green; independent review absent; not applied to QA/Production.
- PR #210 — Phase 60; Draft; exact-head CI green; independent review absent; not applied to QA/Production.
- PR #181 — receipt/SDG provenance UI; Draft; exact-head CI green; Phase 58/59 exist in QA only; Production rollout blocked.
- PR #255 — saved prescription print + Phase 63 + clinical authoring corrections; Draft; exact-head CI green; no hosted migration, no merge, no device/staff acceptance.
- Owner-authored comments/review notes are not independent second-person approval.

## Safety and release boundary

- No Production database DDL/DML, ACL, RLS, Auth, Storage, patient, clinical, inventory, invoice, payment, ledger or prescription writes were performed.
- No QA migration was applied during this round. Only synthetic QA test rows inside explicit transactions were inserted and rolled back.
- No PR was merged and no Vercel deployment was promoted.
- Existing QA migration state is not Production migration state. Production migration ledger and effective catalog remain unreconciled with QA.
- The backup attempt failed before the backup job; do not claim a fresh backup exists from this round.

## Next critical sequence

1. Obtain independent SQL/security review for PRs #250 and #210; run approved QA migration rehearsals only after source/ledger reconciliation.
2. Complete Phase 63 QA rehearsal and independent clinical review of PR #255; separately design Phase 64 dose-basis persistence and server-side pediatric weight gate.
3. Confirm PR #181 receipt behavior with authenticated cashier/branch sessions in QA; retain Production gate until provenance migrations and rollback plan are independently reviewed.
4. Configure exactly one database credential secret in the backup runner and rerun the encrypted dump + isolated restore workflow; then perform owner-side decryption verification.
5. Run authenticated role/branch E2E, Android RTL/LTR print preview, A4/thermal-printer output and staff acceptance before changing Operational Acceptance.

**Disposition: engineering candidates advanced; round not fully closed; Production remains NO-GO.**
