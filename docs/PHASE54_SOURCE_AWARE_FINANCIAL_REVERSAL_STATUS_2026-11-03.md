# Phase 54 source-aware financial reversal — status (2026-11-03)

## Delivered
- PR #168 merged: `bf2792b2057d86ee285e21ea531cac4f82e758a3`.
- PR #169 merged: `dc31fd3da67510759cae59de8abfe987d75ac96b`.
- Phase 54 and Phase 54B are present in main under:
  - `db/roshan_phase54_source_aware_financial_reversal.sql`
  - `db/roshan_phase54b_payment_updated_at_compat.sql`

## QA deployment and verification
- QA migration `20261103114242_roshan_phase54_source_aware_financial_reversal` applied.
- QA migration `20261103114612_roshan_phase54b_payment_updated_at_compat` applied.
- The first real-schema smoke exposed that `payments.updated_at` does not exist in Production or QA. The transaction failed and rolled back; follow-up read-only checks found zero synthetic invoice/payment rows.
- Phase 54B removed that nonexistent-column dependency while preserving `updated_by` actor attribution.
- Focused PostgreSQL 17 run `41630073392`: passed.
- Exact-head full CI run `41630073310`: 18 success, 0 failure, 1 intentional skip (`Canonical PG17 baseline replay and authenticated clinical acceptance`).
- Real QA transactional smoke after Phase 54B passed:
  1. Generic reversal rejected for a source-linked payment without side effects.
  2. Invoice payment reversed through the source-specific function.
  3. Payment soft-deleted with both `deleted_by` and `updated_by` set to the actor.
  4. Invoice paid balance/status recomputed.
  5. One linked reversal ledger row created; second attempt rejected.
  6. Explicit transaction rollback left zero synthetic QA invoice/payment rows.
- ACL: `anon_execute=false`, `authenticated_execute=true`.

## Production boundary
- No Phase 54 or Phase 54B migration has been applied to Production.
- Production catalog still has no `reverse_invoice_payment(uuid,text)` function and the generic reversal function has no payment-source guard.
- Encrypted backup and isolated restore rehearsal remain release gates. Do not apply Phase 54/54B to Production before those gates pass.

## Remaining
- Dedicated supplier-payment and insurance-claim-payment reversal workflows are not implemented; generic reversal blocks those source-linked rows.
- Full migration-chain reconciliation, authenticated clinical E2E, and staff UAT remain open.
- The SECURITY DEFINER advisor finding for `reverse_invoice_payment` is expected for this guarded authenticated RPC; it is not executable by anon. Existing unrelated advisor findings remain unchanged.
