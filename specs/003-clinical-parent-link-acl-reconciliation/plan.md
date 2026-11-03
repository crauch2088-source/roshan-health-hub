# Implementation Plan: Clinical parent-link and private helper ACL reconciliation

## Design

Use a forward-only migration to replace the live-drifted Phase36 trigger function with the exact tracked function body, then revoke direct EXECUTE on private helper/trigger functions from all application roles. Do not recreate triggers or change tables.

## Migration

`db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql`:
- restores the `order_id` immutable guard;
- preserves existing cancelled-visit and patient/visit immutability checks;
- explicitly revokes direct EXECUTE from PUBLIC, anon, authenticated, service_role and authenticator.

## Validation

A disposable PostgreSQL 17 workflow:
1. creates the Phase36 fixture;
2. applies the tracked Phase36 migration;
3. simulates the weaker production function and permissive QA helper ACLs;
4. applies Phase55;
5. re-runs Phase36 behavioral assertions;
6. asserts order_id immutability, helper ACLs and trigger operation under authenticated role.

Apply to QA after PR merge and verify advisors/catalog. Production application remains behind the encrypted backup/restore gate.
