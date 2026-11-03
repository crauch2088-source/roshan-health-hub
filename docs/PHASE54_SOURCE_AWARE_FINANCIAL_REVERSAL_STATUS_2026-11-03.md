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

## Phase 54C, UI guard, and current deployment follow-up (2026-11-03)

- Phase 54C source is present in main: `db/roshan_phase54c_branchless_receipt_integrity.sql`.
- QA migration `20261103115649_roshan_phase54c_branchless_receipt_integrity` is present in the QA migration history.
- Dedicated PostgreSQL 17 workflow run `41667019118` passed against main SHA `a1ee3ae937f351311ab1838a135ce6e95d825db0`; the synthetic fixture, Phase 54/54B/54C replay, and behavioral assertions all succeeded.
- PR #176 merged as `e098b9ed7110a6c9d0d623a790989d1c89ef58d0`. The finance UI now loads `source_type`, suppresses generic cashbox reversal for invoice/supplier/insurance payment ledger rows in mobile and desktop layouts, and explains the restriction in Arabic and English.
- Exact main push CI run `41669124069`: 18 successful jobs, zero failures, one intentional skip (canonical baseline replay plus authenticated clinical acceptance).
- Vercel Production deployment `dpl_93E58qVFXexLc8RFmPDUj67KrAUA` reached READY for the merge commit. A 30-minute post-deploy runtime-error query returned no errors.
- No Production or QA database writes were made as part of PR #176 or this follow-up.

## Outstanding reconciliation and release gates

- Production migration history currently contains no Phase 54, 54B, or 54C migration. Do not apply them to Production until the encrypted backup and isolated restore rehearsal pass.
- QA migration history also contains `20261103155227_roshan_phase55_clinical_parent_guard_acl_reconciliation`, but no matching Phase 55 source migration or commit was found on main at SHA `e098b9ed7110a6c9d0d623a790989d1c89ef58d0`. Treat this as an unresolved QA/source-parity discrepancy; do not replay, reverse, or infer its SQL. Reconcile its provenance and source before further migration-chain work.
- The source-specific invoice reversal RPC is not yet exposed as an action in the UI. The generic reversal path is now blocked for all source-linked payment types. Supplier and insurance source-specific reversal workflows remain unimplemented.
- Encrypted Production backup and restore rehearsal remain NOT DONE. The private backup runner is prepared, but its short-lived Supabase PAT secret and public age recipient variable still require owner-side secure setup; the age private identity must remain offline or in a password manager.
- Full migration-chain reconciliation, authenticated clinical E2E, and staff UAT remain open.

