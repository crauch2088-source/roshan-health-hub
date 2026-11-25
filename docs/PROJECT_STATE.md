# Roshan Health Hub — Project State Snapshot

**Snapshot:** 2026-11-25 (read-only checks and repository cleanup). Refresh mutable values before any write or release decision.

## Repository

- Repository: `crauch2088-source/roshan-health-hub`.
- `main`: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a` (unchanged by this review/cleanup).
- Open pull requests after cleanup: **19**. Open issues: **4** (#199, #217, #218, #253).
- 28 superseded PRs were closed without merging; no branches were deleted.
- PR #299 is Draft/open at `cc3260e6018212ea9688ea9fc5e95c8dd4e7e0cf`, base `3bc317b0`. Latest exact-head workflow run `45703453595` was in progress at the last check; previous docs-only run `45702924048` passed. Vercel deployment is intentionally skipped for docs-only changes.
- Mainline push CI run `44872060499` and finance write-isolation run `44872060315` completed successfully. Do not infer skipped conditional acceptance jobs passed.
- Branch protection: Issue #253's latest direct evidence (2026-11-15) says protection was disabled. Current branch-protection API read returned 403; current protection state is **NOT VERIFIED**.

## Open PR inventory — 19

| PR | Scope | Base freshness |
|---|---|---|
| #299 | Second review and documentation cleanup | Current main |
| #297 | Backup recovery/DR evidence | Current main |
| #296 | QA operational blockers | Current main |
| #294 / #293 | Inventory ledger / pharmacy cancellation and return | Old base `79d81f08` |
| #292 / #291 | Pediatric safety / ICD-10 validation | Old base `79d81f08` |
| #290 | Liveness/readiness and PHI-safe telemetry | Old base `79d81f08` |
| #288 | Optional Antigravity CLI setup | Old base `79d81f08` |
| #287 | Phase 61 correction workflow indexes | Old base `79d81f08` |
| #280 | Invoice-payment idempotency; successor to #181 | Old base `79d81f08` |
| #269 | Phase 61 correction no-side-effect test hardening | Old base `79d81f08` |
| #263 | Independent medicine catalogue review report | Old base `79d81f08` |
| #260 | Phase 55 private helper ACL tests | Old base `79d81f08` |
| #258 | Saved prescription/document printing; successor to #179 | Old base `79d81f08` |
| #256 / #254 | CI path routing / Repomix context snapshots | Old base `fe8d770f` |
| #250 / #210 | Pharmacist role boundary / medicine identity | Current main |

All old-base implementation PRs must be reconciled with current main before merge. Repository policy requires a normal merge from main into the existing feature branch; do not rebase or force-push published branches. Current main's 15-commit delta from the Production deployment SHA is docs/spec-only, but branch ancestry still needs explicit refresh.

## Exact-head workflow snapshot

| PR | Exact-head workflow runs | Result |
|---|---:|---|
| #250 | 12 | 12 success; no independent review or authenticated pharmacist acceptance |
| #210 | 8 | 8 success; physical pack and identity acceptance open |
| #258 | 9 | 9 success; manifest provenance still stale |
| #280 | 9 | 9 success |
| #294 | 6 | 6 success |
| #293 | 8 | 6 success / 2 failed |
| #292 | 8 | 8 success |
| #291 | 8 | 8 success |
| #290 | 6 | 6 success |
| #287 | 6 | 6 success |
| #260 | 6 | 6 success |
| #254 | 8 | 8 success |
| #256 | 8 | 8 success |
| #269 | 6 | 6 success |
| #296 | 9 | 9 success |
| #297 | 1 | 1 success |
| #263 | 1 | 1 success |
| #288 | 1 | 1 success |
| #299 | 1 | In progress at last check; previous docs-only run passed |

These are workflow-run counts on the named PR heads, not human acceptance. Some workflows contain intentionally skipped jobs; skipped jobs are not passes.

### PR #293 failure diagnosis

- Phase 62 PostgreSQL 17 integration failed with `idempotency_key_payload_mismatch`: the test reuses the same idempotency key with a different reason string during the purported successful replay. The first call uses `Patient declined before pickup`; the replay uses `Retry same key`. A later return replay uses `Unopened box returned` then `Dup`. The function's mismatch rejection is correct; fix the test to replay the identical payload and retain a separate mismatch-negative assertion.
- CI also failed at the Phase 62 PG17 job and lint. The lint log reports 241 Prettier errors and 97 warnings; the Insurance claim UI validation workflow fails in its typecheck/lint/build step due the same lint errors. Format only the touched files and rerun.

## Deployment/source parity

- Canonical Production alias resolves to a READY deployment built from `a9040601702972bdf144fc96b9658eebd5a6d31a`.
- GitHub compare shows current main is 15 commits ahead, zero behind, and every intervening changed path is docs/specification only. No `src/`, `db/`, workflow or package files changed in that interval. The older deployment SHA therefore does not demonstrate application-code drift.
- Do not trigger a deployment for documentation-only changes. Recheck alias and code diff before any release.

## Repository hygiene completed in this branch

- Root README reduced from 63,288 bytes / 432 lines to 3,119 bytes; the full previous README is preserved in docs/archive.
- MASTER_PLAN reduced from 562,393 bytes / 3,167 lines / 362 headings to a 9,397-byte strategic roadmap; the exact original blob is preserved in docs/archive/MASTER_PLAN_HISTORY.md.
- Added documentation index, dated project state, task registry, verification matrix and architecture decision record.
- Archived the root roadmap, old execution ledger, 2026-10-18 deep-research report and 12 Phase 8–18 root reports. Original root paths remain compatibility pointers.
- Preserved the clinical guideline/ICD-10 policy document from the stale #295 branch without importing its conflicting status claims.

## Supabase environments — read-only catalog

| Measure | Production | QA |
|---|---:|---:|
| Project ref | `jewzonxplxhogqrnhosl` | `hopfohcnrtbiqjkgeukz` |
| Public base tables | 56 | 58 |
| RLS enabled | 56/56 | 58/58 |
| FORCE RLS | 44/56 | 46/58 |
| Migration rows | 129 | 30 |
| Latest migration | `20261102232941` | `20261122152027` |
| SECURITY DEFINER functions (public + private) | 94 | 107 |
| SECURITY DEFINER executable by authenticated | 54 | 58 |
| SECURITY DEFINER executable by anon | 3 | 1 |
| SECURITY DEFINER with fixed empty search_path | 94/94 | 107/107 |

Production latest migration: `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal`. QA latest migration: `roshan_qa_secdef_search_path_hardening_20261122`. Ledger counts are not directly comparable; QA is a later curated baseline with environment-specific migrations.

## Security findings requiring action

1. `public.atomic_pharmacy_dispense(uuid, boolean, uuid)` in both Production and QA checks broad permission bits but does not itself enforce the canonical pharmacist role.
2. Production `public.fn_dispense_prescription_with_invoice(uuid, boolean)` checks `pharmacy.update` and `billing.create` but has no role gate. QA's wrapper allows `pharmacist` and `legacy_pharmacist`; decide whether the legacy role remains valid and make environments consistent.
3. Production `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` have NULL ACLs (PostgreSQL default PUBLIC EXECUTE); QA has explicit owner-only ACLs. Track under Issue #218 / PR #260.
4. All catalogued SECURITY DEFINER routines currently have an empty fixed search_path. This does not prove their bodies, grants or callers are safe.
5. Supabase Advisor reports 26 Production and 30 QA authenticated SECURITY DEFINER RPC warnings. Treat as inventory, not confirmed vulnerabilities.
6. `public.setup_required()` is callable by anon and returns a boolean via the private helper. Keep it minimal and test for no additional information disclosure.
7. `pg_trgm` is installed in public in both environments; move only after dependency review.
8. Advisor reports private tables with RLS/no policies and leaked-password protection warnings. Inspect schema exposure and plan availability rather than applying blanket changes.

## QA, backup and release state

- PR #296 remains unmerged and QA-only. QA ledger contains the 2026-11-21 operational-blocker migration and 2026-11-22 search_path hardening migration; Production remains unchanged.
- PR #250 is open Draft at `832a8d38fba10409a44cd9eac7a4e34760aceaac`. Twelve configured workflows on that exact head succeeded. Its submitted reviews are owner-authored COMMENTED notes only; independent SQL/security review and authenticated QA pharmacist acceptance remain absent. Its migration is not applied to QA or Production.
- PR #263 remains open as a detailed independent medicine-catalogue review report linked to PR #210.
- PR #297 records independent encrypted database restore, checksums, off-site copy/read-back and structural parity. Overall DR remains OPEN for accepted cadence/RPO/RTO/retention, timed control-plane recovery, Storage object-byte recovery before first real attachment, Vault/secrets recovery and independent acceptance.
- Proposed RPO 24h / RTO 4h / 30-day retention are proposals, not approved policy.

## Evidence limitations

- This is a dated snapshot, not a guarantee live state has not changed after 2026-11-25.
- No Production or QA writes, migrations, grants, deployments, settings changes or data changes were performed during this review/cleanup.
- No clinical/staff acceptance or physical-printer acceptance was performed.
- Branch protection is not verified due API permission denial.
- SECURITY DEFINER counts are catalog inventory only.