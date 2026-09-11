# PHASE12_AUDIT.md

## Step 1 — Verification of Phase 1–11 (before touching anything)

Checked directly against this exact ZIP, not memory:
- `clinic.tsx`: zero occurrences of the old bogus `"dob"` column — the Phase 11 query fix is present and intact.
- `queue.tsx` and `ConsultationPage.tsx`: both contain `buttonVariants` — the Phase 11 `Button asChild + Link`
  navigation fixes are present.
- `patients.tsx`: `new_visit` present — the New Visit quick action is present.
- `accounting.tsx`: `post_cashbox_entry` present — the Phase 11 RPC-routing fix is present.

**No Phase 1–11 work was reimplemented.** All work this session is new, on top of a verified-intact base.

## Step 2 — Major correction to my own prior finding

In the last session I stated "billing has zero visit awareness." That was **incomplete, not fully wrong**:
`visits.tsx` already auto-creates a linked invoice (`invoices.visit_id`, `invoices.patient_id`, plus an
`invoice_items` row for the consultation fee) at the moment a visit is created, *if* a fee was set then. The real,
narrower gap — verified by reading `billing.tsx` and `ConsultationPage.tsx` directly — is:
1. Nothing surfaces that already-created invoice anywhere in the clinical workflow. A doctor finishing a
   consultation has no way to see or reach the invoice that was silently created when the visit began.
2. If the fee wasn't set at visit creation (or was zero), there was no safe path to create one later without risking
   a second, duplicate invoice for the same visit — because `invoices.visit_id` had **no uniqueness constraint at
   all** (confirmed live: `idx_invoices_visit_id` existed but was a plain, non-unique index).

## Step 3 — Fix implemented

**`src/features/clinic/consultation/ConsultationPage.tsx`**: added a Billing section in the header actions row,
next to "Finish visit" — the natural, minimal-click location:
- Queries `invoices` by `visit_id`. If one exists → shows it as a clickable summary (amount + status) linking
  straight to `/billing/$invoiceId`. **Never offers to create a second one when one already exists.**
- If none exists and `consultation_fee > 0` → offers "Create invoice", using the *exact same insert shape*
  `visits.tsx` already uses (same RPC for the invoice number, same `invoices`/`invoice_items` pattern) — no new
  financial logic invented, just the same logic made reachable from a second entry point.
- If none exists and the fee is zero/unset → shows nothing (no dead button promising something that can't happen
  without a fee).
- Loading state: billing action area renders nothing while the invoice-lookup query is in flight (no flash of a
  "Create invoice" button that then has to disappear once the real state loads).

**Database — `uq_invoices_visit_id`** (applied live to the connected Supabase project, migration file included for
the repo record): a partial unique index on `invoices(visit_id) where visit_id is not null and deleted_at is
null`. This is what actually prevents a duplicate invoice — the UI check (query first, then decide whether to show
"Create") is a good user experience, but it's not atomic against two rapid clicks or two open tabs. The database
constraint is the real guarantee. **Verified there were zero existing violations before applying** — the migration
would have failed loudly rather than silently corrupting data if there had been any.

## What I did not do, and why

- Did not add `visit_id` to `billing.tsx`'s own invoice list/filtering — the higher-value fix was reachability
  from the clinical side (where the actual workflow gap was reported), and I'd rather ship that verified than
  stretch further into `billing.tsx` under the same time constraint that's applied to every session so far.
- Did not touch Nav Rail / Dashboard / Command Palette / Mobile nav this session — same reasoning as last time:
  the explicit, concrete workflow-integrity work took priority over further cosmetic review, and I'd rather report
  that honestly than pad this with unverified tweaks.

## Files modified
- `src/features/clinic/consultation/ConsultationPage.tsx`

## SQL applied (live, this session)
- `uq_invoices_visit_id` — see `db/roshan_phase12_invoice_visit_unique.sql`, fully idempotent
  (`create unique index if not exists`), safe to re-run.

## Verification
- `tsc --strict` clean on the modified file.
- Could not run `npm run build`/`typecheck` — no `node_modules`/network in this sandbox, consistent with every
  prior session.

## Remaining limitations
- The UI-level "Create invoice" button becomes correctly hidden only after the invoice-lookup query completes and
  re-renders; on a very slow connection there's a brief window where a user could theoretically fire two create
  requests before the first resolves. The database constraint added above is what actually prevents corruption in
  that case — the second request will fail with a clear constraint-violation error rather than silently creating a
  duplicate.
- `billing.tsx`'s own invoice list still doesn't visually indicate which invoices are visit-linked — a small,
  safe follow-up if useful.
