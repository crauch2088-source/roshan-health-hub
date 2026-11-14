# Roshan Health Hub — SECURITY DEFINER triage

**Evidence captured:** 2026-11-12 09:06:45 UTC  
**Application main:** `08da4612e7bda89481a0afd7007fd3a1dc7467c8`  
**Production project:** `jewzonxplxhogqrnhosl` (PostgreSQL 17.6)  
**QA project:** `hopfohcnrtbiqjkgeukz` (PostgreSQL 17.11)

This is a read-only catalog/advisor review. No SQL, ACL, RLS, Auth, Storage, patient, clinical, inventory, or financial writes were performed.

## 1. Supabase advisor and catalog totals

| Measure | Production | QA |
|---|---:|---:|
| Public SECURITY DEFINER functions | 53 | 58 |
| Public SECURITY DEFINER functions executable by authenticated | 26 | 30 |
| Public SECURITY DEFINER functions executable by anon | 1 | 1 |
| Authenticated-callable functions with an explicit `app_has_perm` check in the function body | 23 | 27 |
| Authenticated-callable functions without a direct `app_has_perm` call | 3 | 3 |
| Authenticated-callable functions without fixed empty `search_path` | 0 | 0 |

The Supabase advisor reports 26 Production and 30 QA authenticated-callable SECURITY DEFINER warnings, plus one anon-callable function in each project. These are findings for function-by-function review, not evidence that every RPC is an exploitable vulnerability. Most are intentionally callable application RPCs with explicit permission checks, fixed empty search paths, and narrowly scoped behavior.

### The three authenticated-callable functions without a direct permission check

- `public.complete_visit_atomic(uuid)`: a short wrapper that delegates to `public.complete_clinical_visit_and_bill(uuid)`, which performs the permission check. Preserve the wrapper only while the delegated contract remains guarded.
- `public.get_my_app_profile()`: requires `auth.uid()` and selects only the application profile linked to that Auth identity. This is a self-profile RPC, not a general user lookup.
- `public.setup_required()`: returns only the boolean result of `private.setup_required()`, which is `NOT EXISTS (SELECT 1 FROM public.users)`. This is the intentional unauthenticated first-run bootstrap-status check; it does not return user records or PII.

All authenticated-callable public SECURITY DEFINER functions in both environments were read back with a fixed empty `search_path`. No blanket revocation or conversion to SECURITY INVOKER is justified by the advisor count alone.

## 2. Concrete Production/QA privilege drift

### 2.1 Private Phase 55 helpers — Production exposure

Production currently has default/PUBLIC-effective EXECUTE on:

- `private.app_has_claim_branch(uuid)`
- `private.sync_user_role_text()`

Effective privilege checks show anon, authenticated, service_role, and authenticator can execute these functions in Production. QA has owner-only ACLs for both; those application roles cannot execute them directly.

The tracked forward-only migration `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` revokes direct application-role execution while preserving trigger execution and SECURITY DEFINER caller behavior. Its source payload was verified byte-for-byte against QA's stored Phase 55 migration payload. Dedicated PostgreSQL 17 workflow [#43184305893](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43184305893) passed, including trigger and ACL assertions.

**Disposition:** high-priority narrow ACL reconciliation. Do not hand-edit grants or migration history; apply the reviewed Phase 55 migration only after the remaining recovery/release gates pass.

### 2.2 Deferred insurance-payment RPC — Production-only authenticated EXECUTE

`public.post_insurance_claim_payment(uuid,numeric,text,text)` is executable by authenticated in Production but not in QA. The function has `insurance.update` and branch checks, but the insurance settlement/currency-provenance workflow is explicitly deferred. The tracked Phase 58 migration conditionally revokes this RPC.

**Disposition:** do not expose or use this workflow until the approved persisted-currency source path exists. Phase 58 is the tracked forward migration that adds SDG provenance and removes the deferred RPC's browser-role EXECUTE grant. Do not issue an isolated ad-hoc grant change or enable insurance payment behavior.

### 2.3 QA-only RPCs

QA has five public SECURITY DEFINER signatures absent from Production:

- `get_invoice_payment_receipt_status(uuid[])`
- `get_invoice_payment_receipt_status_v2(uuid[])`
- `request_prescription_item_correction(uuid,text)`
- `resolve_prescription_item_correction(uuid,text,jsonb,text)`
- `reverse_invoice_payment(uuid,text)`

The receipt functions are part of the QA-only receipt/currency workstream; the correction functions are part of QA-only Phase 61. Their presence in QA is not authorization to copy grants or migration-ledger rows into Production.

## 3. Private idempotency tables and advisor INFO finding

The advisor reports RLS-enabled tables with no policies:

- Production: `private.pharmacy_dispense_idempotency` and legacy `private.pharmacy_dispense_idempotency_legacy_20261103`.
- QA: `private.pharmacy_dispense_idempotency`.

Catalog checks confirm RLS is enabled; there are zero policies; anon, authenticated, and service_role have no SELECT privilege. The active table has an owner-only ACL. The legacy Production table has no application-role table grants either.

This is intentional private-schema isolation for SECURITY DEFINER dispensing logic, not a reason to add permissive policies. Do not drop the legacy table until dependencies and recovery requirements are separately established.

## 4. Other advisor findings

- `pg_trgm` is installed in `public` in both projects. The advisor flags this as a warning; moving it requires extension/dependency analysis and is not part of the urgent ACL fix.
- No authenticated-callable public SECURITY DEFINER function lacked a fixed empty search path in either project.
- The only anon-executable public SECURITY DEFINER function in either environment is `public.setup_required()`, which returns a boolean first-run status.

## 5. Related release evidence and next actions

- Production ledger: 129 rows, latest `20261102232941`; QA ledger: 26 rows, latest `20261112061251`.
- Exact QA stored-payload parity has been verified for Phase 55, Phase 57 and Phase 57B. Phase 58 and Phase 59 source bodies also match QA stored payloads.
- PostgreSQL 17 tests passed for Phase 55, Phase 57/57B pharmacy dispensing, Phase 58/59 currency provenance, and the Phase 49/50 atomic pharmacy/visit-billing path.
- Fresh encrypted Production backup and runner-side local PostgreSQL 17 restore rehearsal passed in backup run [#43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731); ciphertext integrity and the canonical private Drive copy were verified.
- The owner-side offline decryption of the retained archive has not yet been independently verified. The private age identity must remain offline and must never be pasted into ChatGPT, GitHub, an issue, or a workflow log.
- An independent second-person migration review and explicit Production release-window/recovery sign-off remain open. Production migrations are therefore still **NO-GO** despite standing delegated authorization.
- No Production or QA DDL/DML/ACL/RLS/Auth/Storage change was made during this review.

### Recommended sequence

1. Owner verifies decryption of the retained archive offline and confirms the result without sharing the private identity.
2. Obtain independent review of the exact forward-only Phase 55/57/57B package and its source fingerprints.
3. Apply Phase 55, then Phase 57 and Phase 57B to Production through migration-history-preserving tooling; verify ACLs, trigger behavior, quantity rejection, free-text/external rejection, and absence of inventory/finance side effects.
4. Reconcile and rehearse Phase 58/59 against Production's actual finance schema; apply only after source, compatibility, backup, and post-change gates pass.
5. Only after Phase 58/59 are deployed and verified should the receipt UI PR be considered for merge/deployment; cashier, Android, RTL/LTR, A4/thermal printer acceptance remains a separate human gate.

**Progress accounting:** this catalog review and documentation do not earn implementation-completion credit. The unmerged receipt compatibility fix is a validated PR branch, not a shipped feature. Keep the last evidence-weighted baseline at 62% Engineering RC / 15% operational acceptance until a qualifying implementation is merged and verified.
