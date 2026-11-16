# Parallel Engineering — Window 02
## Independent Security Review: Phase 61C / PR #250

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review date:** 2026-11-16
- **Target:** [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- **Reviewed PR head:** `c43c0258eb80760191b1b523128ddcb2c7537344`
- **Current main at review:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **PR state:** Open, Draft, not merged
- **Review mode:** Read-only; no SQL, grants, migrations, hosted data, PR state, or deployments changed.

> **Template/continuation-doc discrepancy:** The requested `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` were not present in the current `main` tree or at the reviewed PR head. Repository tree inspection and GitHub code search did not locate them. This report therefore uses a conventional structured security-review format; it does not claim compliance with an unavailable template. Restore those two files if exact project formatting or continuation rules are mandatory.

## 1. Executive decision

**Decision: HOLD — do not merge PR #250 yet.**

The Phase 61C SQL design closes the identified direct-RPC role-boundary gap in the candidate code: the public atomic dispense wrappers require the canonical `pharmacist` role plus `pharmacy.update` and `billing.create`, while the unchecked SECURITY DEFINER implementations are moved behind private entry points and denied direct API-role execution.

No confirmed privilege-escalation bypass was identified in the Phase 61C candidate paths reviewed. However, the hosted QA database still has the pre-61C atomic RPC behavior and permits Admin/Super Admin to pass its broad permission checks. Production is further behind and lacks Phase 61B/61C. The candidate is not deployed, and the documented clinical/branch acceptance gate remains outstanding.

This is a code/security review result, not a release authorization.

## 2. Refs and comparison

- PR head: `c43c0258eb80760191b1b523128ddcb2c7537344`
- PR base recorded by GitHub: `f8c8b2d1767643561599764405b4cdbfd4db2c79`
- Current main: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`

The PR's recorded base is behind current main. Comparing current main to the candidate showed that the intervening main commits were documentation-only; no additional functional SQL delta affecting the reviewed dispense boundary was identified. This report evaluates the candidate against current main, not against the historical PR base alone.

## 3. RPC and privilege map

| Entry point | Purpose | Candidate authorization / boundary |
|---|---|---|
| `public.atomic_pharmacy_dispense(uuid,boolean,uuid)` | Idempotent atomic pharmacy dispense | Authenticated caller must be canonical `pharmacist` and hold both `pharmacy.update` and `billing.create` |
| `private.atomic_pharmacy_dispense_unchecked(...)` | Internal atomic dispense implementation | Internal SECURITY DEFINER implementation; direct API-role EXECUTE revoked |
| `public.fn_dispense_prescription_with_invoice(uuid,boolean)` | Legacy invoice-linked dispense entry point | Phase 61B nested role guard retained; candidate keeps legacy role excluded |
| `private.fn_dispense_prescription_with_invoice_unchecked(...)` | Internal invoice-linked implementation | Internal implementation, not an API entry point |
| `private.app_has_role_permission(text[],text)` | Role/permission helper | SECURITY DEFINER helper with fixed empty search_path |

The public wrappers retain the expected RPC signatures. The wrapper checks the canonical role and both required permissions before payload validation or idempotency processing. This prevents a caller from reaching the internal dispense operation merely by possessing broad permissions.

## 4. Role matrix

| Role | Candidate atomic dispense | Rationale |
|---|---|---|
| canonical `pharmacist` | Allow, when both required permissions are present | Intended clinical actor |
| `doctor` | Deny | Not an authorized dispensing role |
| `admin` | Deny | Administrative permissions do not confer pharmacist identity |
| `super_admin` | Deny | No super-admin bypass is intended |
| `legacy_pharmacist` | Deny | Explicitly excluded from the canonical role boundary |
| `anon` | Deny | No public anonymous execution |
| `service_role` | Deny through the public RPC ACL | No service-role EXECUTE grant in the candidate |
| `authenticator` | No direct EXECUTE grant | Supabase role switching must still be considered separately from direct ACL membership |

The role matrix was checked against the hosted role/permission state. Admin and Super Admin possess both `pharmacy.update` and `billing.create`; therefore a permission-only gate is insufficient. The candidate's explicit canonical-role requirement is the material security control.

## 5. SECURITY DEFINER, search_path and grants

The reviewed candidate definitions use SECURITY DEFINER with an empty fixed `search_path` and schema-qualified object references. The public wrappers delegate to private unchecked functions. Direct EXECUTE on the unchecked functions is revoked from API-facing roles; the public entry points are exposed to authenticated callers subject to their internal role/permission checks.

No search-path injection or direct-call route to the unchecked implementation was confirmed in the reviewed candidate SQL.

An ACL review must distinguish a role's direct EXECUTE grant from Supabase's normal `authenticator` → `authenticated` role-switching model. A positive `has_function_privilege` result for a login/connection role alone is not proof that the caller can bypass the authenticated wrapper's role checks.

## 6. Atomicity, idempotency and branch isolation

The Phase 49 dispense implementation retains the following controls:

- Prescription row locking with `FOR UPDATE`.
- Pending-state validation before dispense.
- Branch consistency checks for the prescription, patient and visit.
- Branch-scoped stock batch selection.
- FEFO batch selection and locking.
- Exclusion of expired or undated batches from eligible stock.
- Stock movement and inventory updates within the dispense transaction.
- Invoice creation within the same transaction.
- Rollback on failure, avoiding a committed stock deduction without its corresponding invoice.

The idempotency path records the request key, serializes access to the request record, validates actor/prescription/payload identity, returns the previous result for an identical replay, and rejects reuse with a changed payload.

The candidate's PG17 integration workflow exercises dispense success, replay, changed-choice rejection, invoice/stock invariants, role denials, ACL/search_path checks, and correction-resolution serialization. The report does not infer multi-request dispense concurrency coverage beyond the exact tests recorded by the repository.

## 7. Direct table writes and RLS boundary

Read-only privilege inspection of QA and Production confirmed that authenticated users do not have direct INSERT/UPDATE/DELETE privileges on the critical stock and prescription write tables inspected, including `pharmacy_inventory`, `stock_movements`, `prescriptions` and `prescription_items`. Their writes are expected to pass through controlled routines.

This check is limited to the inspected relations and privileges; it is not a claim that every table in the database is write-protected. RLS, table ACLs, function ownership and SECURITY DEFINER behavior must be considered together.

## 8. Confirmed hosted exposure

### QA

- Phase 61B is present.
- Phase 61C is not applied.
- The live QA `atomic_pharmacy_dispense` still relies on broad `app_has_perm` checks rather than the explicit canonical pharmacist boundary.
- A rollback-only synthetic authenticated-role smoke recorded in the repository's PR evidence showed Doctor denied, while Admin and Super Admin passed the current atomic RPC's broad permission gate and reached the deliberate NULL-argument guard. The transaction was rolled back; no dispense, inventory, invoice, payment, ledger or prescription mutation occurred.
- The separate Phase 61B invoice-linked RPC rejected Doctor/Admin/Super Admin and allowed the pharmacist past its role gate before the deliberate NULL guard.

This is a confirmed live QA authorization-boundary gap in the current pre-61C atomic RPC, not a bypass of the candidate Phase 61C wrapper.

### Production

- Production has not received Phase 61B or Phase 61C.
- The production dispense RPCs remain on the older permission-based boundary.
- Consequently, Admin/Super Admin are not excluded by the intended canonical pharmacist role check on the existing production atomic RPC.

No production mutation or migration was performed during this review.

## 9. Integration tests and remaining gaps

The exact candidate head `c43c0258eb80760191b1b523128ddcb2c7537344` has 11 PR-triggered workflow runs recorded: 10 successful and one intentionally skipped under the repository's current canonical PG17 baseline/authenticated clinical-acceptance policy; zero failed or pending runs were recorded in the PR evidence.

The Phase 61/61B/61C PostgreSQL 17 workflow passed on the exact head. The repository records canonical pharmacist success, Admin/Super Admin/Doctor denial, legacy pharmacist denial, idempotency, invoice/stock invariants, ACL checks, and two-session correction serialization.

Remaining release evidence to obtain:

1. Authenticated QA PostgREST smoke against the *applied Phase 61C migration*, using separate canonical pharmacist, Doctor, Admin and Super Admin identities.
2. Explicit proof that rejected Admin/Super Admin/Doctor requests create no idempotency, stock, invoice, payment or ledger side effects.
3. Two-session concurrency test for two different dispense request IDs racing on the same prescription / final available stock, verifying one valid dispense and no overdraw or duplicate invoice.
4. Branch-isolation negative tests after Phase 61C is applied to QA, including cross-branch prescription and stock references.
5. Production migration-ledger reconciliation and a separately authorized staged release plan; do not infer production readiness from QA or CI.
6. Human pharmacy/clinical acceptance remains a separate operational gate.

The repository's exact-head PG17 evidence corrects an earlier preliminary concern: Doctor denial is included in the candidate's role-boundary integration coverage. The remaining concern is not absence of all negative role tests; it is hosted post-migration acceptance and the specific concurrency/branch race evidence listed above.

## 10. Merge and release recommendation

**Keep PR #250 Draft / HOLD. Do not merge at this point.**

The Phase 61C implementation is directionally sound and the exact-head PostgreSQL 17 workflow is strong. The current hosted QA and Production catalogs still expose the older atomic RPC authorization boundary. The QA Phase 61C migration gate and authenticated pharmacist/branch acceptance have not been completed. The additional concurrency evidence should be completed before treating the atomic dispense path as release-ready.

Recommended sequence:

1. Complete the independent review and resolve any review findings.
2. Preserve the documented QA-only migration gate; apply Phase 61C only after the authorized gate passes.
3. Run authenticated role and branch smoke tests on QA after migration.
4. Complete the dispense concurrency test and verify no side effects on denied requests.
5. Reconcile Production's migration ledger, then plan a separately approved staged release. Do not apply Phase 61C alone where its Phase 61B prerequisite is absent.
6. Obtain human clinical/pharmacy acceptance before operational use.

## 11. Change and execution record

- No source SQL changed.
- No grants, RLS policies, functions or triggers changed.
- No QA or Production migration was applied.
- No hosted DDL/DML or clinical/financial data was written.
- PR #250 was not approved, merged or modified.
- This report is a documentation-only artifact on a separate branch and is intended for a separate documentation PR.

## 12. Evidence links

- [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- [Phase 61 PG17 exact-head workflow](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968360)
- [Exact-head CI](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43766968433)
- [Phase 61C candidate SQL](https://github.com/crauch2088-source/roshan-health-hub/blob/c43c0258eb80760191b1b523128ddcb2c7537344/db/roshan_phase61c_atomic_dispense_role_boundary.sql)
- [Phase 61B SQL on current main](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase61b_clinical_role_boundary.sql)
- [Phase 49 SQL on current main](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase49_atomic_pharmacy_dispense.sql)
- [Phase 50 SQL on current main](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase50_clinical_visit_bill_completion.sql)
