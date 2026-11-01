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
