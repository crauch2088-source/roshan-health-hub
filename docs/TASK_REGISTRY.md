# Roshan Health Hub — Task Registry

GitHub Issues and PRs are the canonical backlog. This is a routing/index layer, not a duplicate task system. Re-query GitHub before selecting work.

## Priority rules

| Priority | Meaning |
|---|---|
| P0 | Stop-ship: credible patient-safety, privilege, data-loss or production-integrity risk |
| P1 | Release prerequisite: migration provenance, core transaction integrity, backup/restore, role/branch acceptance |
| P2 | Important workflow completeness and reliability |
| P3 | UX polish, optional tooling and post-launch experiments |

## P0 — stop-ship

| Canonical item | Purpose | Required evidence |
|---|---|---|
| [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250) | Canonical pharmacist role boundary for atomic dispense | Independent SQL/security review; same-prescription/different-key and final-stock races; negative no-side-effect tests; authenticated QA pharmacist acceptance |
| [Issue #218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) / [PR #260](https://github.com/crauch2088-source/roshan-health-hub/pull/260) | Production/QA private helper ACL divergence | Caller inventory, owner-only ACL regression, migration dependency and read-back plan |
| [Issue #253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) | Protect main and require verified CI | Recheck current protection with authorized API access; choose actual required check names; require independent review for high-risk changes |

## P1 — release prerequisites and core workflows

| Item | Domain | Dependency / disposition |
|---|---|---|
| [PR #293](https://github.com/crauch2088-source/roshan-health-hub/pull/293) + [PR #294](https://github.com/crauch2088-source/roshan-health-hub/pull/294) | Pharmacy cancellation/returns and inventory ledger | Review together with #250 and #210; preserve transaction ordering and test multi-session races |
| [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) + [review PR #263](https://github.com/crauch2088-source/roshan-health-hub/pull/263) | Medicine identity, physical pack and catalogue attestation | Review found no DB-enforced duplicate identity policy; identity edits after stock/batch history need safeguards; pack/base-unit/conversion model is incomplete; saved attestation is not proof of physical pack inspection; historical prescription/receipt rendering after identity edits is unproven. PR discussion reported 9/9 incomplete Production catalogue rows on 2026-11-16; recheck before any controlled remediation. No bulk inference or guessed identity values. |
| [PR #280](https://github.com/crauch2088-source/roshan-health-hub/pull/280) | Invoice-payment retry idempotency and saved receipts | Successor to closed #181; reconcile UI/RPC idempotency, immutable payment identity, exact SDG precision, role and reversal semantics |
| [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | Saved prescription and document printing | Successor to closed #179. Review report #284 found the Phase 63 soft-delete guard omitted persisted patient-facing instructions and the migration manifest still referenced superseded PR #255; recheck the current head before merge. Physical A4/thermal/mobile printing remains a human gate. |
| [PR #292](https://github.com/crauch2088-source/roshan-health-hub/pull/292) | Pediatric dose/concentration/route governance | Confirm current UI wiring, unknown DOB behavior, persisted mg-to-mL calculation and clinician approval |
| [PR #291](https://github.com/crauch2088-source/roshan-health-hub/pull/291) | ICD-10 validation | Versioned source, local coding rules and clinician-approved mapping; no fuzzy auto-diagnosis |
| [PR #296](https://github.com/crauch2088-source/roshan-health-hub/pull/296) | QA operational blockers | QA-only changes; reconcile applied QA migrations and verify mainline source before any Production action |
| [PR #297](https://github.com/crauch2088-source/roshan-health-hub/pull/297) + [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) | Backup, restore and DR | Database restore evidence exists; control-plane, Storage/Vault, RPO/RTO policy and timed rehearsal remain open |

## P2 — reliability and engineering efficiency

- [PR #269](https://github.com/crauch2088-source/roshan-health-hub/pull/269): pharmacist-to-prescriber correction workflow test hardening; independent security review and authenticated staff UAT remain distinct gates.
- [PR #287](https://github.com/crauch2088-source/roshan-health-hub/pull/287): Phase 61 correction-workflow indexes; confirm query-plan benefit and migration dependencies.
- [PR #290](https://github.com/crauch2088-source/roshan-health-hub/pull/290): PHI-safe liveness/readiness telemetry; verify output allowlist and no PHI leakage.
- [PR #254](https://github.com/crauch2088-source/roshan-health-hub/pull/254): Repomix/context snapshots. Follow-up comments report the fork/workflow_run trust-boundary and token-exposure fixes; secret scanning and artifact data-minimization remain gates. This is optional developer tooling, not a release prerequisite.
- [PR #256](https://github.com/crauch2088-source/roshan-health-hub/pull/256): CI path routing. Keep protected database/security jobs; do not narrow checks by guesswork.

## Optional tooling

- [PR #288](https://github.com/crauch2088-source/roshan-health-hub/pull/288): Antigravity CLI setup is an optional owner-side development workflow. It is not a project runtime dependency, release blocker or replacement for the agent-neutral Spec Kit baseline. Keep separate from application delivery.

## Documentation and PR hygiene

- [PR #299](https://github.com/crauch2088-source/roshan-health-hub/pull/299): current second review and documentation cleanup; keep as the single active project-wide review.
- PR #295 was closed as stale; its clinical guideline/ICD-10 policy document was preserved separately. Its other status claims were not imported.
- PR #289 was closed after its ACL dependency analysis was reconciled into PROJECT_STATE and Issue #218.
- PRs #257 and #259 were closed as stale execution/release snapshots.
- 28 superseded PRs were closed on 2026-11-25; no branches were deleted and no PR was merged by this cleanup.
- Closed #179 as superseded by #258; closed #181 as superseded by #280.
- Closed earlier parallel-report rounds and the 2026-11-16 report PRs after consolidating material findings here and in the 2026-11-25 review. The detailed PR diffs remain accessible.
- [PR #263](https://github.com/crauch2088-source/roshan-health-hub/pull/263) remains open because its detailed catalogue review is directly relevant to #210.

## Open issues

- [#199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) — backup/restore and clinical/staff acceptance.
- [#217](https://github.com/crauch2088-source/roshan-health-hub/issues/217) — pharmacist-to-prescriber correction workflow.
- [#218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) — private helper ACL reconciliation.
- [#253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) — main branch protection and required checks.

## Deduplication rules

1. One observable outcome has one canonical GitHub Issue; link implementation PRs to it.
2. One active implementation branch per overlapping file/migration set. Do not let two agents edit the same migration or shared path.
3. Keep the latest evidence only when earlier rounds add no unique finding. Preserve unique findings before closing a report PR.
4. Never close an implementation PR just because it is old; compare complete diffs and dependencies first.
5. Never merge a report PR that records stale SHAs, superseded claims or an outdated task plan.
6. Do not delete branches or history during cleanup. Close superseded PRs only after evidence is preserved and a successor is identified.
7. Refresh this index from GitHub before every new execution campaign.