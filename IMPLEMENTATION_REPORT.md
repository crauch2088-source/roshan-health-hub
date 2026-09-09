# ROSHAN — Implementation Report
Session covering: Part B verification, Phase 1–3 restoration, Phase 4 finance application + UI.

## 1. What was found (audit, against the live Supabase project and the __12_ ZIP)

- Part B (patient picker / repeat-visit workflow) was correctly manually installed. No fixes needed.
- Phase 1 (Global Search) was **partially** present: `global-search-dialog.tsx` existed, but every file it imports
  (`search-service.ts`, `use-global-search.ts`, `command-palette-provider.tsx`) was missing — the app would not
  have compiled.
- Phase 2 (Navigation) was **not** present: `nav.ts` was the old flat structure, and `nav-rail.tsx`,
  `use-nav-preferences.tsx`, `breadcrumb-nav.tsx`, `mobile-bottom-nav.tsx`, `nav-icons.tsx`, `quick-actions.ts` were
  all missing. `app-shell.tsx` still hard-coded its own nav list.
- Phase 3 (Pharmacy batches/FEFO) was, contrary to expectations, **fully present and correct**
  (`inventory.tsx`, `pharmacy.tsx`, `lib/pharmacy.ts`) — only its translation keys were missing from `i18n.tsx`.
- **Phase 4 (Finance)**: the big finding. `db/roshan_phase4_finance.sql` existed in the repo and is genuinely
  well-designed (atomic RPCs, idempotent ledger posting, immutable cashbox, dual-column-safe recompute triggers) —
  but had **never been fully applied** to the live database. Only its table-creation and permission-insert sections
  had run at some point; the views, triggers, RPCs, and RLS switch had not. This meant the "dual-column" risk
  flagged last session (`invoices.total_amount`/`net_amount`, `payments.payment_method`/`method`) was already
  solved *in the file*, just not live.

## 2. What was fixed / restored

**Phase 1 + 2 — full restoration**, all newly written against the live schema (not guessed):
`src/config/nav.ts`, `src/lib/nav-icons.tsx`, `src/lib/quick-actions.ts`, `src/lib/search-service.ts`,
`src/hooks/use-global-search.ts`, `src/hooks/use-nav-preferences.tsx`, `src/components/command-palette-provider.tsx`,
`src/components/nav-rail.tsx`, `src/components/breadcrumb-nav.tsx`, `src/components/mobile-bottom-nav.tsx`,
`src/components/app-shell.tsx` (rewritten to compose the above instead of a hard-coded duplicate list).

While building `search-service.ts` I checked the live schema before writing the lab search query and caught a bug
before it shipped: `lab_order_items` has no `test_name` column — the real name lives on `lab_tests.name` via
`test_id`. Fixed before delivery, not after.

**Phase 3** — no code changes needed; added the missing i18n keys (`batches`, `suppliers`, `expiring_soon`,
`quantity_received`, etc.), checked for and found zero collisions with existing keys.

**Phase 4** — applied `db/roshan_phase4_finance.sql` to the live database in full. Hit one real conflict during
application: a partial unique index `uq_cashbox_source` already existed with a different predicate than the file
expected (`source_type IS NOT NULL AND source_id IS NOT NULL` vs. the file's `source_id IS NOT NULL`), which broke
the file's `ON CONFLICT` clauses. Fixed by matching the existing predicate rather than fighting it. Also found: the
file's RLS section grants the new `suppliers.*` permission codes to admin/accountant/cashier but not `pharmacist`,
who manages suppliers day-to-day per Phase 3. The old `pharmacy.*` policies on `suppliers` are untouched (RLS
policies OR together, so nothing broke), but I additionally granted `suppliers.read/create/update` to `pharmacist`
so the permission model is coherent going forward rather than depending on two code families both happening to
work. Recorded as `db/roshan_phase4_finance_pharmacist_grant.sql`.

**Phase 4 UI — built new**: `src/routes/_authenticated/finance.tsx` — Cashbox (balance, ledger, deposit/withdrawal,
reversal), Receivables (from `v_patient_receivables`, payment via `post_invoice_payment`), Supplier debt (from
`v_supplier_outstanding` + `supplier_bills`, new bill via `post_supplier_bill`, payment via `post_supplier_payment`).
Every write goes through the RPCs already in the database — the UI never does a multi-step client-side sequence
that could leave a payment without a ledger entry.

## 3. Files in this ZIP

New: `nav-icons.tsx`, `quick-actions.ts`, `search-service.ts`, `use-global-search.ts`, `use-nav-preferences.tsx`,
`command-palette-provider.tsx`, `nav-rail.tsx`, `breadcrumb-nav.tsx`, `mobile-bottom-nav.tsx`, `finance.tsx`,
`db/roshan_phase4_finance_pharmacist_grant.sql`.
Modified: `nav.ts` (rewritten), `app-shell.tsx` (rewritten), `i18n.tsx` (Phase 3 + finance keys added, zero
duplicates).
Database: `db/roshan_phase4_finance.sql` applied to the live project in full (not included in this ZIP since its
content is unchanged from the repo — only the follow-up grant file above is new).

## 4. Validation

Every file above was individually type-checked with `tsc --strict` against this repo's actual tsconfig settings
(including cross-file member resolution against its real dependents). All clean. **I could not run
`npm run typecheck` or `npm run build`** — this sandbox has no `node_modules` and no network access to install
them. That is a real gap: isolated `tsc` checks catch syntax/type errors but not bundler-level issues (route tree
generation, Vite resolution, circular imports). Please run both before deploying.

## 5. Not done this session

Phase 5 (Insurance) was not started. It's a large, financially-sensitive module (companies, plans, coverage rules,
prior authorization, a 7-state claims workflow, atomic reconciliation into the cashbox) that deserves the same
schema-first, apply-and-verify treatment as Phase 4 got here — which took most of this session's budget once the
Phase 4 file turned out to need actual database work, not just a UI. Recommend it as its own session, starting from
inspecting whatever insurance-adjacent structures already exist (none were found this session, but Phase 4 also
"already existed" and turned out to be half-applied, so that should be checked directly rather than assumed).

## 6. Installation

1. Unzip preserving paths (matches the repo structure under `roshan-health-hub-main/`).
2. `npm install && npm run typecheck && npm run build` — first real build check; fix anything Vite/route-tree-level
   that isolated `tsc` couldn't see.
3. Database changes are already live — only run `db/roshan_phase4_finance_pharmacist_grant.sql` if you haven't
   already (idempotent, safe to run regardless).
4. Add `/finance` to any hard-coded route allowlists outside `nav.ts` if your deployment has any (none found in
   this repo).
