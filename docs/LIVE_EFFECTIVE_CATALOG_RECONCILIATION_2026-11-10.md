# Effective PostgreSQL catalog reconciliation — 2026-11-10

## Scope

Read-only comparison of Production project `jewzonxplxhogqrnhosl` (PostgreSQL 17.6) and isolated QA project `hopfohcnrtbiqjkgeukz` (PostgreSQL 17.11). The comparison covered relation definitions, columns, constraints, indexes, RLS flags, policies, triggers, function definitions/security properties/ACLs, and table-level grants in `public` and `private`.

The queries read catalog metadata and function definitions only. No business rows, patient data, prescription data, invoice data, payment data, stock rows, Auth users, Storage objects or Vault secrets were queried. No DDL/DML or hosted setting was changed.

## Executive result

The previously reported public-schema structure is now confirmed in a direct object-by-object comparison. **All public table/view definitions, columns, constraints, indexes, RLS flags, policies, triggers and table-level grants match across the two environments in the captured scope.** Remaining differences are concentrated in (1) two Production-only private quarantine tables, (2) known QA-only forward migrations, and (3) two private helper-function ACLs.

| Object category | Production | QA | Interpretation |
|---|---:|---:|---|
| Relations (public + private) | 65 | 63 | Two additional Production-only private quarantine tables |
| Columns | 866 | 855 | Eleven additional columns belong only to those two private tables |
| Constraints | 222 | 218 | Four additional constraints belong only to the private tables |
| Indexes | 254 | 252 | Two additional indexes belong only to the private tables |
| RLS-enabled/forced tables | 60 | 58 | The two additional private tables account for the difference |
| RLS policies | 210 | 210 | Exact same aggregate fingerprint and object-level set |
| Non-internal triggers | 69 | 69 | Exact same aggregate fingerprint and object-level set |
| Functions/procedures | 143 | 145 | Two QA-only public functions; several known definitions differ by QA-only forward migrations |
| Table-level grants | 1,733 | 1,719 | Fourteen additional grants are only to postgres on the two private tables |

The aggregate category fingerprints were computed from sorted catalog descriptors. They are comparison fingerprints, not cryptographic attestations. The object-level grouping diff was also checked; it found no public table/column/constraint/index/policy/trigger/table-grant differences.

## Production-only private quarantine objects

| Object | State | Grants |
|---|---|---|
| `private.pharmacy_dispense_idempotency_legacy_20261103` | RLS enabled, not forced; 4 columns, 3 constraints, 1 index | postgres only |
| `private.roshan_remediation_archive_20261103` | RLS disabled; 7 columns, 1 constraint, 1 index | postgres only |

Both objects are in the non-public `private` schema and have no table grants to anon, authenticated or service_role. They are quarantine/archive artifacts, not public application tables. Their presence in Production is intentional historical state; do not drop, replay or copy them to QA as a parity exercise.

## Function differences explained by the migration ledger

### QA-only functions

- `public.reverse_invoice_payment(uuid,text)` exists only in QA. It is introduced by the Phase 54 source-aware financial reversal work.
- `public.get_invoice_payment_receipt_status(uuid[])` exists only in QA. It is introduced by the Phase 54C receipt-integrity work.

### Different function definitions

| Function | Production | QA | Known explanation |
|---|---|---|---|
| `public.reverse_cashbox_entry(uuid,text)` | Older generic reversal implementation | Requires active app user and branch-bound original row; rejects payment/supplier-payment/insurance-payment source types that require source-specific workflows | Phase 54 is QA-only |
| `private.phase36_guard_clinical_visit_links()` | Does not reject a changed `lab_order_items.order_id` | Rejects changing `order_id` on existing lab-order items | Phase 55 is QA-only |
| `public.fn_dispense_prescription_with_invoice(uuid,boolean)` | Retains `COALESCE(pi.quantity,1)` fallback | Explicitly rejects NULL catalogue-linked quantities before invoice/stock mutation | Phase 57 is QA-only |

The function differences above are consistent with the live migration ledgers: Production has no Phase 54/54B/54C/55/57 rows; QA has Phases 54/54B/54C/55/57. They are known release deltas, not unexplained drift. Phase 57B's free-text/external-prescription guard is a candidate-only forward migration and is not applied to either hosted environment. Phase 58/59 SDG provenance migrations are also candidate-only and neither environment currently has the seven currency columns.

## Private helper ACL discrepancy requiring Production follow-up

The function bodies and security properties match, but effective ACLs differ:

| Function | Production | QA |
|---|---|---|
| `private.app_has_claim_branch(uuid)` | authenticated has schema USAGE and EXECUTE; anon/service_role have no private-schema USAGE | direct EXECUTE revoked from anon/authenticated/service_role |
| `private.sync_user_role_text()` | authenticated has schema USAGE and EXECUTE; anon/service_role have no private-schema USAGE | direct EXECUTE revoked from anon/authenticated/service_role |

The helper functions use an empty search path and SECURITY DEFINER. `sync_user_role_text()` is trigger-only, but its direct EXECUTE privilege should still be revoked. The direct authenticated EXECUTE privilege on `private.app_has_claim_branch(uuid)` is the more material difference: it permits an authenticated database role to invoke a private branch/claim helper in Production, whereas QA revokes that privilege. The existing Phase 55 source contains the explicit revoke for both functions; Production has not received that forward migration.

The following ACL text differences are ordering-only and have the same effective privilege checks in both environments: `public.enforce_public_system_setting_keys()`, `public.sync_medicines_2_stock_columns()`, `public.sync_pharmacy_inventory_legacy_columns()`, `public.users(follow_ups)`, and `public.verify_lab_order(uuid)`. The trigger functions remain trigger-only; `verify_lab_order` denies anon and allows authenticated/service_role in both environments.

## Reconciliation conclusion

1. Public schema structure and table-level access controls are materially aligned in the categories tested.
2. Production's missing Phase 54/54C/55/57 forward migrations explain the known function-body and QA-only function differences.
3. The private helper ACL discrepancy is an actionable Production hardening item. Phase 55 already carries the relevant revoke statements, but no Production application is authorized here.
4. Production-only private quarantine tables must remain intact and private; they are not evidence of public schema drift.
5. The full effective catalog is not yet declared identical: function definitions and the two helper ACLs still differ as described above. The next step is an independently reviewed, forward-only Production rollout plan after the backup/restore and source-reconciliation gates, not manual catalog edits.

## Safety boundary

This was a read-only catalog comparison. No Production or QA migration, DDL/DML, role/permission/Auth/Storage change, business-data write, deployment, or backup operation was performed. All candidate PRs remain Draft. This report does not authorize Production rollout.
