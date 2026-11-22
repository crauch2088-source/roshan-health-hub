# Neon Owner-Gated QA Acceptance & Release-Gate Closure Report (2026-11-22)

> Window/Round: Standalone Neon closure campaign (no numbered parallel window 01–10 applies; executes `docs/OWNER_GATED_QA_ACCEPTANCE_AND_RELEASE_GATE_CLOSURE_MANDATE_2026-11-22.md`).

## 1. Identity and scope

- **Original task / PR:** [PR #296](https://github.com/crauch2088-source/roshan-health-hub/pull/296) (`fix/qa-operational-blockers-20261121` → `main`), **OPEN / DRAFT / UNMERGED**
- **Mandate commit:** [`42a520a9932b3bbe2b6942b8cd2624bba8c63189`](https://github.com/crauch2088-source/roshan-health-hub/commit/42a520a9932b3bbe2b6942b8cd2624bba8c63189)
- **Current `main` SHA checked:** `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`
- **Verified identities:**
  - QA Supabase: `hopfohcnrtbiqjkgeukz` (`roshan-health-hub-qa`) — QA synthetic only
  - Production Supabase: `jewzonxplxhogqrnhosl` — **READ-ONLY (untouched)**
  - Vercel project: `prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk` (team `team_GxMH4eyATlCfJMG8SJXzDcAg`)
- **Explicit exclusions:** No merge to `main`, no Production writes/migrations/deployments, no clinical protocol activation, no bypass of `requires_user_takeover`.

## 2. Executive verdict

- **Status:** **PASS WITH OWNER-GATED CLOSURE ITEMS (QA-ONLY — PRODUCTION REMAINS NO-GO)**
- **Completed in this closure campaign:**
  - Reconciled live Git, PR #296, CI, Vercel Preview, QA/Prod Supabase, and backup-runner state via Composio MCP.
  - Resolved the **7-vs-8 workflow count discrepancy**: on exact commits `a12589d6` and `42a520a9`, there are **7 repository `pull_request` workflows** (`.github/workflows/*.yml`) **+ 1 GitHub dynamic CodeQL code-scanning run** (`event=dynamic`, `path=dynamic/github-code-scanning/codeql`, named `PR #296`) = **8/8 `success`**.
  - Resolved the **canceled Vercel Preview mystery**: commits `a12589d6` (test-only) and `42a520a9` (docs-only) were skipped by the configured Ignored Build Step (`git diff --quiet HEAD^ HEAD -- src/ public/ index.html package.json package-lock.json vercel.json vite.config.ts tsconfig*.json`). The newest **READY** preview for `fix/qa-operational-blockers-20261121` is **`dpl_CBozymV47bEvcpC9f6nE5dY4xCRg`** (`https://roshan-health-31yvlw89c-roshan45.vercel.app`, SHA `73ee5551`), which contains the **identical runtime application source tree** to `42a520a9` (caveat: Vercel QA env vars are scoped to `qa/isolated-acceptance-20261023`, so QA DB live testing continues on `https://roshan-health-ay58tt7s5-roshan45.vercel.app` until QA env scope or branch deployment is updated).
  - Re-enumerated all **18 reported `SECURITY DEFINER` functions** in both QA and Production: **0** had `NULL` (mutable) `proconfig`; 13 had `search_path=public` and 5 had `search_path=public, pg_temp`. Safely hardened **17/18** exact signatures to `SET search_path = ''` in **QA ONLY** (`roshan_qa_secdef_search_path_hardening_20261122`, tracked in `db/roshan_qa_secdef_search_path_hardening_20261122.sql`), preserving `owner=postgres` and all ACLs, and intentionally left `public.create_staff_user(text,text,text,text)` untouched because it invokes unqualified `pgcrypto` `crypt()`/`gen_salt()`. Confirmed Production remained **18/18 unchanged**.
  - Verified the pending QA synthetic prescription (`7239fedf-b480-4970-bc65-f0a0cde15ce1`, `QA Test Paracetamol 500mg`, `medicine_id=e9fdbdb8-3539-4809-9dea-0842bb9818a2`, Qty `2`, selling price `150 SDG`, stock `10`, branch `ROS-MAIN`) is intact and ready for the owner's 1-click Dispense confirmation (**OWNER REQUIRED / NOT COMPLETED**).
  - Re-verified backup-runner state (`f171732b61fe0460c61a36aa63b861065f9ea9d1`; note manual dispatch `#43764265014` on 2026-11-15 failed, leaving `#43183851731` from 2026-11-12 as the latest verified encrypted DB backup) and prepared the exact offline owner decryption checklist.

## 3. Repository, CI, and Preview state verified

| Item | Exact value | Evidence / status |
|---|---|---|
| `main` SHA | `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a` | Verified (unchanged) |
| PR #296 state | OPEN, `draft=true`, unmerged | Verified |
| Exact-head CI on `42a520a9` | **7/7** `pull_request` workflows `success` + **1/1** dynamic CodeQL (`#45036427658`) `success` = **8/8** | `#45036431130` (CI), `#45036431171` (Insurance UI), `#45036430999` (Insurance integrity), `#45036430955` (Clinical child PG17), `#45036431047` (Finance RPC), `#45036431186` (Prescription atomicity), `#45036431039` (Privileged role guard), `#45036427658` (Dynamic CodeQL `PR #296`) |
| Newest READY Preview on PR #296 | `dpl_CBozymV47bEvcpC9f6nE5dY4xCRg` (`https://roshan-health-31yvlw89c-roshan45.vercel.app`) | `READY`, `target=preview`, SHA `73ee5551` (identical `src/` runtime tree to `42a520a9`; `a12589d6`/`42a520a9` canceled by Ignored Build Step) |
| QA-scoped Preview (live QA DB) | `https://roshan-health-ay58tt7s5-roshan45.vercel.app` | Branch `qa/isolated-acceptance-20261023` (`d8f494be`); holds QA Supabase env vars |

## 4. Before/After Table — 18 Reported `SECURITY DEFINER` Functions

| Exact Signature | Owner | QA Before | QA After (`hopfohcnrtbiqjkgeukz`) | Prod (`jewzonxplxhogqrnhosl`, read-only) | Disposition |
|---|---|---|---|---|---|
| `public.audit_row_change()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.bootstrap_super_admin(text,text,text)` | `postgres` | `search_path=public, pg_temp` | **`search_path=""`** | `search_path=public, pg_temp` (unchanged) | Hardened in QA; ACL preserved |
| `public.bootstrap_super_admin(uuid,text,text)` | `postgres` | `search_path=public, pg_temp` | **`search_path=""`** | `search_path=public, pg_temp` (unchanged) | Hardened in QA; ACL preserved |
| `public.create_staff_user(text,text,text,text)` | `postgres` | `search_path=public, pg_temp` | `search_path=public, pg_temp` *(unchanged)* | `search_path=public, pg_temp` (unchanged) | **Intentionally untouched:** calls unqualified `crypt()`/`gen_salt()` (`pgcrypto`) |
| `public.current_role_name()` | `postgres` | `search_path=public, pg_temp` | **`search_path=""`** | `search_path=public, pg_temp` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_cashbox_immutable()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_finance_audit()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA (`gen_random_uuid()` is in `pg_catalog` in PG17) |
| `public.fn_ledger_from_expense()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_ledger_from_payment()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_ledger_from_supplier_payment()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_ledger_post(text,numeric,text,text,text,text,uuid,timestamp with time zone,uuid)` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_recompute_invoice_paid()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.fn_recompute_supplier_bill()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.get_current_user_profile()` | `postgres` | `search_path=public, pg_temp` | **`search_path=""`** | `search_path=public, pg_temp` (unchanged) | Hardened in QA; ACL preserved |
| `public.record_cashbox_expense()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.record_cashbox_payment()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.record_cashbox_supplier_payment()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |
| `public.sync_supplier_bill_payment()` | `postgres` | `search_path=public` | **`search_path=""`** | `search_path=public` (unchanged) | Hardened in QA; ACL preserved |

## 5. Owner-Operated Procedures (Explicitly Owner-Gated — Not Falsely Claimed)

### A. QA Pharmacy Dispense (1-click UI confirmation)
- **Status:** **OWNER REQUIRED / NOT COMPLETED** (blocked by managed browser `requires_user_takeover: true`; not bypassed).
- **Exact QA Record Ready:** Prescription `7239fedf-b480-4970-bc65-f0a0cde15ce1` · Patient `مريض تجريبي QA-20261121` (`RMC000001`) · Medicine `QA Test Paracetamol 500mg` (`e9fdbdb8-3539-4809-9dea-0842bb9818a2`) · Qty `2` · Price `150 SDG` · Expected Total `300 SDG` · Current Stock `10`.
- **Owner Step:** Open `https://roshan-health-ay58tt7s5-roshan45.vercel.app/pharmacy` as `roshan.qa.pharmacy@example.com`, click **Dispense** once on the top pending card, then verify `/inventory` decrements `10 → 8` and `/billing` shows the linked `300 SDG` pharmacy charge without double-billing.

### B. Android Mobile RTL/LTR Acceptance (`320px`, `360px`, `390px`, `430px`)
- **Status:** **OWNER REQUIRED / NOT VERIFIED** (managed browser has no viewport-resize control; desktop RTL/LTR passed).
- **Owner Checklist (on Android phone, both Arabic RTL & English LTR):** Test `/auth`, `/dashboard`, `/patients` (register modal + duplicate warning), `/visits`, `/clinic`, `/lab`, `/lab-catalog`, `/pharmacy`, `/inventory`, `/expenses`, `/billing`, `/audit` for zero horizontal overflow, legible dialogs, touch targets, and zero raw i18n keys.

### C. Offline Backup Decryption & Restore Gate
- **Status:** **OWNER REQUIRED / UNVERIFIED** (`roshan-health-hub-backup-runner` main `f171732b`; latest successful encrypted DB-only archive is run `#43183851731` / Drive `roshan-production-backup-43183851731.zip`, SHA-256 `54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9`; note manual run `#43764265014` on 2026-11-15 failed and should be investigated/re-run). Scope is **database-only** (excludes control-plane, storage object bytes, and secrets).
- **Owner Offline Steps (never share private age key):**
  1. `sha256sum roshan-production-backup-43183851731.zip` (verify matches `54b79954...`).
  2. `unzip roshan-production-backup-43183851731.zip` and `age -d -i ~/.config/age/roshan.key -o backup.dump backup.dump.age`.
  3. Restore into a disposable local PostgreSQL 17 database (`pg_restore --clean --if-exists -d roshan_restore_test backup.dump`) and verify critical row counts.

## 6. Safety and Actions NOT Performed

- **Production Supabase writes / migrations / ACL / RLS changes:** **No** (verified 18/18 functions & `branches_select` unchanged)
- **Production Vercel deployment / promotion / env changes:** **No**
- **Merge to `main` / PR closure / release approval:** **No** (PR #296 remains Draft)
- **Real patient, clinical, or financial data access/use:** **No**
- **Secret or private key exposure:** **No**
- **Clinical protocol activation:** **No**

## 7. Recalculated Scores & Production Decision

- **Engineering RC:** **71.3%** (up from 69.8%: Workstream D Security/Migration moves `62% → 68%` for hardening 17/18 `SECURITY DEFINER` functions in QA + tracked migration + regression guard; `+0.25 * 6 = +1.5%`).
- **Operational Acceptance:** **28.0%** (unchanged — owner-gated Pharmacy dispense click, Android mobile device pass, offline backup decryption, and staff/printer UAT remain open).
- **Production Decision:** **NO-GO** until all mandatory owner, security, migration-parity, backup-decryption, and staff/clinical gates are independently completed.
