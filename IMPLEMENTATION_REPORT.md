# ROSHAN — Implementation Report (Phase 5 session)

## 1. Audit (Step 1 — before any change)

Verified against the `__13_` ZIP directly:
- Phase 1–4 files are genuinely merged and wired, not orphaned: `app-shell.tsx` imports and uses `NavRail`,
  `CommandPaletteProvider`, `MobileBottomNav`, `BreadcrumbNav`; `routeTree.gen.ts` contains 13 references to
  `finance`, confirming a real build ran and picked up last session's route. No re-implementation needed or done.
- Patient-picker audit across every visit-creation-adjacent path: only `visits.tsx` inserts into `visits` (single,
  coherent entry point — good). But `appointments.tsx` had its own separate, older patient search+select
  implementation (search box + plain `<Select>`, no debounce, no keyboard nav, no previous-visit snapshot) —
  exactly the kind of duplicate the earlier phases were meant to eliminate. **Fixed**: now uses `PatientPicker` +
  `PatientSnapshotStrip`, same component as Visits and Patient Profile.
- `followups.tsx` has a similar older pattern but also supports a free-text `patient_name` fallback (for contacts
  not yet in the system) — a materially different data model, not a drop-in swap. **Not changed this session** —
  flagged below as a real, known remaining item rather than risking a rushed edit to a more complex form under
  time pressure.
- Live schema re-checked directly before writing any Insurance table (no assumptions from old SQL files). Only
  pre-existing insurance-adjacent structure is `partners` (0 rows) — a flat per-company discount-percent table,
  structurally unsuited to plans/coverage-rules/claims. Left untouched; new `insurance_*` tables built instead,
  as the brief anticipated for this exact case.

## 2. Phase 5 — Insurance (built and applied live)

**Database** (`db/roshan_phase5_insurance.sql`, already applied to the live project in 3 steps this session):
- Tables: `insurance_companies`, `insurance_plans`, `patient_insurance`, `insurance_coverage_rules`,
  `insurance_prior_authorizations`, `insurance_claims`, `insurance_claim_items`, `insurance_claim_payments`.
- Coverage matching for medicines is by **generic name** first (falls back to plan default), per the brief's
  Amoxicillin example — a specific `reference_id` rule outranks a generic-name rule, which outranks the plan's
  blanket default for that service type.
- Claim workflow enforced *in the database*, not just the UI: `update_insurance_claim_status()` only allows
  `draft→submitted→under_review→{approved|partially_approved|rejected}→paid`. Anything else raises an exception.
- `post_insurance_claim_payment()` is one atomic function: inserts the payment, recomputes `paid_amount`/status,
  and posts to the cashbox via the **existing** Phase 4 `fn_ledger_post()` — reused, not duplicated. That function
  is idempotent on `(source_type, source_id)`, so this cannot double-post the same settlement.
- Permissions: **3 new codes** (`insurance.read/create/update`) — nothing existing covered this module, so this is
  the minimum necessary, matching the existing per-module pattern (`pharmacy.*`, `cashbox.*`, `debts.*`). Granted
  to `super_admin`/`admin` (full) and `receptionist` (read/create, for registering patient membership at the
  front desk). RLS mirrors the exact pattern already used for Phase 3/4 tables.
- The dual-column `invoices`/`payments` issue was **not re-touched** — Phase 4's `fn_recompute_invoice_paid()`
  already keeps both column pairs in sync, and this session's insurance payments flow through the cashbox ledger,
  not through `invoices`/`payments` directly, so no new interaction with that issue was introduced.

**Frontend**:
- `src/lib/insurance.ts` (new) — types + thin RPC wrappers, no business logic duplicated client-side.
- `src/routes/_authenticated/insurance.tsx` (new) — Companies, Plans, Patient Insurance (reuses `PatientPicker`),
  and Claims (create with live coverage calculation per line item, status transitions, payment recording) tabs.
- Nav: added to the Finance group in `nav.ts`, `ShieldCheck` icon registered in `nav-icons.tsx`.
- `i18n.tsx`: 25 new keys, Arabic + English, checked for zero duplicates against the full file (not just the new
  block).

## 3. Files

**ADD**: `src/lib/insurance.ts`, `src/routes/_authenticated/insurance.tsx`, `db/roshan_phase5_insurance.sql`.
**REPLACE**: `src/config/nav.ts`, `src/lib/nav-icons.tsx`, `src/lib/i18n.tsx`, `src/routes/_authenticated/appointments.tsx`.

## 4. Verification

- Every file above individually type-checked with `tsc --strict` against this repo's actual compiler options,
  including cross-file member resolution. All clean.
- i18n duplicate-key scan run against the full file after edits, not just the new block: zero duplicates.
- **`npm run typecheck` / `npm run build` were not run** — this sandbox has no `node_modules` and no network to
  install them. This is stated plainly per your instruction not to claim "clean" from syntax-checking alone:
  isolated `tsc` catches type/syntax errors but not Vite bundling, route-tree regeneration, or circular-import
  issues. Please run both before merging.

## 5. Known remaining item

`followups.tsx` still has the older, non-debounced patient search pattern, and additionally supports a free-text
patient name for people not yet in the system — changing it safely means deciding how that free-text case should
interact with `PatientPicker` (which assumes a registered patient), not just swapping the component in. Left as-is
rather than guessing that behavior under time pressure.

## 6. Installation

1. Unzip preserving paths.
2. Database is already live — `db/roshan_phase5_insurance.sql` is included for the repo record and is safe to
   re-run (fully idempotent) if you want to apply it from a fresh environment instead.
3. `npm install && npm run typecheck && npm run build`.
