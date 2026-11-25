# Production pharmacy and clinical-correction migration runbook


**Status:** preparation only. Production has not been changed. This document is not authorization to execute the rollout.

## Verified Production preflight — 2026-11-25

Read-only catalog inspection of Production confirmed:

- Required columns exist on `prescriptions`, `prescription_items`, `pharmacy_inventory`, `users`, `role_permissions` and `permissions`.
- The `pharmacist` role already has both `pharmacy.update` and `billing.create`.
- `prescription_item_correction_requests` and `prescription_item_correction_events` do not exist; Phase 61 is expected to create them.
- `public.fn_dispense_prescription_with_invoice(uuid, boolean)` and `public.atomic_pharmacy_dispense(uuid, boolean, uuid)` exist, but their current bodies are the pre-Phase-57/61 versions.
- The current invoice-linked dispense function uses `COALESCE(pi.quantity, 1)`, so a missing prescription quantity can be treated as one unit. It does not reject external prescriptions or free-text items before stock mutation.
- The current atomic dispense function checks broad permission bits but does not enforce the canonical `pharmacist` role.
- The current insurance RLS policies call `private.app_has_claim_branch(uuid)`; that helper exists with a NULL ACL (default PUBLIC EXECUTE). Phase 55 revokes application-role execution, so Phase 55B must immediately follow Phase 55 to rebind those policies.
- Production's migration ledger does not contain Phases 55, 55B, 57, 57B, 61, 61B or 61C.

This is a structural preflight only. It does not prove operational acceptance or backup recoverability.

## Required approvals before Production

1. Independent second-person SQL/security review of PR #300 (Phase 55B) and PR #301 (Phase 61 source parity).
2. Completion of the Production backup/DR gate: encrypted backup, successful PostgreSQL 17 restore, storage object bytes, Vault/secrets and control-plane recovery, approved RPO/RTO, retention/cadence, and a repeatable exercise.
3. Authenticated pharmacist acceptance in isolated QA using synthetic patients, prescriptions and stock only.
4. A scheduled maintenance window and a named operator/reviewer pair.

Do not use real patient data for acceptance tests.

## Proposed migration order

Apply the exact repository SQL sources, not copied SQL from old reports. Confirm each migration is absent from the Production ledger before applying it.

| Order | Migration | Source | Purpose |
|---:|---|---|---|
| 1 | Phase 55 | `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` | Clinical parent guards and private-helper ACL tightening |
| 2 | Phase 55B | `db/roshan_phase55b_private_helper_acl_reconciliation.sql` (PR #300) | Rebind the four insurance policies through the permission-checked wrapper |
| 3 | Phase 57 | `db/roshan_phase57_pharmacy_quantity_required_guard.sql` | Reject missing/invalid prescription quantities |
| 4 | Phase 57B | `db/roshan_phase57b_free_text_external_prescription_guard.sql` | Reject external/free-text prescriptions from internal stock dispensing |
| 5 | Phase 61 | `db/roshan_phase61_prescription_item_correction_workflow.sql` | Auditable pharmacist-to-prescriber correction workflow |
| 6 | Phase 61B | `db/roshan_phase61b_clinical_role_boundary.sql` | Wrap correction and invoice-linked dispensing RPCs with canonical role checks |
| 7 | Phase 61C | `db/roshan_phase61c_atomic_dispense_role_boundary.sql` | Enforce pharmacist role at the atomic dispense boundary |

**Critical ordering rule:** apply Phase 55 and Phase 55B consecutively in the same maintenance window, with no application traffic between them. Phase 55 revokes direct execution on a helper still referenced by the current insurance policies; Phase 55B replaces those policy call sites. The Phase 57/57B/61/61B/61C sources do not reference that insurance helper, so Phase 55B can safely follow Phase 55 before continuing the pharmacy chain.

Do not apply Phase 61C by itself. It depends on Phase 61B's role helper and unchecked-function boundary. Do not manually insert, delete or edit rows in `supabase_migrations.schema_migrations`.

## Post-migration verification

- Confirm all seven migrations appear once in the ledger with the exact names and source commits.
- Confirm `private.app_has_claim_branch`, `private.sync_user_role_text`, `private.fn_dispense_prescription_with_invoice_unchecked` and `private.atomic_pharmacy_dispense_unchecked` are not executable by anon, authenticated, service_role or authenticator.
- Confirm public dispense wrappers are executable by authenticated only and deny Admin, Super Admin, legacy pharmacist aliases and other non-pharmacist roles even if broad permission bits are present.
- Confirm pharmacist requests require both `pharmacy.update` and `billing.create`.
- Confirm null/zero/fractional/oversized quantities, external prescriptions, free-text items, wrong-branch stock and insufficient stock are rejected before invoice, stock movement, prescription status or idempotency side effects.
- Confirm same-prescription and final-stock concurrency tests serialize correctly; confirm identical idempotent retries return the stored result and changed-payload retries fail.
- Confirm correction requests are pharmacist-originated, doctor-resolved, branch-bound, immutable and audited.
- Re-run the exact PostgreSQL 17 Phase 55 and Phase 61 workflows, then perform authenticated pharmacist acceptance with synthetic records.

## Stop conditions

Stop the rollout immediately if any source hash differs, any prerequisite column/function/role permission is missing, a migration version is already present unexpectedly, a policy name differs from the verified live catalog, a migration fails, any denied role creates an idempotency/stock/invoice/audit side effect, or backup restore evidence is incomplete.

On failure, preserve logs and migration evidence. Do not continue to the next migration and do not repair the ledger manually. Use a reviewed forward fix or the approved restore procedure.

## Current environment state

- QA: Phase 55, 57, 57B, 61, 61B and 61C applied; Phase 55B applied as `20261125225912`. Source parity is checked for Phases 57, 57B, 61, 61B and 61C.
- Production: none of the seven migrations above applied; no Production DDL/DML was performed in this review round.
- PR #300: corrected Phase 55B; exact-head CI and PostgreSQL 17 tests passed; independent review pending.
- PR #301: restores Phase 61 source to QA-applied SQL and adds source-hash regression coverage; exact-head CI and Phase 61 PostgreSQL 17 workflow passed; independent review pending.
