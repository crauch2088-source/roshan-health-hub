# Roshan Health Hub — Live Project State

**Purpose:** compact, evidence-backed session snapshot. This file is a cache, not authority over live GitHub, Supabase, or Vercel state.
**Snapshot date:** 2026-11-14 (refreshed after code-head checks, live Phase 55/61 read-only checks, and governance correction). **Refresh before relying on any mutable value or performing a write.**

## Repository and active change

| Field | Last verified value |
|---|---|
| Repository | `crauch2088-source/roshan-health-hub` |
| Main baseline | `a9040601702972bdf144fc96b9658eebd5a6d31a` |
| Active branch | `fix/phase61c-atomic-dispense-role-boundary-20261114` |
| Active PR | [#250 — atomic pharmacy dispense pharmacist-role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250) |
| PR head | `b90a05bda40d1dda68360768abf36a205a40a96e` |
| Branch comparison | 39 commits ahead, 0 behind `main` |
| PR state | Open, Draft |
| Latest READY Production deployment | `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH` on main SHA `a9040601702972bdf144fc96b9658eebd5a6d31a`; canonical alias `roshan-health-hub.vercel.app`; `aliasError=null` |
| Independent review | 0 submitted reviews; 0 inline review threads |

## Exact-head verification

SQL/application code checked: `83ed9a9d82b3a1ee78ccadcc70db86139b182983`. Latest docs-only head: `b90a05bda40d1dda68360768abf36a205a40a96e`.

| Workflow / check | Result |
|---|---|
| Complete CI check suite | PASS — 31 successful checks, 1 intentional authenticated clinical-acceptance skip, 0 failures; [run 43577740702](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43577740702) |
| Vercel status | SUCCESS status, but deployment was canceled by the Ignored Build Step; no preview deployment was produced |

**Important exclusions:** authenticated clinical acceptance remains intentionally skipped/deferred. Green CI does not constitute independent SQL/security review, hosted QA acceptance, clinical acceptance, staff UAT, or a Vercel preview. Do not merge PR #250 or apply Phase 61C to hosted environments solely because CI is green.

## Hosted environments — fresh read-only Phase 55 and Phase 61 snapshot

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

### Phase 55 ACL reconciliation

| Check | QA | Production |
|---|---|---|
| Phase 55 migration | Present: `20261103155227` | Absent |
| `private.app_has_claim_branch(uuid)` EXECUTE to anon/authenticated/service_role/authenticator | Denied | Allowed via NULL proacl / default PUBLIC grant |
| `private.sync_user_role_text()` EXECUTE to anon/authenticated/service_role/authenticator | Denied | Allowed via NULL proacl / default PUBLIC grant |
| `private.phase36_guard_clinical_visit_links()` EXECUTE to those roles | Denied | Denied |

The only public function callers found for `private.app_has_claim_branch(uuid)` are `post_insurance_claim_payment(uuid,numeric,text,text)` and `update_insurance_claim_status(uuid,text,numeric,text)`; both are SECURITY DEFINER with fixed empty `search_path` in both environments. `private.sync_user_role_text()` is trigger-only on `public.users`. Phase 36 guard triggers remain attached to the five expected clinical child tables. See [Issue #218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) for the fresh evidence note. No hosted changes were made.

## Backup and recovery

- Backup runner main is `f171732b61fe0460c61a36aa63b861065f9ea9d1`; runner CI [43190851147](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43190851147) passed. Latest successful encrypted Production backup plus runner-side PostgreSQL 17 restore remains [43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) on older runner SHA `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`. No new backup was dispatched; `SUPABASE_DB_PASSWORD` had been deleted after the earlier run. The retained Drive ciphertext has not yet passed owner-side Android/Termux decryption.
- The backup is database-only. Do not describe it as a complete system backup; Storage bytes and Vault secrets are outside its scope.
- The runner now provides an offline Android/Termux verifier. Owner-side decryption remains a manual release gate; a fresh backup is blocked on owner-side credential setup. The archive remains database-only; Storage object bytes and Vault secrets are outside its scope.

## Data classification and change authority

- The owner confirmed that all rows currently present in QA and Production are synthetic/test data; no real patient records have been trialed or entered. This classification is durable and need not be reconfirmed.
- This fact does **not** authorize deleting, truncating, resetting, replacing, or reseeding those rows, nor destructive schema rebuilds. Such operations require a specific scoped owner decision and recovery plan.
- Do not create new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production.
- Preserve Supabase project identity, Auth recovery, credentials/secrets, environment bindings, deployments, integrations, and essential platform settings.
- Clinical policy changes and real-world clinical/staff acceptance remain separately governed.

## Parallel feature-branch status — read-only review

| Workstream | Current branch vs main | Exact-head checks | Disposition |
|---|---:|---|---|
| [PR #250 — Phase 61C dispense role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250) | 36 ahead / 0 behind | SQL/application head `83ed9a9`: 31 pass, 1 intentional clinical-acceptance skip, 0 fail; docs-only head `f526bf`: no checks triggered for the docs-only commit | Draft; no independent review; hosted Phase 61C not applied |
| PR #233 — medication engine | Closed as superseded; implementation files are byte-identical to main via PR #249 and its documentation was carried to PR #252 | Historical checks green | No remaining implementation delta on that branch |
| [PR #181 — payment receipts](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | 37 ahead / 18 behind | 29 pass, 1 intentional clinical-acceptance skip, 0 fail | Draft; Phase 58/59 hosted contract absent; do not deploy UI |
| [PR #210 — catalogue identity/pack attestation](https://github.com/crauch2088-source/roshan-health-hub/pull/210) | 74 ahead / 18 behind | 25 pass, 1 intentional clinical-acceptance skip, 0 fail | Draft; attestation is not physical-pack verification or a dispensing hard-stop |
| [PR #251 — TIT UX comparison](https://github.com/crauch2088-source/roshan-health-hub/pull/251) | Based on current main at creation | Documentation-only | Draft; no runtime changes |
| [PR #252 — Feature 056 specification consolidation](https://github.com/crauch2088-source/roshan-health-hub/pull/252) | 2 ahead / 0 behind | Spec Kit validation and both CodeQL language scans passed; no runtime changes | Draft; documentation-only; no clinical activation |

The remaining older feature branches (#181 and #210) are divergent from current main. Their historical green CI is not current-main validation. Reconcile with normal two-parent merges, resolve overlapping source/spec/manifest files, then rerun exact-head CI. Do not force-push or merge stale branches. PR #185 was also closed as superseded by the consolidated #252 documentation package.

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