# Window 08 — Round 02 Report

> Release & Branch Reconciliation Audit. Review-only continuation; this report does not approve a merge, closure, migration, branch-protection change, backup dispatch, or release.

## 1. Identity and scope

- Window: **08**
- Original task: Release & Branch Reconciliation — PRs #179, #258, #257; Issues #199 and #253; backup/restore and release gates
- Round: **02**
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `docs/parallel-release-reconciliation-window-08-round-02` / separate docs-only PR
- Scope: recheck Round 01 findings against live GitHub and Supabase state; inspect the latest Phase 63 correction and exact-head validation; preserve backup, migration, governance and human-acceptance evidence; prepare owner-facing acceptance checklists.
- Explicit exclusions: no implementation edits to PR #258; no edits to PRs #179/#257; no changes to `docs/MASTER_PLAN.md`, `AGENTS.md`, shared continuation protocol, or any other window report; no PR/issue merge or closure; no branch protection/settings mutation; no Production/QA writes, migrations, ACL/RLS changes, backup dispatch, secret changes, or deployment promotion.

## 2. Executive verdict

- Status: **PASS WITH FINDINGS**
- What is actually complete:
  - Rechecked current main, PR #266, #258, #179, #257, Issues #199/#253, backup-runner history, rulesets and both live migration ledgers.
  - Verified PR #258's new exact head `8312c92273d50d6eb9d8e700a2eebf89192bcf68` is seven commits ahead / zero behind main.
  - Verified all eight PR-triggered workflow runs on that exact head succeeded; the CI workflow's dedicated Phase 63 PostgreSQL 17 job passed.
  - Inspected the active-to-soft-delete correction and its new PostgreSQL 17 regression assertions.
  - Prepared explicit owner-side backup, pharmacist, printer and staff-UAT acceptance criteria below.
- What remains incomplete:
  - PR #258 has no independent approval; the only submitted review is owner-authored and COMMENTED. The inline Phase 63 discussion remains present in the API response; no independent approval or confirmed thread-resolution evidence was found.
  - The active-to-deleted guard compares eight persisted fields but omits `instructions`, even though the print model carries that field. Decide whether it must be immutable during archive, then test or document the exception.
  - `db/MIGRATIONS_MANIFEST.md` still calls PR #255 the Phase 63 source candidate, although #258 now carries the candidate.
  - PR #179 remains divergent; #257 remains a historical snapshot.
  - Latest backup attempt failed before dump; owner-side decrypt/integrity verification of the latest retained artifact remains unproven.
  - QA pharmacist acceptance, physical Android/A4/thermal printing, staff UAT, migration provenance reconciliation and main branch protection remain incomplete.
- Work type: **review-only verification and documentation**, not implementation.
- Release verdict: **Production NO-GO**. Green candidate CI does not equal independent security review, hosted migration, or clinical/operational acceptance.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main](https://github.com/crauch2088-source/roshan-health-hub/tree/main) | Verified live |
| PR #266 (Round 01 report) | Open, not merged; head `56cd2f2992e3e819b0056754f6b90d72295867a5` | [PR #266](https://github.com/crauch2088-source/roshan-health-hub/pull/266) | Verified live; prior report preserved |
| PR #258 | Open, Draft, mergeable; head `8312c92273d50d6eb9d8e700a2eebf89192bcf68`; seven ahead / zero behind main | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | Verified live |
| PR #258 exact-head workflows | Eight PR-triggered workflow runs succeeded on `8312c922...`; CI job list has 19 successful jobs and one intentional skip | [Actions](https://github.com/crauch2088-source/roshan-health-hub/actions) | Verified exact head |
| Phase 63 PG17 job | `Phase 63 prescription item completeness guard (PostgreSQL 17)` — success in CI run `43853928921` | [CI run #43853928921](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853928921) | Verified exact head |
| PR #258 review | One owner-authored COMMENTED review; existing inline comment `4584207030` at SQL line 11; no independent approval | [Review discussion](https://github.com/crauch2088-source/roshan-health-hub/pull/258#discussion_r4584207030) | Verified; not approved |
| PR #179 | Open, Draft; head `0a1aec71a20c7448eed5275fd349ea6d1832c97d`; 39 ahead / 34 behind main | [PR #179](https://github.com/crauch2088-source/roshan-health-hub/pull/179) | Verified; do not merge |
| PR #257 | Open, Draft; head `1ee4cf3bf1e4af2540b225284983f81548797ef9`; four ahead / one behind main | [PR #257](https://github.com/crauch2088-source/roshan-health-hub/pull/257) | Verified; historical snapshot |
| Backup runner latest attempt | Run `43764265014`, failed credential preflight; no dump/artifact | [Run #43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) | Verified |
| Latest successful backup/restore | Run `43183851731`, runner SHA `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`; PG17 isolated restore, integrity comparison, encryption and ciphertext upload succeeded | [Run #43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) | Historical success; not latest runner |
| Latest retained artifact | `roshan-production-backup-43183851731.zip`, 305,284 bytes, Drive MD5 `22271054f6c10b1baf1d23ac4bdac24e` | [Encrypted artifact](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk) | Present; owner decrypt check unverified |
| Production migration ledger | 129 rows; latest `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | Read-only Supabase migration list | Verified live |
| QA migration ledger | 27 rows; latest `20261113232719 roshan_phase61b_clinical_role_boundary` | Read-only Supabase migration list | Verified live |
| Main protection | `protected=false`; protection disabled; required checks enforcement off; no rulesets | [main branch API](https://api.github.com/repos/crauch2088-source/roshan-health-hub/branches/main) · [rulesets](https://api.github.com/repos/crauch2088-source/roshan-health-hub/rulesets) | Verified live |
| Issue #199 | Open; latest owner update 2026-11-16 confirms backup preflight failure and owner-side steps | [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) | Verified live |
| Issue #253 | Open; latest owner update 2026-11-16 confirms branch protection disabled and aggregate-gate prerequisite | [Issue #253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) | Verified live |

## 4. Work actually performed

1. Re-read the Window 08 continuation protocol and the report template from the handoff branch; resumed from the prescribed Round 01 next action.
2. Re-fetched main, #266, #258, #179, #257, #199, #253, latest backup-runner workflow history, branch protection and rulesets.
3. Re-read Production and QA migration ledgers using read-only Supabase calls.
4. Compared #258 against main and confirmed seven commits ahead / zero behind. Compared #179 and #257 against main and confirmed their divergence.
5. Re-fetched #258 review submissions and inline comments. Confirmed the review remains COMMENTED and owner-authored; no independent approval exists.
6. Inspected the #258 Phase 63 SQL trigger and integration test. Confirmed the new trigger rejects an active-row soft-delete UPDATE if the eight compared prescription fields are changed, allows an ordinary soft delete, and preserves already-soft-deleted legacy rows during non-clinical updates.
7. Inspected the exact-head CI job list and verified the dedicated Phase 63 PG17 job succeeded. One canonical baseline/authenticated clinical acceptance job remains intentionally skipped.
8. Prepared owner-run checklists for the latest encrypted backup and the still-missing pharmacist, printer and staff acceptance.
9. Created a new Round 02 report branch from verified main. No application, SQL, shared-plan, or hosted-environment files were changed.

## 5. Findings

### F-01 — Phase 63 active-to-deleted bypass is materially corrected; one payload field remains outside the guard

- Severity: **Medium**
- Status: **Verified in candidate source; candidate-only**
- Affected file/function: `db/roshan_phase63_prescription_item_completeness_guard.sql`, `private.validate_prescription_item_completeness()`
- Evidence and exact source/commit: PR #258 head `8312c92273d50d6eb9d8e700a2eebf89192bcf68`; comparison now includes medication name, dose, dosage, frequency, duration, quantity, dosage form and route on active-to-deleted transition.
- Reproduction or test: `db/tests/phase63_prescription_item_completeness_integration.sql` now attempts `SET deleted_at=now(), dose='', dosage=''`, asserts SQLSTATE check violation and verifies the original row remains active and unchanged. It separately proves ordinary soft deletion works and a pre-existing deleted legacy row remains updateable for non-clinical instructions.
- Impact: The specific bypass reported in Round 01 is closed in this candidate. However, `instructions` is omitted from the protected row comparison even though `src/lib/print/prescription.ts` includes it in the persisted print model. An archive transition can therefore alter patient-facing instructions while retaining the other compared values.
- Recommended correction: Decide whether `instructions` is part of the protected prescribed payload. If yes, include it in both row comparisons and add a PG17 regression for simultaneous soft-delete plus instruction mutation. If no, document why it is mutable on archive and ensure audit history preserves the prior value.
- Required regression test: active row + `deleted_at` + changed `instructions` must either be rejected with the prior value preserved, or satisfy an explicitly approved audit policy.
- Dependency / owner: PR #258 owner and independent clinical/security reviewer.

### F-02 — Phase 63 migration manifest still names superseded PR #255

- Severity: **Low**
- Status: **Verified**
- Affected file: `db/MIGRATIONS_MANIFEST.md`
- Evidence: PR #258 adds the Phase 63 guard and its PG17 tests, but the added manifest section still says the source candidate is Draft PR #255.
- Impact: The manifest misdirects future reviewers and release operators to the superseded candidate.
- Recommended correction: Update the candidate pointer to #258 in the feature PR before merge, preserving the fact that #255 was the predecessor if historical context is needed.
- Required regression test: documentation/source-reference check only; no database test.
- Dependency / owner: PR #258 owner.

### F-03 — PR #258 has green automated checks but no independent approval

- Severity: **High**
- Status: **Verified**
- Affected PR: #258.
- Evidence: Eight exact-head workflow runs succeeded on `8312c922...`; CI run `43853928921` reports the dedicated Phase 63 PG17 job successful. The complete CI job list has 19 successful jobs and one intentionally skipped canonical baseline/authenticated clinical acceptance job. The only submitted review is owner-authored COMMENTED; the inline review comment remains in the PR comment collection.
- Impact: CI validates automation, not independent SQL/security review, pharmacist workflow correctness, or clinical acceptance. A self-authored review cannot satisfy the independent-review gate.
- Recommended correction: Obtain a second-person review of the trigger, trigger column list, privileges/search path, migration integration and prescription save/print flows. Resolve the inline discussion only after its requested behavior and the `instructions` decision are evidenced.
- Required regression test: reviewer should verify exact-head PG17 tests plus the print-model and authorization tests; no new CI run is needed unless code changes.
- Dependency / owner: Repository owner to request an independent reviewer.

### F-04 — PR #179 and #257 remain non-authoritative for release

- Severity: **High**
- Status: **Verified**
- Evidence: #179 is 39 ahead / 34 behind main and diverged; #257 is four ahead / one behind and diverged. #258 is the current rebased candidate at seven ahead / zero behind.
- Impact: Merging #179 risks reintroducing overlapping prescription/pharmacy code from an old base. #257's execution-round report is a historical snapshot and must not override the newer #258 correction or backup evidence.
- Recommended correction: Keep both open until the successor is independently accepted and the owner explicitly approves closure/supersession documentation. Do not merge either branch.
- Required regression test: compare any proposed replacement to current main and re-run exact-head CI; no duplicate implementation.
- Dependency / owner: Repository owner/coordinator.

### F-05 — Latest backup run is blocked before dump; prior success is historical only

- Severity: **Critical release gate**
- Status: **Verified**
- Evidence: Backup runner main `f171732b61fe0460c61a36aa63b861065f9ea9d1`; latest run `43764265014` failed because neither `SUPABASE_DB_ACCESS_TOKEN` nor `SUPABASE_DB_PASSWORD` was available. Backup job skipped; no dump/artifact created. Latest full success is run `43183851731` on older runner SHA `eb7d8ae8...`.
- Impact: No current-run encrypted backup/restore evidence exists. Owner-side decryption/integrity verification of the retained 43183851731 artifact remains unproven. The backup is database-only and excludes Storage object bytes and Vault secrets.
- Recommended correction: Owner restores exactly one approved database credential directly in the backup-runner GitHub Secrets through the trusted settings UI; owner explicitly authorizes a new manual run; then owner verifies the exact resulting artifact offline. Never put secret values or the private AGE identity in chat, issues or source control.
- Required evidence: successful dump, isolated PostgreSQL 17 restore, integrity comparison, encryption and ciphertext-only upload; exact artifact SHA-256; offline decryption and archive listing; confirmation temporary plaintext was removed.
- Dependency / owner: Repository/backup owner.

### F-06 — Migration history remains non-linear across Production and QA

- Severity: **Critical release gate**
- Status: **Verified live**
- Evidence: Production 129 migrations (latest 20261102232941); QA 27 (latest 20261113232719). Three shared version IDs have conflicting names:
  - `20261102122437`: Production placeholder Phase 49 dispense; QA Phase 51 setup-required.
  - `20261102133658`: Production placeholder Phase 50 visit-bill; QA Phase 49 dispense.
  - `20261102133734`: Production placeholder Phase 51 setup-required; QA Phase 50 visit-bill.
- Impact: Migration ledgers are not a common linear history. A blind QA replay or ledger rewrite could mark the wrong source as applied or duplicate schema changes.
- Recommended correction: Separate environment-specific, forward-only reconciliation with SQL source fingerprints, live schema/function/ACL catalog comparisons, disposable PG17 replay and explicit approvals. Do not edit migration-history rows or reuse colliding versions.
- Required regression test: prove clean disposable PG17 baseline/upgrade paths for each environment-specific migration sequence and compare expected catalog fingerprints.
- Dependency / owner: Database/release coordinator; no hosted write authorized.

### F-07 — Main branch remains unprotected

- Severity: **High**
- Status: **Verified live**
- Evidence: main API reports `protected=false`, protection disabled, required status enforcement off, empty contexts; rulesets endpoint returns an empty array.
- Impact: Green checks are advisory and can be bypassed by direct pushes or merges without enforced review.
- Recommended correction: First implement and test an always-running aggregate PR gate that handles code, SQL, Spec Kit and docs-only paths. Only then configure PR-only, independent approval, last-push approval, stale-review dismissal, conversation resolution, strict checks, admin enforcement and no force-push/deletion.
- Required regression test: representative code-only, SQL-only and docs-only PRs must all produce the aggregate result; missing/failed/skipped required checks must fail closed.
- Dependency / owner: Repository owner/coordinator; Issue #253.

### F-08 — Human clinical and physical acceptance remains absent

- Severity: **Critical release gate**
- Status: **Not performed / not evidenced**
- Evidence: Issue #199 remains open; no authenticated pharmacist acceptance, physical A4/thermal print acceptance or staff UAT is evidenced. The canonical clinical acceptance CI job is intentionally skipped.
- Impact: The candidate is not yet accepted in the actual clinic workflow or on the target devices.
- Recommended correction: Complete the controlled synthetic-data acceptance below with the responsible human roles and record signed results. Do not use real patient data in test fixtures.
- Dependency / owner: Clinic owner and authorized pharmacist, prescriber, receptionist and lab staff.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| PR #258 exact-head PR workflows | Eight runs on `8312c92273d50d6eb9d8e700a2eebf89192bcf68` | **PASS** | All eight completed successfully |
| Repository CI job set | Run `43853928921` | **PASS with one SKIP** | 19 jobs successful; canonical PG17 baseline/authenticated clinical acceptance job intentionally skipped |
| Phase 63 PG17 integration | Job in run `43853928921` | **PASS** | Includes active→deleted invalid-field regression, ordinary soft delete, and legacy deleted-row behavior |
| PR #258 review gate | Review API + inline comment `4584207030` | **BLOCKED** | No independent approval; owner-authored COMMENTED review only |
| Backup/restore latest attempt | Runner run `43764265014` | **FAIL / BLOCKED** | Credential preflight; no dump or artifact |
| Prior backup/restore success | Runner run `43183851731` | **PASS — historical** | Older runner SHA; does not close latest-artifact owner decryption |
| Production/QA migration ledger read | Supabase `list_migrations` for both projects | **PASS — read-only** | 129 vs 27 rows; three shared version IDs have conflicting names |
| Main protection/rulesets | GitHub branch + rulesets GET | **PASS — read-only** | Protection false; no rulesets |
| Pharmacist browser acceptance | Not run | **NOT RUN** | Human authenticated acceptance required |
| Android/A4/thermal print acceptance | Not run | **NOT RUN** | Physical devices required |
| Staff end-to-end UAT | Not run | **NOT RUN** | Reception → GP → lab → pharmacy → billing |

### Owner checklist A — backup and restore

1. Open the backup-runner repository's GitHub Settings → Secrets and variables → Actions using the owner's authenticated session.
2. Restore exactly one approved database credential through the trusted UI; do not send the value to ChatGPT or place it in an issue/comment/commit.
3. Confirm the AGE recipient configuration is still valid without exposing the private identity.
4. Owner explicitly authorizes a new manual Production backup run. Do not dispatch from this review-only window.
5. Confirm the workflow completes database dump, isolated PostgreSQL 17 restore, integrity comparison, AGE encryption and ciphertext-only upload.
6. Record the exact run ID, artifact name, SHA-256 and byte size.
7. On the owner's trusted offline device, verify the exact artifact checksum, decrypt with the locally stored identity, list/validate the archive and confirm the temporary plaintext is securely removed.
8. Record that this is database-only; separately inventory Storage object bytes and Vault secrets if either becomes non-empty.

### Owner checklist B — authenticated QA pharmacist acceptance

Use synthetic patient/prescription data only and an approved QA pharmacist login. Record pass/fail for each:
- Pharmacist role can access only the intended branch and pharmacy actions; Doctor/Reception/Admin/Super Admin do not gain dispense authority through a generic permission bypass.
- Queue and saved prescription show the correct patient, prescriber, branch and status.
- Missing, NULL, zero, negative, fractional or out-of-range quantity fails closed; no fallback to quantity one.
- Free-text/unlinked medicine and invalid/missing required clinical fields cannot be dispensed.
- FEFO selection is correct for eligible batches; expired, quarantined or insufficient stock is rejected.
- Successful dispense creates the expected invoice/stock movement exactly once; retry with the same idempotency key does not double-dispense or double-bill.
- Rejected attempts leave stock, invoices, payments and prescription dispense state unchanged.
- Audit trail records actor, branch, prescription, quantities, selected batch and resulting transaction references.
- Capture only synthetic identifiers and safe pass/fail evidence; no patient-identifiable screenshots.

### Owner checklist C — physical prescription and document printing

- Android browser/mobile preview: verify layout at the actual clinic phone viewport and printer route.
- Arabic RTL and English LTR: verify mixed-language medicine names, numerals, dates, units and punctuation.
- A4 printer: verify page breaks, margins, font legibility, header/footer and no clipped fields.
- Thermal printer (if used operationally): verify width, wrapping, barcode/QR if present, and paper-cut boundary.
- Compare every printed field to the saved prescription record; no inferred or unsaved medication, dose, route, frequency, duration or quantity.
- Verify patient and prescriber identity, branch, date, status and any legally required clinic identifiers against owner-approved policy.
- Verify cancelled/soft-deleted/incomplete records cannot be presented as an official active prescription.
- Record printer model, paper size, Android/browser version, language mode, synthetic record ID and human pass/fail. Do not claim physical acceptance from a browser screenshot alone.

### Owner checklist D — staff workflow UAT

Run a single synthetic encounter across Reception → GP → Lab → Pharmacy → Billing:
- Reception registration/search and duplicate-patient handling.
- GP encounter, vitals, diagnosis and explicit prescription save.
- Lab order, specimen/result entry, verification and return to clinician.
- Pharmacist review, correction/rejection, FEFO dispense and stock audit.
- Invoice, payment and receipt; retry/idempotency and reversal behavior.
- Role/branch boundaries and audit trail at each handoff.
- Arabic/English usability on the actual Android device and network conditions.
- Signed acceptance or a reproducible defect list from each responsible role.

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-02/window-08.md` | New isolated Round 02 reconciliation and owner acceptance checklists | Recorded in PR commit metadata |

- Branch: `docs/parallel-release-reconciliation-window-08-round-02`
- Commit(s): created as one report-only commit
- PR: to be created after file verification
- Report file path: `docs/parallel-reports/round-02/window-08.md`
- Report commit SHA: available in the GitHub commit metadata; not self-embedded in its own content
- Delivery type: separate docs-only PR because this is a review-only window.
- No implementation change was appropriate: #258 is owned by the feature PR; the remaining trigger-field decision requires clinical/security reviewer judgement; backup, QA acceptance and branch protection require owner-controlled steps.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Secret or credential changes: **No**
- Backup dispatch: **No**
- PR merge / issue closure / release approval: **No**
- Branch protection/ruleset changes: **No**

## 9. Risks, dependencies, and owner decisions

1. **Critical — Backup:** owner must restore an approved credential and authorize a fresh manual backup; then verify the exact artifact offline.
2. **Critical — Migration provenance:** Production and QA require separate forward-only reconciliation; no blind ledger repair.
3. **Critical — Clinical acceptance:** authenticated QA pharmacist, prescriber, physical printing and staff UAT remain unperformed.
4. **High — Independent review:** PR #258 needs a second-person review and explicit resolution of the Phase 63 thread.
5. **Medium — Phase 63 archive payload:** decide whether `instructions` must be protected during soft deletion; test or document the policy.
6. **Low — Manifest accuracy:** update the Phase 63 source pointer from superseded #255 to #258.
7. **High — Governance:** build and verify the always-running aggregate PR gate before enabling main protection.
8. Keep #179 and #257 open until #258 is accepted and the owner explicitly approves closure/supersession.

## 10. Next action

The repository owner should request an independent clinical/security review of PR #258 at exact head `8312c922...`, specifically deciding the archive-time mutability of `instructions` and correcting the stale Phase 63 manifest pointer; then require a fresh exact-head validation only if code changes.

## 11. Session closeout

- Work completed in this session: live state rechecked; Phase 63 correction and exact-head PG17 evidence inspected; residual archive-payload and manifest findings recorded; owner backup/pharmacist/printer/UAT checklists prepared; isolated Round 02 report created.
- Work not completed: independent approval; any code change; owner backup credential setup/dispatch/decryption; authenticated pharmacist acceptance; physical print acceptance; staff UAT; migration reconciliation; branch protection.
- Exact current state at close: main remains `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; #258 remains Draft/open at `8312c922...`, seven ahead / zero behind, exact-head automated checks green with one intentional CI skip; Production NO-GO.
- Recommended continuation when the owner says **"أكمل"**: recheck this report PR and current #258/backup/acceptance evidence; do not repeat the completed Round 02 audit. Continue only the next owner-authorized action and create a new Round 03 report file if another meaningful session is required.
