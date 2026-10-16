# Progress batch F — Roshan Health Hub

**Date:** 2026-10-16 (late UTC)  
**Main code merge:** `5229ef8b8d0bec35c495a171ab367774ec8e4986`  
**Latest documentation main:** `c5487a4e16fbdde4808421e24538504b54ef3f9c`  
**Checklist:** 65/156 = **41.7%**  
**Production deployment:** blocked by Vercel API quota; no bypass attempted.

## Source merge and CI
- Merged [PR #13](https://github.com/crauch2088-source/roshan-health-hub/pull/13) as [`5229ef8`](https://github.com/crauch2088-source/roshan-health-hub/commit/5229ef8b8d0bec35c495a171ab367774ec8e4986). Added server-side insurance amount and coverage-validity candidate SQL and explicit EXECUTE revokes/grants for the claim RPC.
- Fixed a real CI failure: the fresh PostgreSQL fixture exposed that new functions receive EXECUTE for PUBLIC unless explicitly revoked. Dedicated PostgreSQL 17 integration passed on [head `8be7e13`](https://github.com/crauch2088-source/roshan-health-hub/commit/8be7e134862fb4cdad3172b1f888bbc237295bf0). Main app/security/concurrency checks passed on the immediately preceding code-equivalent head; mainline CI on the merge commit passed all four jobs.
- PR #13 SQL is **not applied to production**. Migration parity, staging validation, invoice-line/reference semantics, and the manual coverage-override policy remain open.

## Production SQL applied
- Applied the additive atomic prescription RPC as Supabase migration `roshan_phase7_atomic_prescription_20261016`, version `20261016172209`.
- Verified exactly one function exists, SECURITY DEFINER, empty `search_path`, EXECUTE denied to `anon`/PUBLIC and allowed to `authenticated`. A rollback-only unauthenticated call was denied.
- The RPC remains unused by production UI because PR #22 is still draft/unmerged. It is additive and has a documented rollback: `DROP FUNCTION IF EXISTS public.create_prescription_atomic(uuid, boolean, jsonb);`.

## Clinical branch readiness
- Refreshed PR #22 and PR #34 onto current main. After the final documentation-only main refresh, all checks passed again on [PR #22 head `7e009d9`](https://github.com/crauch2088-source/roshan-health-hub/commit/7e009d98e0fb7463bc95ace1fed3a6c2b5a2c7e8) and [PR #34 head `8e7756d`](https://github.com/crauch2088-source/roshan-health-hub/commit/8e7756db333d788fa706e942454745f967b05d98). Both remain draft due the live branch-data release gate.
- Live aggregate-only snapshot: 2 active branches; 5/6 active users branchless; 36/36 visits branchless; 9/10 patients branchless. The branch named `ROSHAN Main Branch` has one assigned active user and one patient but no visits; the Arabic `الفرع الرئيسي` branch has no assigned users, patients, or visits. 31 branchless visits have no creator recorded; the other 5 have assigned creators, but none matches the creator's branch to the linked patient's or invoice's branch. Creator linkage is not a safe assignment source.
- No records were changed. PR #22 and #34 remain draft because the branchless data must be reconciled before a branch-aware UI/RLS rollout. Full details and the safe reconciliation sequence are in [`docs/BRANCH_DATA_READINESS_2026-10-16.md`](BRANCH_DATA_READINESS_2026-10-16.md).

## Deployment quota
- Retried Vercel production deployment after the earlier expected reset; Vercel again returned HTTP 402 `api-deployments-free-per-day`, `retryAfter=86400`, at approximately 2026-10-16 17:31 UTC.
- Earliest reasonable retry: **2026-10-17 17:31 UTC / 19:31 Sudan local time**. The available cloud shell has no Vercel CLI. No alternate account or quota bypass was used.

## Remaining security/performance review
- Supabase security advisor: `pg_trgm` in `public`; 17 authenticated-callable SECURITY DEFINER RPC notices needing function-by-function review. These are not automatically vulnerabilities: intended RPCs must be reviewed for permission checks, branch checks, safe search_path, and correct grants before changing ACLs.
- Performance advisor reports 124 unused-index advisories. No indexes/extensions were removed because usage history and dependency review are needed.
