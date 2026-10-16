# Progress batch D — Roshan Health Hub

**Date:** 2026-10-16 (UTC)  
**Canonical branch:** `main`  
**Main SHA:** `3166f0bef5b734dad541516fb37fa003accfed2f`  
**Master-plan checklist:** 65/156 = **41.7%**

## Production deployment
- The Vercel daily deployment API quota reset sufficiently to allow deployment.
- Production deployment [2Usy7342GX3XFarGVrqs64sGFFWk](https://vercel.com/roshan45/roshan-health-hub/2Usy7342GX3XFarGVrqs64sGFFWk) reached **READY** and aliases to [https://roshan-health-hub.vercel.app](https://roshan-health-hub.vercel.app).
- Deployed SHA: `3166f0bef5b734dad541516fb37fa003accfed2f`, including the merged expenses RPC, finance audit deduplication, and patient-registration RPC changes.

## CI verification
GitHub Actions run [#38932545934](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38932545934) passed all four jobs:
1. Finance audit trigger deduplication.
2. Atomic patient registration and MRN concurrency.
3. Cashbox reversal two-session concurrency.
4. Install, dependency audit, typecheck, lint, and build.

## HTTP smoke checks
The canonical production domain returned HTTP 200 for `/`, `/auth`, `/setup`, `/dashboard`, `/patients`, `/insurance`, `/pharmacy`, and `/queue`. These are unauthenticated route-shell checks only, not authenticated workflow tests. The non-existent `/login` route returned 404; the actual route is `/auth`.

## Database verification
- Read-only review inspected 16 SECURITY DEFINER RPCs, confirming empty function-level `search_path`, no EXECUTE grants for `anon` or `PUBLIC`, and EXECUTE for `authenticated`.
- No SQL migration or privilege change was applied during this batch.
- Phase 21B privilege revocation remains gated on authenticated smoke testing of the deployed registration UI/RPC.
- Historical migration-history parity remains unresolved; recovered historical SQL remains quarantined and has not been replayed.

## Remaining blockers and risks
- Authenticated login, role-gate, patient registration, expense creation, and branch-isolation smoke tests still need an authenticated browser/session workflow.
- Supabase advisors still report `pg_trgm` in `public`, 16 authenticated-callable SECURITY DEFINER functions (reviewed as intentional RPCs, but still requiring adversarial tests), and disabled leaked-password protection.
- Three older draft PRs (#22, #34, #38) could not be refreshed through the GitHub branch-update API because it reported merge conflicts. They remain unmerged; resolve and rerun CI before considering them for merge.

## Next actions
1. Complete authenticated smoke testing and only then apply Phase 21B.
2. Resolve stale PR conflicts and continue the prescription atomicity, clinical child-row branch isolation, and privileged-role-guard workstreams.
3. Continue migration-history parity and review the remaining security advisor findings.
