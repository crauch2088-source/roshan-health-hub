# Phase 56A — permission-gated medicine identity correction

**Status:** source candidate in PR #189; no schema migration or database write.

## Verified database boundary

Read-only catalog-only queries were run against Production (`jewzonxplxhogqrnhosl`) and isolated QA (`hopfohcnrtbiqjkgeukz`) on 2026-11-04. Both returned the same relevant structure:

- `public.medicines` has no `branch_id`; it is a shared catalogue record, so identity edits affect every branch.
- RLS is enabled and forced.
- Authenticated UPDATE is guarded by `medicines_update`, whose USING and WITH CHECK both call `app_has_perm('pharmacy.update')`.
- Current role mapping in both projects grants `pharmacy.update` to `admin`, `legacy_admin`, `legacy_super_admin`, `pharmacist` and `super_admin`. This flow is therefore permission-gated, **not strictly pharmacist-only**. Enforcing pharmacist-only access requires a separate permission or server-side role guard plus a forward migration; no such migration is included or applied.
- `trg_audit_medicines` writes row changes through `audit_row_change()`.
- `trg_guard_medicine_stock_aggregate` remains installed and rejects browser-role changes to `stock_quantity`.
- `normalize_medicine_names()` fills `generic_name` only when the supplied value is blank; the edit builder requires a non-empty generic ingredient.

No patient, prescription, invoice, payment, stock, or other business rows were queried.

## Edit contract

The UI exposes editing only when the current app permission set includes `pharmacy.update`. The server-side RLS policy remains authoritative if the client is stale or manipulated.

The pure builder returns exactly these columns:

1. `name` (display name; generated from brand or generic + strength + dosage form when blank)
2. `generic_name`
3. `brand_name` (nullable)
4. `strength`
5. `dosage_form`

It never includes `unit`, cost/selling price, reorder level, stock quantity, expiry, batch number, barcode, active flags or branch identifiers. Packaging unit is intentionally immutable in this dialog because existing batch quantities are already expressed using the stored unit.

Before saving, the authorized user must confirm that the product name, strength and dosage form were compared with the physical pack. The dialog also warns that the record is shared across branches.

**Important audit limitation:** the checkbox is a per-save acknowledgement only. The existing audit trigger records the changed row's old/new values and authenticated actor; it does not persist the checkbox, source, pack image, reviewer attestation or a dedicated verification date. The UI therefore does not label the product “verified”.

## Validation and release boundary

- Pure helper RED/GREEN TDD was exercised locally before repository integration (2 failing tests before implementation; 2 passing after).
- Repository regression tests are included in the existing `test:guard` suite and cover the five-field whitelist, custom/required-form validation, permission and pack-confirmation wiring, the existing UPDATE RLS policy and audit-trigger source.
- Code-bearing exact head: `679266228a48eb16db45988f8446793c9d85b0d6`. CI run `41794972957`: 18 successful jobs, one intentionally skipped authenticated clinical-acceptance job. Supporting workflows: `41794972960`, `41794973017`, `41794973114`, `41794973187` — all successful. The first CI attempt at `b913a46d6138c58495cf272bfb7201f3513dc1d3` exposed formatting-only failures; the tested head includes the correction.
- Vercel preview deployment `dpl_FSjcL1qWMisxzWCQewnyFu1E9Ttc` is READY at `https://roshan-health-74hgojpbm-roshan45.vercel.app`, but a read-only fetch returns `login_required`. No SSO bypass or visual/browser acceptance is claimed.
- No DDL, DML, permission changes, seed data, Auth-user creation, deployment promotion or production data access occurred.
- Authenticated browser acceptance and staff UAT remain deferred. Do not modify `auth.users` directly or create a new credential endpoint.
- Keep PR #189 Draft until the role-scope decision, authorized non-staff browser/mobile/RTL review and independent review are complete.

## Main reconciliation and exact-head validation — 2026-11-06

- Synchronized with main `0b1785b69dd0d2cbc523757db79a886780495d25` by normal two-parent merge commit `29ee3c60b82ec304daae1f0886b8c28448335a6f`; first parent is prior feature head `ec886194fc164bfcab673dfb8f56f35cf7e580c8`. No published history was rewritten.
- PR #189 is now 12 commits ahead / 0 behind main and GitHub reports mergeable=true. It remains Draft.
- Exact-head CI [42177775976](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177775976): 18 successful jobs, zero failures, one intentional skip for canonical PG17 baseline/authenticated clinical acceptance. Install, audits, role guard, typecheck, lint and build passed. Supporting runs [42177775946](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177775946), [42177775953](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177775953), [42177776009](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177776009), [42177775930](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177775930) and CodeQL [42177771248](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42177771248) all passed.
- Vercel preview status is successful, but no interactive browser/RTL/mobile acceptance was performed because preview SSO remains enabled and no authorized non-bypass browser session is available. No SSO or build-quota bypass was used.
- Read-only schema metadata checks on QA and Production confirmed the catalogue columns match; no business rows were queried or modified.
- No migration, database write, Auth/Storage change, patient/financial record, or Production deployment occurred. The authenticated clinical acceptance job remains intentionally deferred.

Next: resolve the role-scope question (the existing `pharmacy.update` map includes admin and super-admin roles as well as pharmacist), obtain independent review, and complete authorized non-staff mobile/RTL/LTR preview checks. Keep this PR Draft until those gates are evidenced.

## Branch reconciliation and exact-head checks — 2026-11-07

- PR [#189](https://github.com/crauch2088-source/roshan-health-hub/pull/189) was merged with current main by normal two-parent commit e944812c6c85662ac5806852e83dd0b499423326. The previous feature head is the first parent and main ac521c7c8cd15ce83d389e53a320d6edfc6a4f18 is the second. Compare result: 14 ahead / 0 behind; PR is mergeable and remains Draft.
- Exact-head CI [42350006998](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350006998): 18 successful, zero failed, one intentional clinical-acceptance skip. Supporting exact-head runs passed: [42350006984](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350006984), [42350007131](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350007131), [42350007180](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350007180), [42350006977](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350006977), and CodeQL [42350004776](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350004776), both language analyses successful.
- Vercel status check passed for the exact PR head. Protected-preview visual acceptance, mobile review and RTL/LTR review remain NOT TESTED; SSO was not weakened or bypassed.
- No database migration, QA/Production DDL/DML, catalogue seed, Auth/Storage mutation, patient/clinical/financial record creation or Production promotion occurred.
- Next: independent review and explicit role-scope decision, then authorized mobile/RTL/LTR preview checks. Keep Draft until those gates are evidenced.

## Latest-main reconciliation — 2026-11-07

- Main at reconciliation: 20e3d872f23171354166bd58504b4c6368835733. The feature branch was updated by normal two-parent merge commit 2f725cdc416caafa12910027359a02a0cae9cb49 (first parent 34b81851869f31542ff63b224b77335f2d2e9437, second parent main). No published history was rewritten.
- PR [#189](https://github.com/crauch2088-source/roshan-health-hub/pull/189) is 16 commits ahead / 0 behind and GitHub reports mergeable/clean; it remains Draft.
- Exact-head CI [42350748375](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350748375): 18 success, zero failures, one intentional clinical-acceptance skip. Supporting integration and CodeQL workflows passed: [42350748366](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350748366), [42350748371](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350748371), [42350748403](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350748403), [42350748448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350748448), and [42350745706](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42350745706).
- Vercel status is successful; no protected-preview browser/visual acceptance or physical pack workflow was performed. SSO remains enabled.
- No QA/Production database changes, migration application, Auth-user creation, clinical/financial records, or deployment promotion occurred. Keep the PR Draft pending independent review, role-scope decision and authorized mobile/RTL/LTR acceptance.


## Owner-approved authority and attestation extension — Phase 60 (2026-11-10)

The owner approved the following exact model for the global, cross-branch medicine catalogue:

- Shared identity editing is allowed only to current `admin`, `pharmacist`, and `super_admin` roles. The candidate uses a dedicated `pharmacy.catalogue_identity.update` permission and replaces the direct `medicines_update` RLS policy; the broad `pharmacy.update` permission is not sufficient for direct catalogue identity edits. Super Admin keeps the existing explicit `app_has_perm()` bypass.
- Physical-pack verification is a separate pharmacist-only action (`pharmacy.pack.verify`), with Super Admin bypass. It is not a transient checkbox attached to saving an identity edit.
- The server-side `verify_medicine_physical_pack(uuid)` RPC reads the currently saved identity under a row lock and creates an append-only record containing application-user actor, server timestamp, canonical identity snapshot and SHA-256 fingerprint. Historical attestations are never rewritten when the catalogue identity changes.
- Attestation rows are RLS-forced, authenticated SELECT-only, direct table writes are revoked (including service_role), UPDATE/DELETE/TRUNCATE are blocked, and INSERT is written to `audit_logs` through a dedicated empty-search-path trigger function.
- The attestation is an immutable audit event in this phase; it is **not yet a hard dispensing prerequisite**. A separate clinical/product decision is required before making verification a dispense gate, especially for legacy catalogue rows.

Candidate SQL: `db/roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql`. PostgreSQL 17 assertions: `db/tests/phase60_medicine_catalogue_authority_integration.sql`, wired into a dedicated CI job that replays the disposable v112 baseline. No hosted QA/Production database or live role mapping has been changed. Keep PR #210 Draft until exact-head CI, independent SQL/security review, migration-history reconciliation and authenticated QA pharmacist acceptance pass.


## Audit-coverage reconciliation and exact-head verification — 2026-11-10

Independent review of the disposable v112 baseline found that it did not contain the medicine row-audit trigger, even though read-only catalog inspection confirmed that both live Production and QA currently have trg_audit_medicines calling public.audit_row_change(). Phase 60 now installs that exact trigger idempotently when absent, so a clean baseline replay cannot silently omit audit coverage for catalogue identity edits. The integration test also requires exactly one UPDATE policy on medicines and confirms that it is the dedicated catalogue-identity permission policy; this prevents an additional permissive policy from OR-bypassing the restriction.

The first PostgreSQL 17 run failed on the missing baseline audit trigger, as intended. After adding the idempotent trigger installation, the Phase 60 PostgreSQL 17 job passed on exact code head c781c312755c550acc15a1efccf7529c64394066. Full CI run 42781835755 completed with 19 successful jobs, zero failures and one intentional skip for canonical baseline/authenticated clinical acceptance. The other four reported PR workflows also completed successfully. PR #210 remains Draft; no hosted QA/Production changes, migration application, role changes or deployment promotion occurred.
