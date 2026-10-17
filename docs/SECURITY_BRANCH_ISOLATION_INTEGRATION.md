# Security branch-isolation integration gate

**Status date:** 2026-10-17  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Main reviewed at start:** `457eb008cfa146e09107c9c14df92055373ffc8a`

This document is the handoff point for integrating the open branch-isolation and finance-RPC security candidates. It deliberately separates green isolated tests from proof that the candidates can be replayed together on the canonical migration history.

## Current evidence

| Change | Current head | Exact-head CI | Scope |
|---|---|---:|---|
| [PR #50](https://github.com/crauch2088-source/roshan-health-hub/pull/50) | `ba5f742a05bb912ec169a056e9c29a0b08967f64` | 18/18 green | `invoice_items` policies derive branch access from the parent invoice |
| [PR #51](https://github.com/crauch2088-source/roshan-health-hub/pull/51) | `b2cd795af0ffa0d4de93ccdfe721bfa94257ee9f` | 20/20 green | certificates, medical certificates, patient discounts, procedure orders/results |
| [PR #52](https://github.com/crauch2088-source/roshan-health-hub/pull/52) | `c8060592284355ed1c934120be7cfe0ae7c650c1` | 20/20 green | follow-ups and queue tickets |
| [PR #53](https://github.com/crauch2088-source/roshan-health-hub/pull/53) | `91c6f33d0873c533040a911de1599065aa995acf` | 20/20 green | prescriptions, prescription items, lab-order items |
| [PR #54](https://github.com/crauch2088-source/roshan-health-hub/pull/54) | `d77bb2fbb3fdc9db71f6251b39763775abb9b8ef` | 21/21 green | direct-write restrictions and finite-value/authorization checks for finance RPCs |

Main at the reviewed SHA had 14/14 checks green. These results are tied to the listed exact heads; they do not establish cross-branch compatibility. All five PRs remain draft/open and none is represented here as merged.

The live Supabase migration history reports 93 applied versions. The latest listed version is `20261016222009` (`roshan_phase25_current_app_profile_20261016`). Source parity remains a separate gate: 92/93 normalized source matches, with one intentionally redacted historical identity-link migration. Do not treat that text-level match count as proof of a clean full-chain replay.

## Why integration needs its own test

The five candidates were developed on different bases, all behind current `main`. Their merge bases differ. In particular, #51 and #52 both define `private.app_has_patient_visit_branch_access(uuid, uuid)` using the same semantic contract but different formatting. The integrated chain should own one canonical definition, then test every consumer against it rather than relying on branch order or repeated `CREATE OR REPLACE FUNCTION` statements.

The candidate SQL files are currently under `db/`, with per-change fixtures and integration SQL under `db/tests/`; they are not permission to apply those files directly to production.

## Integration order and ownership

1. **Baseline first:** reconcile current `main`, the tracked 93-version live history, and the source migration inventory. Confirm the target canonical migration location and ordering before generating a production migration.
2. **Shared authorization contract:** define and test one canonical `private.app_has_patient_visit_branch_access(uuid, uuid)` helper. It must verify both branch access and patient/visit identity consistency; keep its `SECURITY DEFINER`, empty `search_path`, and explicit execute grants/revokes.
3. **Invoice child rows (#50):** scope all four `invoice_items` operations through the parent invoice's branch. Check whether `private.app_has_invoice_branch(uuid)` exists with the expected body and privileges in the current baseline.
4. **Patient/visit child rows (#51):** scope certificates, medical certificates, discounts, procedure orders, and procedure results. Verify that procedure results inherit access from the parent order and that update policies constrain both old and new row values.
5. **Queue/follow-up rows (#52):** reuse the canonical patient/visit helper; preserve the explicit super-admin-only delete rule for queue tickets and also require branch access.
6. **Prescription/lab children (#53):** ensure prescription items inherit access from their prescription and lab-order items inherit access from a valid lab order, its branch, and a patient-consistent visit.
7. **Finance RPC-only writes (#54):** independently validate grants and every live application call site before revoking direct table writes or retiring `add_cashbox_entry`. Confirm super-admin-without-branch compatibility and finite-number rejection. Do not combine this with insurance-coupled changes.

## Required combined validation matrix

Run against a disposable PostgreSQL instance built from the reconciled canonical migration chain, not the live Supabase database.

- Roles: super-admin, branch-A user with permission, branch-A user without permission, branch-B user with permission, inactive/deleted user, and the supported super-admin account without a branch.
- Rows: same-branch parent, other-branch parent, missing parent, soft-deleted parent where applicable, mismatched patient/visit, and parent reassignment attempt.
- Operations: SELECT, INSERT, UPDATE (both old-row USING and new-row WITH CHECK), DELETE, and RPC invocation/grants.
- Table families: invoice items; certificates and medical certificates; patient discounts; procedure orders/results; follow-ups; queue tickets; prescriptions/items; lab-order items.
- Finance: authorized and unauthorized direct table writes, RPC grants, cross-branch invoice payment, idempotency replay/mismatch, zero/negative/NaN/Infinity amounts, invalid direction, and supplier bill subtotal/discount bounds.
- Migration behavior: fresh replay from the documented baseline; repeat application where supported; verify policy names, helper signatures/definitions, grants, and absence of unexpected duplicate or missing policies.
- Application compatibility: confirm all existing UI call sites use the approved RPCs before restricting direct table writes.

## Release gates

Do not merge or apply the security SQL to production until all are true:

- [ ] Canonical source migration order and the 93-version live-history reconciliation are documented and independently checked.
- [ ] A combined integration workflow applies the reconciled chain plus these candidates on a disposable PostgreSQL 17 database.
- [ ] The combined role × branch × operation matrix passes, including mismatched parent identities and UPDATE reassignment cases.
- [ ] Function privileges and policies are asserted from PostgreSQL catalogs after replay.
- [ ] The application RPC call-site audit passes, especially for finance and queue operations.
- [ ] All required checks pass on the final integration head, not merely on the five isolated draft heads.
- [ ] Production deployment and database change are planned as separate, reversible steps with a post-change read-only verification.

**Production safety:** no SQL or policy changes were made to the live database as part of this audit. Until the gates above pass, treat the cross-branch RLS gap as a release blocker before introducing real patient or financial data.

## Newly verified integration-harness gap

The five existing PostgreSQL 17 workflows each create an isolated miniature database fixture. Each fixture declares the same global roles (`anon`, `authenticated`), schemas (`auth`, `private`), and overlapping helper functions; several create shared table names such as `users`, `patients`, and `visits`. The finance fixture also creates a separate set of finance RPCs and a payment trigger. Therefore, the current fixture files cannot simply be concatenated and run in one PostgreSQL session: duplicate role/schema/function/table declarations and fixture-specific policy setup would collide. The existing green checks prove the individual candidates in their own fixtures, not their combined migration order or combined database behavior.

**Required next implementation step:** create one purpose-built combined fixture with each shared role/schema/table/helper defined exactly once, then apply the candidate migration SQL in a declared order and run one combined integration script. Keep the individual workflows intact as fast targeted regression checks. The combined fixture must assert policy catalog state and effective role/branch behavior after all migrations have been applied; it must not be described as full historical replay until the reviewed pre-migration baseline is also present.


## Aggregate candidate regression workflow added — 2026-10-17

A dedicated integration branch, `security/combined-branch-isolation-regression`, now stages all five candidate SQL changes and their existing fixture/integration scripts together and adds `.github/workflows/ci-security-candidate-bundle.yml`. This workflow uses a five-entry GitHub Actions matrix, with a separate PostgreSQL 17 service/container per candidate job. Each fixture therefore gets a fresh cluster, avoiding collisions on cluster-global roles as well as database-local schemas, helper functions, and overlapping table names.

**What this improves:** the five candidate migrations and test suites are now exercised together at one branch head, with one aggregate required result to monitor. **What it does not prove:** it does not apply all five migrations to the same schema, does not test shared-helper interactions, and is not full historical migration replay. The canonical combined-schema fixture and catalog/role behavior assertions remain required before merging or production application. This workflow is intentionally a stepping stone and must not be represented as completion of the integration gate.


### Aggregate matrix result

At integration head `f4282efb10b6aeced74c6b7dbf6ae5916a65895e`, the corrected aggregate workflow completed **5/5 candidate jobs successfully**: invoice-item isolation, parent/patient child isolation, queue/follow-up isolation, prescription/lab child isolation, and finance RPC-only writes. The earlier single-job design failed because PostgreSQL roles are cluster-global even when separate databases are used; the workflow was corrected to use a separate PostgreSQL service container per matrix job. This result validates the isolated candidate suites from one integration branch, not a shared-schema combined migration replay. Other PR checks were still running at the time of this note.


## Combined-schema test implementation — 2026-10-17

Added `db/tests/security_candidate_combined_fixture.sql`, which defines the shared roles, schemas, tables, helper functions, seed rows, permissions, and baseline policies once, and `db/tests/security_candidate_combined_integration.sql`, which runs the five existing regression scripts sequentially against that same schema and then checks the final policy catalog and finance direct-write grants. The workflow now has a separate PostgreSQL 17 `combined-schema` job that applies candidates #50, #51, #52, #53, and #54 in that order before running the shared integration script. This is stronger than the five-job isolated matrix because it exercises the shared helper redefinition and cross-candidate policy state in one database.

The latest workflow revision also removes the branch-push trigger so changes to this branch do not launch duplicate runs alongside the pull-request trigger. **Verified result:** the combined-schema job completed successfully at code head `e3bf1f47c3b5bdc96085ce08c907b26cba941dbb`; it applied all five candidate migrations in order, ran all five existing integration scripts in the same database, and passed the final catalog/privilege assertions. The subsequent `9da4c551a8e9e871b84edfbd3e8a90ae43cc32ea` commit only updated this documentation, not SQL, tests, or workflow code. The earlier isolated matrix completed 5/5 successfully at `f4282efb10b6aeced74c6b7dbf6ae5916a65895e`.


## Application call-site compatibility audit — first pass (2026-10-17)

Reviewed the current `main` source snapshot at `0157ff3d74692fa4786b60d4e0917b4d1488f02f` for direct table and RPC usage. This is a first-pass compatibility inventory, not yet the exhaustive repository-wide AST/search audit required for release.

- **Invoice items:** `src/routes/_authenticated/billing_.$invoiceId.tsx` reads invoice items. Visit invoice creation in `visits.tsx` and `ConsultationPage.tsx` uses `create_visit_consultation_invoice_atomic`; it does not issue a direct client insert into `invoice_items`. The #50 parent-branch policies should preserve the intended invoice view while filtering items through the invoice parent.
- **Queue:** `queue.tsx` reads tickets and updates status; `visits.tsx` cancels queue tickets; `ConsultationPage.tsx` completes queue tickets. These direct updates rely on the candidate RLS policies to constrain both old and new row values. The branch/parent policy must be validated with the actual row shapes.
- **Follow-ups:** `followups.tsx` reads, inserts, and updates follow-ups; dashboard and patient detail pages also read them. These operations are direct table calls and therefore intentionally remain permission-gated plus parent-branch-gated by #52.
- **Medical certificates:** `certificates.tsx` reads and inserts `medical_certificates` with `patient_id`; #51 scopes this table through the patient's branch.
- **Lab order items:** the lab-order detail page reads and updates `lab_order_items`; reports read them joined to `lab_orders`. #53 must continue to allow same-branch updates and reject cross-branch/mismatched-parent access.
- **Prescriptions:** pharmacy, dashboard, and patient detail pages read `prescriptions` with nested `prescription_items`. The reviewed pages did not show direct client writes to prescription items; keep verifying all write paths and RPCs before release.
- **Finance:** finance/accounting pages read payments, expenses, supplier bills, and cashbox transactions. Reviewed writes use `post_cashbox_entry`, `reverse_cashbox_entry`, `post_invoice_payment`, `post_supplier_bill`, and `post_supplier_payment`; no direct insert/update/delete call to the five tables restricted by #54 was found in these reviewed pages. Keep the existing RPCs and verify all other call sites before revoking direct privileges. `post_expense` was not found as a call site in these screens and needs a repository-wide check before changing its grants.

No application source was changed in this audit. Next compatibility work is a full search of all direct writes, RPC names, server actions, and generated client wrappers, including insurance-adjacent paths; then test the real payload shapes against the final combined policies.


## Canonical migration artifact and latest live audit — 2026-10-17

- Added `db/roshan_security_candidate_bundle_20261017.sql` as the single ordered artifact for the five candidate changes. The combined PostgreSQL 17 job now applies this exact file (not a hand-maintained list of separate `-f` calls) before running the aggregate integration suites and catalog assertions.
- The five isolated matrix jobs remain in place, so the workflow checks both component behavior and the bundle's combined behavior.
- Read-only live catalog checks reconfirmed the release risk: all 44 policies across the 11 target child tables still lack parent-branch predicates, and `authenticated` currently has INSERT/UPDATE/DELETE table privileges on all five finance tables targeted by PR #54. These are configuration findings, not proof of a successful exploit.
- The live database already has `private.app_has_invoice_branch(uuid)`, `private.app_has_patient_branch(uuid)`, `private.app_has_attachment_branch_access(uuid,uuid)`, and `private.app_has_branch_access(uuid)`; the bundle adds the missing wrapper helpers and scopes the policies. This reduces schema uncertainty but does not prove the entire historical migration chain replays cleanly.
- Current main is `627baa6568eebf1b69cd7afa73da7fa7e9fc3da9`. Its reported Vercel status is a build-rate-limit failure, not an application test result. The bundle PR is still draft/unmerged; the latest source commit must receive fresh workflow checks before any merge.
- **Production gate remains:** run the exact bundle and role × branch × operation tests against a clean, disposable schema derived from a reviewed baseline, then confirm app compatibility and post-change grants/policies. Do not claim this bundle is production-applied until the migration ledger and catalog are re-read after a deliberate application step.
