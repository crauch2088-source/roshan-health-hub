# Roshan work-closure protocol

**Owner-approved:** 2026-11-11  
**Applies to:** all engineering, database, clinical workflow, UX, release and documentation work.

## Why this protocol exists

The project accumulated parallel candidate branches, repeated planning, stale completion percentages and statements that sometimes treated authored code or an older green CI run as completed delivery. That is not an acceptable definition of progress for a live clinical system. Each unit of work must be finishable, independently verifiable and safe to release.

## Mandatory execution rules

1. Select one primary workstream and state its user-visible acceptance criteria before implementation.
2. Parallelize only independent tasks with non-overlapping files, APIs, schema contracts and release dependencies.
3. For behavioral changes, write a failing regression test first, implement the smallest safe correction, then refactor without changing behavior.
4. A task is done only when acceptance criteria, tests, exact-head CI, diff review and documentation are complete. A PR, commit, plan, preview or isolated passing test is not completion.
5. Verify checks against the exact current commit. Older green runs are historical evidence only. Record failed, passed and intentionally skipped jobs separately.
6. On failure, inspect the job log, isolate root cause, make the smallest correction, and rerun only affected checks and required dependent gates.
7. Keep Engineering Readiness and Operational Acceptance as separate measures. Recalculate weighted gates from evidence; if denominator or evidence is missing, do not publish a percentage or ETA.
8. No Production database writes, migrations, role/ACL/RLS/Auth/Storage changes, deployment promotion, paid upgrades or quota workarounds without separate authorization.
9. Respect free-tier limits. When Vercel's daily deployment cap is reached, stop retrying previews and continue source-level, CI and disposable-database work that does not require deployment.
10. Deliver source, tests and documentation in one atomic logical commit. Preserve published history and use expected-SHA updates.
11. Close a workstream before opening another, unless parallel work is truly independent and has an explicit owner, acceptance gate and no shared-file conflict.
12. Report only artifacts and evidence: exact commit, PR, files, checks, safety boundaries, what remains, and why. No filler status updates.

## Definition of a closed workstream

A workstream may be marked **closed** only when all applicable conditions are true:

- Requirements and acceptance criteria are explicit.
- Implementation is complete and narrowly scoped.
- Regression coverage proves the changed behavior.
- Focused tests and required repository-wide checks pass on the exact head.
- Security, permissions, branch isolation, audit and data-integrity implications are reviewed.
- Database changes pass disposable PostgreSQL 17 and QA-first release gates.
- Clinical behavior has current authoritative source provenance, independent GP and pharmacist approval, golden cases and synthetic role-based end-to-end coverage.
- Browser/mobile RTL/LTR and staff acceptance are completed when the task affects real workflows.
- Documentation reflects actual merged/deployed state, not intended state.

A closed engineering workstream does not automatically mean the product is clinically or operationally ready.

## Evidence log — 2026-11-11

- PR #233 is open and Draft at branch head `c288390cfe4a697bb42e5d6d0ead863dfd4ac597`.
- Exact-head CI run `43090861346` failed at lint with five Prettier errors in `src/lib/medication-engine/protocol-matcher.ts`; typecheck, dependency security audits, role-guard tests and applicable PG17 integration jobs passed. Build was skipped after lint failure.
- Insurance claim validation run `43090861400` passed focused insurance tests but failed the combined typecheck/lint/build step because the same shared lint errors remained.
- Vercel preview was blocked by the free daily deployment cap. No retry or quota bypass will be attempted.
- No hosted database writes, clinical protocol activation, production data changes, Auth/Storage/ACL mutation or deployment promotion occurred during this inspection.

**Status:** Protocol documented. The CI formatting defect is being corrected in the existing PR branch; PR #233 remains Draft pending exact-head CI and independent review.


### Follow-up exact-head validation — 2026-11-11

- Commit `528bc3caddef708111de1ffd92796750a992797c` corrected four of the five Prettier findings. Its exact-head CI run `43092737006` still failed on one remaining status-union formatting line in `protocol-matcher.ts`; typecheck and all completed security/PG17/integration jobs passed, while build was skipped after lint failure.
- Insurance validation run `43092736912` passed its focused tests but failed the combined lint/build gate on the same single Prettier issue.
- The remaining formatting correction is included in the next commit. Do not count this as fixed until exact-head lint/build and all required workflows finish successfully.


### Second formatter correction — 2026-11-11

- Exact-head run `43093172320` completed with 27 successful checks, one intentional authenticated clinical-acceptance skip, and one lint failure: Prettier requires the protocol status union's first line to begin on the line after the assignment. The separate insurance aggregate run failed on the same one-line formatting issue; its focused tests passed.
- All other completed checks, including CodeQL and applicable PostgreSQL 17 integration workflows, passed. The remaining issue is formatting-only; no clinical or insurance behavior regression was reported.
- The exact formatter layout is now corrected in the following commit. Final acceptance still requires a fresh exact-head CI and the insurance validation workflow.
