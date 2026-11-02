# Phase 51 — anonymous bootstrap setup-status RPC

**Status:** source candidate only; PR #150 Draft; exact-head CI passed on code commit ef66e4bdc1d2e93e293c4bcc776a331e4e950906; not applied to QA or production.  
**Issue:** [#146](https://github.com/crauch2088-source/roshan-health-hub/issues/146)

## Verified starting contract

- The canonical baseline defines private.setup_required() as a STABLE SECURITY DEFINER helper with an empty fixed search path. It returns only NOT EXISTS (SELECT 1 FROM public.users).
- The public public.setup_required() wrapper is currently STABLE SECURITY INVOKER, also with an empty search path. Its direct EXECUTE grant to anon is absent, while authenticated can execute it.
- The public root, auth, and setup routes call this zero-argument boolean RPC. PR #139 contains public UI error-containment work but does not change the database ACL or function security mode.

## Phase 51 contract

- Replace only public.setup_required() with a zero-argument boolean, STABLE SECURITY DEFINER SQL wrapper.
- Pin search_path to the empty string and call the existing helper by its fully qualified name: private.setup_required().
- Revoke direct EXECUTE grants from PUBLIC, anon, authenticated, service_role, authenticator, and supabase_auth_admin, then grant direct EXECUTE only to anon and authenticated.
- Do not change private.setup_required(), its owner, its ACL, its body, the users table, or bootstrap-super-admin logic.
- The only public disclosure is one boolean indicating whether the initial setup is required. No user identity, count, email, role, or row is returned.

## Regression coverage

- db/tests/phase51_setup_required_anon_assertions.sql verifies function return type/arity, STABLE + SECURITY DEFINER flags, empty search_path, exact direct EXECUTE ACL, private-schema/helper denial to anon, and anonymous behavior before/after one synthetic public.users row.
- The synthetic row uses the reserved .invalid email domain and is inserted only in the disposable PostgreSQL 17 test transaction, which ends with ROLLBACK.
- tests/phase51-setup-required-anon.test.ts guards the migration and assertion contracts; npm run test:guard includes it.
- The existing Phase 37 baseline/forward-replay CI job runs Phase 51 only after the v115 catalog fingerprint has been checked, so the canonical v115 comparison remains unchanged.

## Migration and release boundary

- Phase 49 and Phase 50 names are already used by the draft pharmacy/billing candidate in PR #149; this independent setup-status candidate is Phase 51.
- The stale migration-version reference 117 must not be reused. The previously documented live ledger read-back had 118 production entries and latest version 20261031103927; recheck the live ledger and PR #149 merge order before assigning an actual Supabase migration timestamp.
- Candidate only. No QA or production migration, privilege mutation, Auth change, or business-data write is authorized by this PR. Any later QA application needs exact-head review and a separate release action; production remains gated by the documented backup/restore and release controls.
- Authenticated clinical E2E remains deferred until an isolated free QA login path and suitable synthetic clinician identity exist.


## Verified live state and exact CI result

Read-only catalog inspection on 2026-11-02 confirmed the same state in production and QA: owner postgres; current public wrapper STABLE SECURITY INVOKER with empty search_path; anon EXECUTE false; authenticated EXECUTE true; private helper EXECUTE and private schema USAGE denied to anon. The authenticator role is a member of anon, authenticated, and service_role in both projects.

Production migration ledger: 118 entries, latest 20261031103927. QA ledger: 12 entries, latest 20261031103912. No live DDL or ACL changes were made.

Corrected code commit ef66e4bdc1d2e93e293c4bcc776a331e4e950906 passed exact-head CI run 41399729647: 28 successful checks, one intentionally skipped clinical-acceptance check, zero failures. The Phase 51 PostgreSQL 17 assertions, v115 7/7 fingerprint, source test guard, typecheck, lint, and build all passed. The first code commit had four Prettier findings; the follow-up was formatting-only.

PR #150 remains Draft pending independent security review. The next action is review of the direct ACL and PostgREST role inheritance, followed by a source-only merge if approved. Any QA application is separate; production remains gated.



## Execution update — 2026-11-02

**Status:** source merged; QA applied; production pending backup/restore release gate.  
**Merged PR:** [#150](https://github.com/crauch2088-source/roshan-health-hub/pull/150), merge SHA `0bb8bab7acee6acccb1fadeb0ae7a5270f097c4a`.

### CI failure diagnosis and correction
- Commit `ce88d504b4c546e4611f78f74346ab1ff415c4e8` failed lint on four Prettier formatting findings in `tests/phase51-setup-required-anon.test.ts`.
- The insurance-claim validation regression job's focused claim tests passed; its shared verification step failed on the same lint findings. No insurance UI behavior defect was demonstrated.
- Formatting correction: `ef66e4bdc1d2e93e293c4bcc776a331e4e950906`. Final PR head: `3d7666c2ff70ef99e2d5e70bc9fa764bd3514f44`.
- Exact-head CI [41400152008](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41400152008): 28 successful checks, one intentionally skipped clinical-acceptance check, zero failures. Phase 51 PG17 assertions, v115 fingerprint, source guard, typecheck, lint, build, insurance validation and CodeQL passed.

### QA migration
- Applied to QA project `hopfohcnrtbiqjkgeukz` as migration `20261102122437 roshan_phase51_public_setup_required_anon`.
- Post-apply read-back: owner postgres; STABLE SECURITY DEFINER; empty search_path; anon/authenticated EXECUTE true; anon private helper EXECUTE false; anon private schema USAGE false.
- A read-only `SET ROLE anon` call successfully executed `public.setup_required()` and returned Boolean false for the initialized QA database.
- QA Security Advisor reports the expected public SECURITY DEFINER warning for this boolean-only endpoint. No table grants, user data, identities, or counts were exposed.

### Production
- Production was not changed. Its migration ledger remains 118 entries, latest `20261031103927`; anon EXECUTE remains false.
- The documented production gate requires a manual logical backup, off-site storage and restore rehearsal because the Free plan has no automatic daily backups. The connected Supabase toolset does not provide a backup/export workflow or database credential for safely completing that rehearsal here. Do not apply Phase 51 to production until that gate is evidenced.

### Clinical acceptance
- Authenticated clinical E2E and staff UAT remain deferred as requested. Issue #95 stays open.
