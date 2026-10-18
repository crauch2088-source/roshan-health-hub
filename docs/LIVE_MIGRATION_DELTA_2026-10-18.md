# Live migration source delta — 2026-10-18

This is a source-mapping supplement to the frozen 93-entry normalized-SQL hash snapshot in `docs/recovered-migrations/source-parity-report.json`. It is based on the live Supabase migration ledger read-back at 107 entries through `20261018064139`; it is **not** a fresh hash of SQL stored by Supabase, because the connected Management API exposes ledger name/version but not persisted migration SQL text.

| Live version | Ledger name | Canonical source file | Evidence |
|---|---|---|---|
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | `db/roshan_security_candidate_bundle_20261017.sql` | Included in the prior 96/97 source-match audit. |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | `db/roshan_phase5_insurance_claim_amount_integrity.sql` | Included in the prior 96/97 source-match audit. |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | `db/roshan_phase5_insurance_coverage_validity.sql` | Included in the prior 96/97 source-match audit. |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | `db/roshan_phase27_revoke_legacy_invoice_number.sql` | Included in the prior 96/97 source-match audit. |
| `20261017225523` | `roshan_insurance_prior_authorization_branch_isolation` | `db/roshan_insurance_prior_authorization_branch_isolation.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017225540` | `roshan_post_expense_finite_amount` | `db/roshan_post_expense_finite_amount.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017230623` | `roshan_post_expense_money_precision` | `db/roshan_post_expense_money_precision.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017230645` | `roshan_insurance_claim_money_precision` | `db/roshan_insurance_claim_money_precision.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017231612` | `roshan_invoice_payment_money_precision` | `db/roshan_invoice_payment_money_precision.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017231629` | `roshan_pharmacy_batch_money_precision` | `db/roshan_pharmacy_batch_money_precision.sql` | Exact source text submitted to the migration API; ledger version/name read back. |

The companion JSON contains normalized **source-file** hashes and source Git blob IDs. The CI verifier checks these files have not drifted and that the delta mapping remains fourteen unique ordered entries. It does not assert that the six live SQL hashes were read from Supabase.

The original 93-entry snapshot still has 92 normalized content matches and one intentionally redacted environment-specific identity mapping. The fourteen later migrations are accounted for separately. The full migration chain remains unreplayable from a reviewed initial schema baseline; this source-mapping check is not a substitute for replay or semantic equivalence.


## Additional live migrations verified on 2026-10-18

| Live version | Ledger name | Canonical source file | Evidence |
|---|---|---|---|
| `20261018061746` | `roshan_pharmacy_batch_receipt_idempotency` | `db/roshan_pharmacy_batch_receipt_idempotency.sql` | Exact source submitted to Supabase; ledger version/name read back. |
| `20261018062939` | `roshan_pharmacy_batch_receipt_guards` | `db/roshan_pharmacy_batch_receipt_guards.sql` | PostgreSQL 17 regression passed; exact migration version/name read back. |
| `20261018063549` | `roshan_phase19_invoice_rpc_only_writes` | `db/roshan_phase19_invoice_rpc_only_writes.sql` | PostgreSQL 17 regression passed; direct invoice DML denial and parent-branch read policy verified. |
| `20261018064139` | `roshan_phase20_clinical_child_branch_isolation` | `db/roshan_phase20_clinical_child_branch_isolation.sql` | PostgreSQL 17 branch-isolation regression passed; policy/helper catalog read back. |

The forward delta now has fourteen source mappings over the frozen 93-entry historical snapshot. The source hashes describe repository files; they do not prove stored live SQL hashes or full historical replay.
