---
name: roshan-qa
description: Use to design and execute Roshan regression, integration, browser, accessibility, role-based, mobile, RTL/LTR, and release acceptance verification.
---

# Roshan QA

## Discover the test system
Read package.json, adjacent tests, CI workflows, and current phase gates. Use repository scripts, not assumed defaults.

## Verification layers
1. Unit/contract tests for pure rules and source invariants.
2. Component/route tests for visible states, keyboard behavior, error recovery, and permission-safe UX.
3. Disposable PostgreSQL 17 integration tests for transactions, RLS, grants, branch scope, idempotency, and migrations.
4. Browser tests for route behavior, network failures, console errors, and mobile layout.
5. Exact-head CI as merge evidence; deployment status is a separate signal.

## Critical scenarios
- Reception: patient lookup/registration, queue assignment, duplicate prevention, network recovery.
- Clinician: correct patient/visit context, partial save, observations, diagnosis, medication, certificate and signature states.
- Pharmacy: product identity, role-restricted changes, stock receipt/dispense, batch/expiry and invoice atomicity.
- Laboratory: order lifecycle, typed results, partial save, critical flags, verification and retry.
- Finance: exact precision, immutable ledger, idempotency, reversals and branch attribution.

## Experience and efficient execution
- Prioritize phone widths 320–430px, Arabic RTL and English LTR.
- Check labels, focus, keyboard, screen-reader semantics, contrast, loading/empty/error/success states.
- Validate allowed and denied roles; visual hide/show is insufficient.
- Synthetic/browser tests do not establish staff UAT or clinical acceptance.
- Run smallest relevant test first, then applicable full guard suite once after complete change.
- Reuse exact-head CI only when commit and workflow scope are identical.
