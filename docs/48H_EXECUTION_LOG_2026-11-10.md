# 48-Hour Accelerated Execution — H0 Baseline and Work Ledger

**Sprint start (H0):** 2026-11-10 09:09:08 Africa/Khartoum (UTC+02:00)  
**48-hour decision deadline:** 2026-11-12 09:09:08 Africa/Khartoum  
**Main baseline:** `bed6ff4c87d582107bf62ee353be4eb35958481b`  
**Charter:** [48H_ACCELERATED_EXECUTION_CHARTER.md](48H_ACCELERATED_EXECUTION_CHARTER.md)  
**Constitution:** Spec Kit Constitution v1.1.0  
**Currency invariant:** SDG only.

## 1. Measurement rule

This ledger measures the remaining launch-critical work required to produce an evidence-backed Engineering Release Candidate. It is **not** a percentage of all historical product features and must not be compared directly with earlier broad project estimates. Each workstream is weighted by release risk and effort; completion credit requires evidence, not the existence of a PR or a green source-only test.

Formula: `sum(workstream weight × evidence-backed completion)`.

## 2. H0 engineering baseline

| Workstream | Weight | H0 completion | Evidence at H0 | Main remaining work |
|---|---:|---:|---|---|
| A. Orchestration, scope, evidence | 10% | 90% | Charter merged to main; six streams and stop rules ratified; current main and PR heads inspected; fresh live migration inventory captured | Maintain deduplicated task ledger, exact-head checks, evidence index and decision log |
| B. Pharmacy + medicine catalogue | 20% | 55% | Phase 57 source candidate and PG17 regression suite passed on prior code head; Phase 56 identity editor and stale-pack-ack invalidation tests exist | Independent review; free-text remediation and external-prescription behavior; role scope; durable pack-verification audit; authenticated pharmacist acceptance |
| C. SDG finance + receipts | 20% | 60% | Phase 58/59 candidate SQL and PG17 tests passed on prior code head; receipt model blocks missing/mismatched persisted currency | Independent SQL/ACL review; receipt UI integration and exact-head tests; explicit legacy-NULL governance; authenticated finance acceptance |
| D. Migration provenance + security | 25% | 25% | Read-only Production/QA ledgers and catalog/security inventories captured; no public table is missing RLS | Reconcile source-to-ledger history and effective catalog; function-by-function SECURITY DEFINER review; define a safe forward-only release sequence |
| E. Mobile, bilingual UX, printing | 10% | 30% | Pharmacy queue and receipt UI candidates; automated receipt-model and RTL/LTR source coverage | Browser/mobile validation, role/branch journeys, actual A4 printer acceptance; no physical-device evidence yet |
| F. QA, recovery, release decision | 15% | 20% | Candidate CI/PG17 tests passed on pre-sync heads; encrypted database backup, restore rehearsal, owner-side decrypt/archive readability previously evidenced | Re-run exact-head CI after branch synchronization; authenticated QA, staff UAT, current recovery evidence, residual-risk and rollback review |

**Weighted Engineering RC baseline: 44.25% (reported as 44%).**

The baseline intentionally gives low credit where code exists but independent review, hosted QA acceptance, or source reconciliation is still missing. A successful CI run on an earlier commit does not automatically validate a later merge/synchronization commit.

## 3. Separate operational-acceptance baseline

This is a different denominator from Engineering RC progress.

| Acceptance gate | Weight | H0 completion | Evidence / gap |
|---|---:|---:|---|
| Authenticated role/branch QA acceptance | 25% | 0% | No completed authenticated receptionist/GP/lab/pharmacist/finance acceptance record |
| Real staff workflow UAT | 25% | 0% | Reception → GP → lab → pharmacy → billing staff sign-off not evidenced |
| Android/browser/RTL/LTR and physical printing | 20% | 0% | Source and automated checks exist; target-device and physical A4/thermal acceptance not evidenced |
| Backup and recovery | 15% | 70% | PostgreSQL 17 restore rehearsal and owner-side encrypted archive decryption/readability passed; Storage/Vault are excluded, and the latest portable helper has not had a full end-to-end run |
| Production migration/release authorization | 15% | 0% | Production and QA migration ledgers remain unreconciled; no current production rollout approval |

**Weighted operational-acceptance baseline: 10.5% (reported as 11%).**

This does not mean that only 11% of the software exists. It means that independently witnessed operational acceptance is deliberately stricter than implementation progress.

## 4. Live technical baseline — read-only, 2026-11-10

### Supabase migrations and schema
- Production project `jewzonxplxhogqrnhosl`: 129 migration-ledger rows; latest `20261102232941`.
- QA project `hopfohcnrtbiqjkgeukz`: 22 migration-ledger rows; latest `20261104065852`.
- The environments share only three version IDs; all three shared IDs have different names and stored statement fingerprints. Production-only: 126; QA-only: 19.
- Both environments have 56 public tables, 842 public columns, RLS enabled on all 56 public tables, and 210 public RLS policies.
- QA already contains the Phase 57 quantity guard; Production still has the old dispense function with a NULL-to-one fallback. Phase 57 is not authorized for Production rollout by this sprint.
- **Never** replay the QA migration, edit migration-ledger rows, or force the environments to look identical. Recover and map source/effective catalog first.

### Security inventory
- Current read-only inventory: 94 SECURITY DEFINER functions/procedures across public+private in Production and 96 in QA. The public-schema counts remain 53 Production / 55 QA; public authenticated EXECUTE counts remain 26 / 28.
- The only public-schema anon-executable SECURITY DEFINER function is `public.setup_required()`, the documented first-run boolean signal. Production additionally has anon EXECUTE grants on two private helpers, but anon has no USAGE on the private schema; treat these as ACL cleanup/review items, not evidence of an exposed API.
- Eighteen Production public SECURITY DEFINER functions use `search_path=public` or `public, pg_temp`; sampled functions are trigger/service helpers and are not directly executable by anon/authenticated. Review individually; do not bulk-revoke or bulk-rewrite.
- Leaked-password protection remains disabled in both Supabase projects. Any Auth configuration change is a separate approval gate.

### Candidate pull requests at H0
- [PR #214](https://github.com/crauch2088-source/roshan-health-hub/pull/214): charter and Constitution v1.1.0; merged to main as `bed6ff4c87d582107bf62ee353be4eb35958481b`.
- [PR #209](https://github.com/crauch2088-source/roshan-health-hub/pull/209): Phase 57 pharmacy quantity guard/UI. Prior exact code head passed PG17 and aggregate CI; current main-sync head requires its own checks. QA already has the SQL guard; Production does not.
- [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210): medicine catalogue identity editor. Stale physical-pack acknowledgement is invalidated on identity edits and regression-tested. Shared-catalogue role scope and durable audit attestation remain open.
- [PR #211](https://github.com/crauch2088-source/roshan-health-hub/pull/211): Phase 58/59 SDG provenance and receipt integrity. Prior exact code head passed PG17/aggregate CI; current synchronization head requires its own checks and mergeability recheck.
- [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181): persisted payment receipt UI; dependent on Phase 58/59 and real print acceptance.
- [PR #179](https://github.com/crauch2088-source/roshan-health-hub/pull/179): saved-prescription printing; browser/Android and physical printer acceptance remain open.
- [PR #213](https://github.com/crauch2088-source/roshan-health-hub/pull/213): backup destination documentation; no new backup dispatch is authorized by this charter.
- [PR #185](https://github.com/crauch2088-source/roshan-health-hub/pull/185) and [PR #112](https://github.com/crauch2088-source/roshan-health-hub/pull/112): clinical decision-support specification and broad UX modernization; defer non-launch-critical expansion until the RC gates are closed.

## 5. H0 stop-ship findings and owner decisions

1. **P0 — Production dispensing:** Production still defaults a NULL prescription quantity to one unit. No Production dispensing release until the guard is independently reviewed, QA pharmacist acceptance is evidenced, and a separately approved forward-only rollout is prepared.
2. **P0 — Migration provenance:** Production/QA histories are materially divergent. No Production migration may be applied until the exact source/effective-catalog map and recovery plan are reconciled.
3. **P1 — Pharmacy remediation:** PR #209 blocks the whole prescription if any active line is free text/unlinked. The queue needs an actionable prescriber correction path; the treatment of `is_external` prescriptions must be explicit and tested.
4. **P1 — Medicine catalogue governance:** PR #210's client acknowledgement is not a durable verification record. The catalogue is shared across branches (no `medicines.branch_id`), so identity and pack verification need distinct, deliberate scope/audit rules.
5. **P1 — SDG receipt provenance:** new financial records must persist SDG and official receipt/reprint must never infer historical currency from mutable settings. Legacy NULLs remain non-printable unless a separate owner-approved privileged reconciliation migration is ever proposed.
6. **External acceptance:** staff, clinician, pharmacist, finance, target Android/browser and actual printer acceptance cannot be synthesized by CI.

## 6. Actions already taken after H0

- Constitution v1.1.0 and the 48-hour charter merged to main.
- Phase 57 and Phase 56 branches were synchronized with the ratified charter/main baseline using normal merge commits; their new exact-head CI is running.
- Phase 58/59 branch received a normal two-parent synchronization commit; its new exact-head CI is queued and mergeability is being rechecked.
- Added review comments to PR #209 describing the unlinked/free-text correction dead-end and the need to define `is_external` handling.
- Added a clarification to PR #211: ordinary application roles cannot alter historical currency; any future legacy reconciliation must be a separate owner-approved privileged forward migration with evidence, audit, pre/post counts and recovery plan.
- Re-ran read-only Production/QA migration and SECURITY DEFINER inventories. No hosted database was changed.

## 7. Sprint exit and reporting

- H48 outcome must be Engineering RC complete, blocked RC, or no-go under the charter.
- Report Engineering RC and operational acceptance as separate percentages.
- Every status update must identify exact commit/head, tests, skipped checks, external dependencies, and remaining time.
- No Production DDL/DML, migration application, permission/Auth/Storage changes, business-data writes, deployment promotion, or backup dispatch is authorized by this baseline.


## Run 7 exact-head and release-gate recheck — 2026-11-10

**Repository baseline:** main `bed6ff4c87d582107bf62ee353be4eb35958481b`; H0 evidence branch parent `5c7a44e9c272642abf8f9799fc03b7ddf9346f89`. Main has one open release issue (#199) and 12 open PRs. No PR was merged in this run.

### Exact-head checks

- Main CI [42772781756](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772781756), Spec Kit [42772781055](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772781055), and finance-only RPC integration [42772781054](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772781054): all successful.
- PR #209 head `ac1654d87da9596bba4818e5b7c7914ee9fa808c`: CI [42772961672](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772961672), PR validation [42772955862](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772955862), and prescription/role/insurance integrations [42772961503](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772961503), [42772961447](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772961447), [42772961613](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772961613), [42772961425](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772961425): all successful. PR remains Draft; authenticated pharmacist acceptance is not inferred.
- PR #210 head `3d748929725b766c13da9838aa1c950ae97b4bba`: CI [42772978377](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772978377), PR validation [42772970400](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772970400), and supporting integrations [42772978173](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772978173), [42772978307](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772978307), [42772978519](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772978519), [42772978726](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772978726): all successful. The stale pack acknowledgement is now invalidated on all six identity-field edits and regression-tested. Shared-catalogue role scope and durable attestation remain open.
- PR #211 head `da77cd4608bb9e01bdc5d710f85f305f77b23945`: CI [42773043285](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043285), PR validation [42773035484](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773035484), historical migration hash check [42773043370](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043370), finance/security/insurance/prescription integrations [42773043148](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043148), [42773043391](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043391), [42773043401](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043401), [42773043136](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043136), [42773043119](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043119), [42773043358](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043358), [42773043472](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043472), and Spec Kit [42773043355](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773043355): all successful. PR remains Draft pending independent SQL/security review and legacy-NULL policy.
- H0 ledger PR #215 head `5c7a44e9c272642abf8f9799fc03b7ddf9346f89`: CI [42773394528](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773394528) and PR validation [42773390535](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42773390535): successful.

### Live release gates

- Production/QA ledger metadata: 129 / 22 rows; only 3 shared version IDs, all mismatched. Five cross-version statement-fingerprint pairs are now documented (Phases 46/47/48/50/52); see the linked source-map report and JSON snapshot. This is not full source or effective-catalog parity.
- Phase 57: QA applied at `20261104065852`; Production not applied. Production function retains NULL-to-one fallback; QA explicitly rejects NULL. Quantity column remains nullable in both; active NULL item count is zero in both.
- Supabase advisors: health findings 0/0. Security: Production 2 private RLS/no-policy INFO, 1 public extension WARN, 1 anon SECURITY DEFINER WARN, 26 authenticated SECURITY DEFINER WARN, 1 leaked-password WARN; QA 1, 1, 1, 28, 1 respectively. Performance: Production 2 unindexed-FK INFO + 94 unused-index INFO; QA 142 unused-index INFO and no unindexed-FK finding. No ACL, Auth, extension or index change.
- Vercel Production alias remains READY on deployment `dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv`, application SHA `6daf1f15be23aa391bd40bc38f671c00c842b446`, `aliasError=null`. Main changes since that app SHA are non-runtime documentation/CI/spec changes; no deployment was promoted.
- Backup runner main `ed41574bb278325e7bc06fd034e767db1544c55a`. Latest run [42537677251](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42537677251) passed validation but skipped backup and produced no artifact. Latest full run [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) passed PostgreSQL 17 dump, isolated restore, row-count comparison, age encryption and ciphertext upload on prior PR #2 code. GitHub artifact expired; the encrypted Drive copy remains present in the verified canonical folder and owner-device decryption/archive-readability was previously verified. A new full run using current main's portable checksum helper remains unverified; no backup was dispatched.

### Safety and next task

No Production/QA writes, migration application, business-data reads/writes, permission/Auth/Storage mutation, backup dispatch, PR merge or deployment promotion occurred. Clinical E2E remains deferred until the isolated free environment and suitable synthetic doctor/pharmacist identities exist.

**Next P0:** complete the 129/22 source-to-effective-catalog map and independently review the remaining unmapped/redacted migration evidence. The quarantined rename and parameterized cleanup fixtures already pass; PR #216 hardens their negative cases. The original `20261102232941` SQL remains unavailable, so no fixture may claim to certify the original statement. Keep Production blocked.


## Post-H0 verified deltas — 2026-11-10

- PR #216 commit `1b2a81e807b0c867bef3742794f2c15e4f1af536` adds negative PG17 cases to the existing quarantined Phase 49 fixture. Exact-head CI [42774855081](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855081) completed successfully: 18 jobs succeeded, one authenticated clinical-acceptance job was intentionally skipped, and the Phase 49 quarantined-remediation job passed. The fixture does not execute the redacted original cleanup SQL.
- Independent review of PR #211 found that Phase 54 identifies `insurance_claim_payment` as a cashbox source while Phase 58 intentionally defers insurance currency provenance. PR #211 was updated at commit `6d2440381e78710fc5579598ff7684b1909884a8` to reject new cashbox rows with this deferred source type (SQLSTATE 23514), with a PG17 regression. In CI run [42775216135](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216135), the Phase 58 and Phase 59 PostgreSQL 17 jobs passed. The overall CI and insurance UI validation were still running at this snapshot; no overall pass is claimed.
- The next P0 remains current source/effective-catalog reconciliation. Phase 57 remains QA-only; Production retains the NULL-to-one dispensing fallback.


## Run 7 final completion record — 2026-11-10

- PR #216 head `1b2a81e807b0c867bef3742794f2c15e4f1af536`: CI [42774855081](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855081) completed with 18 successful jobs and one intentional clinical-acceptance skip. The `Phase 49 quarantined remediation contracts (PostgreSQL 17)` job passed. PR validation [42774852127](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774852127) and prescription/insurance/role integrations [42774855005](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855005), [42774855064](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855064), [42774855065](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855065) passed.
- PR #211 head `6d2440381e78710fc5579598ff7684b1909884a8`: CI [42775216135](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216135) completed with 20 successful jobs and one intentional clinical-acceptance skip. Phase 58 and Phase 59 PostgreSQL 17 jobs passed; insurance UI [42775216669](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216669), finance-only RPC [42775216157](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216157), security candidate bundle [42775216066](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216066), historical migration source check [42775216129](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216129), Spec Kit [42775216527](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216527), and PR validation [42775210843](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775210843) passed. Phase58/59 remain candidate-only and are not applied to QA or Production.
- PR #215 prior head `5e571000e1c8b15bd7e2c876eca737fbef7de5dc` passed CI [42775366974](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775366974) and PR validation [42775363102](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775363102). This final log update is a new docs-only commit and will receive its own check run.
- The existing encrypted archive is confirmed in Drive: root folder **Roshan Health Hub - Encrypted Backups** (`1m-1JA2yT_NZxo0Drb4qGjyd24UW_Mta5`), dated child **2026-11-09** (`14q8YQbDddwzJ1tEyM0t8bK9f5ExRezF7`), file **Roshan-Production-Backup-2026-11-08.zip** (`1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv`), 305,317 bytes, Drive MD5 `875a85ac23e8b7a671c371cca41f7732`, `trashed=false`, owned by the connected account. The separate legacy folder **Roshan Health Hub Backups** (`1ak6tu379LSxfmjioeQsxUN5eJ_FWitd6`) is empty and is not the archive parent. Draft PR #213 records the canonical destination correction.
- Backup runner main remains `ed41574bb278325e7bc06fd034e767db1544c55a`. The latest run `42537677251` only validated and skipped backup; the previous full run `42535939237` passed dump, PostgreSQL 17 restore, row-count comparison, age encryption and ciphertext upload. Its GitHub artifact expired, but the Drive copy and owner-device decryption/archive-readability evidence remain. A full backup using the current main checksum helper remains unverified.

**Next P0:** complete current 129/22 source-to-ledger and effective-catalog reconciliation. Keep Phase 57 unapplied in Production until this is complete and the backup/current-runner evidence is refreshed. Keep clinical E2E deferred until the isolated free environment and synthetic doctor/pharmacist identities exist.


## H+1 execution update — 2026-11-10 10:07:34 Africa/Khartoum

**Elapsed:** 00:58:26. **Remaining to H48 decision deadline:** 47:01:34. **Main baseline remains:** `bed6ff4c87d582107bf62ee353be4eb35958481b`.

### Revised evidence-weighted Engineering RC estimate

| Workstream | Weight | H+1 completion | Evidence-backed reason | Remaining blockers |
|---|---:|---:|---|---|
| A. Orchestration, scope, evidence | 10% | 95% | Charter and Constitution v1.1.0 merged; H0 ledger and exact-head tracking documented; live-state and candidate PRs continuously checked | Keep decision/evidence log current; merge the H0 ledger documentation after review |
| B. Pharmacy + medicine catalogue | 20% | 65% | PR #209 Phase57 quantity + external-prescription guards passed all five workflows; PR #210 Phase60 role/attestation candidate passed all five workflows including dedicated PG17 behavioral role tests | Actionable free-text/unlinked prescription correction path; independent security review; QA pharmacist acceptance; decide separately whether INSERT/medicine creation should share the same three-role restriction |
| C. SDG finance + receipts | 20% | 60% | Phase58/59 candidate previously passed ten workflows; new Phase59 metadata-redaction hardening and cross-branch PG17 regression are in a fresh exact-head run | Finish new CI; independent SQL review; receipt UI integration and print acceptance; migration-history reconciliation; authenticated finance QA |
| D. Migration provenance + security | 25% | 25% | Production/QA ledgers and SECURITY DEFINER inventories remain captured read-only; no broad RLS gaps discovered | Material ledger divergence remains unresolved; individual function/ACL review and forward-only rollout design remain mandatory |
| E. Mobile, bilingual UX, printing | 10% | 30% | Receipt and prescription print candidates exist; RTL/LTR automated coverage remains available | Real Android/browser workflow, A4/thermal printer, and staff acceptance are not evidenced |
| F. QA, recovery, release decision | 15% | 20% | PG17 candidate checks are expanding; encrypted DB backup/restore and owner-side archive readability were previously evidenced | Latest portable backup helper E2E run; Storage/Vault recovery; authenticated QA; clinical/staff UAT; rollback/release decision |

**Weighted Engineering RC progress: 46.75% (reported as 47%), up from the H0 44.25% (44%).** This denominator measures launch-critical Engineering RC evidence only, not all product features.

**Operational acceptance remains 10.5% (reported as 11%)** on its separate denominator. No authenticated staff/clinician/pharmacist/finance sign-off, target-device acceptance, physical printer acceptance, or production rollout approval has been added.

### Exact candidate-head evidence

- PR #209 current candidate head `48fc38e867e6f1387881862e9ab806b93cda6c9c`: all five PR-triggered workflows passed, including PG17 dispense/invoice integration and UI validation. External prescriptions are now rejected before stock/invoice mutation. The free-text correction path remains open.
- PR #210 current candidate head `a7bf975247cbfbd5b67512e291af717b08402344`: all five PR-triggered workflows passed, including aggregate install/audit/typecheck/lint/build and the dedicated Phase60 PG17 behavioral test. The test verifies Admin, Pharmacist, Legacy Admin and Super Admin behavior, actor-bound attestations, audit rows, and UPDATE/DELETE/TRUNCATE rejection.
- PR #211 current candidate head `9a35bddd1669c836137e0f54767d0f8094e43b82`: Phase59 receipt metadata redaction was added after independent review; exact-head CI is running again. The previous synchronized candidate head `c4600dbdd042afcc489ca7d4b3bf07ff7f380155` had all ten workflows successful.
- PRs #209, #210 and #211 remain Draft. No candidate migration has been applied to hosted QA or Production; no live role mapping, business data, Auth/Storage settings, or deployment promotion was changed.

### H+1 stop-ship status

1. Production dispensing still has the NULL quantity → one-unit fallback; do not release dispensing changes to Production before approved forward-only migration and QA pharmacist acceptance.
2. Production/QA migration histories remain materially divergent; no hosted migration application is authorized.
3. Free-text prescription items fail closed but still lack an actionable prescriber correction loop.
4. Phase60 controls **editing** existing shared medicine identity; medicine INSERT remains on the existing `pharmacy.create` role map pending a separate owner decision. No live role mapping was changed.
5. Phase59 mismatch metadata redaction is under exact-head PG17/CI revalidation.
6. Staff UAT, authenticated role acceptance, Android/browser acceptance, and physical printer acceptance remain external gates.

**Safety boundary unchanged:** H48 targets an evidence-backed Engineering RC. It does not authorize Production DDL/DML, migration application, Auth/Storage/permission changes, business-data writes, deployment promotion, or backup dispatch.


## H+2 security review update — 2026-11-10 10:10:47 Africa/Khartoum

A second read-only pass classified every public-schema SECURITY DEFINER function executable by `authenticated` in both environments:

- Production: 26 functions; QA: 28 functions.
- In each environment, all but two contain an explicit permission, authenticated-actor, branch, or Super Admin check in their own body.
- The two low-signal exceptions were individually inspected: `complete_visit_atomic(uuid)` is a thin wrapper around `complete_clinical_visit_and_bill(uuid)`, which enforces `visits.update`, current application actor, and visit/patient branch binding; `setup_required()` is the documented first-run boolean signal, with an empty search path.
- Therefore the 26/28 advisor warnings do **not** justify bulk revocation. Continue per-function review and preserve the deliberate setup signal.

This adds evidence to workstream D; the migration-history divergence and the separate 18 Production public functions using `search_path=public` or `public, pg_temp` (not directly executable by anon/authenticated) remain to be reconciled/reviewed individually.

### H+2 revised weighted estimate

| Workstream | Weight | H+2 completion |
|---|---:|---:|
| A. Orchestration, scope, evidence | 10% | 95% |
| B. Pharmacy + medicine catalogue | 20% | 65% |
| C. SDG finance + receipts | 20% | 60% |
| D. Migration provenance + security | 25% | 30% |
| E. Mobile, bilingual UX, printing | 10% | 30% |
| F. QA, recovery, release decision | 15% | 20% |

**Weighted Engineering RC progress: 48.0% (reported as 48%).** Operational acceptance remains **10.5% (reported as 11%)**; no external acceptance evidence has changed.

At this timestamp, PR #209 head `48fc38e867e6f1387881862e9ab806b93cda6c9c` and PR #210 head `a7bf975247cbfbd5b67512e291af717b08402344` each have all five workflows successful. PR #211 head `18eba21018d7314cf1a44d5f3a6024ede429c2cd` is re-running after the Phase59 cross-branch metadata-redaction fix and a source-test formatting correction; its Phase59 PostgreSQL 17 behavioral test passed on the preceding candidate head. PR #215 documentation CI is in progress.

**Time:** elapsed 01:01:39; remaining 46:58:21 to the H48 decision deadline. No hosted DB, live permission map, business data, Auth/Storage setting, or deployment was changed.


## 8. Progress update — 2026-11-10, after H0

### Evidence-backed Engineering RC recalculation

The denominator and workstream weights are unchanged. Credit is updated only where an exact code head has passed its relevant automated checks.

| Workstream | Weight | H0 | Current | New evidence | Remaining release-critical gap |
|---|---:|---:|---:|---|---|
| A. Orchestration, scope, evidence | 10% | 90% | 90% | Charter/constitution and H0 evidence ledger remain current | Keep exact-head evidence and stop rules current |
| B. Pharmacy + medicine catalogue | 20% | 55% | 65% | PR #209 exact code head 48fc38e passed all five reported workflows; PR #210 exact code head a7bf975 passed all five reported workflows, including the dedicated Phase 60 PostgreSQL 17 authority/attestation job | Independent clinical/security review; actionable prescriber correction for free-text/unlinked items; pharmacist acceptance |
| C. SDG finance + receipts | 20% | 60% | 70% | PR #211 code head 7e7b610 passed 20 CI jobs, including Phase 58 and Phase 59 PostgreSQL 17; added fail-closed cashbox source-discriminator regression | Independent SQL/ACL review; receipt UI exact-head integration and print acceptance; legacy NULL governance; finance acceptance |
| D. Migration provenance + security | 25% | 25% | 25% | Current 129/22 ledger and source-mapping evidence remains documented; source-parity CI passed | Complete per-row source mapping and effective catalog/function/ACL reconciliation; no hosted rollout before this |
| E. Mobile, bilingual UX, printing | 10% | 30% | 30% | Existing automated RTL/LTR and print model evidence unchanged | Browser/mobile journeys, actual A4/thermal print, staff workflow acceptance |
| F. QA, recovery, release decision | 15% | 20% | 25% | Exact candidate CI/PG17 evidence improved; Phase 58/59 and Phase 60 integration jobs passed | Authenticated QA and staff acceptance; latest full backup-helper run; Storage/Vault scope and rollback/release review |

**Current weighted Engineering RC estimate: 49%** (from 44.25% at H0). This is a measured sprint workstream estimate, not a claim that 49% of the whole product exists or that the clinic is launch-ready.

**Operational-acceptance estimate remains 10.5% (11%).** No authenticated role/branch acceptance, real staff UAT, target Android/browser/physical-printer sign-off, or Production migration authorization has been evidenced since H0.

### Exact-head test evidence

- PR #209, code head 48fc38e867e6f1387881862e9ab806b93cda6c9c: all five reported workflows completed successfully. The candidate rejects NULL/invalid quantities and external prescriptions from internal stock dispensing. Free-text/unlinked prescription items still block the whole order; the prescriber correction workflow is not yet implemented.
- PR #210, code head a7bf975247cbfbd5b67512e291af717b08402344: all five reported workflows completed successfully. Its dedicated Phase 60 PostgreSQL 17 job passed. Identity editing and physical-pack verification now use separate permissions; verification is an append-only, audited event bound to the saved identity snapshot. PR remains Draft.
- PR #211, code head 7e7b610f9ef2d99534e0f06d39fb1a1424865b22: workflow 42781299925 completed with 20 successes, zero failures, and one intentional skip for canonical baseline/authenticated clinical acceptance. Phase 58 and Phase 59 PostgreSQL 17 jobs passed. A follow-up documentation-only commit was added after this tested code head; verify its current PR head before merge. PR remains Draft.
- The first source-discriminator test run failed because the generic cashbox test fixture attempted to create an untyped new row. The fixture was corrected to use the valid manual source; the guard was not weakened. The corrected exact code head passed the Phase 58 PostgreSQL 17 job.
- No candidate PR above has been merged. No Production or QA database was changed by this sprint update. No Auth, Storage, permissions, deployment, or business-data writes were performed.

### Updated execution priorities

1. Complete independent review of PRs #209, #210 and #211; preserve Draft state until the findings are closed.
2. Define a safe, auditable prescriber correction path for free-text/unlinked prescription items. Do not auto-link by fuzzy name or silently drop an item.
3. Complete current live migration source/effective-catalog reconciliation; the 129-row Production and 22-row QA histories remain divergent and are not repairable by replaying either ledger.
4. Integrate and validate receipt UI PR #181 only against the Phase 58/59 contract; legacy NULL currency must remain non-printable.
5. Obtain real authenticated pharmacist/doctor/finance acceptance, staff workflow UAT, target Android/browser checks and physical printer evidence.
6. Keep Production read-only until source reconciliation, recovery gates and separate explicit rollout authorization are complete.

**Sprint clock:** H0 2026-11-10 09:09:08 Africa/Khartoum; H48 deadline 2026-11-12 09:09:08 Africa/Khartoum. At the 10:11 local checkpoint, 46h 58m remained. The sprint exit remains Engineering RC complete, blocked RC, or no-go; operational acceptance is a separate decision.


## 9. Progress update — 2026-11-10, exact-head review checkpoint

### Current candidate evidence

- **PR #209 — pharmacy quantity/external-prescription guard:** code head 48fc38e867e6f1387881862e9ab806b93cda6c9c. CI run 42778194392: 18 successful jobs, zero failures, one intentional skip for authenticated clinical acceptance. Vercel preview status is successful. The candidate blocks invalid/NULL quantities and external prescriptions from internal dispensing. Free-text/unlinked items still fail closed; the correction workflow is tracked separately in Issue #217.
- **PR #210 — shared medicine identity and physical-pack attestation:** code head 324a2cb479380aab58e81bad1e695e998852e20d. CI run 42782438963: 19 successful jobs, zero failures, one intentional skip. The Phase 60 PostgreSQL 17 job passed after the candidate added an idempotent medicine row-audit trigger for clean v112 baseline replay, asserted exactly one dedicated UPDATE policy, and tested that direct writes/trigger-guard execution are unavailable to application/service roles. Vercel preview returned build-rate-limit failure; this is not a code-test failure and no Production deployment occurred.
- **PR #211 — single-SDG provenance and receipt integrity:** code head faec5ddd9fdec54081332628ab037a2f7e770243. CI run 42783350744: 20 successful jobs, zero failures, one intentional skip. Phase 58 and Phase 59 PostgreSQL 17 jobs passed. Cashbox source types are fail-closed; trigger-only currency enforcement is not directly executable by PUBLIC/anon/authenticated/service_role; receipt-status RPC is executable only by authenticated. A documentation-only follow-up commit was added after this tested code head; recheck current PR head before any merge. Vercel preview returned build-rate-limit failure; no Production deployment or hosted DB change occurred.
- **PR #181 — saved receipt UI:** its earlier exact-head CI run 42596877669 passed 18 jobs with one intentional authenticated-acceptance skip. It still needs cross-contract verification against the latest Phase 58/59 exact code, browser/mobile testing and physical print acceptance; it is not a substitute for the financial source migration.
- **Issue #217** now tracks the auditable pharmacist-to-prescriber correction workflow for free-text/unlinked prescription items, with strict no-fuzzy-linking/no-stock-or-invoice-side-effects acceptance criteria.

### Current release interpretation

The weighted Engineering RC estimate remains **49%**; the operational-acceptance estimate remains **11%**. Automated evidence is improving, but the remaining work is disproportionately in high-risk reconciliation and real-world acceptance rather than ordinary feature coding.

Current estimated time to a defensible, explicitly qualified Engineering RC: **24–40 hours**, conditional on completing the migration source/effective-catalog reconciliation and closing independent reviews. This is an estimate, not a promise. Initial operational acceptance remains a separate, likely **1–3 week** process because real pharmacist/doctor/finance sign-off, staff UAT, Android/browser and physical printer checks cannot be replaced by CI.

### Vercel/free-build discipline

The repeated candidate commits caused Vercel preview checks on PR #210 and PR #211 to return the platform's build-rate-limit status. These are preview checks only; the GitHub Actions suites are green and no Production deployment was attempted. Avoid further nonessential commits, rebases or preview-triggering updates. Batch remaining documentation changes and do not spend additional free build capacity on cosmetic iterations.

### Non-negotiable boundary

All three candidate PRs remain Draft. Do not merge, apply migrations, alter Auth/Storage/roles, reconcile migration history by replay, or promote a deployment until independent review, source/effective-catalog reconciliation, backup/recovery evidence and the applicable human acceptance gates are satisfied.


## Parallel review checkpoint — 2026-11-10

- PR #209 exact head `48fc38e867e6f1387881862e9ab806b93cda6c9c`: five of five PR workflows successful.
- PR #210 follow-up exact head `7e64287d754f737e9e82a05e27279ccecf90c595`: a regression fix now clears pending physical-pack confirmation after every identity-field edit. The immediately preceding head `324a2cb479380aab58e81bad1e695e998852e20d` passed five of five workflows. The latest follow-up head has no visible PR-triggered workflow run through the connected status endpoint at this checkpoint; do not claim the fix is validated until a workflow run or equivalent full test execution is evidenced.
- PR #211 exact head `2b0e35bb2bbff585f4a9942709bc39f842d5855e`: ten of ten PR workflows successful, including Phase58/59 PostgreSQL17 and finance/security/source/Spec Kit checks.
- PR #181 exact head `00f09d956c0632d6e193e4864bdb0401b092b09a`: eight of eight PR workflows successful. Its body now explicitly records the Phase58/59 dependency and fail-closed handling of legacy NULL/mismatched currency. Browser/mobile/physical printing and authenticated finance acceptance remain pending.
- PR #215 documentation baseline merged; its exact head `8f0e3073aa222d25197354c4ab7d780df91986d8` had successful CI.
- Vercel previews for PR #210 and #211 continue to report free-plan build-rate-limit status. Do not spend additional preview capacity on cosmetic changes.

A fresh SELECT-only query against both hosted projects reconfirmed Production migration ledger 129 rows/latest `20261102232941` and QA 22 rows/latest `20261104065852`. Neither project currently has `currency_code` on the seven Phase58 financial tables. A whitespace-normalized function-definition check reconfirmed Production still contains the `COALESCE(pi.quantity,1)` fallback and lacks explicit NULL rejection, while QA has explicit NULL rejection and no fallback. The initial whitespace-sensitive probe was inconclusive and was discarded; only the normalized result is authoritative for this checkpoint.

The weighted Engineering RC estimate remains **49%**; operational acceptance remains **11%**. The PR #210 UI correction is not credited until exact-head CI passes. No live DDL/DML, migration, permission, Auth/Storage, business-data, deployment or backup operation occurred. Full details: [48H_PARALLEL_REVIEW_2026-11-10.md](48H_PARALLEL_REVIEW_2026-11-10.md).


### Backup-runner review delta — 2026-11-10

- Corrected the private backup-runner README to target the canonical Drive folder **Roshan Health Hub - Encrypted Backups** and identify **Roshan Health Hub Backups** as the legacy empty folder.
- Removed the unconditional shell-level `PGOPTIONS=-c jit=true` override so only the URL builder controls the temporary-token JIT option; database-password fallback remains without the token-only option.
- Added Python regression tests for credential mode and shell option isolation. Static source inspection passed, but a fresh validation-only Actions run has not yet executed these tests. No backup was dispatched.
- This improves documentation and connection-mode correctness but does not change the previously reported backup/recovery acceptance score until the test suite and current-runner end-to-end rehearsal pass.

### H+13 — Phase 61 database backend and Phase 57 mainline recovery — 2026-11-10

- Phase 61 exact candidate head `763985fafe52c83ca65b808ec67c50569ed35752`: **30/30 checks passed**, zero failures; one canonical authenticated clinical-acceptance gate intentionally skipped. The PostgreSQL 17 correction workflow test passed after two genuine regressions were found and fixed: broad permission leakage into clinical prescription creation, and zero-price fallback for unpriced catalogue medicines in both replacement paths.
- Phase 61 remains a database/backend candidate only. No front-end correction request/resolution flow, authenticated doctor/pharmacist E2E, or staff acceptance is claimed.
- Phase 57 has been reconstructed on a fresh branch from current main to avoid the dirty/stale PR #209 base. The branch preserves the exact QA-applied Phase 57 source body and separates Phase 57B free-text/external-prescription guards. The pharmacy UI now blocks invalid/missing quantities and unlinked/external items without substituting quantity 1. Full exact-head CI is pending.
- Production remains on the old dispense fallback; QA has Phase 57. No Supabase writes, migration replay, role changes, Production deployment, or backup dispatch occurred.
- Weighted Engineering RC remains **49%** pending Phase 57 exact-head validation and independent review; operational acceptance remains **11%**. Estimated Engineering RC remaining remains **24–40 hours**, conditional on migration reconciliation and release-gate evidence.

## H+14 — Phase 61 UI/mainline reconciliation — 2026-11-11

- PR #229's UI candidate includes pharmacist correction requests, a permission/RLS-scoped prescriber inbox, replace-one-item, reject-with-reason and full cancel-and-reissue. Replacement entries require explicit re-entry of every medicine and regimen field; no old regimen is inferred or copied.
- Historical code head 83aee76f1ef18e58f52b9712f78e3b271602b797 passed its documented 20-job suite (19 successful, one intentional authenticated clinical-acceptance skip). The retargeted PR head is not covered by that historical result.
- Reconciliation uses the current mainline Phase 57/57B quantity/external-prescription guards, preserving fail-closed dispense behavior. The matching pharmacy-quantity helper is byte-identical to main.
- A normal two-parent merge commit is being prepared; no force-push or history rewrite. Fresh exact-head CI is the next gate.
- Remains Draft until exact-head CI, independent SQL/security review, 320–430px Android RTL/LTR acceptance and real pharmacist/prescriber UAT. No hosted QA/Production migration, business-data write, Auth/Storage/role mutation, backup dispatch or deployment promotion.
 
## H+15 — Phase 61 mainline reconciliation and exact-head CI — 2026-11-11

- Reconciled PR #229 with current main by normal merge commit; no force-push or history rewrite. The pharmacy route preserves both correction UI and Phase 57/57B fail-closed quantity/external-prescription behavior. CI workflow preserves the Phase 61 PG17 job and mainline Phase49/57/57B replay steps.
- Exact reconciled head 064b4964b5c83257f6134cc6274c74b50b29134f completed **30 checks: 29 success and one intentional authenticated clinical-acceptance skip**. Typecheck, lint, build, security audits, Spec Kit, Phase 61 PG17 authorization/RLS/audit/concurrency/no-side-effects, prescription atomicity, insurance and mainline integrations passed.
- PR remains Draft pending independent SQL/security review, 320–430px Android Arabic RTL/English LTR browser acceptance and real pharmacist/prescriber UAT.
- No hosted QA/Production DDL/DML, migration, business-data write, Auth/Storage/role mutation, backup dispatch or deployment promotion.
 
## H+16 — Phase 61 correction-event RLS proof — 2026-11-11

- Added four negative event-visibility assertions for unassigned doctor, wrong-branch doctor, wrong-branch pharmacist and ordinary Admin.
- PostgreSQL 17 exact-head run confirms the EXISTS subquery against the RLS-protected correction-request table inherits its row visibility restrictions. All four assertions pass; no policy rewrite was necessary.
- Exact head c946f1486c1f0f0b8e4f327bb70b50a0cfe22038: **30 checks, 29 successful, one intentional authenticated clinical-acceptance skip, zero failures**. Full CI, Phase 61 PG17, Spec Kit, insurance, prescription atomicity and privileged-role checks passed.
- PR remains Draft for independent SQL/security review, 320–430px Android Arabic RTL/English LTR acceptance and real pharmacist/prescriber UAT. No hosted QA/Production migration, business-data write, Auth/Storage/role mutation, backup dispatch or deployment promotion.
 
## H+17 — Phase 61 exact-head validation after finance integration — 2026-11-11

- PR #229 was reconciled with current main after Phase58/59 merge using a normal two-parent merge commit; branch remains zero behind main.
- Exact code head 7f558a4279d97082eefb721019709ca9aeab7bb3 passed 29 successful checks and one intentional authenticated clinical-acceptance skip, with zero failures. Phase58/59 PG17, Phase61 PG17, prescription atomicity, insurance, typecheck, lint, build, security audits and Spec Kit passed.
- Four negative event-visibility assertions for unassigned doctor, wrong-branch doctor, wrong-branch pharmacist and ordinary Admin pass; no policy rewrite was needed.
- PR remains Draft for independent SQL/security review, 320–430px Android Arabic RTL/English LTR acceptance and real pharmacist/prescriber UAT. No hosted QA/Production migration, business-data write, Auth/Storage/role mutation, backup dispatch or deployment promotion.
