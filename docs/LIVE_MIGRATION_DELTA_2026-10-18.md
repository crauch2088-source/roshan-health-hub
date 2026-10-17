# Live migration source delta — 2026-10-18

This is a source-mapping supplement to the frozen 93-entry normalized-SQL hash snapshot in `docs/recovered-migrations/source-parity-report.json`. It is based on the live Supabase migration ledger read-back at 99 entries through `20261017225540`; it is **not** a fresh hash of SQL stored by Supabase, because the connected Management API exposes ledger name/version but not persisted migration SQL text.

| Live version | Ledger name | Canonical source file | Evidence |
|---|---|---|---|
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | `db/roshan_security_candidate_bundle_20261017.sql` | Included in the prior 96/97 source-match audit. |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | `db/roshan_phase5_insurance_claim_amount_integrity.sql` | Included in the prior 96/97 source-match audit. |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | `db/roshan_phase5_insurance_coverage_validity.sql` | Included in the prior 96/97 source-match audit. |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | `db/roshan_phase27_revoke_legacy_invoice_number.sql` | Included in the prior 96/97 source-match audit. |
| `20261017225523` | `roshan_insurance_prior_authorization_branch_isolation` | `db/roshan_insurance_prior_authorization_branch_isolation.sql` | Exact source text submitted to the migration API; ledger version/name read back. |
| `20261017225540` | `roshan_post_expense_finite_amount` | `db/roshan_post_expense_finite_amount.sql` | Exact source text submitted to the migration API; ledger version/name read back. |

The companion JSON contains normalized **source-file** hashes and source Git blob IDs. The CI verifier checks these files have not drifted and that the delta mapping remains six unique ordered entries. It does not assert that the six live SQL hashes were read from Supabase.

The original 93-entry snapshot still has 92 normalized content matches and one intentionally redacted environment-specific identity mapping. The six later migrations are accounted for separately. The full migration chain remains unreplayable from a reviewed initial schema baseline; this source-mapping check is not a substitute for replay or semantic equivalence.
