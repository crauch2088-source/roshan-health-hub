# Supabase Security Advisor Triage — 2026-10-19

## Scope

Read-only triage of the live Supabase Security Advisor findings for project `jewzonxplxhogqrnhosl` (PostgreSQL 17.6). No privileges, function definitions, extension placement, authentication settings, or business data were changed during this review.

## Summary

The advisor reports three categories:

| Finding | Count | Triage |
|---|---:|---|
| Authenticated users can execute SECURITY DEFINER functions | 22 | Expected for the application's client-callable RPC architecture, subject to the per-function guard review below. No blanket revocation justified. |
| Extension installed in `public` (`pg_trgm`) | 1 | Defer schema move until operator classes/index dependencies and extension relocation compatibility are mapped. |
| Leaked-password protection disabled | 1 | Supabase feature is plan-gated on the connected tier; no paid upgrade or workaround attempted. |

## Per-function catalog review

The live catalog query enumerated the exact 22 functions listed by the advisor. For all 22:

- `prosecdef = true` (SECURITY DEFINER).
- Function configuration fixes `search_path` to the empty string.
- `authenticated` has EXECUTE.
- `anon` does not have EXECUTE.
- The source-text scan found application permission-helper markers and branch/actor-context markers in 21 of the 22 function bodies. The exception is `get_my_app_profile()`, which binds its output to the caller via `auth.uid()`. These markers are triage evidence only, not a substitute for a full line-by-line adversarial review of every body.

### Clinical workflows

| Function | Catalog finding | Decision |
|---|---|---|
| `complete_lab_order_item(uuid)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; test suite covers branch/permission and state-transition checks. |
| `complete_visit_atomic(uuid)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; test suite covers atomic/idempotent visit/queue completion. |
| `create_billing_invoice_atomic(..., p_request_id uuid)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep current overload; request-id overload is the intended idempotent RPC. |
| `create_lab_order_with_invoice_atomic(..., p_request_id uuid)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep current overload; request-id overload is the intended idempotent RPC. |
| `create_medical_certificate(uuid,text,date,date,uuid)` | Permission-helper + branch/actor markers; linked visit; empty fixed search path; authenticated only | Keep client EXECUTE; doctor role, branch, patient/visit consistency and cancelled-visit checks are covered by Phase 31 regression. |
| `create_patient_atomic(text,text,date,text,text)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; atomic registration and national-ID uniqueness have regression coverage. |
| `create_prescription_atomic(uuid,boolean,jsonb)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; preserve atomic prescription creation. |
| `create_visit_consultation_invoice_atomic(uuid,date)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; preserves atomic visit-consultation invoicing. |
| `get_visit_form_options()` | Permission + caller/branch context; empty fixed search path; authenticated only | Keep client EXECUTE; options RPC is required for permission-safe visit forms. |

### Insurance workflows

| Function | Catalog finding | Decision |
|---|---|---|
| `create_insurance_claim(uuid,uuid,jsonb,text)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; claim/invoice consistency checks remain important. |
| `fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric)` | Permission-helper + caller identity binding; empty fixed search path; authenticated only | Keep client EXECUTE; do not revoke a calculation RPC used by insurance flows. |
| `post_insurance_claim_payment(uuid,numeric,text,text)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; maintain RPC-only financial writes. |
| `update_insurance_claim_status(uuid,text,numeric,text)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; maintain claim status and approval invariants. |

### Pharmacy and inventory workflows

| Function | Catalog finding | Decision |
|---|---|---|
| `fn_dispense_prescription_with_invoice(uuid,boolean)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; dispense must remain invoice-backed and atomic. |
| `fn_receive_pharmacy_batch_atomic(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; inventory receiving uses an atomic/idempotent RPC. |

### Finance workflows

| Function | Catalog finding | Decision |
|---|---|---|
| `post_cashbox_entry(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; validated cashbox RPC. |
| `post_expense(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; validated expense RPC. |
| `post_invoice_payment(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; precision/idempotency/concurrency tests remain required. |
| `post_supplier_bill(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; validated supplier-bill RPC. |
| `post_supplier_payment(...)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; validated supplier-payment RPC. |
| `reverse_cashbox_entry(uuid,text)` | Permission-helper + branch/actor markers; empty fixed search path; authenticated only | Keep client EXECUTE; reversal reason and two-session concurrency checks remain required. |

### Caller-scoped read helper

| Function | Catalog finding | Decision |
|---|---|---|
| `get_my_app_profile()` | Does not use a generic permission-code check, but binds lookup to `auth.uid()`; empty fixed search path; authenticated only | Keep client EXECUTE. This self-profile RPC is deliberately caller-scoped and has an RLS regression workflow. |

## Legacy overloads are already denied

The same live catalog query found these older overloads are **not executable by authenticated** and are therefore not among the 22 advisor findings:

- `create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean)` (without request ID).
- `create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean)` (without request ID).
- `create_medical_certificate(uuid,text,date,date)` (without linked visit ID).

Do not re-grant these legacy overloads. The supported client-callable versions are the request-ID and visit-linked signatures listed above.

## Decision and next work

**No privilege changes are warranted solely from these warnings.** The advisor identifies the presence of SECURITY DEFINER plus authenticated EXECUTE, but does not evaluate the application's custom permission and branch checks. A blanket revoke would break normal clinical, pharmacy and finance workflows.

Before any future function-level grant change, require:
1. Read the exact live `pg_get_functiondef` and grants for that signature.
2. Match the signature against actual frontend RPC call sites and role permissions.
3. Confirm permission, actor identity, branch scope, input validation, idempotency and fixed search path.
4. Add/update a PostgreSQL 17 regression for allowed and denied roles/branches.
5. Apply a narrowly scoped migration and verify live grants immediately after.

Clinical end-to-end browser acceptance remains deferred per user instruction. This triage is a catalog/guard-pattern review, not a claim that every function has passed a complete adversarial security audit.
