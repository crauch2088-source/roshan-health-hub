# Roshan Health Hub — Live Project State

**Purpose:** compact, evidence-backed session snapshot. This file is a cache, not authority over live GitHub, Supabase, or Vercel state.
**Snapshot date:** 2026-11-14. **Refresh before relying on any mutable value or performing a write.**

## Repository and active change

| Field | Last verified value |
|---|---|
| Repository | `crauch2088-source/roshan-health-hub` |
| Main baseline | `a9040601702972bdf144fc96b9658eebd5a6d31a` |
| Active branch | `fix/phase61c-atomic-dispense-role-boundary-20261114` |
| Active PR | [#250 — atomic pharmacy dispense pharmacist-role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250) |
| PR head | `2ced297b6942408354445fc24792304f4c4a68f5` |
| Branch comparison | 27 commits ahead, 0 behind `main` |
| PR state | Open, Draft |
| Independent review | 0 submitted reviews; 0 inline review threads |

**Correction:** the previous `MASTER_PLAN.md` snapshot said 24 commits ahead. The live comparison returned 27 ahead / 0 behind; this snapshot supersedes that stale count.

## Exact-head verification

Commit checked: `2ced297b6942408354445fc24792304f4c4a68f5`.

| Workflow / check | Result |
|---|---|
| CI | PASS — run [43575210104](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210104) |
| Spec Kit validation | PASS — run [43575210116](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210116) |
| Insurance claim integrity integration | PASS — run [43575210150](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210150) |
| Prescription atomicity integration | PASS — run [43575210096](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210096) |
| Privileged role guard integration | PASS — run [43575210109](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210109) |
| Phase 61 prescription correction workflow | PASS — run [43575210167](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210167) |
| Insurance claim UI validation | PASS — run [43575210152](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43575210152) |
| Vercel commit status | PASS — status URL points to the existing Roshan project |

**Important exclusions:** authenticated clinical acceptance remains intentionally skipped/deferred. These workflow results do not constitute independent SQL/security review, hosted QA acceptance, clinical acceptance, or staff UAT. Do not merge PR #250 or apply Phase 61C to hosted environments solely because CI is green.

## Hosted environments — stale checkpoints only

| Environment | Project ref | Last recorded ledger checkpoint |
|---|---|---|
| Production | `jewzonxplxhogqrnhosl` | 129 entries; latest recorded `20261102232941` |
| QA | `hopfohcnrtbiqjkgeukz` | 27 entries; latest recorded `20261113232719` |

These are historical values copied from the last repository status record, **not a fresh database read in this snapshot**. Query the live project identity, migration ledger, schema, grants, RLS, and dependencies before any migration or database write.

## Backup and recovery

- Encrypted PostgreSQL archive metadata was checked on 2026-11-14.
- That session did not download/decrypt the archive; the latest recorded restore rehearsal is older than the current backup-runner head.
- The backup is database-only. Do not describe it as a complete system backup; Storage bytes and Vault secrets are outside its scope.
- Refresh runner head, artifact checksum, decryptability, restore rehearsal, and exclusions before release.

## Data classification and standing authority

- The owner confirmed that all rows currently present in QA and Production are synthetic/test data and authorized reset/rebuild of those existing rows under Constitution Section X.
- This does **not** authorize creating new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production.
- Preserve Supabase project identity, Auth recovery, credentials/secrets, environment bindings, deployments, integrations, and essential platform settings.
- Clinical policy changes and real-world clinical/staff acceptance remain separately governed.

## Next verified work sequence

1. Obtain an independent SQL/security review of the complete PR #250 diff and its role/permission, branch, idempotency, audit, inventory, and billing invariants.
2. Reconcile migration provenance and Production/QA ACL divergence tracked by [Issue #218](https://github.com/crauch2088-source/roshan-health-hub/issues/218); do not manufacture ledger parity.
3. Refresh encrypted backup and restore evidence and close the release gates in [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199).
4. Plan the auditable pharmacist-to-prescriber correction workflow in [Issue #217](https://github.com/crauch2088-source/roshan-health-hub/issues/217), preserving the current fail-closed dispense blocker.

## Progress estimates — historical, not current

The last separately stated estimate (2026-11-12) was 62% engineering release-candidate completion, 15% operational readiness, and 17–30 focused engineering hours remaining. These values are **stale** and must not be repeated as current without a fresh deduplicated requirement/evidence audit. Post-launch experiments are excluded from completion calculations.

## Refresh protocol

Before each substantive session:

1. Fetch `main` SHA, active PR head/state, changed files, reviews, review threads, open issues, and exact-head workflow runs from GitHub.
2. Compare the active branch with current `main`; never copy ahead/behind counts from this file.
3. For database work, read the exact Supabase project ref and live migration ledger; for Vercel work, verify project, environment, alias, deployment SHA, and quota.
4. Update this file only when a meaningful state change is verified. Record source links and timestamp; mark unavailable evidence `UNKNOWN` or `STALE`, never infer it.
5. Keep the detailed roadmap in `MASTER_PLAN.md`; keep task records in GitHub Issues/PRs. Do not duplicate either here.