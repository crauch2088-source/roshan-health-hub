# Independent Review — Gemini Argon 4 Roshan Master Completion Blueprint

**Review date:** 2026-11-11  
**Evidence snapshot:** current `main` at `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`; PR #232 review branch at `3b372cbdf22ab2de2e560e640ea8494c059d654e`; Supabase Advisor observations at approximately `2026-11-11T08:43Z`.  
**Review type:** read-only source, PR, CI-status, deployment, schema-catalog and official-documentation review.  
**Disposition:** **PARTIALLY ACCEPTED — NOT AN EXECUTION SCRIPT.** Adopt the valid discoveries and safe workstreams below; correct stale claims; reject or defer unsafe and owner-conflicting work.

---

## 1. Executive decision

Gemini Argon 4 has useful structure and several correct high-value directions. It correctly recognizes the Production/QA migration split, the Phase 61 and Phase 58/59 integration blockers, the need for a measured inventory aggregate, the value of Spec Kit, and the separation between engineering completion and real-clinic acceptance.

It is **not safe to execute literally**. The most consequential defects are:

1. It describes an obsolete direct `addStock` inventory write even though current `main` already receives batches through `fn_receive_pharmacy_batch_atomic`.
2. It recommends adding CI concurrency although the main CI workflow already has concurrency cancellation.
3. It gives incorrect PR housekeeping instructions: PR #219 is already merged, PR #225 is already merged, and PR #210 is an active, distinct medicine-catalogue/physical-pack workstream that must not be closed as superseded.
4. Its Bankak index proposal uses columns and a reversal field that do not exist in the live schema.
5. Its clinical CDS implementation contradicts the existing owner-approved simplification recorded in PR #185: a dosing engine, interaction database and structured allergy/current-medication model are deferred from the MVP.
6. It treats a proposed 48-hour sprint and percentages of 64%/15%, 92–95%/62–65% as if they were evidence-weighted forecasts. The denominators, gate weights and operational proof are not sufficiently established.
7. Its backup schedule and Google Drive handoff do not match the current backup-runner workflow: the workflow is manual-dispatch only and the current script stages ciphertext for a GitHub Actions artifact; it does not upload to Drive.

The report should therefore be used as a **candidate-work register**, not as authority to merge PRs, create migrations, promote databases, schedule production backups or activate clinical rules.

## 2. Verified current baseline

### 2.1 Repository, PR and deployment state

| Item | Verified state | Decision |
|---|---|---|
| Current `main` | `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`; includes merged PRs #228, #230 and #231 | Use this as the source baseline |
| PR #232 | Open, Draft, mergeable; head `3b372cbdf22ab2de2e560e640ea8494c059d654e` | Keep as the documentation/review branch; do not merge automatically |
| PR #229 — Phase 61 | Open, Draft, non-mergeable; GitHub reports conflicts in `pharmacy.tsx`, `MASTER_PLAN.md` and the 48-hour execution log | Reconcile with current main; preserve Phase 57/57B guards; run exact-head CI after conflict resolution |
| PR #211 — Phase 58/59 | Open, Draft, non-mergeable | Reconcile and repair the general build/type/lint failures; retain the SDG-only invariant |
| PR #216 — Phase 49 quarantine tests | Open, not Draft, mergeable; its recorded exact-head CI has 18 successful jobs, zero failures and one intentional clinical-acceptance skip | Independent review, then owner-approved merge is reasonable; it is not merged yet |
| PR #219 | Closed and merged on 2026-11-10 | No further merge/rebase action |
| PR #210 — medicine catalogue / pack attestation | Open, Draft, mergeable; exact-head PG17 suite previously passed | **Do not close as superseded.** It carries distinct catalogue authority and physical-pack attestation work; review it separately |
| PR #181 — persisted payment receipts | Open, Draft, mergeable; not merged | Do not describe persisted receipt functionality as merged or production-ready |
| PR #185 — prescribing/CDS specification | Open, Draft, non-mergeable | Retain as a future design reference; respect its explicit MVP deferral |
| PR #179 — saved-prescription printing | Open, Draft, non-mergeable | Keep print/browser/device acceptance separate from CI claims |
| PR #222 / #213 | Open documentation Drafts, non-mergeable | Reconcile their evidence against the current master plan before deciding whether to close; do not bulk-close by PR-number range |
| PR #209, #221, #223, #224, #226 | Closed unmerged/superseded; PR #225 is merged | Do not repeat closure actions already completed |

The report's instruction to close #225 is wrong because it is merged. Its instruction to close #210 is materially wrong because #210 is an active, separate workstream. Its instruction to merge #219 “if still open” is stale because #219 is already merged.

PR #229's previously green PostgreSQL tests do not certify its current final head after base changes and documentation commits. The exact reconciled head must pass again. The same rule applies to PR #211: focused SQL success does not compensate for a failing general build or stale base.

**Production deployment:** the latest READY Production deployment inspected is commit `1eb6b273f01e190f8862d54a23734983512784d9` from PR #228. Later documentation-only main commits were ignored/cancelled by Vercel's configured ignore-build rule. This is not evidence that the hosted database has the migrations represented by the frontend.

### 2.2 Hosted database state

| Item | Production | QA |
|---|---|---|
| Project ref | `jewzonxplxhogqrnhosl` | `hopfohcnrtbiqjkgeukz` |
| Status | ACTIVE_HEALTHY | ACTIVE_HEALTHY |
| PostgreSQL | 17.6 | 17.11 |
| Migration ledger rows | 129 | 22 |
| Latest migration | `20261102232941` | `20261104065852` |
| Phase 57 | Not applied | Applied |
| Phase 57B | Candidate only / not applied | Candidate only / not applied |
| Phase 58/59 | Not applied | Not applied |
| Phase 61 | Not applied | Not applied |

This confirms a real release split: QA has the Phase 57 missing-quantity database guard; Production does not and retains the legacy NULL-to-one dispense fallback. PR #228 has already merged the frontend fail-closed behavior and the separate Phase 57B source candidate, but that does **not** mean Phase 57 or 57B has been promoted to Production.

A read-only catalog query found no table with `receipt` in its name in either hosted project's public/private schemas. Therefore the report's claim that persisted payment receipts from PR #181 are already merged and present in QA is not supported by the current catalog check. PR #181 remains open.

The PostgreSQL minor-version difference (17.6 vs 17.11) is worth recording, but is not by itself a reason to combine a version upgrade with the migration promotion. Do not add a paid upgrade or infrastructure change to the critical path without a compatibility need and owner decision.

### 2.3 Supabase Advisor snapshot

Observed at approximately 2026-11-11 08:43 UTC:

| Project | Security | Performance | Health |
|---|---:|---:|---:|
| Production | 5 groups / 31 findings | 2 groups / 96 findings | 0 |
| QA | 5 groups / 32 findings | 1 group / 142 findings | 0 |

Relevant details:

- Production has two private RLS-enabled idempotency tables with no policies; QA has one. These are private-schema deny-by-default boundaries, not a reason to add permissive policies.
- Both environments report `pg_trgm` in `public` and an anon-callable SECURITY DEFINER `setup_required()`. The latter is an intentionally minimal boolean setup-status contract; verify its exact body and grants, but do not assume the warning proves data exposure.
- 26 authenticated-callable SECURITY DEFINER functions are reported in Production and 28 in QA. These require function-by-function review, not blanket revocation.
- Leaked-password protection is disabled in both environments; this is a legitimate Auth hardening item to plan with staff password-reset impact considered.
- Production reports 94 unused-index notices and two unindexed foreign keys on the legacy private idempotency table; QA reports 142 unused-index notices. Do not bulk-delete unused indexes on a pre-launch/low-traffic system.

Advisor findings are triage signals, not exploitability verdicts.

## 3. Source-level corrections to the report

### 3.1 Inventory and pharmacy

Current `src/routes/_authenticated/inventory.tsx` confirms:

- Lines around 184–193 load non-deleted medicines' `stock_quantity`, `reorder_level` and `cost_price` through `useRows`, then calculate low-stock count and stock value in browser memory. **This is a genuine optimization candidate.**
- The batch list applies `.limit(500)` and the returned rows are filtered client-side. **This is a genuine pagination/server-filtering candidate.**
- The Receive Stock action already calls `supabase.rpc("fn_receive_pharmacy_batch_atomic", ...)`, passes an idempotency key, and invalidates inventory/batch/stat queries. The current file does not contain the report's claimed direct `addStock` update path.
- Existing regression tests explicitly protect the atomic batch-receipt RPC and idempotency key.

Therefore:

1. Do not rewire batch receiving; it is already wired.
2. Do not create `medicine_batches`, a second stock ledger or a competing receipt RPC.
3. Do not calculate authoritative stock value from `medicines.stock_quantity * medicines.cost_price` until the batch/branch source of truth and price basis are settled.
4. Design the aggregate against the existing `pharmacy_inventory.quantity_remaining`, batch purchase-price semantics, medicine catalogue and branch rules. First decide whether the UI wants per-branch on-hand stock, global catalogue counts, expiring stock, or a finance valuation; these are not interchangeable.
5. Add exact tests for more than 500 batches, more than 1,000 medicines, empty catalogues, NULL prices, branch isolation, concurrent receipt/dispense, and aggregate-to-batch reconciliation.

The report's exact “1,000-row PostgREST ceiling” is not established by the current project evidence. The client-side unbounded fetch is real; the exact API cap is configuration-dependent and must not be stated as a verified 1,000-row limit without checking the project setting.

### 3.2 Medicine pack and catalogue model

The live Production and QA `medicines` catalogues do not currently expose `pack_size` or `units_per_pack`. The live `pharmacy_inventory` schema has batch, expiry, `quantity_received`, `quantity_remaining`, purchase price, branch and idempotency fields.

PR #210 adds dedicated catalogue identity authority and physical-pack attestation with append-only evidence. It does not, by itself, prove a complete pack-to-base-unit conversion contract.

Do not implement the report's proposed `units_per_pack` calculation until the team defines:
- base dispensing unit for each formulation;
- pack contents and pack-size evidence from the physical label;
- whether fractional quantities are allowed for liquids;
- purchase-price and selling-price units;
- receiving, dispensing, returns, wastage and stock-count conversion rules;
- who can verify/reject a pack and how the evidence is audited.

Do not add a bare `pack_verified` flag.

### 3.3 Bankak and payment schema

Live Production and QA catalog queries show `public.payments` fields including:

- `payment_method`, `method`;
- `reference_no`, `reference`;
- `branch_id`, `idempotency_key`;
- `deleted_at` / `deleted_by`.

The queried live schema does **not** contain `reference_number`, `reversed_at`, or a table named `invoice_payments`. The existing unique index is on `payments.idempotency_key`; no Bankak-reference unique index was found.

Current billing UI shows the reference field for Bankak/mobile/bank methods but does not mark it required. The payment mutation sends `reference.trim() || null`. The current `post_invoice_payment` RPC writes the supplied reference into both `reference_no` and `reference`, but does not require it for Bankak.

**Adopt the problem statement, reject the proposed SQL verbatim.** Before a migration:

1. Choose one canonical method/reference representation and reconcile legacy duplicate columns.
2. Define whether a Bankak reference is unique globally, per bank account/merchant, or per branch. Branch-only uniqueness may allow the same bank transfer to be credited twice in two branches if they share an account.
3. Define reversal/deletion semantics using the actual `deleted_at` and cashbox reversal model; do not invent `reversed_at`.
4. Run a read-only duplicate/NULL preflight and design a cleanup/reconciliation path for historical rows.
5. Require the reference in UI and RPC only after the owner approves the cashier workflow.
6. Test concurrent duplicate submissions, retries, reversals, cross-branch behavior and legitimate reuse across distinct bank accounts.

A unique reference prevents duplicate posting; it does not verify that the transfer actually arrived at Bank of Khartoum. Do not call manual reference entry “bank verification” unless a trusted reconciliation/API process exists.

### 3.4 Clinical decision support — defer the proposed implementation

PR #185 explicitly records the owner's simplification decision for the MVP:

- first deliverable: verified structured medicine catalogue, pharmacist review against the physical pack, and read-only links to trusted references;
- do not implement a protocol engine, dose calculator, interaction database, structured allergy/current-medication model or new clinical tables as part of the current catalogue work;
- revisit only after the simple workflow has been used and a separate clinical requirement, applicable source, licensing and GP/pharmacist approval exist.

This supersedes WP-06 / Phase 63 as an immediate implementation task. The report's proposed schema also needs further design before it could be considered safe: it omits a clear activation/version/effective-date contract, makes maximum doses mandatory even when a source does not define them, mixes frequency-per-day and minimum interval, and leaves concentration/unit conversion ambiguous. Its allergy cross-reactivity array cannot safely operate on the current free-text patient allergy field.

The report's BNFc link points to a third-party Medaptly calculator, not an official BNF for Children source. The WHO AWaRe 2022 book page itself notes that newer WHO guidelines from 2024/2025 exist for several infections and that the book is being updated. Do not seed the proposed 25–50 rules or use the report's sample numeric doses as production rules.

### 3.5 CI, Vercel and PR housekeeping

- Main `.github/workflows/ci.yml` already has a concurrency group and `cancel-in-progress: true`. Do not add the same feature again.
- The Spec Kit validation workflow already has path filters and concurrency.
- `vercel.json` already has an `ignoreCommand` that excludes documentation-only changes from application builds. Recent documentation commits were ignored/cancelled while the latest Production code deployment remained on PR #228.
- GitHub Actions path filters affect GitHub workflows; they do not by themselves prevent Vercel from receiving a deployment event. Vercel's ignore-build configuration is the relevant control for source-path-based deployment skipping.
- Vercel's official Hobby limits currently document 100 deployments/day and 32 builds/hour. The report's wording that the limit is “100 commits/PR updates” is inaccurate; the limit is on deployments/builds, not commit count.
- The application repository is public; do not apply private-repository Actions minute assumptions to it. The separate backup-runner repository is private, so its usage budget is a different calculation.
- Any further CI optimization should be based on measured duration/queue time and a path-impact map. Do not skip database/security tests when migrations, tests, permissions or workflows change.

### 3.6 Backup and recovery reality

The current `roshan-health-hub-backup-runner` workflow is `workflow_dispatch` only; it has no scheduled cron.

Its current script:
- dumps the PostgreSQL database and custom role definitions;
- restores the dump into an isolated local Supabase/PostgreSQL 17 instance;
- compares selected critical table counts;
- age-encrypts the archive and writes `SHA256SUMS`;
- refuses to proceed if Storage object bytes exist or Vault secrets exist, because those are not included in the archive;
- includes Storage metadata but not Storage object bytes;
- does not include project-level settings, API/JWT keys, Edge Function secrets or provider configuration.

The workflow uploads ciphertext as a GitHub Actions artifact with one-day retention. The current workflow/script has no Google Drive upload step. Any Drive copy is a separate artifact/process and must be verified independently.

The report's backup metadata (304,773 bytes / SHA-256) differs from the Master Plan's recorded Drive artifact metadata (305,317 bytes / MD5). They may refer to different wrapper/archive files; do not treat them as the same artifact without matching exact filenames, sizes and hashes.

The report's “1.5 minutes/day / 45 minutes/month” schedule estimate is not benchmarked. The private runner performs package installation, database dump, local database startup, full restore and comparison; measure a successful full run before forecasting monthly usage. A nightly schedule is a reasonable option to evaluate, but no schedule was added and no Production backup was dispatched during this review.

Supabase Free projects can pause after seven days of low activity; a few real user queries per day are typically enough but are not a guarantee. PITR is a paid add-on and is not included in the Free plan. A keep-alive ping is not a backup, restore test, monitoring system or guaranteed no-pause mechanism.

## 4. Review of external tools and Spec Kit

| Recommendation | Decision | Reason |
|---|---|---|
| Gemini CLI | Adopt as an optional, quota-aware research/engineering assistant | Official Google sign-in quota is documented as 1,000 model requests/day and 60/minute; Gemini API-key free tier is different (250/day, 10/minute, Flash-only). Do not mix the two tiers or assume 1M context applies to every model. |
| GitHub Spec Kit | Keep permanently | Already installed and pinned at v1.2.6; repository validation workflow checks the pinned CLI and project contract. |
| One feature branch / one consolidated PR | Adopt | Keep spec, plan, tasks, code and tests together for a feature. Allow focused documentation-only PRs for independent release/security/backup audits when genuinely needed. |
| Codex / Claude Code entitlements and prices | Do not assume | The report's “included with existing subscription” and price claims need account/product verification; do not build the plan around an unverified paid entitlement. |
| 30–40% token reduction | Reject as an unmeasured claim | No before/after token benchmark is supplied. |
| actionlint / zizmor / Knip / Repomix / FHIR types | Evaluate only for a demonstrated gap | Avoid duplicate scanners, unnecessary dependencies and new maintenance burden. Verify official installation commands; do not copy unverified `npx` invocations. |
| Full FHIR/Medplum adoption | Defer | No current interoperability requirement justifies platform expansion. |
| New autonomous clinical tooling | Defer | Conflicts with the current MVP simplification and clinical sign-off boundary. |

## 5. Completion percentages and two-day sprint claim

The report's 64% Engineering RC and 15% Operational readiness are not accepted as new canonical scores:

- 16/25 and 2/13 are not accompanied by a fully enumerated, weighted gate register.
- PR merges, database promotion, UI features, automated test counts and real-clinic acceptance are mixed into a single arithmetic model.
- Passing PG17 tests does not prove authenticated browser behavior, correct hosted migration state, device printing or staff readiness.
- The report's 92–95% Engineering and 62–65% Operational predictions at H+48 are not derived from verified elapsed effort or demonstrated test capacity.
- The 48-hour schedule includes Production promotion but does not establish all required current-head checks, complete backup coverage, a current-runner restore, authorized synthetic role accounts, physical printer availability or clinical sign-off.

A concentrated two-day engineering sprint can make meaningful progress on PR reconciliation, inventory statistics design/implementation, Bankak integrity design and automated tests. It cannot honestly guarantee a 92–95% release candidate or Production-ready healthcare operation in 48 hours under the current evidence.

**Canonical progress treatment:** retain the last Master Plan baseline of **51% Engineering RC / 11% Operational Acceptance as historical**, not as a newly recalculated status. The previous estimate of 20–34 engineering hours and 1–3 weeks for operational acceptance is also historical; do not present it as a fresh forecast until tasks are re-estimated from current PR heads and actual staff availability.

## 6. Corrected execution sequence

### P0 — Stabilize and integrate existing work

1. Preserve this verified baseline; do not open more micro-PRs.
2. Review/merge PR #216 only after final independent review and owner approval; it is test-only and currently mergeable with recorded green CI.
3. Reconcile PR #229 with current main using normal history-preserving integration; preserve PR #228's fail-closed quantity UX; resolve the three conflicts; run exact-head typecheck, lint, build, test:guard, insurance UI and PG17 tests. Keep Draft until pharmacist/prescriber mobile acceptance.
4. Reconcile PR #211 independently; repair its general build/type/lint checks, verify the immutable SDG-only semantics and migration manifest/timestamp order; do not apply it to hosted DBs yet.
5. Review PR #210 as a distinct catalogue/physical-pack workstream. Do not combine its global catalogue permissions with stock-unit conversion without a specific spec.
6. Reconcile PR #181 receipt UI against the actual missing hosted table and Phase 58/59 dependencies; do not count it as merged.

### P1 — Close the genuine application gaps

7. Implement server-side inventory aggregates and batch pagination only after defining branch scope, batch source-of-truth and stock valuation semantics.
8. Design Bankak reference requirements using the actual `payments` schema, reversal model, account scope and legacy duplicate preflight. Then implement a required reference and database-level duplicate prevention with PG17 concurrency tests.
9. Audit stock movement completeness across receipt, dispense, reversal, returns and write-offs; fix only proven missing ledger paths.

### P1 — Controlled database and release preparation

10. Reconcile every pending migration source against both live ledgers. Do not blindly `db push`; specifically preserve the distinction between Phase 57 (QA-applied), Phase 57B (candidate), Phase 58/59 and Phase 61 (not hosted).
11. Verify a fresh encrypted backup from the current backup-runner head, successful isolated restore, artifact checksum and separate Storage/configuration recovery. If off-site Drive retention is required, implement and test that path explicitly; it is not present in the current workflow.
12. Apply migrations to QA only after source/ledger reconciliation and exact review. Run role-scoped browser acceptance on QA with synthetic identities.
13. Promote to Production only after QA acceptance, backup/restore proof, exact dry-run migration list, ACL/RLS review, rollback plan and explicit owner approval.

### P2 — Real clinic acceptance

14. Complete authenticated multi-role workflows, Arabic RTL / English LTR at 320–430px, actual Android browser use, physical A4 printer tests, cashier Bankak reconciliation and staff training. Keep Issue #95 open until evidence and real staff sign-off exist.

### Explicitly deferred

- Phase 63 autonomous or semi-automated clinical dosing engine and interaction database.
- FHIR export/platform migration.
- New inventory/batch tables or competing receipt/dispense RPCs.
- Bulk SECURITY DEFINER revocation or unused-index deletion.
- Scheduled Production backup until the current backup path, retention, off-site destination, restore and private-runner cost are validated and the owner approves scheduling.

## 7. Owner decisions that remain genuinely necessary

1. **Bankak:** reference-required policy, account/merchant scope for uniqueness, acceptable manual evidence/reconciliation and shift-closure variance handling.
2. **Backup:** approve a recurring schedule, confirm the durable off-site destination and private-key custody, after the current runner's complete restore path is verified.
3. **Clinical catalogue:** designate the GP and pharmacist who will verify medicine identity/formulation/physical packs. This is not approval for automated dosing.
4. **Operational acceptance:** confirm printer model/connection, test staff/role availability and the clinic walkthrough window.
5. **Production release:** explicit approval of the exact migration list and change window after QA and backup/restore gates pass.

Do not ask the owner to decide technical details that can be established from source, schema or tests.

## 8. No-change attestation and verification limits

This review performed read-only repository, PR, deployment, Supabase metadata/catalog and Advisor inspection plus official documentation research. It did **not**:

- edit application code or migrations;
- run DDL/DML against QA or Production;
- alter RLS, grants, Auth, Storage or secrets;
- create, close, merge or retarget a PR;
- trigger a backup, deploy or database promotion;
- create or modify patient, clinical or financial records;
- run physical-device, printer or real-staff acceptance.

This document is a planning/review artifact, not an implementation or clinical approval.

## 9. Evidence links

### Repository / release
- [Current main commit](https://github.com/crauch2088-source/roshan-health-hub/commit/ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb)
- [PR #229 — Phase 61](https://github.com/crauch2088-source/roshan-health-hub/pull/229)
- [PR #211 — Phase 58/59](https://github.com/crauch2088-source/roshan-health-hub/pull/211)
- [PR #216 — Phase 49 quarantine tests](https://github.com/crauch2088-source/roshan-health-hub/pull/216)
- [PR #210 — catalogue and pack attestation](https://github.com/crauch2088-source/roshan-health-hub/pull/210)
- [PR #181 — persisted payment receipts](https://github.com/crauch2088-source/roshan-health-hub/pull/181)
- [PR #185 — prescribing/CDS specification and MVP deferral](https://github.com/crauch2088-source/roshan-health-hub/pull/185)
- [PR #232 — documentation/review branch](https://github.com/crauch2088-source/roshan-health-hub/pull/232)
- [Inventory route](https://github.com/crauch2088-source/roshan-health-hub/blob/main/src/routes/_authenticated/inventory.tsx)
- [CI workflow](https://github.com/crauch2088-source/roshan-health-hub/blob/main/.github/workflows/ci.yml)
- [Vercel configuration](https://github.com/crauch2088-source/roshan-health-hub/blob/main/vercel.json)
- [Backup runner workflow](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/blob/main/.github/workflows/manual-encrypted-production-backup.yml)

### Official external references
- [Gemini CLI quotas and pricing](https://github.com/google-gemini/gemini-cli/blob/main/docs/resources/quota-and-pricing.md)
- [Vercel platform limits](https://vercel.com/docs/limits)
- [Supabase Free project pausing](https://supabase.com/docs/guides/platform/free-project-pausing)
- [Supabase PITR usage and pricing](https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery)
- [WHO AWaRe Antibiotic Book — publication and update note](https://www.who.int/publications/i/item/9789240062382)
- [WHO Pocket Book of Hospital Care for Children](https://www.who.int/publications/i/item/9789241548373)
