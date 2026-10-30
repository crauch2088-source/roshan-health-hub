# Roshan Health Hub — Autonomous Engineering Execution Report

**Date:** 2026-10-30

**Repository:** `crauch2088-source/roshan-health-hub`

**Baseline:** `origin/main` at `83bcfd9a46f55ff16e9c6a2133f5e01d696f7d79`

**Security-fix branch:** `fix/staff-provisioning-soft-delete-20261030`

## Executive summary

The live repository was checked before new work. Main was clean at `83bcfd9`; its latest CI (`40835690794`), finance-only RPC isolation (`40835690771`), and CodeQL (`40835690024`) succeeded. PR #139 remained open and clean at `1922e9759bed884b99a60ae32ade71189d81869c`; its five exact-head workflows succeeded, with the explicit authenticated-clinical acceptance job skipped. PR #141 remained open at `ace1d0e83f88e4eb1eaf62392afc692e3a6da919`; its five exact-head workflows succeeded, but its QA-only reconciliation has not been applied.

Two independent, read-only source reviews found a high-confidence staff-provisioning authorization bug and a separate Storage path/entity binding gap. The staff-provisioning bug is fixed on a dedicated branch with a failing-before regression test and a passing focused and full local suite. The Storage finding is tracked in new P1 Issue [#142](https://github.com/crauch2088-source/roshan-health-hub/issues/142); this review does **not** prove a cross-branch object read. No production or QA data/configuration was changed, no migration was applied, no deployment was initiated, and no clinical acceptance is claimed.

## Verified issue and PR inventory

Open issues at the audit: [#25](https://github.com/crauch2088-source/roshan-health-hub/issues/25) (historical environment cleanup and security settings; no labels), [#95](https://github.com/crauch2088-source/roshan-health-hub/issues/95) (protected UX release gate; no labels), and [#140](https://github.com/crauch2088-source/roshan-health-hub/issues/140) (QA baseline `security_invoker` fidelity; no labels). Issue #140 is actively addressed by PR #141. Issue #95 must remain open until the actual human/clinic acceptance criteria are met. No duplicate existed for the Storage entity-binding finding before Issue #142 was created; #142 is labeled `bug`.

Open PR state, checked live:

| PR                                                                      | Verified state and implication                                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [#139](https://github.com/crauch2088-source/roshan-health-hub/pull/139) | Open/clean at `1922e9759bed884b99a60ae32ade71189d81869c`; five workflows succeeded. The exact-head CI intentionally skipped authenticated clinical acceptance. Public-route browser/accessibility acceptance remains untested.                                                                   |
| [#141](https://github.com/crauch2088-source/roshan-health-hub/pull/141) | Open/clean at `ace1d0e83f88e4eb1eaf62392afc692e3a6da919`; CI, insurance UI, insurance integrity, privileged-role guard, and prescription atomicity workflows succeeded. CodeQL was neutral and the canonical PG17/clinical acceptance gate skipped. Its QA-only reconciliation was not executed. |
| [#125](https://github.com/crauch2088-source/roshan-health-hub/pull/125) | Open/clean at `117952591aaa5e3d635f524eb2b22ba5481b3504`; 26 checks passed and the explicit clinical acceptance gate skipped. Staff acceptance is still required.                                                                                                                                |
| [#138](https://github.com/crauch2088-source/roshan-health-hub/pull/138) | Open at `5779e01d81dafa4f1c9dd39dca48a08aad8990e4`; 26 checks passed and the clinical gate skipped. This is the policy/test guard deferring incompatible ESLint 10 updates.                                                                                                                      |
| [#108](https://github.com/crauch2088-source/roshan-health-hub/pull/108) | Open at `074ab74d5367817558b483d8bf111757f8a27551`; 41 checks passed and one clinical gate skipped. This is the GitHub Actions-major update; no merge was made.                                                                                                                                  |
| [#131](https://github.com/crauch2088-source/roshan-health-hub/pull/131) | Open/unstable at `b15465b55a76e8e48b49d736ca5c316aa0b4ef20`; two checks failed. The CI failure was `Install from lockfile`; Vercel was also failing. Keep unmerged pending compatibility/install diagnosis.                                                                                      |
| [#103](https://github.com/crauch2088-source/roshan-health-hub/pull/103) | Open/stale at `5cfc43ecd0a2b046680dc9e22c9cf897479b414e`; old CI run `40067129351` failed its Security audit step. It records the user-directed authenticated QA test deferral.                                                                                                                  |
| [#112](https://github.com/crauch2088-source/roshan-health-hub/pull/112) | Open documentation-only UX modernization plan; 23 checks passed. It overlaps the active tracking scope of Issue #95; no competing UX plan or code work was started.                                                                                                                              |

Recent completed work was checked to avoid duplication: PR #135 already merged setup autocomplete tokens; PR #132 already merged the Seroval security patch; PR #137 and related docs PRs recorded refresh evidence. No branch was deleted or rewritten. Older remote branches were not assumed abandoned solely from age.

## Prioritized backlog

### P0 — Critical

- No new, independently verified production data exposure, financial corruption, or production RLS bypass was established by this execution. Continue to treat historical secret exposure under Issue #25 as **unverified**, not cleared. Preserve existing production and migration release gates.

### P1 — High

1. **Staff-provisioning identity revocation — implemented, local verification complete; exact-head remote CI pending.** `createStaffUser` used a service-role lookup that checked `active` but did not exclude `deleted_at IS NOT NULL`; a still-valid token for a soft-deleted super-admin could pass authorization and assign a role, including `super_admin`. The caller query now filters `.is("deleted_at", null)` before role checks. A source-contract regression verifies the filter and that caller rejection precedes Auth-user creation and profile insertion. Work is isolated from PR #139 and based on the verified main SHA above.
2. **Storage entity-to-branch binding — BLOCKED for implementation pending bucket/path contract review; tracked by [Issue #142](https://github.com/crauch2088-source/roshan-health-hub/issues/142).** The current helper checks path prefix/shape and permission but does not bind the object-path entity UUID to the actual row and branch. Risk is misassociated/orphaned clinical attachments; cross-branch reading was not demonstrated. Implement with disposable PostgreSQL 17 policy tests; do not apply live QA/production without separate authorization.
3. **QA baseline security-invoker consistency — active candidate [PR #141](https://github.com/crauch2088-source/roshan-health-hub/pull/141), [Issue #140](https://github.com/crauch2088-source/roshan-health-hub/issues/140).** Exact-head CI is green, but QA reconciliation and the follow-up advisor check remain unperformed and require separate authorization. No production change is needed or authorized.
4. **Full UX and clinic workflow acceptance — HUMAN ACCEPTANCE REQUIRED under [Issue #95](https://github.com/crauch2088-source/roshan-health-hub/issues/95).** Blockers include actual browser screenshots/assertions at 320/360/390/430px, RTL/LTR, keyboard/focus, autofill, screen-reader announcements, protected-route role tests, and clinic staff sign-off. The QA runbook still records the unknown-password/Auth Admin limitation; no credentials were provisioned here.
5. **Prescription workflow sign-off — HUMAN ACCEPTANCE REQUIRED for [PR #125](https://github.com/crauch2088-source/roshan-health-hub/pull/125).** Required checks are dose plus unit, custom frequency/duration, form, route, and age cue with an authorized synthetic clinician/pharmacist workflow. Do not infer acceptance from green automation.

### P2 — Medium

- **[Issue #25](https://github.com/crauch2088-source/roshan-health-hub/issues/25):** historical exposure remains unverified; Dependabot vulnerability-alert and some secret-scanning settings are disabled/unavailable through the current connector. No credentials were retrieved or changed. A future read-only history scan must suppress/redact any match; changing repository security settings needs an authorized connector.
- **Dependency/CI maintenance:** PR #131 is failing install/Vercel; PR #138 defers ESLint 10 and is green; PR #108 is green with its explicit skip. Keep them separate and do not merge or batch majors without exact compatibility evidence. PR #103's Security-audit failure is from its old head and should be re-evaluated only by its owner; PR #112 is a stale docs plan adjacent to Issue #95.
- **Reliability/privacy roadmap:** offline resilience, backup/restore rehearsal, and data portability are already represented in existing roadmap documents. Do not cache clinical data offline or add sync without a reviewed privacy/threat model, expiry, logout cleanup, and tested recovery design. No duplicate issue was created.

### P3 — Optional

- Defer nonessential visual polish and future integrations until P1 release gates have evidence. No new feature was added merely to expand scope.

## Completed code change and evidence

Changed files for the staff-provisioning candidate:

- `src/routes/_authenticated/-users.server.ts` — adds the server-side `deleted_at IS NULL` filter to the caller lookup.
- `tests/role-guard.test.ts` — adds a regression asserting the filter is applied before `maybeSingle`, authorization rejection precedes Auth user creation, and profile insertion follows only after the guarded creation path.
- `docs/MASTER_PLAN.md` and this report — append the verified snapshot, findings, backlog, and acceptance boundaries.

Test-first evidence:

- Before the fix: `node --test --experimental-strip-types tests/role-guard.test.ts` failed the new regression (6/7 passed); the assertion identified the missing `deleted_at` filter.
- After the fix and correction of the test's guard-order assertion: the focused command passed **7/7**.
- Final local validation on the source/test change: `npm run lint`, `npm run typecheck`, `npm run build`, and `npm run test:guard` all exited successfully. The full guard suite passed **223/223**, zero failures. Prettier and `git diff --check` were also run; the final documentation formatting/whitespace check is recorded with the committed PR state.

The regression is a source-contract guard, not a live Supabase or end-to-end Auth test. No service-role credentials, live Auth users, database, or production/QA records were accessed. Exact-head GitHub Actions are required after publication; local success is not a substitute.

## Remaining limitations and safety

- No browser/Vercel visual acceptance was performed. No Vercel SSO was bypassed.
- No clinical, staff, authenticated-role, or prescription acceptance was performed.
- No Supabase/Storage/QA/production setting, database, migration, or data was changed. PR #141's QA script remains unapplied.
- Issue #95 remains open. No pull request was merged and no production deployment was initiated.

## Recommended next task

Complete the P1 Storage contract review for [Issue #142](https://github.com/crauch2088-source/roshan-health-hub/issues/142): map each bucket path to its authoritative clinical row, design a narrowly scoped fail-closed branch/entity check, and add disposable PostgreSQL 17 negative and positive INSERT policy tests. Keep any live QA application behind separate explicit authorization.

## Exact CI links for reviewed baselines

- **Main `83bcfd9`:** [CI — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40835690794), [finance-only RPC isolation — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40835690771), [CodeQL — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40835690024).
- **PR #139 at `1922e975`:** [CI — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40976565047), [insurance claim UI — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40976565030), [insurance claim integrity — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40976565066), [privileged-role guard — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40976565322), [prescription atomicity — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40976564943). The canonical PG17/authenticated clinical acceptance job was **skipped** inside CI.
- **PR #141 at `ace1d0e`:** [CI — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40978509299), [insurance claim UI — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40978509247), [insurance claim integrity — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40978509180), [privileged-role guard — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40978509171), [prescription atomicity — success](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40978509167). CodeQL was neutral; the canonical clinical acceptance job was **skipped** inside CI.
