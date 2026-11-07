# Roshan Health Hub — Continuation Handoff

**Snapshot date:** 2026-11-03  
**Snapshot time:** approximately 23:11 Africa/Khartoum (21:11 UTC)  
**Repository:** [crauch2088-source/roshan-health-hub](https://github.com/crauch2088-source/roshan-health-hub)  
**Production app:** [roshan-health-hub.vercel.app](https://roshan-health-hub.vercel.app/)  
**Purpose:** Preserve the verified engineering state, open release gates, and exact continuation order. This is a handoff record, not a release approval.

---

## 1. Executive status

The repository has progressed beyond the earlier Phase 53 planning snapshot. The Phase 53 research/plan PR (#175) is merged, a production deployment exists for the invoice/certificate print-isolation work, and subsequent branches now cover prescription printing, payment receipts, prescription-input safety, and evidence-based prescribing design.

**Do not describe the project as fully released or clinically accepted.** The following remain material:
- Phase 54/54B/54C/55 are present in QA migration history but have not been promoted to Production.
- The encrypted Production backup and isolated restore rehearsal have **not** actually been completed. The private backup-runner workflow has only had validation-only runs; its backup job was skipped.
- Two Phase 53 document-printing PRs remain draft/open.
- The prescription safety work has an open CI failure in PR #184.
- Staff UAT, authenticated clinical acceptance, and Issue #95 remain open.
- Vercel's free daily deployment limit has blocked additional preview deployments for active branches.

No production database write, production migration, patient/financial row read, or new application code change was performed during the handoff documentation task.

## 2. Repository and deployment snapshot

- Latest observed `main` commit: `d2cb1e068e4bcf78e20968c77f255b160f77d9f2` — “docs(spec): reconcile Phase 53 plan and release gates” (2026-11-03 20:20:53 UTC).
- Phase 53 planning PR [#175](https://github.com/crauch2088-source/roshan-health-hub/pull/175) is **merged**. Merge commit: `c2e2dd8a0af1576fa33c9ba9617a5ec8f9b14fda`.
- The production alias resolves to a Vercel deployment in **READY** state, built from `main` commit `d1195432a3c6db2cf4c2260f60b22d82aaf805d7` (“fix(print): isolate invoice and selected certificate output”). This deployed commit is older than the latest observed `main` documentation commit above; do not imply every later main commit was deployed.
- Vercel preview/deployment comments on PRs #179 and #181 record the free-plan `api-deployments-free-per-day` limit (more than 100 deployments in 24 hours). The relevant previews were ignored/blocked. Do not retry deployments repeatedly or upgrade paid services without a deliberate decision.
- Spec Kit is integrated at **v1.2.6**, agent-neutral integration `none`. The latest PR #185 exact-head checks include successful Spec Kit validation. No OpenCode setup is required or intended.

## 3. Merged Phase 53 planning and print foundation

### PR #175 — merged

[PR #175](https://github.com/crauch2088-source/roshan-health-hub/pull/175) added the research, implementation plan, read-only data model, internal print contract, QA quickstart, and task breakdown for clinical document printing.

Verified source findings:
- The original shared `PrintButton` called global `window.print()`; existing CSS did not establish strict one-document print isolation.
- The certificates list previously called global print without selecting exactly one certificate.
- Invoice print did not prove exclusion of payment entry/history and unrelated page content.
- The settings page manages `center_name`, `center_name_ar`, `phone`, `address`, and `invoice_footer`, while invoice rendering previously read `clinic_*` keys. `useSettings()` does not alias these names.
- Receipt printing must start from a persisted payment and be tied to the source-aware cashbox ledger/reversal state.
- Prescription printing must use saved prescription values only; never infer dose, route, frequency, duration, dosage form, or quantity.
- QR/public verification is excluded from v1 pending a separate opaque-token/privacy contract.
- A4 browser print is the baseline. 58 mm/80 mm thermal support is not claimed until physically tested with the center's printer/browser.

### Production print fix

The READY production deployment was built from `d1195432`, whose commit message records that it:
- isolates invoice output from unrelated page content;
- prints only the selected medical certificate;
- preserves invoice identity/financial footer;
- aligns invoice clinic identity with the existing center-settings contract.

This is a code deployment record, not evidence of staff acceptance or physical printer validation.

## 4. Open pull requests at snapshot time

| PR | State | Verified checks | Scope / remaining condition |
|---|---|---:|---|
| [#179](https://github.com/crauch2088-source/roshan-health-hub/pull/179) | Draft, open | 30 checks: all non-skipped successful; one intentional skip | Saved-prescription print model and bilingual A4 copy. Exact persisted values, incomplete-order blocking, same visit/patient binding, soft-delete checks, and explicit “not digitally signed” label. Needs review, final acceptance, and a preview/device path that is not blocked by Vercel quota. |
| [#181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Draft, open | 30 checks: all non-skipped successful; one intentional skip | Persisted-payment receipt using Phase54C `get_invoice_payment_receipt_status(uuid[])`; only saved payment rows; branch/ledger binding; reversal state. Explicitly blocked from Production until Phase54C is promoted after the encrypted backup/restore gate. Its Vercel preview was blocked by the daily deployment limit. |
| [#183](https://github.com/crauch2088-source/roshan-health-hub/pull/183) | Open, non-draft | 26 checks successful | Removes inferred `oral` route from dosage-form selection; requires prescriber to select route. Regression coverage covers eight dosage forms. Not yet merged. |
| [#184](https://github.com/crauch2088-source/roshan-health-hub/pull/184) | Draft, open | CI failed in role-guard unit test; downstream typecheck/lint/build skipped | Makes custom prescription fields editable, requires dosage form and route, and validates date-only DOB. Failure is a stale/incorrect expected validation ordering in `tests/clinical-workflow-redesign.test.ts`: expected `invalid-quantity`, actual `missing-dosage-form`. Other integration jobs passed. Fix the test contract/order deliberately, rerun exact-head CI, and reconcile with #183/#179 before merge. |
| [#185](https://github.com/crauch2088-source/roshan-health-hub/pull/185) | Open, non-draft | 23 checks successful, including Spec Kit validation | Feature spec and architecture plan for evidence-based prescribing/clinical decision support. This is a specification, not an implemented clinical decision-support engine. |

**Coordination warning:** PRs #179 and #184 both touch prescription-related UI/workflow contracts. PR #183 changes route-selection semantics. Reconcile these branches and avoid merging overlapping changes independently without reviewing the combined result.

## 5. Supabase environments and release gates

Projects:
- QA: `hopfohcnrtbiqjkgeukz`
- Production: `jewzonxplxhogqrnhosl`

Read-only migration-history inspection returned:
- QA latest observed migration: `20261103155227_roshan_phase55_clinical_parent_guard_acl_reconciliation`.
- Production latest observed migration: `20261102232941_roshan_synthetic_patient_cleanup_and_stock_ledger_reversal`.
- QA has Phase54 (`20261103114242`), Phase54B (`20261103114612`), Phase54C (`20261103115649`), and Phase55 (`20261103155227`) recorded.
- Production does **not** have those Phase54/54B/54C/55 migrations applied. Keep them QA-only until the backup/restore gate is satisfied.

### Backup/restore gate — NOT DONE

The private repository `crauch2088-source/roshan-health-hub-backup-runner` has a manual-only backup workflow. Validation-only runs passed, but the actual backup job was skipped. As documented in `docs/MASTER_PLAN.md`:
- no Production backup artifact exists;
- no encrypted artifact has been uploaded/checksummed;
- no isolated restore rehearsal has passed;
- the required Supabase temporary database-access preview/PAT and repository secret have not been configured;
- the age keypair has not been configured as required (only the public recipient belongs in the runner);
- no Production connection was attempted by the runner.

**Hard gate:** do not apply Phase54/54B/54C/55 to Production until a real encrypted backup is produced, uploaded, checksum-verified, and successfully restored in isolation. Do not run a destructive or write-capable backup rehearsal against live data.

### QA/Production schema and ACL follow-ups

The existing Master Plan records:
- a pre-Phase55 read-only schema comparison with matching core table/column, constraint, index, trigger, RLS, policy, grants, and view counts, excluding documented quarantine artifacts;
- QA Phase55 corrected the clinical parent-link guard and private-helper EXECUTE ACLs;
- Production still has default PUBLIC EXECUTE exposure on `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` (authenticated has USAGE on `private`, making these grants effective);
- Production's Phase36 guard still lacks the tracked `lab_order_items.order_id` immutability check.

These are known Production reconciliation items; do not attempt a blanket ACL revocation. Design a narrowly scoped, tested migration and release it only after backup evidence and review.

### Current Supabase advisor snapshot

The read-only advisor calls at approximately 21:11 UTC returned:
- Security advisor: QA 32 findings across 5 rule groups; Production 31 findings across 5 rule groups. Both included warnings and informational findings.
- Performance advisor: QA 145 findings; Production 97 findings, largely unused-index observations.

Not every advisor finding is an exploitable vulnerability or a defect. In particular, many authenticated SECURITY DEFINER RPC findings are expected to be application RPCs whose internal permission checks must be reviewed individually. Do not mass-revoke EXECUTE privileges or drop indexes based only on advisor counts.

Specific review items surfaced:
- QA advisor reports `public.setup_required()` as a SECURITY DEFINER function executable by `anon`; verify whether this is intentionally public and whether its output is strictly non-sensitive.
- `pg_trgm` is installed in `public` (extension placement warning).
- QA reports RLS enabled without policies on `private.pharmacy_dispense_idempotency`; confirm intended private-schema access model.
- Review the corresponding Production advisor details before any remediation; the advisor snapshot is a triage input, not an authorization to alter schema or privileges.

## 6. Prescription safety and clinical decision-support work

### Verified risks and changes in flight
- A dosage form (tablet/capsule/syrup/suspension) does not prove administration route. Route must be selected explicitly by the prescriber.
- “Custom” prescription fields must be genuinely editable; a Select option with an empty value is not a usable free-text field.
- Dosage form and route must be required for a complete prescription; dose, frequency, and duration remain clinician-entered. Do not introduce protocol defaults or arbitrary duration limits.
- Pediatric dosing remains clinician-entered and clinician-verified. Do not introduce a dose calculator or dose defaults without a separately validated clinical protocol and evidence base.
- DOB parsing must treat date-only values strictly; do not normalize impossible dates into plausible ages.
- The pharmacy workflow should preserve and display the saved dosage form, route, and instructions after confirming the existing persisted/read-model contract.

### PR #185 specification boundary
The evidence-based prescribing feature specification exists and has green checks. It is not permission to start writing prescriptions automatically or to add decision-support alerts without product/formulation verification, clinical governance, and validated source data.

## 7. Open acceptance and operational gates

- Issue [#95](https://github.com/crauch2088-source/roshan-health-hub/issues/95) remains open until practical acceptance and testing with center staff.
- Authenticated clinical E2E and staff UAT remain deferred; automated CI does not replace them.
- The canonical PG17 baseline/authenticated clinical acceptance workflow is intentionally skipped in several check suites. Record it as skipped, not passed.
- No physical A4/thermal printer validation has been recorded in this snapshot.
- No public QR/verification destination has been approved.
- No production promotion of QA-only migrations is approved by this handoff.

## 8. Recommended continuation order

1. **Resume from current live state, not this file alone.** Re-fetch `main`, open PRs, exact-head CI, current Vercel deployment, QA/Production migration ledgers, and backup-runner state.
2. **Resolve prescription safety PR overlap.** Fix #184's failing role-guard assertion with a deliberate validation contract, reconcile #183 route semantics, and coordinate the shared component changes with #179. Run exact-head tests before merging any of them.
3. **Review #179 prescription printing** against the actual saved lifecycle and authorization semantics; keep the “not digitally signed” label unless a real signature model is proven.
4. **Complete the real encrypted backup and isolated restore rehearsal** using the private runner. This is the blocker for promoting Phase54/54B/54C/55 and for making #181 Production-releaseable.
5. **Review #181 receipt semantics** against persisted payment, cashbox source linkage, reversal state, cashier attribution, and branch scope. Never print from unsaved payment form state.
6. **Reconcile Production ACL and Phase36 guard differences** with narrow regression-tested changes after backup evidence; do not mass-edit grants.
7. **Control Vercel deployment volume.** Avoid repeated preview retries while the free daily quota is exhausted. Use CI and source-level validation first; deploy once per meaningful integration when quota permits.
8. **Run the center's staff acceptance and authenticated clinical E2E**; keep Issue #95 open until the actual workflow is accepted.
9. **Only then** update release status and promote QA-only migrations under a separately reviewed production release plan.

## 9. Explicit stop point for this session

This handoff is the end of the current work session. No further implementation, merge, production database action, deployment retry, or clinical workflow change is authorized by this document. On resumption, start with the live-state verification in step 1 above.

---

*This document records observed repository/tool state as of the snapshot time. Branches, checks, deployments, migration ledgers, and advisor results can change afterward; re-verify them before acting.*
