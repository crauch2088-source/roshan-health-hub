# Production rollout record — 2026-10-31

## Applied to production

- Repository PR [#147](https://github.com/crauch2088-source/roshan-health-hub/pull/147) merged to `main` as `2077c71dbb9cc3ca473bfddb5a280ed6ea02202c`.
- Production Supabase project `jewzonxplxhogqrnhosl` received the following forward migrations in order:
  - `20261031071119` — `roshan_phase46_uat_schema_compatibility`
  - `20261031071122` — `roshan_phase47_queue_branch_attribution`
- The historical migration `20261020232033` remains recorded as migration 115 / Phase 39 and was **not** modified or replayed.
- Phase 46 added `patients.allergies`, `patients.chronic_conditions`, and `prescriptions.branch_id`, with prescription branch attribution tied to the linked visit.
- Phase 47 added `queue_tickets.branch_id`, repaired the one branchless visit and its queue ticket from the patient's explicitly assigned sole active branch, and ensures new visits/queue tickets inherit and validate branch attribution.
- Production read-back confirms the four columns exist with expected types; both branch foreign keys and indexes exist; all three branch-attribution triggers are present with fixed empty search paths; there are zero branchless active visits/tickets and zero branch mismatches. The production prescription table contained zero rows at migration time.
- The complete application query-column contract for `patients`, `prescriptions`, `visits`, `medicines`, and `queue_tickets` returned no missing columns.
- PostgREST schema reload was requested. Supabase logs queried from `2026-10-31T07:11:20Z` showed no missing-column / SQLSTATE 42703 events.

## Deployment and CI

- Vercel production deployment is `READY`, alias `roshan-health-hub.vercel.app`, deployment `dpl_HJnrrKUFXSsWtdA8QDwrTtmFpAjq`, source commit `2077c71dbb9cc3ca473bfddb5a280ed6ea02202c`, no alias error.
- Main commit checks: 25 completed, zero failures; the canonical PostgreSQL 17 baseline replay/authenticated clinical acceptance check remains intentionally skipped.
- Phase 46 and Phase 47 disposable PostgreSQL 17 regression suites passed before merge.
- Production dependency audit is blocking at moderate severity; full dependency audit blocks high/critical severity. Fourteen moderate `minimatch` advisories remain in development/build tooling; they are not present in the production-only dependency audit and remain tracked as a residual CI/build-tool risk.

## Security and operational gates still open

- Supabase organization is on the Free plan. Automatic daily database backups are not included. A manual logical backup, off-site storage, and a restore rehearsal remain required before official clinic launch.
- Storage buckets are private and currently contain zero objects, with no broad `true` object policies. However Issue [#142](https://github.com/crauch2088-source/roshan-health-hub/issues/142) remains open: upload path checks still need authoritative entity-to-branch binding for lab orders and medical certificates. Do not treat zero current objects as proof that future uploads are safe.
- Issue [#146](https://github.com/crauch2088-source/roshan-health-hub/issues/146) remains open for anonymous setup bootstrap RPC exposure.
- Issue [#95](https://github.com/crauch2088-source/roshan-health-hub/issues/95) remains open. The operator-reported UAT covered the Super Admin, patient creation, visit/queue, inventory review, and audit entries; authenticated receptionist/clinician/lab/pharmacy role acceptance has not been completed. The related CI gate is skipped, not passed.
- GitHub repository rulesets returned an empty list; branch protection could not be independently read with the connected GitHub permission. Required-check enforcement is therefore not confirmed.
- Supabase Security Advisor still reports 23 authenticated-callable SECURITY DEFINER RPCs (intentional application RPCs, fixed empty search_path, no anon execute) and the `pg_trgm` extension in `public`. Review evidence exists, but the extension warning remains.
- QA-only reconciliation restored `security_invoker=true` on four views in isolated QA under migration `20261031071243`; PR [#141](https://github.com/crauch2088-source/roshan-health-hub/pull/141) remains open to preserve that setting in the canonical baseline.
- No signed-in TinyFish browser profile exists for `roshan-health-hub.vercel.app`; authenticated live smoke tests could not be repeated by the assistant. The operator must verify `/clinic`, `/pharmacy`, and `/queue` in the signed-in browser after deployment.

## Release decision

**Schema/deployment repair: complete. Official production launch: not yet green-lit.** The remaining backup/restore, Storage entity-binding, setup RPC, staff-role acceptance, and branch-protection gates must be closed and evidenced before the clinic begins real patient operations.


## Phase 48 Storage rollout — 2026-10-31 (read-back 2026-11-01)

- PR [#148](https://github.com/crauch2088-source/roshan-health-hub/pull/148) merged to `main` at `25f7fd29c5142cbfc1bdf65a2dfc6d99e3b48ee6` on 2026-10-31 10:19:20 UTC.
- Production migration ledger: `20261031103927 roshan_phase48_storage_entity_branch_binding`. Isolated QA ledger: `20261031103912 roshan_phase48_storage_entity_branch_binding`. These entries were confirmed by read-only `list_migrations` on 2026-11-01; no migration was applied during this verification.
- Read-only catalog checks on both projects confirm the Phase 48 helper is STABLE SECURITY DEFINER, fixed to an empty search path, and not directly executable by anon/authenticated/service_role. All four restrictive Storage boundary policies remain RESTRICTIVE.
- Issue [#142](https://github.com/crauch2088-source/roshan-health-hub/issues/142) is closed. No claim is made here about object upload lifecycle testing against live clinical objects.
- Main commit checks: 24 total, 23 success, one intentional clinical-acceptance skip. Successful runs: [CI 41192274350](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41192274350), [Phase 48 PG17 41192274124](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41192274124), [clinical-child RPC 41192274059](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41192274059), [finance RPC 41192274187](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41192274187), and [push/CodeQL 41192273896](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41192273896).
- Vercel production deployment `dpl_H93ik8uXuGa3uyjJCjqyxSrghz9Y` is READY on the exact merge SHA with canonical alias `roshan-health-hub.vercel.app` and no alias error. Vercel runtime-error aggregation returned no runtime errors in the preceding 24 hours.
- Remaining launch gates: manual backup/off-site restore rehearsal on the Free Supabase plan; Issue #146 setup RPC; Issue #140 canonical QA baseline; Issue #95 complete UX/staff acceptance; and GitHub required-check enforcement. Authenticated clinical E2E remains deferred.



## Phase 51 merge and QA rollout — 2026-11-02

### Source / CI
- PR [#150](https://github.com/crauch2088-source/roshan-health-hub/pull/150) was marked ready and squash-merged to main as `0bb8bab7acee6acccb1fadeb0ae7a5270f097c4a`. The source change exposes only the boolean `public.setup_required()`; the private helper remains inaccessible to anon.
- The initial failing head `ce88d504b4c546e4611f78f74346ab1ff415c4e8` had four Prettier errors in `tests/phase51-setup-required-anon.test.ts`. The focused insurance-claim regression assertions themselves passed; that job's shared typecheck/lint/build step failed at the same lint errors. The final corrected source commit was `ef66e4bdc1d2e93e293c4bcc776a331e4e950906`; final exact PR head `3d7666c2ff70ef99e2d5e70bc9fa764bd3514f44` passed [CI run 41400152008](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41400152008): 28 success, one intentional clinical-acceptance skip, zero failures. Phase 51 PostgreSQL 17, v115 7/7 fingerprint, test:guard, typecheck, lint, build, insurance validation, and CodeQL passed.
- The 97 React Fast Refresh lint warnings are pre-existing warnings; the four formatting errors were the blocking findings and were corrected. No insurance UI logic change was required.

### QA application
- Applied `roshan_phase51_public_setup_required_anon` to isolated QA project `hopfohcnrtbiqjkgeukz` using the merged migration source. Supabase assigned migration version **20261102122437**. QA ledger now has 13 entries.
- Read-back confirms owner `postgres`, `STABLE SECURITY DEFINER`, empty fixed `search_path`, anon and authenticated EXECUTE true, anon private-helper EXECUTE false, anon private-schema USAGE false. An actual `SET ROLE anon` read-only call returned the expected boolean `false` in the existing initialized QA database.
- QA Security Advisor now reports one expected `anon_security_definer_function_executable` warning for this intentionally public boolean-only RPC. This is a documented intentional exposure, not a grant to tables or the private helper. Existing unrelated advisor findings remain.

### Production and PR #149 boundary
- Production was not changed: 118 migrations, latest `20261031103927`; the public wrapper remains SECURITY INVOKER and anon EXECUTE remains false.
- The production rollout record states that the Free Supabase plan has no automatic daily backups and requires a manual logical backup, off-site storage, and a restore rehearsal before launch. No supported backup/export credential path is available in the connected Supabase tools in this run; do not claim the backup gate passed. **Production Phase 51 remains blocked** until the backup/restore rehearsal and production change window are evidenced.
- PR [#149](https://github.com/crauch2088-source/roshan-health-hub/pull/149) was retargeted from the obsolete Phase 48 feature branch to `main`. The PR head is `5c28eb14a0c5554d60b1621c9ff2b68acc728982`; comparison showed 20 commits ahead / 5 behind and GitHub reports CONFLICTING. GitHub's update-branch operation explicitly returned merge conflicts. Its previous checks on the old base (run 41185376552) were green, but they are not current-main validation. Keep #149 open until conflicts are resolved and exact-main CI passes.
- PR #149 contains pharmacy dispense and visit billing workflow changes. Do not merge or promote those changes while authenticated clinical/staff UAT remains deferred under Issue #95 and the backup/restore gate remains open.
- Issue #95 remains open. Authenticated clinical E2E is still deferred until the isolated free QA login path and suitable synthetic doctor identity are available.
- Next: resolve PR #149's main-merge conflicts in a reviewed atomic change, rerun exact-head PostgreSQL 17 and full CI, then complete the documented staff UAT and backup/restore rehearsal before merge/promotion.

<!-- LIVE-PHASE49-52-RECONCILIATION-2026-11-03 -->
## Live rollout reconciliation — 2026-11-03

Read-only Supabase recheck reports production ledger count 129/latest `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` and QA count 17/latest `20261102232905 roshan_phase52_reporting_analytics_reconciled`. Phase 49–52 RPCs exist in both projects; six audited function fingerprints match; the pharmacy idempotency table shape is correct; stock-movement access is branch-scoped SELECT-only; and all nine Phase 52 indexes are valid/ready. This supersedes the earlier 118/12 ledger snapshot in this document. See [the live reconciliation report](LIVE_PHASE49_52_RECONCILIATION_2026-11-03.md).

Migration histories remain non-canonical: production has four superseded 134-byte placeholders and later repaired/reconciled rows; QA has different versions/names and a superseded duplicate Phase 50 row. The production cleanup/reversal migration `20261102232941` still needs exact SQL/source review. Matching function fingerprints are not full migration or schema parity.

The production off-site backup and isolated restore rehearsal remain unverified. No production SQL write was performed by this inspection. Do not perform additional production DDL or introduce live patient data until source provenance and backup/restore are evidenced. Authenticated clinical E2E and staff UAT remain deferred.
