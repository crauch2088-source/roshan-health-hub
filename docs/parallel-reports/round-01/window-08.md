# Window 08 — Round 01 Report

> Release & Branch Reconciliation Audit. Review-only delivery; this report does not approve a merge, closure, migration, or release.

## 1. Identity and scope

- Window: **08**
- Original task: Release & Branch Reconciliation Audit — PRs #179, #258, #257; Issues #199 and #253.
- Round: **01**
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `docs/parallel-release-reconciliation-window-08-round-01` / docs-only PR to be created.
- Scope: read-only reconciliation of release evidence, PR/branch history, backup/restore evidence, migration ledgers, human acceptance, and main protection.
- Explicit exclusions: no PR merge/closure; no issue closure; no changes to GitHub protection/settings; no edits to `docs/MASTER_PLAN.md`, `AGENTS.md`, other windows' reports, or shared continuation files; no Production/QA writes, migrations, ACL/RLS changes, backup dispatch, secret changes, or deployment promotion.

## 2. Executive verdict

- Status: **PASS WITH FINDINGS**
- What is actually complete: current repository/PR state was rechecked; exact-head CI for #258 was rechecked; current Production/QA migration ledgers were read; the latest backup-runner workflow and main branch protection were checked; release and human-acceptance blockers were reconciled.
- What remains incomplete: #258 still has an unresolved Phase 63 review thread and no independent approval; #179 remains open but is superseded and must not be merged; #257 is stale relative to the #258 candidate; owner-side decryption of the latest retained backup is not evidenced; pharmacist acceptance, physical printing, staff UAT, migration provenance reconciliation, and branch protection remain incomplete.
- Work type: **review-only audit**, not implementation.
- Release verdict: **Production NO-GO**. CI success is not clinical acceptance or authorization to release.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main branch](https://github.com/crauch2088-source/roshan-health-hub/tree/main) | Verified |
| PR #179 | Open, Draft; head `0a1aec71a20c7448eed5275fd349ea6d1832c97d`; 39 ahead / 34 behind requested main baseline | [PR #179](https://github.com/crauch2088-source/roshan-health-hub/pull/179) | Verified |
| PR #258 | Open, Draft, mergeable; head `abd61871ea418925c855948b24789303b5df6758`; based on requested main SHA | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | Verified |
| PR #257 | Open, Draft; head `1ee4cf3bf1e4af2540b225284983f81548797ef9`; branch has four unique commits while main has one unique commit relative to their merge base | [PR #257](https://github.com/crauch2088-source/roshan-health-hub/pull/257) | Verified |
| #258 exact-head CI | 8/8 PR workflow runs completed successfully on `abd61871...`; combined status has Vercel success | [Actions for #258](https://github.com/crauch2088-source/roshan-health-hub/actions) | Verified |
| #258 review | One owner-authored COMMENTED review; one unresolved, non-outdated inline thread at `db/roshan_phase63_prescription_item_completeness_guard.sql:11`; no independent approval | [Review thread](https://github.com/crauch2088-source/roshan-health-hub/pull/258#discussion_r4584207030) | Verified |
| Backup runner main | `f171732b61fe0460c61a36aa63b861065f9ea9d1` | [Backup runner](https://github.com/crauch2088-source/roshan-health-hub-backup-runner) | Verified from #199 latest update |
| Latest backup attempt | Run `43764265014`, failed at credential preflight; backup job skipped; no artifact | [Run #43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) | Verified |
| Latest full backup/restore success | Run `43183851731` on older runner SHA `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`; isolated PG17 restore, integrity comparison, encryption and ciphertext upload succeeded | [Run #43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) | Verified historically |
| Production migration ledger | 129 rows; latest `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | Supabase read-only `list_migrations` | Verified live |
| QA migration ledger | 27 rows; latest `20261113232719 roshan_phase61b_clinical_role_boundary` | Supabase read-only `list_migrations` | Verified live |
| Main branch protection | `protected=false`; protection disabled; required status checks enforcement off; no contexts | [main branch API](https://api.github.com/repos/crauch2088-source/roshan-health-hub/branches/main) | Verified live |

## 4. Work actually performed

1. Read `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` from the continuation handoff branch `docs/parallel-engineering-continuation-20261116`. The protocol confirms Window 08 ownership, required report path, review-only PR delivery, and the no-mutation boundaries.
2. Read current `AGENTS.md`, `.specify/memory/constitution.md`, and the relevant `docs/MASTER_PLAN.md` release addendum from main. The policy requires atomic commits, quota-safe docs-only delivery, exact-head evidence, no blind migration-ledger repair, and separate engineering vs operational acceptance.
3. Re-fetched #179, #258, #257, Issues #199 and #253; compared branch commits against the requested main baseline.
4. Rechecked all eight PR-triggered workflow runs for #258 at its exact current head. All eight completed successfully. The successful CI does not clear the open review thread or replace independent approval.
5. Rechecked the #258 review submission and inline thread. The comment was authored by the repository owner and is not independent second-person approval.
6. Rechecked the backup-runner workflow history and the latest #199 evidence comment. The latest attempt failed before dump; the prior full encrypted backup/restore remains the latest successful run.
7. Re-read Production and QA migration ledgers directly through read-only Supabase migration-list calls and compared version IDs/names.
8. Read the live GitHub main branch object. It explicitly reports `protected=false`, protection disabled, and no required checks.
9. Created a dedicated report branch from the verified main SHA. No shared project files were edited.

## 5. Findings

### F-01 — PR #179 is superseded by the rebased candidate; do not merge it

- Severity: **High**
- Status: **Verified**
- Affected paths: prescription composer, pharmacy screen, print model, prescription atomicity tests, quantity helper, package/roadmap files.
- Evidence: #179 head `0a1aec71...` diverges from requested main with 39 commits ahead and 34 behind. #258 is based on the requested main SHA and is the current successor candidate.
- Impact: merging #179 risks replaying stale code over later pharmacy/clinical contracts. It is not safe to treat the old branch as an alternative merge candidate.
- Recommended correction: continue only on #258. Mark #179 as superseded only after #258 has passed independent review and owner acceptance. Do not close it now.
- Required regression: retain exact-head print isolation, saved-row-only eligibility, branch/status checks, and PostgreSQL 17 Phase 63 tests on the successor.
- Dependency / owner: #258 review and acceptance; owner approval required before closing #179.

### F-02 — #258 passes current CI but remains unapproved and has an unresolved Phase 63 integrity finding

- Severity: **High**
- Status: **Verified, candidate-only**
- Affected object: `db/roshan_phase63_prescription_item_completeness_guard.sql`, trigger guard at line 11.
- Evidence: all eight PR workflows passed on exact head `abd61871...`. The inline thread is unresolved and non-outdated. It identifies that the early return for any `NEW.deleted_at IS NOT NULL` can bypass validation when an active row is soft-deleted in the same UPDATE that blanks/invalidates clinical fields.
- Impact: the transition can persist a changed invalid clinical payload even though already-deleted historical rows need a compatibility exemption. This is a data-integrity concern; it is not evidence that the print model prints deleted rows.
- Recommended correction: distinguish pre-existing deleted rows (`OLD.deleted_at IS NOT NULL`) from active-to-deleted transitions; reject clinical payload changes or preserve the original clinical fields on that transition.
- Required regression: PostgreSQL 17 tests for active valid row + simultaneous soft-delete and invalid clinical field, ordinary soft-delete, and updates to already-deleted historical rows.
- Dependency / owner: implementation owner and independent clinical/security reviewer. Keep #258 Draft until resolved and independently reviewed.

### F-03 — PR #257 is a historical record, not a current release-state authority

- Severity: **Medium**
- Status: **Verified**
- Affected files in #257: `docs/EXECUTION_ROUND_2026-11-15.md` and `docs/MASTER_PLAN.md`.
- Evidence: #257 records PR #255 as the printing/Phase 63 candidate and its exact-head evidence. The current candidate is now #258 at `abd61871...`, with a new unresolved Phase 63 review finding. The #257 branch is diverged from main; it has four branch-only commits and main has one main-only commit.
- Impact: relying on the 15 November report without a dated superseding note can misstate the active candidate and current review status. Its historical backup/acceptance statements must also remain tied to their original timestamps.
- Recommended correction: add a new dated reconciliation in a follow-up docs-only change after the report owner/coordinator decides whether #257 itself should be updated. Do not rewrite the historical round record and do not edit `MASTER_PLAN.md` from this window.
- Required regression: review exact-head evidence links and ensure every candidate SHA matches the PR head at the stated timestamp.
- Dependency / owner: coordinator/owner; this window's scope does not modify #257 or shared roadmap files.

### F-04 — Latest backup attempt failed; earlier full backup/restore success is not a fresh recovery rehearsal

- Severity: **Critical**
- Status: **Verified**
- Evidence: latest run `43764265014` failed Production credential preflight because neither `SUPABASE_DB_ACCESS_TOKEN` nor `SUPABASE_DB_PASSWORD` was available; backup job skipped and no artifact created. Latest full success remains `43183851731`, on older runner SHA `eb7d8ae8...`, with isolated PostgreSQL 17 restore, integrity comparison, AGE encryption, and ciphertext-only upload passing.
- Impact: no new backup was created by the latest attempt. The latest retained encrypted artifact's owner-side decryption remains unverified. A previous Android/Termux check documented in PR #201 concerns the 2026-11-08 bundle and must not be conflated with this later artifact.
- Recommended correction: owner restores one approved credential directly through GitHub Secrets, authorizes a new manual backup, verifies the encrypted artifact checksum and decryption on the trusted offline device, and confirms temporary plaintext removal. Never send credentials/private AGE identity in chat or source.
- Required regression: new manual run passes dump → isolated PG17 restore → integrity comparison → encryption → ciphertext upload; owner-side offline decrypt/archive verification of that exact artifact.
- Dependency / owner: owner-controlled secret setup and explicit backup dispatch/decryption acceptance.
- Scope note: database-only backup does not include Storage object bytes, Vault secrets, or full Supabase control-plane configuration.

### F-05 — Production and QA migration ledgers remain materially divergent

- Severity: **Critical**
- Status: **Verified live, read-only**
- Evidence: Production has 129 migrations through `20261102232941`; QA has 27 through `20261113232719`. Only three version IDs are shared and all three have different names:
  - `20261102122437`: Production `superseded_placeholder_phase49_atomic_pharmacy_dispense`; QA `roshan_phase51_public_setup_required_anon`.
  - `20261102133658`: Production `superseded_placeholder_phase50_clinical_visit_bill_completion`; QA `roshan_phase49_atomic_pharmacy_dispense`.
  - `20261102133734`: Production `superseded_placeholder_phase51_public_setup_required_anon`; QA `roshan_phase50_clinical_visit_bill_completion`.
- Impact: migration histories are not interchangeable. The version/name collisions mean no blind replay, manual ledger insertion, or copying QA history into Production is safe.
- Recommended correction: reconcile source provenance and effective schema/catalog in a separately reviewed plan; construct an ordered, forward-only migration sequence with recovery evidence. Do not repair the ledger by editing history.
- Required regression: source-to-ledger reconciliation, disposable PostgreSQL 17 replay, exact dependency/order checks, and read-only post-apply verification for any later authorized rollout.
- Dependency / owner: database/security reviewers and release coordinator. No rollout is authorized by this report.

### F-06 — Human clinical and operational acceptance remains unproven

- Severity: **Critical**
- Status: **Verified as outstanding in latest Issue #199 update**
- Affected workflows: pharmacist dispensing, prescription print, clinic staff UAT.
- Evidence: latest #199 update still records no authenticated QA pharmacist acceptance, no physical printer acceptance, and no staff UAT. Exact-head CI and rollback-only QA SQL authorization smokes are not equivalent to authenticated workflow acceptance.
- Impact: automated tests do not demonstrate that real staff can safely complete reception → GP → lab → pharmacy → billing, or that actual printed output is correct and usable.
- Recommended correction:
  1. Complete authenticated QA pharmacist acceptance with synthetic QA data: valid FEFO, quantity rejection, mixed/free-text rejection, invoice atomicity, retry/idempotency, and audit trail.
  2. Physically test Arabic RTL and English LTR output at supported phone widths and on A4/thermal devices as applicable.
  3. Record staff UAT for reception → GP → lab → pharmacy → billing and disposition all P0/P1 findings.
- Required regression: signed acceptance checklist with role, environment, exact candidate, test case, result, and defect references; no real patient data.
- Dependency / owner: clinic pharmacist and staff; owner schedules and records acceptance.

### F-07 — Main branch protection is currently disabled

- Severity: **High**
- Status: **Verified live**
- Evidence: GitHub main branch API reports `protected=false`, `protection.enabled=false`, enforcement off, and empty required-check contexts. The latest Issue #253 comment independently records the same state.
- Impact: passing CI is advisory and not an enforced merge gate.
- Recommended correction: first add and verify an always-running aggregate PR gate that handles code, SQL, Spec Kit, and docs-only paths; then configure protection with PR-only changes, independent approval, last-push approval, stale-review dismissal, conversation resolution, strict up-to-date checks, admin enforcement, and no force-push/deletion.
- Required regression: prove aggregate gate behavior on representative code-only, SQL-only, and docs-only PRs; read back final branch protection settings after an owner-authorized change.
- Dependency / owner: repository owner/coordinator. No settings were changed in this window.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| PR #258 exact-head workflows | Commit `abd61871ea418925c855948b24789303b5df6758`; eight PR workflow runs | **PASS** | All eight completed successfully: CI, Phase 48 PG17, prescription atomicity, privileged-role, clinical child RPC, finance RPC isolation, insurance integrity, insurance UI. |
| PR #258 combined status | Same SHA | **PASS** | Vercel status success. This does not imply clinical acceptance. |
| PR #258 independent review | Review list + review-thread API | **BLOCKED** | Only owner-authored COMMENTED review; one unresolved inline thread. |
| Backup full run | `43183851731` | **PASS (historical)** | Runner-side PG17 restore, integrity comparison, encryption, ciphertext upload succeeded on older runner SHA. |
| Latest backup attempt | `43764265014` | **FAIL** | Credential preflight failed; backup job skipped; no artifact. |
| Production migration ledger | Supabase `list_migrations` | **PASS (read-only)** | 129 rows; latest `20261102232941`. |
| QA migration ledger | Supabase `list_migrations` | **PASS (read-only)** | 27 rows; latest `20261113232719`. |
| Main protection read-back | GitHub `GET /branches/main` | **PASS (read-only)** | Confirms protection disabled and no required contexts. |
| Physical printer test | Not available in repository evidence | **NOT RUN / NOT ACCEPTED** | No claim of A4/thermal success. |
| Authenticated pharmacist browser acceptance | Not available in repository evidence | **NOT RUN** | Automated PG17 tests are not human acceptance. |
| Staff UAT | Not available in repository evidence | **NOT RUN** | Requires clinic staff. |

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-01/window-08.md` | New isolated Window 08 audit report | To be filled after commit |

- Branch: `docs/parallel-release-reconciliation-window-08-round-01`
- Commit(s): created as one docs-only commit.
- PR: separate docs-only report PR; no implementation PR modified.
- Report file path: `docs/parallel-reports/round-01/window-08.md`
- Report commit SHA: to be filled after commit.
- Delivery type: separate docs-only PR because this task is review-only.
- No changes to #179, #258, #257, #199, #253, `MASTER_PLAN.md`, `AGENTS.md`, or other window reports.

## 8. Safety and actions not performed

- Production or QA database writes: **No**.
- Hosted migrations / ACL / RLS changes: **No**.
- Production or QA deployment: **No**.
- Real patient, clinical, or financial data access/use: **No**.
- Secret or credential changes: **No**.
- Backup dispatch: **No**.
- Branch protection/settings changes: **No**.
- PR merge / issue closure / release approval: **No**.
- Shared roadmap/policy files changed: **No**.

## 9. Risks, dependencies, and owner decisions

1. **Critical — latest backup recovery evidence:** owner must re-establish one approved DB credential and authorize a new encrypted backup; then decrypt/verify that exact artifact offline.
2. **Critical — migration provenance:** Production/QA version/name collisions and schema divergence require an independently reviewed forward-only reconciliation plan.
3. **Critical — clinical acceptance:** pharmacist, physical printing, and staff UAT require human execution and recorded evidence.
4. **High — #258 candidate:** fix active-to-soft-deleted clinical-field bypass and obtain independent review before removing Draft status.
5. **High — branch governance:** implement/verify an always-running aggregate gate before enabling branch protection.
6. **Owner decision — #179 closure:** keep open until #258 is accepted; then close as superseded only with explicit owner/coordinator decision.
7. **Coordinator decision — #257:** preserve the historical 15 Nov report; add a dated update or a superseding reconciliation after deciding whether the existing PR is still the appropriate vehicle.

## 10. Next action

**Window 08 / coordinator:** after this report PR is reviewed, prepare one dated release-gate reconciliation that links #258 as the current print candidate, records the unresolved Phase 63 thread and exact-head CI, carries forward the live backup/ledger/protection evidence, and leaves all owner-controlled and human-acceptance gates open. Do not close #179 or #199/#253 and do not change hosted state.

## 11. Session closeout

- Work completed in this session: continuation protocol/template read; current main/PR/issue/backup/branch-protection state rechecked; current Production/QA migration ledgers compared; isolated Window 08 report authored.
- Work not completed: no code fix to #258, no update to #257, no PR/issue closure, no backup dispatch/decryption, no human acceptance, no branch-protection change, no hosted migration.
- Exact current state at close: main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; #179/#258/#257 open Draft; #199/#253 open; Production NO-GO.
- Recommended continuation when the owner says **"أكمل"**: re-fetch the report PR and all referenced exact heads; do not recreate this report. Continue only the outstanding reconciliation/verification authorized by the owner and create a new report file under the next round directory when the round advances.
