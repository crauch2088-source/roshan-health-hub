# Authenticated Production Route QA — 2026-10-18

## Scope and release identity

- Canonical production URL: https://roshan-health-hub.vercel.app/
- Vercel project: `roshan-health-hub`
- Production deployment: `dpl_BLKVmzkoD5hs2E3ZsTCGrRLkDXMM`, state `READY`, deployed from `main` commit `451fd13cfd4ffa47dc62841dae07c00619594019`.
- Supabase project: `jewzonxplxhogqrnhosl`, PostgreSQL 17.6, status `ACTIVE_HEALTHY`.
- This was authenticated, read-only UI inspection. No patient, visit, lab, certificate, inventory, pharmacy, or financial records were created or changed.

## Browser evidence

- Initial dashboard/lab/certificate smoke test: https://agent.tinyfish.ai/runs/d4126f3f-7fcb-423f-9e59-80a9be71ad0b
- Clinical navigation sweep (patients, visits, queue, clinic, appointments, follow-ups, lab and lab catalog): https://agent.tinyfish.ai/runs/40bd657f-108a-4a48-b0d3-daa4a877d18d
- Pharmacy, inventory, finance, accounting, expenses, partners, reports, analytics, insurance, users, audit and settings sweep: https://agent.tinyfish.ai/runs/2fd10ab5-dfce-4f50-ac6a-62f49bc4ff10
- Clinical form and validation inspection: https://agent.tinyfish.ai/runs/566be2b2-f048-46b1-85e3-fe433ff9a61b
- Follow-up live DOM check for visit save state and certificate role gating: https://agent.tinyfish.ai/runs/606e63ad-8076-4a1a-b017-37599f4bfeaa

## Results

### Routes that loaded without a visible fatal UI error

- Core: `/dashboard`
- Clinical: `/patients`, `/visits`, `/queue`, `/clinic`, `/appointments`, `/followups`, `/certificates`
- Laboratory: `/lab`, `/lab-catalog`
- Pharmacy/inventory: `/pharmacy`, `/inventory`
- Finance: `/finance`, `/accounting`, `/expenses`
- Administration and reporting: `/partners`, `/reports`, `/analytics`, `/insurance`, `/users`, `/audit`, `/settings`

Some destinations (appointments, follow-ups, partners, reports, analytics, insurance, users, audit and settings) were only shallowly inspected for navigation/load state; this is not a full field-by-field or permission-matrix audit.

### Data and empty states

- Read-only aggregate SQL returned zero active rows in `patients`, `visits`, `queue_tickets`, `lab_orders`, `medical_certificates`, `invoices` and `prescriptions` at inspection time.
- The lab queue and certificates list rendered clean empty states.
- The lab catalog was populated with test definitions/prices. The inventory UI showed nine medicine records.
- No synthetic records were inserted into production, and no official certificate numbers, queue tickets, stock movements, invoices, payments or audit events were generated.

### Clinical forms and role gating

- The New Visit dialog exposes a required patient picker, department/doctor selectors, visit type, consultation fee and notes.
- Static source on `main` (`src/routes/_authenticated/visits.tsx`) sets the Save button disabled while `patient_id` is empty or a save is pending. One browser-agent report nevertheless described the live Save button as enabled with an empty patient field. The two observations conflict; treat this as an unresolved source/runtime observation mismatch, not as a confirmed bug. The production route must be checked with a browser assertion that reads the actual button `disabled` property before changing code.
- The New Certificate button is deliberately conditional on both `certificates.create` permission and `user.role_code === "doctor"`. The authenticated QA session was a General Manager/admin, so absence of that button in this session is consistent with source-level role gating and does not establish a missing feature.
- The certificate form in source requires a patient and linked visit, disables issuance until both are selected, and invokes `create_medical_certificate` with `p_visit_id`. The Phase 31 SQL/guard tests cover linked-visit and role restrictions.
- No lab order/result existed, so lab result entry and completion could not be exercised through the production UI.

## CI and deployment verification

On exact current-main commit `451fd13cfd4ffa47dc62841dae07c00619594019`, all 17 check runs reported success, including:

- Install/audit/typecheck/lint/build
- Clinical security hardening on PostgreSQL 17
- Atomic patient registration and MRN concurrency
- Atomic pharmacy dispense and invoice integration
- Atomic invoice integration and consolidated visit invoice integration
- Finance RPC-only writes and invoice-payment idempotency concurrency
- Cashbox reversal two-session concurrency
- Migration source parity manifest
- Clinic-local visit/queue date regression
- Authenticated self-profile RPC under RLS
- CodeQL JavaScript/TypeScript and Python analysis

Run: https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39162719194

The production alias is assigned to the READY deployment for the exact current-main SHA. This verifies release identity and deployment state, not end-to-end clinical readiness.

## Live Supabase advisor signals (2026-10-18 20:42 UTC)

- Security: 22 authenticated-callable `SECURITY DEFINER` routine warnings, one `pg_trgm`-in-public-schema warning, and one leaked-password-protection-disabled warning.
- Performance: one unindexed foreign key (`medical_certificates.visit_id`) and 88 unused-index suggestions.
- These are triage items, not authorization for blanket RPC revocation or index deletion. The current public security-definer routines require function-by-function review of permission checks, branch scoping, fixed search paths and intentional client use.
- Leaked-password protection is plan-gated on the connected Supabase tier; no paid upgrade was made.

## Closure status

**Read-only authenticated route audit: complete for the scope listed above.** No visible fatal UI errors were detected in inspected routes.

**Full clinical end-to-end acceptance: still open.** The production database had no active patients, visits, lab orders or certificates, and no separate staging database/browser identity for a doctor-role session was available. No real production records were created merely to manufacture test data. Required next step is to provide/use an isolated zero-cost PostgreSQL 17 test environment and a doctor-role test identity, then run the existing SQL regression suite plus browser E2E for patient registration → visit/queue → lab order/result/completion → invoice/pharmacy as applicable → visit-linked medical certificate. Recheck the New Visit button's actual disabled property as part of that run.

No clinical-readiness claim is made by this report.


---

## Follow-up — Phase 32 performance finding resolved (2026-10-19 06:14 UTC)

- Added tracked migration `db/roshan_phase32_medical_certificate_visit_index.sql` and regression assertion `db/tests/medical_certificate_visit_index_assertions.sql`.
- Applied the migration to production using the connected Supabase migration API as `roshan_phase32_medical_certificate_visit_index`; live ledger now has **112** entries, latest version `20261019061315`.
- Live read-back confirms `public.medical_certificates_visit_id_idx` exists on `medical_certificates(visit_id)`, and PostgreSQL reports `indisvalid=true`, `indisready=true`.
- Supabase Performance Advisor no longer reports an unindexed foreign key. It now reports 89 unused-index suggestions; this is not evidence that indexes should be removed, especially with the near-empty clinical tables and the new index not yet exercised by production traffic.
- The disposable PostgreSQL 17 CI job replays Phase 31 plus Phase 32 and passes the catalog assertion. Main CI, typecheck, lint, build, source-parity checks, CodeQL, and finance concurrency checks passed on the code revision before the documentation-only follow-up.
- No clinical/financial records were created or changed; clinical end-to-end acceptance remains explicitly deferred per user instruction.
