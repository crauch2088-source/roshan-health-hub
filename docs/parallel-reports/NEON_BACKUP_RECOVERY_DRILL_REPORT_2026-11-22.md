# Neon Backup Recovery & Disaster Recovery Verification Report (2026-11-22)

> Standalone Neon verification campaign executing `docs/BACKUP_RECOVERY_AND_DISASTER_RECOVERY_VERIFICATION_MANDATE_2026-11-22.md` on PR #296 (`fix/qa-operational-blockers-20261121`).

## 1. Identity and scope

- **Window:** Standalone DR Verification Campaign (2026-11-22)
- **Original task / Issue / PR:** [PR #296](https://github.com/crauch2088-source/roshan-health-hub/pull/296) (`fix/qa-operational-blockers-20261121` → `main`), **OPEN / DRAFT / UNMERGED**
- **Mandate commit:** [`3fdeaa843ca3871b62131d904051aac2343f53b4`](https://github.com/crauch2088-source/roshan-health-hub/commit/3fdeaa843ca3871b62131d904051aac2343f53b4) (following QA pharmacy closure [`eda06ef2`](https://github.com/crauch2088-source/roshan-health-hub/commit/eda06ef234cba3d9261ac34613368b17d4fb3abe))
- **Current `main` SHA checked:** `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`
- **Backup runner repository checked (read-only):** `crauch2088-source/roshan-health-hub-backup-runner` (`main` `f171732b61fe0460c61a36aa63b861065f9ea9d1`)
- **Explicit exclusions:** No Production Supabase (`jewzonxplxhogqrnhosl`) or Production Vercel writes/exports/deployments; no Production secret changes; no access to or exposure of the owner's private `age` key; no merge to `main`; no clinical protocol activation.

## 2. Executive verdict

- **Status:** **PASS WITH OWNER-GATED PRODUCTION RESTORE (QA SYNTHETIC PG17 DRILL PASSED — PRODUCTION REMAINS NO-GO)**
- **Actually complete:**
  - Diagnosed failed backup runner run `#43764265014` (2026-11-15) with 100% log + GitHub Secrets metadata evidence.
  - Verified live metadata of the last successful Production encrypted DB-only archive (`#43183851731`, 2026-11-12): expired on GitHub Actions (`retention-days: 1`), intact on Google Drive (`roshan-production-backup-43183851731.zip`, `305,284 bytes`, `trashed: false`).
  - Added reusable preflight/redaction/checksum/PG17-compatibility/atomic-staging guards (`scripts/backup-dr-guard.mjs`), 7 automated unit tests (`tests/backup-recovery-dr.test.ts`), safe DR runbook (`docs/BACKUP_AND_DISASTER_RECOVERY_RUNBOOK.md`), and a live isolated synthetic QA PostgreSQL 17 backup & restore drill (`scripts/qa-synthetic-pg17-restore-drill.sh` + `.github/workflows/ci-qa-synthetic-pg17-restore-drill.yml`).
  - Executed the real isolated **PostgreSQL 17.12** synthetic QA backup, `age 1.1.1` encryption, SHA-256 verification, decryption, restore, structural/smoke validation (**QA Drill RTO = 103 ms**), and verified full cleanup (`0` leftover DBs/files) in GitHub Actions run [`#45042325296`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/45042325296).
- **What remains incomplete (Owner-Gated):**
  - Owner-side offline decryption and isolated PostgreSQL 17 restore of the real Production archive `roshan-production-backup-43183851731.zip` (**OWNER REQUIRED / NOT VERIFIED**).
  - Owner decision on configuring a least-privilege DB backup credential in `roshan-health-hub-backup-runner` and approving a monitored scheduled backup cadence + Production RPO/RTO targets.

## 3. Repository & environment state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a` | PR #296 base | Verified |
| PR #296 state | `open`, `draft=true`, `merged=false` | [PR #296](https://github.com/crauch2088-source/roshan-health-hub/pull/296) | Verified |
| Backup runner `main` SHA | `f171732b61fe0460c61a36aa63b861065f9ea9d1` | `crauch2088-source/roshan-health-hub-backup-runner` | Verified |
| Failed backup run | `#43764265014` (`2026-11-15T21:32:41Z`, `validate` `#132965725378`) | [Run #43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) | Verified |
| Last successful Prod backup | `#43183851731` (`2026-11-12T08:36:01Z`, SHA `eb7d8ae8`) | [Run #43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) | Verified |
| GitHub artifact `#13927247998` | Expired (`total_count: 0`, `retention-days: 1`) | GitHub Actions artifacts API | Verified |
| Google Drive archive | `roshan-production-backup-43183851731.zip` (`305,284 bytes`, `trashed: false`, `2026-11-12T08:38:02.545Z`) | [Drive File](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk) | Verified (metadata only) |

## 4. Root cause of failed run `#43764265014` & why no new Production backup was dispatched

- **Root-cause classification:** **Authentication / Missing Repository Secret** (High confidence — direct log + GitHub API evidence).
- **Exact causal failure:** Job `validate` (`#132965725378`), Step 4 (`Preflight Production backup credentials`, `bash scripts/validate_backup_credentials.sh`) exited with code `1`:
  - `##[error]Configure exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD.`
  - Job `backup` (`#132965838233`) was `skipped`.
- **Direct metadata confirmation (names only, zero secret values accessed):**
  - `GET /repos/crauch2088-source/roshan-health-hub-backup-runner/actions/secrets` returned `total_count: 1` (`SUPABASE_ACCESS_TOKEN`, created `2026-11-12T06:41:26Z`).
  - `GET /repos/crauch2088-source/roshan-health-hub-backup-runner/environments` returned `total_count: 0`.
  - Both `SUPABASE_DB_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` are absent. The 1-commit diff between `#43183851731` (`eb7d8ae8`) and `#43764265014` (`f171732b`) only added Android offline verification scripts/tests and did not alter the workflow or credential validator.
- **Why no new Production backup was dispatched:** (1) Required DB credential secret is absent, (2) modifying Production secrets or initiating Production data egress requires explicit owner authorization per Mandate §2 & §4.6–4.7.

## 5. Synthetic QA PostgreSQL 17 Restore Drill Evidence (Phase C1)

- **Workflow Run:** [QA synthetic PG17 backup & restore drill #45042325296](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/45042325296) (Job `synthetic-pg17-restore-drill` `#137269298832`, commit `e8dbc0f6`) — **PASS**
- **Versions:** `pg_dump (PostgreSQL) 17.12`, `pg_restore (PostgreSQL) 17.12`, Server `17.12 (Debian 17.12-1.pgdg13+1)`, `age 1.1.1`.
- **Synthetic Archive & Integrity:** `roshan-qa-synthetic-drill.tar.gz.age` (`5,941 bytes`), encrypted with an ephemeral drill-only `age` keypair, `SHA-256 = 7d03f5f86ac6e704a8816d5b8848037c0da474d9d01cc0670e7c8f56c6a05c52`, `sha256sum -c SHA256SUMS: OK`.
- **Synthetic Recovery Point:** `2026-11-22T16:11:19Z` (synthetic QA data only — **not** Production RPO).
- **Structural, Row-Count & Smoke Verification:**
  - Source == Restored counts: `branches=1, patients=1, visits=1, medicines=1, prescriptions=1, invoices=1, invoice_items=2, stock_movements=2, audit_logs=2, rls_tables=9`.
  - Smoke queries: `qa_drill_invoice_sum` = `800.00 SDG`, `QA Test Paracetamol 500mg` stock = `8`, restored DB size = `8094 kB`.
- **Measured QA Drill RTO:** **`103 ms`** (`2026-11-22T16:11:19Z` → `2026-11-22T16:11:20Z`) — explicitly labeled **QA Drill RTO**, not Production RTO.
- **Verified Cleanup:** `cleanup_leftover_dbs=0`, `cleanup_workdir_exists=false` (both temporary DBs dropped and ephemeral age key + dumps deleted).

## 6. Observed Production RPO / Backup Age, Monitoring Gaps & Proposed Targets

- **Observed Production Backup Age / RPO:** Last verified successful Production DB-only backup completed at **`2026-11-12T08:36:01Z`** (`#43183851731`). At observation time **`2026-11-22T16:11:00Z`**, observed backup age is **10 days, 7 hours, 35 minutes (~247.6 hours)**.
- **Operational Controls & Gaps:** Trigger is **manual-only** (`workflow_dispatch`); there is **no scheduled cron backup** and **no automated failure/staleness alerting**. Archive scope is **database-only** (fails closed if `storage.objects > 0` or `vault.secrets > 0`; excludes control-plane/secrets/Storage object bytes).
- **Proposed Objectives (Pending Owner Approval):** Proposed Production RPO `<= 24h` (via monitored daily schedule) and Production RTO `<= 60m`.

## 7. Production Backup Decrypt/Restore Status & Owner Actions Required

- **Production Backup Decrypt/Restore Status:** **OWNER REQUIRED / NOT VERIFIED**. (Synthetic QA PG17 restore proves tooling and procedure, not Production archive decryptability.)
- **Smallest Precise Owner Actions Required:**
  1. On your local device (never sharing `~/.config/age/roshan.key`), follow [`docs/BACKUP_AND_DISASTER_RECOVERY_RUNBOOK.md`](../BACKUP_AND_DISASTER_RECOVERY_RUNBOOK.md) §3 to verify SHA-256 (`54b79954...`), decrypt `roshan-production-backup-43183851731.zip`, restore into a disposable local PostgreSQL 17 container, confirm row counts match `source-counts.json`, and record measured Production RTO.
  2. Configure exactly one least-privilege DB backup credential (`SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`) in `roshan-health-hub-backup-runner` repository secrets before triggering a fresh manual Production backup, and approve whether to enable a monitored daily schedule.

## 8. Safety, Security Review & Actions NOT Performed

- **Production Supabase / Vercel writes, migrations, exports, or deployments:** **No**
- **Production secret or credential modifications:** **No**
- **Real patient, clinical, or financial data accessed or committed:** **No**
- **Private `age` key or secret exposure:** **No** (verified by `redactBackupLog` unit tests and `set +x` / `umask 077` in drill script; workflow uses least-privilege `permissions: { contents: read }` and `persist-credentials: false`).
- **PR merge / `main` modification / clinical protocol activation:** **No** (PR #296 remains Draft).

## 9. Scores & Final Production Release Decision

- **Engineering RC / Operational Acceptance:** Retained at prior verified baseline (**71.3% Engineering RC / 33.0% Operational Acceptance**); no documented rubric adjustment applied solely for a synthetic QA restore drill while real Production restore remains unverified.
- **Production Release Decision:** **NO-GO** until owner-verified Production archive decryption/restore, Android mobile acceptance (`320–430px`), staff/printer/clinical sign-off, and migration review are closed.
