# Live schema parity and security audit — 2026-11-03

## Executive result

The production and isolated QA projects are **not yet 100% identical**, but the application schema is structurally aligned across the main database objects when two production-only quarantine artifacts are excluded. The remaining material differences are concentrated in function definitions and function ACLs.

This audit used read-only PostgreSQL catalog queries. It did not read patient, visit, prescription, payment, or other business rows. No production DDL or DML was executed.

## Environment and migration ledgers

| Environment | PostgreSQL | Applied migration records | Latest recorded migration |
|---|---:|---:|---|
| Production | 17.6.1 | 129 | `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` |
| Isolated QA | 17.11 | 21 | `20261103155227 roshan_phase55_clinical_parent_guard_acl_reconciliation` |

The migration-record counts are not a schema-parity metric: QA is a restored baseline plus a selected forward-replay sequence, while production retains its complete migration history. Phase 54, 54B, 54C and 55 are currently recorded in QA only; they have not been applied to production.

## Structural catalog comparison

The comparison covered `public` and `private` application schemas. It excluded the following production-only quarantine artifacts from the application-schema fingerprint:

- `private.roshan_remediation_archive_20261103`
- `private.pharmacy_dispense_idempotency_legacy_20261103`

The hashes below are SHA-256 fingerprints of canonically ordered catalog rows, not hashes of business data.

| Catalog category | Production | QA | Result |
|---|---:|---:|---|
| Tables and columns | 855 | 855 | Exact match |
| Constraints | 218 | 218 | Exact match |
| Indexes | 252 | 252 | Exact match |
| Triggers | 69 | 69 | Exact match |
| RLS flags | 58 | 58 | Exact match |
| RLS policies | 210 | 210 | Exact match |
| Table privileges | 991 | 991 | Exact match |
| Views | 5 | 5 | Exact match |
| Functions/procedures | 143 | 145 | Expected Phase 54/54C additions plus one function-body drift |
| Expanded function ACL entries | 461 | 465 | QA-only Phase 54 RPC grants plus remaining Production helper PUBLIC EXECUTE drift |
| `information_schema.routine_privileges` rows | 430 | 434 | Four additional QA routine grants from Phase 54/54C |

Selected structural fingerprints:

- Tables/columns: `445c3beccfadd67ac1a0705351aa9b684c32068c8febde95e3e86152f3ab795f`
- Constraints: `1991f4a31c6a8a33170606a5770aacb9f52fc5895e0e6eede130d8b5d32e3dcb`
- Indexes: `3fb932e7746722b6386b0c71487900027df47b30f3aa2f1b47a6fecee37b2c81`
- Triggers: `38deff8e003bfc987c351e66f47b85650f76761bd524b6e116fb0ad6ddfcb60d`
- RLS policies: `9f9b11fb85ceffed12c5d65b111886402473c01a0535eecf3be984c2f351911e`

## Material function and privilege drift

### P1 — production clinical child-parent guard is weaker than QA/source

Production's `private.phase36_guard_clinical_visit_links()` does not contain the `lab_order_items.order_id` immutability check present in the tracked Phase 36 migration and the QA function. A caller able to update that child row could re-parent the lab item by changing `order_id` while leaving `patient_id` and `visit_id` unchanged.

PR #172 is merged as `a7592e8fc63f498e55e0962718f4ad84557f1b56`. Phase55 is applied to QA as `20261103155227`; the exact-head PostgreSQL 17 replay passed, and the post-apply read-only catalog checks confirm the tracked function body and owner-only ACLs. Production remains unchanged and still requires the Phase55 correction after the backup/restore gate.

### P1 — Production private helper PUBLIC EXECUTE grants remain

The post-Phase55 read-only catalog check on 2026-11-03 corrected an earlier assumption: **Production also retains default PUBLIC EXECUTE** on both `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()`. Their `pg_proc.proacl` values are NULL, which means PostgreSQL's default function ACL applies, including PUBLIC EXECUTE. The `private` schema grants USAGE to `authenticated`, so the authenticated role can reach these helpers directly. The observed `private` schema USAGE is false for `anon`, `service_role` and `authenticator`; the PUBLIC EXECUTE ACL is nevertheless still present and must be removed.

QA is now corrected: all three Phase55 routines have explicit owner-only ACLs (`{postgres=X/postgres}`), and `has_function_privilege` is false for anon, authenticated, service_role and authenticator. The Phase36 trigger function in Production already has owner-only EXECUTE, but its function body is still weaker than the tracked source.

The post-apply catalog fingerprints are:

| Routine | QA definition MD5 | Production definition MD5 | QA ACL | Production ACL |
|---|---|---|---|---|
| `private.app_has_claim_branch(uuid)` | `97edcb133be77dec2bed4d841abb0b72` | `97edcb133be77dec2bed4d841abb0b72` | Owner only | NULL/default PUBLIC |
| `private.phase36_guard_clinical_visit_links()` | `6178b682e41309873726accd651d3080` | `7b1caf088f05afd13ca982b6d7eca6f8` | Owner only | Owner only |
| `private.sync_user_role_text()` | `e0967b2ed064af199fffe9398bace5a4` | `e0967b2ed064af199fffe9398bace5a4` | Owner only | NULL/default PUBLIC |

All six function metadata rows confirm SECURITY DEFINER with an empty `search_path`. Phase55 removes the two default PUBLIC grants and restores the missing `order_id` guard when separately applied to Production after the backup/restore gate. No production ACL or function was changed during this verification.

### Branch binding is nullable in financial tables

Catalog inspection confirms `branch_id` is nullable on `payments`, `invoices` and `cashbox_transactions`. Phase 54C therefore rejects branchless reversals even for super-admins and makes the receipt read model mark branchless or cross-branch ledger rows as inconsistent. This is safer than relying on role-based branch bypasses.

## Phase 54 financial reversal state

The following migrations are applied and recorded in QA:

| Phase | Migration version | Migration name | Production |
|---|---|---|---|
| 54 | `20261103114242` | `roshan_phase54_source_aware_financial_reversal` | Not applied |
| 54B | `20261103114612` | `roshan_phase54b_payment_updated_at_compat` | Not applied |
| 54C | `20261103115649` | `roshan_phase54c_branchless_receipt_integrity` | Not applied |
| 55 | `20261103155227` | `roshan_phase55_clinical_parent_guard_acl_reconciliation` | Not applied |

Phase 54B exists because `public.payments` has `updated_by` but **does not have `updated_at`**. The original Phase 54 migration is historical and remains unchanged; Phase 54B is the forward compatibility correction. Phase 54C is a separate forward-only migration and adds:

- source-aware invoice payment reversal;
- generic reversal guards for payment, supplier-payment and insurance-payment sources;
- branch-binding checks that super-admin status cannot bypass;
- `get_invoice_payment_receipt_status(uuid[])`, capped at 200 IDs, requiring `payments.read` and `billing.read`, and returning only branch-scoped ledger consistency/status fields.

QA Phase 54C verification confirmed the three RPCs are SECURITY DEFINER with an empty `search_path`; `anon` cannot execute them and `authenticated` can execute them subject to the internal permission and branch checks. PostgreSQL 17 CI covers active/reversed receipts, branch isolation, branchless records, duplicate reversal, supplier/insurance source blocking and non-payment reversal.

## Supabase advisor snapshot after Phase 54C (QA)

- Security: 32 findings — 31 WARN and 1 INFO.
- The single anon SECURITY DEFINER warning is the intentionally public `setup_required()` bootstrap RPC; the anonymous-role transaction test returned `false` in both environments.
- Authenticated SECURITY DEFINER warnings include the guarded financial RPCs; these are intentionally authenticated-only and enforce permission/branch checks internally.
- Other pre-existing warnings: extension in `public`, leaked-password protection disabled, and private RLS-enabled table without policies.
- Performance: 146 INFO-level unused-index findings; no new performance warning was introduced by Phase 54C.

The advisor output is a diagnostic list, not a reason to grant broader permissions or move extensions without checking application dependencies and plan/cost implications.

## Production safety and unresolved backup gate

No production migration was applied during this audit. Production work was read-only, including the anonymous bootstrap-role check inside a rolled-back transaction.

The connected Supabase tools expose project inspection, migration application and advisor checks, but do not expose a database backup/export plus isolated restore workflow. No verified encrypted backup and restore evidence is available in the repository or connected tools. Therefore production Phase 54/54B/54C and Phase 55 remain blocked.

The production migration `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` is already recorded as applied. Its recovered provenance artifact contains redacted identifiers/placeholders and is not a replayable migration source. It must not be re-run. This audit did not inspect patient rows or attempt to infer whether the redacted records were synthetic.

## Next gates

1. Phase55 PostgreSQL 17 replay and exact-head full CI passed; QA application and read-only function/ACL verification are complete. PR #172 is merged. Production still requires Phase55 after backup/restore.
2. Finish Phase 53 printing UI using the Phase 54C receipt-status RPC; keep receipt printing visibly unavailable when the RPC is absent in production.
3. Obtain a verified encrypted production backup and isolated restore before applying Phase 54, 54B, 54C and Phase 55 to production.
4. Re-run the same catalog fingerprint and advisor checks after each environment transition; do not claim 100% parity until function bodies and effective routine privileges match, excluding only the documented quarantine artifacts.
