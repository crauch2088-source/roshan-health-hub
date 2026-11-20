# Roshan Health Hub — Checkpoint & Exact Patches (2026-11-21)

## 1. Repository & Production Guardrails
- **Verified `main` HEAD:** `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`
- **Production:** Strictly read-only, untouched.
- **Open PR count:** 45 open pull requests.

## 2. PR #250 (Phase 61c Prerequisite)
- **PR #250:** Commit `26dbc1b`, Draft, 35/35 passed — Phase 61c canonical `private.app_has_role_permission` prerequisite for Phase 62/63.

## 3. PR #293 (`feat/rhh01-pharmacy-cancellation-and-return`)
- **Commits created:** `4a8e4ab`, `9a4f607`, `8fed1e5`, `712d8d4`, `2950476`, `12bc5bd`, `45ed77d`, `c9659dc`, `42f6112`, `5d06594`, `21df632`
- **Files changed:**
  - `db/roshan_phase62_pharmacy_cancellation_and_return.sql`
  - `db/tests/pharmacy_dispense_invoice_fixture.sql`
  - `src/lib/pharmacy-lifecycle.ts`
  - `src/routes/_authenticated/pharmacy.tsx`
  - `tests/phase62-pharmacy-lifecycle-ui.test.ts`
  - `tests/phase39-permissions-and-schema-consistency.test.ts`
  - `package.json`
- **Observed CI result on `21df632`:**
  - Overall checks: **29 successful, 2 failing, 1 skipped** (32 total check entries).
  - `CI / Install, audit, typecheck, lint, build`:
    - Role guard unit tests: **passed** (337/337, 0 fail).
    - Typecheck: **failed** (exit code 2) in `src/routes/_authenticated/pharmacy.tsx`:
      - Line 138: `TS2558: Expected 1 type arguments, but got 2.` (4 `useSave<..., unknown>` calls -> remove `, unknown`).
      - Line 468: `TS2304: Cannot find name 'pid'.` (replace `pid` with `s(p, "id")`) and `TS2554: Expected 0-1 arguments, but got 2.` (2 `formatDateTime(..., lang)` calls -> remove `, lang`).
      - Line 475: `TS2322: Type 'string | Row' is not assignable to type 'ReactNode'.` and `TS2554: Expected 2 arguments, but got 3.` (`rel(q, "medicines", "name")` -> `s(rel(q, "medicines"), "name")`), plus `TS2554: Expected 0-1 arguments, but got 2.` (2 `formatDateTime(..., lang)` calls -> remove `, lang`).
    - Lint & Build: **skipped** (0s, due to Typecheck failure).
  - `Insurance claim UI validation / Insurance claim validation regression`: **failed**.
  - `CI / Canonical PG17 baseline replay and authenticated clinical acceptance`: **skipped**.
  - Note: Web-editor commit attempt on `feat/rhh01-pharmacy-cancellation-and-return` returned "File could not be edited" because the branch had a newer commit while editing.

## 4. PR #294 (`feat/rhh03-inventory-ledger-controls`) & Next Steps
- **PR #294:** `9fe0034` + `3b58e30`, Draft, 28/28 passed.
- **Exact Next Steps:**
  - **Priority 2:** Authenticated inventory UI integration in `src/routes/_authenticated/inventory.tsx`.
  - **Priority 3:** Combined Phase 60/62/63 real-RPC regression.
  - **Priority 4:** Genuine PG 17 two-session concurrency test.

## 5. Other Open PR Statuses
- **PR #292:** Ready, 31/31.
- **PR #291:** Ready, 31/31.
- **PR #210:** `e53216a`, Draft, 32/32, 13 files, 0 reviews.
- **PR #295:** Draft, 5/5.
