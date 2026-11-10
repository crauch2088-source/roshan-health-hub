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
