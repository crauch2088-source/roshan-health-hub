# Roshan Health Hub — Verification Matrix

This matrix routes changes to the evidence they need. It is not a claim that all listed checks passed recently. Record the exact candidate SHA and environment.

## Verification layers

| Layer | Proves | Does not prove |
|---|---|---|
| Unit/source contract | Local rules, mappings, UI and workflow contracts | Live grants, real browser behavior or clinical correctness |
| PostgreSQL 17 integration | Transaction behavior, constraints, RLS, grants, role checks, idempotency and tested concurrency | Hosted QA/Production parity or staff acceptance |
| Browser/E2E | Tested routes and actions in the configured browser | Physical printer behavior, clinical approval or operational readiness |
| Exact-head CI | Configured checks on the named commit | Skipped jobs, live environment health or human acceptance |
| Deployment status | Platform deployment and alias state | Authenticated workflow correctness or clinical readiness |
| Staff/clinical/device acceptance | Authorized people validate workflows and target hardware | Security guarantees not covered by technical tests |
| Backup/restore rehearsal | Recoverability of the specifically tested backup scope | Storage/Vault/control-plane assets excluded from the rehearsal |

## Domain-to-evidence routing

| Domain | Focused evidence | Integrated / external gate |
|---|---|---|
| Role, route and authorization guards | `npm run test:guard`; relevant role/route contract tests | Exact-head CI; negative tests for every role and branch |
| SQL migrations, RLS, grants and RPCs | Relevant `db/tests/*.sql`; disposable PostgreSQL 17 replay | Caller inventory, read-only hosted before/after checks, independent review for high-risk SQL |
| Pharmacy dispense and invoice atomicity | `tests/pharmacy-dispense-invoice.test.ts`, `tests/prescription-atomicity.test.ts`, `tests/privileged-role-guard-sql.test.ts` | PostgreSQL 17 role, idempotency, final-stock and different-key concurrency; authenticated QA pharmacist acceptance |
| Clinical encounter and child writes | `tests/clinical-security-hardening.test.ts`, `tests/clinical-rls.test.ts`, `tests/clinical-child-rpc-writes.test.ts` | PG17 role/branch tests; clinician acceptance |
| Finance and invoices | `tests/invoice-atomicity.test.ts`, `tests/invoice-validation.test.ts`, `tests/finance-rpc-only-writes.test.ts`, `tests/visit-invoice-consolidation.test.ts` | Amount precision, retries, reversals, concurrency and finance staff acceptance |
| Currency and receipts | `npm run test:currency-provenance`; Phase 58/59 tests | Stored historical currency and printed receipt reconciled against controlled QA fixtures |
| Medication decision support | `npm run test:medication-engine`; dose calculator and protocol matcher tests | Clinician review of every active source/version/population/route/concentration and maximum dose |
| ICD-10 and terminology | Dataset/source validation and mapping contract tests | Versioned code-set provenance and clinician/coder review; no automatic diagnosis selection |
| Mobile, RTL/LTR and accessibility | Phase 41/42 UX contract tests | Browser checks at 320–430px in Arabic RTL and English LTR; keyboard/screen-reader review |
| Printing | `tests/print-document-isolation.test.ts` | Actual A4/thermal printer and mobile print tests on target hardware |
| Browser E2E | `npm run test:e2e`; `npm run test:e2e:public` | Authenticated QA workflows using synthetic accounts with explicit cleanup |
| Backup and recovery | Backup-runner workflow, checksums, decryption and isolated restore | Database vs Storage/Vault/control-plane scope, owner policy and timed recovery rehearsal |
| Deployment | GitHub/Vercel status and exact deployment SHA/alias | Authenticated browser smoke and real operational acceptance |

## Current package scripts

- `npm run test:guard` — broad Node contract/guard suite.
- `npm run test:medication-engine` — medication calculator and protocol matcher tests.
- `npm run test:currency-provenance` — SDG and receipt provenance tests.
- `npm run test:e2e` — Playwright suite; use only when the target and data safety are established.
- `npm run typecheck`, `npm run lint`, `npm run build` — static/build gates when source changes warrant them.

Do not run every suite mechanically for a docs-only or isolated SQL-only change. Follow CI path routing and run the smallest sufficient checks first.

## Evidence notation

Every report states commit SHA, environment, command/workflow, result (`PASS`, `FAIL`, `SKIP`, `BLOCKED`, `NOT_RUN`, `STALE`) and evidence URL/output. A skipped clinical-acceptance job remains skipped even when code checks pass.

## Human acceptance checklist

- Reception: lookup/registration, queue, duplicate prevention and network recovery.
- Clinician: patient/visit context, observations, diagnosis, medication, partial save and document/signature states.
- Laboratory: order lifecycle, sample/result, verification, critical values, retry and printing.
- Pharmacy: product identity, pack verification, role boundaries, FEFO, stock movement, invoice atomicity, idempotency and audit.
- Finance: SDG receipts, exact precision, immutable ledger, reversals/refunds and branch attribution.
- Device: phone widths, RTL/LTR, keyboard, A4/thermal printer and mobile print.

Only authorized staff and clinicians can complete these acceptance gates. Automated tests cannot impersonate their approval.