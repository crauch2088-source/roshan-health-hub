# Roshan Health Hub — Billing Architecture Decision

**Status:** Owner-approved product rule; implementation and rollout still pending review.
**Date:** 2026-10-15
**Repository:** crauch2088-source/roshan-health-hub

## Decision
One detailed, itemized invoice per visit is the default. The invoice consolidates all billable services associated with the visit: consultation, each laboratory test, procedures, dispensed medicines, and other charges. Every line records description/type, quantity, unit price, and line total. The invoice shows subtotal, discount, net total, payments, and outstanding balance so reception and accounting can calculate and review the visit in one place.

Separate invoices are allowed only when explicitly requested/selected or required by a reviewed operational rule. A new lab order must not automatically create a second invoice merely because its workflow ran later than the consultation.

## Financial and data invariants
1. Invoice header and line changes are transactional; failure rolls back the whole invoice operation.
2. Server-side logic validates amounts and derives totals from line items. Client totals are display/preflight only.
3. Existing payments and audit history are preserved. Adding a new charge must never silently overwrite payment data or reduce net total below amount already paid.
4. A finalized/paid invoice is not silently changed. The workflow must either use an explicitly separate invoice or a separately authorized correction/adjustment path.
5. Primary and intentional secondary invoices must be distinguishable in the data model. The existing uq_invoices_visit_id partial unique index is live; its replacement requires a separate reviewed migration and validation against current data.
6. Authorization must be workflow-specific (visit, laboratory, pharmacy, or billing) and enforce active patient/visit and branch boundaries inside the RPC. Do not grant broad billing.create to clinical roles as a shortcut.
7. Existing legacy invoices remain readable and reconcilable; migration must not rewrite historic invoice or payment records.

## Required integration scenarios
- Create a visit with a consultation fee, then add one and several laboratory tests: all lines appear on the same primary invoice.
- Add charges to unpaid and partially paid invoices; preserve payments and recalculate outstanding balance correctly.
- Attempt to append to a paid/finalized invoice: reject or require an explicit separate invoice/correction path.
- Explicitly create a secondary invoice for a visit and verify it does not replace or duplicate the primary invoice.
- Concurrent lab orders do not create duplicate primary invoices or lose line items.
- Cross-branch and unauthorized requests fail; malformed precision/quantities fail; injected item-write failures roll back.
- Every UI workflow uses a server-side atomic RPC instead of direct invoice-header/item writes.

## Implementation status — 2026-10-15
Draft PR #23 now routes visit creation and the consultation fallback through a server-derived consultation invoice RPC; the lab-order workflow creates the order, order items, and catalog-priced invoice lines in one transaction. The internal invoice helper is private and revoked from authenticated/anon; the public consultation wrapper does not accept client-supplied prices. Repeated consultation-invoice requests are idempotent. An explicit separate-invoice toggle is available to billing-authorized users in the lab workflow. PostgreSQL 17 integration, security audit, guard tests, typecheck, lint, and build passed on head `57ddfad38f1fe609c50487fa4d63548d231d931b` in [run #38811740570](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38811740570).

Pharmacy dispensing has not yet been wired to invoice lines; the generic private helper intentionally does not permit `pharmacy.create` to submit arbitrary medicine/price data. A dedicated dispense-and-invoice RPC must validate actual dispensed batch/quantity/price before pharmacy lines can be added.

# Rollout constraints
The implementation remains a draft proposal. SQL must remain unapplied until migration-history reconciliation, isolated Supabase branch validation, and authenticated smoke tests pass. Vercel preview is currently blocked by the account build-rate limit. No merge or production rollout is authorized by this decision alone.


## Verified permission constraint (read-only production inspection)
The deployed permission catalog currently assigns `billing.create` to admin, pharmacist, receptionist, and super_admin; `visits.create` includes doctor/receptionist; `lab.create` includes doctor/lab_tech. The deployed `invoices` table has `visit_id` but no primary/secondary discriminator, and the existing unique index is live. Accordingly, workflow-specific RPCs must validate `visits.create`, `lab.create`, `pharmacy.create`, or `billing.create` according to the line-item source. Do not weaken authorization or let clinical callers bypass the guarded invoice-number RPC by calling it directly. This was a read-only catalog/schema inspection; no production data or schema was changed.
