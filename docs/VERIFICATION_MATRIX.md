# Roshan Health Hub — Verification Matrix

Use this matrix to select evidence for changed behavior. It is a routing map, not a claim that every listed check has passed recently. Confirm the current workflow and run results for the exact candidate SHA.

## Verification layers

| Layer | What it proves | What it does not prove |
|---|---|---|
| Unit/source contract | Local rules, mappings, source invariants, UI contract assertions | Live grants, real browser behavior, clinical correctness |
| PostgreSQL 17 integration | Transaction behavior, constraints, RLS, grants, role checks, idempotency, concurrency in the tested schema | Hosted QA/Production parity or staff acceptance |
| Browser/E2E | Tested routes and user actions in the configured browser/environment | Physical printer behavior, staff acceptance, clinical approval |
| Exact-head CI | Configured repository checks on the specified commit | Skipped checks, live environment health, operational readiness |
| Deployment status | Target deployment exists and reports its platform state | Authenticated workflow correctness or clinical readiness |
| Staff/clinical/device acceptance | Real authorized people validate the workflow and target hardware | Security guarantees not covered by technical tests |
| Backup/restore rehearsal | Recoverability of the specifically tested backup scope | Storage/Vault or other excluded assets |

## Domain-to-test routing

| Domain / change | Focused evidence | Integrated / external gate |
|---|---|---|
| General app guard, role and route contracts | `npm run test:guard`; relevant `tests/*` contract file | `npm run typecheck`, `npm run lint`, `npm run build`; exact-head CI |
| PostgreSQL migrations, RLS, grants, RPC security | Relevant `db/tests/*.sql`; migration replay on disposable PostgreSQL 17 | Relevant PostgreSQL/domain workflow; read-only QA/Production catalog verification before/after authorized writes |
| Pharmacy dispense and invoice atomicity | `tests/pharmacy-dispense-invoice.test.ts`, `tests/prescription-atomicity.test.ts`, `tests/privileged-role-guard-sql.test.ts`; Phase 61 source/UI contract tests | `db/tests/phase49_50_critical_path_assertions.sql`, `db/tests/phase61_prescription_correction_integration.sql`, Phase 61 PG17 workflow; independent SQL/security review and authenticated QA pharmacist acceptance |
| Clinical visit, child writes, audit and branch isolation | `tests/clinical-security-hardening.test.ts`, `tests/clinical-rls.test.ts`, `tests/clinical-child-rpc-writes.test.ts` | PG17 migration/role tests; authenticated clinical acceptance remains a separate gate |
| Finance and invoice correctness | `tests/invoice-atomicity.test.ts`, `tests/invoice-validation.test.ts`, `tests/finance-rpc-only-writes.test.ts`, `tests/visit-invoice-consolidation.test.ts` | PostgreSQL concurrency/atomicity workflows; SDG reconciliation and finance staff acceptance |
| Currency provenance and receipts | `npm run test:currency-provenance`; `tests/phase58-sdg-currency-provenance.test.mjs`, `tests/phase59-receipt-currency-provenance.test.mjs` | Verify stored historical currency and rendered receipt against controlled QA fixtures |
| Medication engine | `npm run test:medication-engine`; `tests/medication-dose-calculator.test.ts`, `tests/medication-protocol-matcher.test.ts` | Clinician review of each approved protocol/source/version; tests do not approve a dose or treatment policy |
| Mobile, RTL/LTR, accessibility and route UX | `tests/phase41-ux-safety-and-workflow.test.ts`, `tests/phase42-ux-route-rtl-a11y-guard.test.ts` | Browser verification at 320–430 px in Arabic RTL and English LTR; keyboard/screen-reader checks |
| Printing | `tests/print-document-isolation.test.ts` | Actual A4/thermal printer and mobile print checks on target hardware |
| Browser E2E | `npm run test:e2e`; `npm run test:e2e:public`; `tests/browser-e2e-target-validation.test.mjs` | Authenticated QA workflows with synthetic accounts and explicit cleanup; no Production test transactions |
| Backup and recovery | Current backup-runner workflow, artifact checksum, decryption and isolated restore evidence | Confirm database vs Storage/Vault scope and owner-readable recovery procedure; see Issue #199 |
| Deployment | GitHub Vercel status and current deployment SHA/alias | Authenticated browser smoke and real operational acceptance |

## Repository test commands

- `npm run test:guard` — broad Node guard/contract suite defined in `package.json`.
- `npm run test:medication-engine` — focused medication calculator and protocol matcher tests.
- `npm run test:currency-provenance` — focused SDG/receipt provenance tests.
- `npm run test:e2e` — Playwright suite; use only when the browser target and data safety are established.
- `npm run typecheck`, `npm run lint`, `npm run build` — static/build gates when source changes warrant them.

Do not run the full set mechanically for docs-only or isolated SQL-only changes. Follow current CI routing and run the smallest sufficient set first.

## Required evidence notation

Every report must state commit SHA, environment, command/workflow, result label (`PASS`, `FAIL`, `SKIP`, `BLOCKED`, `NOT_RUN`, `STALE`), and evidence URL or concise output. A skipped clinical-acceptance job remains skipped, even when all code checks pass.

## Human acceptance checklist

- Reception: patient lookup/registration, queue, duplicate prevention, and network recovery.
- Clinician: patient/visit context, observations, diagnosis, medication, partial save, certificate and signature states.
- Laboratory: order lifecycle, sample/result, verification, critical values, retry and printing.
- Pharmacy: product identity, pack verification, role boundaries, FEFO, stock movement, invoice atomicity, idempotency and audit trail.
- Finance: SDG receipts, exact precision, immutable ledger, reversals/refunds and branch attribution.
- Device: phone widths, RTL/LTR, keyboard, A4/thermal printer and mobile print.

Only authorized staff and clinicians can complete these acceptance gates. Automated tests cannot impersonate their approval.