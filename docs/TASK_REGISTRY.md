# Roshan Health Hub — Task Registry and Prioritization

**Canonical backlog:** GitHub Issues and Pull Requests in `crauch2088-source/roshan-health-hub`.
**This file is an index and operating rule, not a second backlog.** Do not copy full issue descriptions, create duplicate TODO lists, or mark an item complete here. Re-query GitHub before choosing work.

## Selection rules

Prioritize by verified risk and dependency, not by age or ease:

| Priority | Meaning | Examples |
|---|---|---|
| P0 | Stop-ship: credible patient-safety, security, data-loss, or production-integrity defect | unauthorized access, incorrect/partial stock or billing mutation |
| P1 | Release blocker or prerequisite to safe controlled rollout | migration provenance, independent SQL review, backup/restore, critical role/branch tests |
| P2 | Core workflow completeness and reliability | missing pharmacy/clinic/lab/finance workflow with safe workaround |
| P3 | UX polish, refactoring, optional integrations, post-launch experiments | non-blocking visual refinement |

Do not assign priority from title alone. Read the current issue body, comments, linked PRs, labels, dependencies, code, and test evidence. A task may be blocked while independent work proceeds.

## Current open work index (verified 2026-11-14)

| GitHub item | Current purpose | Immediate handling |
|---|---|---|
| [PR #250](https://github.com/crauch2088-source/roshan-health-hub/pull/250) — Draft | Phase 61C atomic pharmacy-dispense pharmacist-role boundary | Independent SQL/security review first; no hosted apply or merge based on CI alone |
| [Issue #218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) | Production/QA private-helper EXECUTE ACL divergence | Reconfirm call sites, migration source/provenance, effective ACLs, and release gate before any apply |
| [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) | Encrypted backup, restore, and clinical/staff acceptance gates | Refresh backup-runner and restore evidence; separate owner-controlled setup from engineering work |
| [Issue #217](https://github.com/crauch2088-source/roshan-health-hub/issues/217) | Auditable pharmacist-to-prescriber correction workflow | Preserve fail-closed dispensing; specify authorization, audit, concurrency, and no-side-effect behavior before implementation |

GitHub search returned these three open Issues plus the active PR at the time of this snapshot. This is not a claim that no other issue/PR exists; use live search (`repo:crauch2088-source/roshan-health-hub is:open`) to refresh.

## Dependency and deduplication rules

- One user-visible outcome should have one canonical GitHub Issue. Link implementation PRs to that Issue; use task lists inside the Issue for bounded substeps.
- Express dependencies with GitHub issue/PR links and explicit `blocked by` / `blocks` statements. Do not maintain a second dependency graph in Markdown.
- Reuse an existing open Issue when scope matches. Create a new one only for a distinct outcome or separately owned risk.
- Close only after acceptance criteria and evidence are present; a merged PR, green CI, or a plan is not enough by itself.
- If scope changes materially, update the canonical Issue before implementation; do not silently broaden the PR.
- `MASTER_PLAN.md` owns strategic sequence. This registry only routes the agent to canonical records.