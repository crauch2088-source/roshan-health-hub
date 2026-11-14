# Roshan Health Hub — Live Project State

**Purpose:** compact, evidence-backed session snapshot. This file is a cache, not authority over live GitHub, Supabase, or Vercel state.
**Snapshot date:** 2026-11-14 (refreshed after the 83ed9a9 exact-head and live Phase 61 read-only checks). **Refresh before relying on any mutable value or performing a write.**

## Repository and active change

| Field | Last verified value |
|---|---|
| Repository | `crauch2088-source/roshan-health-hub` |
| Main baseline | `a9040601702972bdf144fc96b9658eebd5a6d31a` |
| Active branch | `fix/phase61c-atomic-dispense-role-boundary-20261114` |
| Active PR | [#250 — atomic pharmacy dispense pharmacist-role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250) |
| PR head | `83ed9a9d82b3a1ee78ccadcc70db86139b182983` |
| Branch comparison | 34 commits ahead, 0 behind `main` |
| PR state | Open, Draft |
| Independent review | 0 submitted reviews; 0 inline review threads |

## Exact-head verification

Commit checked: `83ed9a9d82b3a1ee78ccadcc70db86139b182983`.

| Workflow / check | Result |
|---|---|
| Complete CI check suite | PASS — 31 successful checks, 1 intentional authenticated clinical-acceptance skip, 0 failures; [run 43577740702](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43577740702) |
| Vercel status | SUCCESS status, but deployment was canceled by the Ignored Build Step; no preview deployment was produced |

**Important exclusions:** authenticated clinical acceptance remains intentionally skipped/deferred. Green CI does not constitute independent SQL/security review, hosted QA acceptance, clinical acceptance, staff UAT, or a Vercel preview. Do not merge PR #250 or apply Phase 61C to hosted environments solely because CI is green.

## Hosted environments — fresh read-only Phase 61 snapshot

| Check | QA (`hopfohcnrtbiqjkgeukz`, PostgreSQL 17.11) | Production (`jewzonxplxhogqrnhosl`, PostgreSQL 17.6) |
|---|---|---|
| Phase 61 migration | Present: `20261111223309` | Absent |
| Phase 61B migration | Present: `20261113232719` | Absent |
| Phase 61C migration | Absent | Absent |
| `private.app_has_role_permission(text[],text)` | Present | Absent |
| `public.atomic_pharmacy_dispense(uuid,boolean,uuid)` | Present | Present |
| `private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)` | Absent | Absent |
| Active `pharmacist` users | 1 | 1 |
| Active `legacy_pharmacist` users | 0 | 0 |

This was a read-only SQL check. No DDL, DML, ACL, RLS, Auth, Storage, backup, or deployment changes were made. Full migration-ledger counts and broader catalog fingerprints were not refreshed in this check; do not infer parity from this Phase 61-specific snapshot. Phase 61C remains a candidate only and requires independent SQL/security review before QA application. Production remains untouched.

## Backup and recovery

- Backup evidence was not revalidated during this PR #250 continuation. Treat prior encrypted archive metadata and restore rehearsal as stale for release decisions until runner head, artifact checksum, owner-side decryptability, and a current PostgreSQL 17 restore rehearsal are checked.
- The backup is database-only. Do not describe it as a complete system backup; Storage bytes and Vault secrets are outside its scope.
- Refresh runner head, artifact checksum, decryptability, restore rehearsal, and exclusions before release.

## Data classification and change authority

- The owner confirmed that all rows currently present in QA and Production are synthetic/test data; no real patient records have been trialed or entered. This classification is durable and need not be reconfirmed.
- This fact does **not** authorize deleting, truncating, resetting, replacing, or reseeding those rows, nor destructive schema rebuilds. Such operations require a specific scoped owner decision and recovery plan.
- Do not create new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production.
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