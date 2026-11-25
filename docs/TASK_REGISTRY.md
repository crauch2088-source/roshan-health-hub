# Roshan Health Hub — Task Registry

GitHub Issues and PRs are the canonical backlog. This document is a routing/index layer only; do not duplicate full task descriptions or mark work complete here. Re-query GitHub before selecting a task.

## Priority rules

| Priority | Meaning |
|---|---|
| P0 | Stop-ship: credible patient-safety, privilege, data-loss or production-integrity risk |
| P1 | Release prerequisite: migration provenance, core transaction integrity, backup/restore, role/branch acceptance |
| P2 | Important workflow completeness and reliability |
| P3 | UX polish, optional tooling and post-launch experiments |

Assign priority from verified behavior and evidence, not title or age. A green workflow does not close a clinical, security or operational gate.

## P0 — stop-ship

| Canonical item | Purpose | Next required evidence |
|---|---|---|
| [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250) | Canonical pharmacist role boundary for atomic dispense | Independent SQL/security review; same-prescription/different-key and final-stock races; negative no-side-effect tests; authenticated QA pharmacist acceptance |
| [Issue #218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) / [PR #260](https://github.com/crauch2088-source/roshan-health-hub/pull/260) | Production/QA private helper ACL divergence | Caller inventory, owner-only ACL regression, forward migration dependency and read-back plan |
| [Issue #253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) | Protect main and require verified CI | Recheck current protection with authorized API access; select actual required checks; require independent review for high-risk changes |

## P1 — release prerequisites and core workflows

| Item | Domain | Dependency / disposition |
|---|---|---|
| [PR #293](https://github.com/crauch2088-source/roshan-health-hub/pull/293) + [PR #294](https://github.com/crauch2088-source/roshan-health-hub/pull/294) | Pharmacy cancellation/returns and inventory ledger | Review together with #250 and #210; preserve transaction ordering and test multi-session races |
| [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) | Medicine identity, physical pack and catalogue attestation | Reconcile catalog identity with pharmacy/inventory migrations before merge |
| [PR #280](https://github.com/crauch2088-source/roshan-health-hub/pull/280) + [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Invoice-payment retry idempotency and saved receipts | Reconcile overlapping billing/receipt code; one canonical successor, preserve payment identity and reversal semantics |
| [PR #292](https://github.com/crauch2088-source/roshan-health-hub/pull/292) | Pediatric dose/concentration/route governance | Confirm current UI wiring, unknown DOB behavior, persisted mg-to-mL calculation and clinician approval |
| [PR #291](https://github.com/crauch2088-source/roshan-health-hub/pull/291) | ICD-10 validation | Versioned source, local coding rules and clinician-approved mapping; no fuzzy auto-diagnosis |
| [PR #296](https://github.com/crauch2088-source/roshan-health-hub/pull/296) | QA operational blockers | QA-only changes; reconcile applied QA migrations and verify mainline source before any Production action |
| [PR #297](https://github.com/crauch2088-source/roshan-health-hub/pull/297) + [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) | Backup, restore and DR | Database restore evidence exists; control-plane, Storage/Vault, RPO/RTO policy and timed rehearsal remain open |
| [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) + [PR #179](https://github.com/crauch2088-source/roshan-health-hub/pull/179) | Saved-prescription/document printing | Compare overlap; keep only one canonical implementation branch after preserving unique changes |

## P2 — reliability and engineering efficiency

- [PR #290](https://github.com/crauch2088-source/roshan-health-hub/pull/290): PHI-safe liveness/readiness telemetry; verify output allowlist and no PHI leakage.
- [PR #254](https://github.com/crauch2088-source/roshan-health-hub/pull/254): Repomix/context snapshots. Later comments report the fork/workflow_run trust-boundary fix; secret scanning and artifact data-minimization remain separate gates. This is developer tooling, not a release prerequisite.
- [PR #256](https://github.com/crauch2088-source/roshan-health-hub/pull/256): CI path routing. Retain protected database/security jobs; do not narrow checks by guesswork.
- [PR #287](https://github.com/crauch2088-source/roshan-health-hub/pull/287): Phase 61 correction-workflow indexes; confirm query plan benefit and migration dependencies.
- [PR #269](https://github.com/crauch2088-source/roshan-health-hub/pull/269): pharmacist-to-prescriber correction workflow test hardening; independent security review and authenticated staff UAT remain distinct gates.

## Documentation and PR hygiene

- [PR #299](https://github.com/crauch2088-source/roshan-health-hub/pull/299): canonical full-project review and repository documentation cleanup; keep as the single current documentation PR.
- [PR #295](https://github.com/crauch2088-source/roshan-health-hub/pull/295): stale autonomous plan based on `79d81f08`; contains valuable clinical policy material, but its status claims conflict with live GitHub. Preserve the clinical policy separately; do not merge wholesale.
- [PR #289](https://github.com/crauch2088-source/roshan-health-hub/pull/289), [PR #257](https://github.com/crauch2088-source/roshan-health-hub/pull/257), and [PR #259](https://github.com/crauch2088-source/roshan-health-hub/pull/259): dated report/snapshot PRs. Preserve unique evidence in canonical docs, then close if superseded.
- [PR #288](https://github.com/crauch2088-source/roshan-health-hub/pull/288): Antigravity CLI integration is not required by the agent-neutral Spec Kit policy; close as out of scope unless the owner explicitly reopens that tooling decision.
- Parallel review PRs #262–#286 contain repeated rounds. Keep the latest evidence for each window; close older rounds only after checking that unique findings are retained. Latest report candidates include #282, #283, #284, #285 and #286.

## Open issues

- [#199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) — backup/restore and clinical/staff acceptance.
- [#217](https://github.com/crauch2088-source/roshan-health-hub/issues/217) — pharmacist-to-prescriber correction workflow.
- [#218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) — private helper ACL reconciliation.
- [#253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) — main branch protection and required checks.

## Deduplication rules

1. One observable outcome has one canonical GitHub Issue; link implementation PRs to it.
2. One active implementation branch per overlapping file/migration set. Do not let two agents edit the same migration or shared path.
3. Keep the latest report round only when earlier rounds add no unique evidence. Preserve unique findings before closing a report PR.
4. Never close an implementation PR just because it is old; compare complete diffs and dependencies first.
5. Do not merge a report PR that records stale SHAs, superseded claims or an outdated task plan.
6. Do not delete branches or history during cleanup. Close superseded PRs only after the evidence is preserved and the successor is identified.
7. Refresh this index from GitHub before every new execution campaign.