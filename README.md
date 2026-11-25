# Roshan Health Hub

Roshan Health Hub is a mobile-first, bilingual clinic operations platform combining patient administration, clinical encounters, laboratory, pharmacy, inventory, billing and operational reporting.

## Product and technical scope

- Patient registration, patient history, visits, queue and clinical documentation.
- Diagnoses, observations, prescriptions and clinician-governed decision support.
- Laboratory orders, results and verification.
- Pharmacy catalogue, batches, FEFO dispensing, stock movements and returns.
- Invoices, payments, cashbox, expenses, suppliers and receipts.
- Role-based access, branch isolation, Arabic RTL and English LTR.
- Installable phone-first web application.

Current implementation stack: React, TypeScript, TanStack, Vite, Tailwind CSS, Supabase PostgreSQL/Auth and Vercel. The repository is intentionally a modular monolith; do not introduce microservices or a replacement EMR without a demonstrated requirement and an approved architecture decision.

## Current release status

**Not approved for live clinical or financial system-of-record use.** A Production deployment exists, but the project still has unresolved pharmacy authorization, Production/QA ACL reconciliation, governance, staff/clinical acceptance and disaster-recovery gates. The authoritative status is in [docs/PROJECT_STATE.md](docs/PROJECT_STATE.md); the release sequence is in [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md).

## Local development

Use the repository's pinned lockfile and scripts. Keep secrets out of source control; start from .env.example and use only authorized development credentials.

```bash
npm ci
npm run dev
npm run typecheck
npm run lint
npm run build
npm run test:guard
```

Focused suites include `npm run test:medication-engine`, `npm run test:currency-provenance`, and `npm run test:e2e` when their required environment is available. Consult package.json for the exact current script definitions.

## Start here

- [Documentation index](docs/README.md)
- [Current project state](docs/PROJECT_STATE.md)
- [Master plan and release gates](docs/MASTER_PLAN.md)
- [Task registry and PR triage](docs/TASK_REGISTRY.md)
- [Verification matrix](docs/VERIFICATION_MATRIX.md)
- [Architecture decisions and external research](docs/ARCHITECTURE_DECISIONS_2026-11-25.md)
- [Clinical guideline governance](docs/CLINICAL_GUIDELINE_POLICY_AND_ICD10_RECOMMENDATION_2026-11-20.md)

## Safety rules

- Use synthetic fixtures only in disposable PostgreSQL and QA. Never create synthetic clinical, patient, pharmacy, laboratory, inventory or financial transactions in Production.
- Clinical protocols, diagnosis logic, medication choices and dosing require clinician-approved specifications. Research and software tests are not clinical approval.
- Preserve least privilege, RLS, branch isolation, immutable ledgers, atomic transactions, idempotency and audit trails.
- Treat migrations as ordered, forward-only changes. Never edit the migration ledger to manufacture parity.
- A passing CI run, merged PR or successful deployment is not clinical acceptance or launch authorization.