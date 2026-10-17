# Live Production Security Audit — 2026-10-17

**Scope:** read-only verification against `main` and connected production services. This is evidence, not a declaration of clinical readiness.

## Confirmed current state

- GitHub `main` currently resolves to `5b549663a4d8f26d372a31f19b63ee5d4cdba812`.
- Supabase project `jewzonxplxhogqrnhosl` is `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.
- Supabase migration ledger contains 93 applied versions; latest is `20261016222009_roshan_phase25_current_app_profile_20261016`.
- The canonical candidate artifact is `db/roshan_security_candidate_bundle_20261017.sql` (five ordered components; apply only as one tracked migration).
- Production still has four policies each on all 11 targeted child tables (`invoice_items`, `certificates`, `medical_certificates`, `patient_discounts`, `procedure_orders`, `procedure_results`, `followups`, `queue_tickets`, `prescriptions`, `prescription_items`, `lab_order_items`). Live policy expressions inspected on these tables omit the expected parent/branch-access predicate. This confirms a policy-hardening gap, not evidence that a cross-branch disclosure has occurred.
- `authenticated` still has direct INSERT/UPDATE/DELETE table privileges on all five finance tables (`cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, `supplier_payments`). The candidate bundle revokes these direct writes and retains validated RPC paths.
- The live `public.create_insurance_claim` definition is older than the candidate: it lacks complete JSON object/number checks, coverage/plan/company validity, finite amount checks, two-decimal precision enforcement, and the full item split invariant. The candidate remains source-only.
- `docs/DB_MIGRATION_RECONCILIATION.md` records 92 normalized source matches among 93 ledger entries and one intentionally redacted environment-specific identity-link migration. A clean historical bootstrap remains unproven because early migrations assume existing objects. Do not rewrite the ledger or replay history on production.
- The live schema contains at least one patient row. Although the owner previously described test data as synthetic, this audit did not inspect or disclose patient data and does not use row deletion or destructive operations.
- Vercel team is on Hobby. Latest inspected production deployment was `READY` for commit `71761a2e94586f1b0b60a637eb054198b647e51f`, not the current `main` SHA. Combined status for current `main` returned a Vercel build-rate-limit failure. Runtime-error aggregation showed a historical missing `VITE_SUPABASE_PUBLISHABLE_KEY` error on Oct 14; the Hobby plan rejected a 24-hour runtime-log query due retention limits. No paid upgrade or deployment-limit bypass was attempted.
- Issues [#16](https://github.com/crauch2088-source/roshan-health-hub/issues/16) and [#25](https://github.com/crauch2088-source/roshan-health-hub/issues/25) remain open. #16 correctly records that the insurance candidate is not deployed. #25 records enabled secret scanning, push protection and CodeQL, with historical exposure and Dependabot-alert controls still unresolved.

## Release decision

**Do not apply the candidate SQL to production yet.** The current source has useful regression tests and previous PR-head CI evidence, but the repository still lacks a proven clean replay/baseline and current-main check evidence is incomplete (Vercel build-rate-limit failure). The exact live compatibility and full permission/operation matrix must be established before applying this 29 KB multi-component security migration. This is a deliberate safety gate, not closure of the known risks.

## Next actions

1. Resolve a zero-cost replay strategy without creating a Supabase branch (the prior quote was nonzero) or altering production migration history.
2. Inspect the full bundle against current helper signatures, policy names, finance RPC signatures, table columns and execution grants; run the exact bundle and behavioral tests on a disposable PostgreSQL 17 instance if available at no additional cost.
3. Re-run main checks and confirm canonical Vercel alias/deployment once free build capacity returns; do not force deployment.
4. Apply the candidate only after those checks pass, using one tracked migration, then read back the 11 policies, finance grants/RPC ACLs, insurance function definition, and migration ledger.
5. Resume issue #16 only after live verification. Keep issue #25 open until each remaining control is verified or a documented free-tier limitation is accepted.

## Verification performed in this audit

- Read `main` ref and repository tree; fetched the master plan, README, security review, branch-isolation handoff, migration reconciliation, applied migration inventory, tooling map, insurance SQL candidate and live issue records.
- Queried live table schemas, RLS policy expressions, finance table grants, selected function definitions/ACLs/search paths, migration history, Vercel deployments and runtime-error aggregation.
- No SQL writes, data mutations, paid resources, branch creation, or deployment actions were performed.
