# Progress batch E — Roshan Health Hub

**Date:** 2026-10-16 (late UTC)  
**Canonical main after merge:** `cf42e6bf97dafe47b71cdff37578f42eb3a2ac52`  
**Master-plan checklist:** 65/156 = **41.7%**  
**Production deployment:** still on `3166f0bef5b734dad541516fb37fa003accfed2f`

## Merges and CI
- **PR #12 merged** as `e6f664d6b3a99a1925871280dbfa7b1f528090c5`: insurance claim creation now requires an invoice linked to the selected patient, validates required draft fields, and checks amount splits before calling the RPC. Focused regression workflow and all four main CI jobs passed.
- **PR #38 merged** as `cf42e6bf97dafe47b71cdff37578f42eb3a2ac52`: privileged-role guard now distinguishes anonymous JWTs from trusted service/database contexts. Post-merge CI run [#38937191630](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38937191630) passed all four jobs.
- Resolved repeated stale-base conflicts in PRs #22, #34, and #38 by moving their PostgreSQL integration jobs to dedicated workflow files while preserving current main CI and guard tests.
- PR #22 refreshed head: `4008bdccdc807453c87bf6f11186420de4b9fb63`; dedicated PostgreSQL 17 integration passed. Its latest application CI was still running at the last check.
- PR #34 refreshed head: `ec83e94a33e9c299ecf6ea32c1886e51c2da482f`; dedicated PostgreSQL 17 branch-isolation integration passed. Application CI was queued/not yet visible at the last check. Both remain draft pending live-schema/migration-parity review.

## Production migration applied and verified
- Applied `roshan_security_privileged_role_guard_20261016` through the tracked Supabase migration workflow, version `20261016170816`. The ledger now contains **82** entries.
- Confirmed the three guard triggers exist on `public.users`, `public.roles`, and `public.role_permissions`.
- Confirmed all five private SECURITY DEFINER helpers use empty `search_path` and have no EXECUTE for `anon`, `authenticated`, or `PUBLIC`.
- Verified one super-admin role and two assigned users remain unchanged.
- Executed rollback-only production behavior checks, all passing: anonymous JWT cannot assign the super-admin role; authenticated non-super-admin cannot assign it; a real super-admin remains recognized and can update their own row; ordinary users can update their own non-super-admin row. All test mutations were enclosed in explicit transactions and rolled back.

## Vercel deployment remains blocked
- Current production deployment [2Usy7342GX3XFarGVrqs64sGFFWk](https://vercel.com/roshan45/roshan-health-hub/2Usy7342GX3XFarGVrqs64sGFFWk) is READY on SHA `3166f0bef5b734dad541516fb37fa003accfed2f`, before PR #12 and #38.
- Manual production deployment of `e6f664d` failed with HTTP 402, `api-deployments-free-per-day`, retry-after 86400 seconds. The available cloud shell has no Vercel CLI, so no CLI fallback was available. No quota bypass or alternate account was used.
- Earliest reasonable retry: **2026-10-17 about 17:03 UTC / 19:03 Sudan local time**.
- Patient registration Phase 21B remains gated on a deployed and authenticated registration smoke test. PR #22/#34/#13 SQL remains unapplied pending its own schema/migration/business-rule gates.

## Security findings still open
- Supabase advisors still flag `pg_trgm` in `public`, disabled leaked-password protection, and authenticated-callable SECURITY DEFINER RPC surfaces that need function-by-function adversarial review.
- Historical migration-history parity remains unresolved. Recovered historical SQL remains quarantined and has not been replayed.
- Insurance claim invoice-line/reference semantics remain a business-rule gate; PR #12 is client validation only and does not replace server-side enforcement in PR #13.

## Checklist
- **65/156 = 41.7%**. No extra checklist completion was claimed because deployment/authenticated smoke and broader migration-parity gates remain open.
