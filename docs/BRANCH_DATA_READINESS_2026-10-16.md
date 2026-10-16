# Branch-data readiness audit — 2026-10-16

## Purpose
This is an aggregate-only readiness snapshot from the live Roshan Production Supabase project. It contains no patient names, contact details, or clinical notes. It explains why branch-scoped prescription and clinical-child changes must not be rolled out yet.

## Live aggregate findings
- Active branches: **2**.
  - `ROSHAN Main Branch` / `ROS-MAIN`: 1 active assigned user, 1 assigned patient, 0 assigned visits.
  - `الفرع الرئيسي` / `MAIN`: 0 active assigned users, 0 assigned patients, 0 assigned visits.
- Active users: **6** total; **5** have `branch_id IS NULL`, and 1 has a branch assignment.
- Non-deleted visits: **36** total; **36** have `branch_id IS NULL`, and 0 have a branch assignment.
- Non-deleted patients: **10** total; **9** have `branch_id IS NULL`, and 1 has a branch assignment.
- Of the 36 branchless visits, 5 have a creator account whose branch is assigned; 31 have a creator account with no branch. All 36 currently have no assigned doctor (`doctor_id IS NULL`). Creator branch is only a candidate clue, not sufficient evidence to assign the visit.
- The new `public.create_prescription_atomic(uuid, boolean, jsonb)` RPC is present in production under migration version `20261016172209`. It is SECURITY DEFINER with empty `search_path`, denies EXECUTE to `anon` and PUBLIC, and allows `authenticated`. Its branch guard intentionally rejects a NULL user branch or NULL visit branch for non-super-admin users. The function is additive; PR #22's UI is still unmerged/unreleased, so current UI behavior is unchanged.

## Release decision
**Do not merge/deploy PR #22 or apply PR #34 yet.** The atomic prescription RPC and proposed child-row RLS policies are branch-aware, but the live data is not. Assigning every branchless record to a branch based only on current labels, creator IDs, or the fact the app is prelaunch would be an unsafe inference.

## Safe reconciliation sequence
1. Confirm which branch is canonical for Roshan operations and whether the other active branch is a legitimate second branch or an unused placeholder.
2. Confirm whether the branchless users, patients, and visits are disposable test fixtures or records that must be preserved.
3. Produce a read-only candidate mapping by relationship (patient/visit, creator, appointment, invoice, audit history) without exposing PHI in the report.
4. Review a dry-run change set with before/after counts and explicit exclusions. Do not infer branch from creator alone.
5. If assignment is approved, apply one tracked migration with narrowly scoped updates, preserve audit history, and verify that all linked visit/patient relationships agree. Keep a rollback table or exact pre-update snapshot.
6. Run authenticated cross-branch tests for ordinary staff and super-admin, then merge/deploy PR #22 and only afterward consider PR #34's RLS changes.

## Other open release constraints
- Vercel production deployment API again returned HTTP 402, `api-deployments-free-per-day`, `retryAfter=86400` at approximately 2026-10-16 17:31 UTC. Do not retry via alternate accounts or bypass the quota. The available cloud shell has no Vercel CLI.
- Earliest reasonable deployment retry: **2026-10-17 17:31 UTC / 19:31 Sudan local time**.
- Insurance PR #13 is merged in source but remains unapplied in production pending migration-history parity, full staging validation, and the unresolved invoice-line/reference and manual-coverage-override business rules.
