# Roshan Health Hub — Independent Engineering Acceleration Decisions

**Assessment date:** 2026-11-15  
**Repository baseline:** `main` at `fe8d770f1bd666d00b1bf1b3385f21e109e50872`  
**Evidence boundary:** GitHub source/PR/workflow metadata, current read-only Supabase diagnostics, the supplied Claude/Gemini strategic reports, and official tool documentation. No hosted database writes or deployments.

## 1. Executive decision

The Claude/Gemini direction is broadly useful, but its action queue is too aggressive and assumes several changes are ready to merge together. Adopt a narrower, evidence-led operating model:

1. **Adopt now:** Repomix plus a sanitized live GitHub state snapshot. The existing PR #254 is the correct base; extend it rather than creating a duplicate.
2. **Keep existing controls:** CI already has concurrency cancellation and documentation-only path exclusions. Phase 58/59 already have dedicated migration-specific workflows. Do not add a second generic concurrency/path-filter layer without measuring duplicate jobs.
3. **Defer write-capable AI agents:** The Gemini GitHub Action is technically viable, but it expands token scope and prompt-injection exposure. A critical 2026 advisory affected older action/CLI versions; the project already has direct GitHub tooling and an agent-neutral Spec Kit policy. Start with read-only context/review automation, not comment-triggered arbitrary code modification.
4. **Adopt selectively:** Splinter for read-only SQL linting in disposable PostgreSQL 17 after its lints are tested against Roshan's Supabase-compatible fixture. It is not a migration generator and needs accurate `pgrst.db_schemas` configuration to cover non-public exposed schemas.
5. **Defer AST automation until rules are proven:** ast-grep is suitable for structural prohibitions (e.g. direct stock writes), but each rule needs positive/negative fixtures and an explicit exception policy. It must not replace behavioral SQL/React tests.
6. **Do not replace PostgreSQL 17 tests with PGlite:** PGlite may accelerate isolated JavaScript-side SQL tests, but authoritative RLS, grants, SECURITY DEFINER, locking and concurrency evidence must remain on PostgreSQL 17.
7. **Limit Atlas to schema comparison on an isolated restored clone:** It must not become an automatic source of production migrations. A successful restore rehearsal reduces risk; it cannot prove future promotion with mathematical certainty.
8. **Storage backup is a separate recovery project:** The private backup runner deliberately aborts when Storage object bytes or Vault secrets exist. PostgreSQL dump/restore success does not prove those assets are recoverable.

## 2. Independent live baseline

- `main` remains `fe8d770f1bd666d00b1bf1b3385f21e109e50872`; the prior strategic report's `f8c8b2d` was its audit baseline, not the current branch tip.
- Open PRs include #255 (new mainline prescription-print replacement), #254 (Repomix snapshot), #250 (Phase 61C), #210 (Phase 60), #181 (receipts), #179 (diverged printing branch), and #157 (major dependency group).
- PR #255 is a newer, safer replacement candidate for #179: it is based on current main and restricts printing to persisted complete prescription data. Its exact head `e627af1` has green recorded CI workflows, but browser role acceptance and physical printer checks remain open. Keep #179 from being merged over current main.
- PR #254 has one isolated workflow file, a clean merge base, and a successful workflow-dispatch run. Its initial artifact contained source only; it did not include the current open PR/CI state. This change closes that gap.
- The main CI workflow already defines `concurrency` with cancellation and ignores Markdown/docs/specification-only changes. Separate Phase 58/59 workflows already target their migration contracts. The report's proposed generic concurrency change is therefore redundant; broad `paths-filter` changes need job-by-job routing analysis first.
- Current read-only Supabase checks show Production at migration `20261102232941` (129 ledger rows) and QA at `20261113232719` (27 rows). These counts are not directly comparable because QA uses a consolidated baseline. QA has Phase 54/54B/54C, 55, 58, 59 and 61B entries; Production does not. Required RPCs for receipt status, reversal and private permission checks exist in QA but not Production. No hosted writes were made.

## 3. Where the external blueprint was right — and where it overreached

| Proposal / claim | Independent decision |
|---|---|
| Repomix context snapshot | **Adopt**, but include live PR and CI metadata and explicitly state what was not fetched |
| Mobile-triggered Gemini/Claude write agent | **Defer** until token permissions, untrusted comment handling, prompt-injection controls, branch-only write scope, approval and audit model are designed |
| Add CI concurrency | **Already implemented** in main CI |
| Ignore docs-only commits | **Already implemented** in main CI |
| Add generic paths-filter to monolithic CI | **Defer**; existing dedicated workflows cover some domains; first measure job duplication and ensure every required test still triggers |
| Splinter | **Pilot read-only** against disposable PG17 and Roshan's exposed schemas; no hosted lints or migrations |
| ast-grep | **Pilot only** after structural rules have fixture tests and approved exceptions |
| PGlite | Optional speed layer, never a replacement for PG17 security/concurrency integration |
| Atlas | Isolated schema diff/rehearsal only, no auto-promotion |
| rclone Storage backup | Separate scoped project; current backup runner explicitly aborts when Storage objects or Vault secrets exist |
| Merge PRs #250/#210/#181 into one database mega-PR | **Reject as written**: distinct risk domains, dependency ordering and independent review gates should remain visible. Consolidate migrations only after each contract has been reviewed and the exact dependency graph is proven. |
| 3.5–4 day operational completion estimate | **Reject as unsupported** until QA role credentials, migration rehearsal, restore, and real clinic UAT are scheduled and evidenced |

## 4. Adopted acceleration architecture

### 4.1 Repository context artifact

PR #254 produces a single downloadable artifact containing:
- Repomix XML for the trusted main source tree;
- a minimal JSON snapshot of open PR metadata;
- recent workflow-run metadata for main;
- exact commit SHA, trigger and generation time.

The snapshot does not fetch PR bodies/comments, workflow logs, secrets, artifacts, or database contents. The GitHub token is read-only for contents, pull requests and Actions. The workflow is limited to main, manual dispatch, weekly schedule and completion of the main CI workflow. Treat titles and branch names in the JSON as untrusted data, never as executable instructions.

### 4.2 Work intake and PR discipline

- One domain per PR: clinical, pharmacy/inventory, financial, platform/security, or developer tooling.
- Do not modify `docs/MASTER_PLAN.md`, `AGENTS.md`, package manifests or global CI from ordinary feature PRs unless the feature truly requires that shared contract.
- One atomic tree commit per completed logical task; exact-head CI once after local/source-level validation.
- Keep Draft while any required role, branch, database, or physical-device acceptance is absent.
- Never merge a PR solely because CI is green; candidate tests do not prove hosted schema parity or production runtime behavior.

### 4.3 Parallel execution lanes

| Lane | Work | Can proceed independently? | Gate |
|---|---|---|---|
| A — Dev productivity | Repomix/live-state artifact, safe CI static checks | Yes | Artifact contains no secrets and exact main SHA |
| B — Database security | Phase 55 ACL correction, Phase 60/61C role/stock boundaries | Partially; require dependency map | Independent SQL review + PG17 adversarial tests |
| C — Clinical | Phase 63 validator integration, pediatric weight hard-stop, prescription print #255 | Print model can proceed separately; dosing policy cannot be invented | Medical Director policy + doctor-role E2E |
| D — Pharmacy/ERP | Inventory summary/receive RPC, medicine catalogue, receipt provenance | Partially; database contracts first | PG17 + pharmacist/cashier workflow |
| E — Release recovery | Production backup decrypt/restore, storage-object scope, migration delta rehearsal | Independent until promotion | Owner-side decryption and restore evidence |
| F — Acceptance | Multi-role browser matrix, Android printing, clinic UAT | Requires stable QA candidate | Staff sign-off; never inferred from CI |

## 5. Prioritized next work

1. Complete PR #254's sanitized live-state artifact and test it on a completed main CI run.
2. Independently review PR #250's nested dispense authorization and PR #210's exact intended Super Admin/Pharmacist role contract; do not merge either without review.
3. Keep PR #255 as the sole current prescription-print candidate; review its print-state guards and exact-head tests. Do not revive PR #179's divergent source branch.
4. Build a production migration delta from the live Production ledger/catalog, not by replaying QA ledger rows. Reconcile Phase 55/57/57B/58/59/61/61B/61C/62 dependencies.
5. Add Splinter as a read-only CI pilot only after the exposed-schema setting and Supabase fixture are validated.
6. Plan Storage object backup and Vault recovery separately from PostgreSQL backup.
7. Provision synthetic QA roles and complete authenticated E2E; then conduct physical Android printer and staff workflow acceptance.

## 6. Safety and completion accounting

- No real patient or financial data is to be copied into model context artifacts.
- No hosted DDL/DML, RLS, ACL, Auth, Storage, migration, or deployment change is included in this acceleration PR.
- Production remains NO-GO until the safety-critical database and clinical gaps are closed and tested.
- Engineering release-candidate completion and operational acceptance are separate measures.
- The repository snapshot is a convenience artifact, not a source of truth. Always verify its commit SHA against current main before using it.
- A backup restore rehearsal is evidence of a tested procedure, not a 100% guarantee of future recovery or migration success.
