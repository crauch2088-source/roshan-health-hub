# Roshan Parallel Engineering — Window 05
## Round 01: CI Workflow Routing Review (PR #256)

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review target:** [PR #256](https://github.com/crauch2088-source/roshan-health-hub/pull/256)
- **Target head reviewed:** `76f542c7a4a5ca1e3c2c67fa5d72e54e1ddc01a4`
- **Declared main baseline:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Review type:** Read-only CI routing and test-dependency audit
- **Outcome:** Changes requested; do not approve the current routing contract as complete.
- **Repository changes to PR #256:** None
- **CI runs initiated:** None

## 1. Executive summary

The path-filter tightening is directionally sound and should reduce unnecessary PostgreSQL integration runs. Three workflows have generally appropriate narrow SQL/test routing, and the insurance-validation workflow preserves its manual dispatch. However, the prescription atomicity workflow omits source files directly imported/read by its focused regression test. The privileged-role TypeScript test also has an implicit dependency on the root package module configuration. The new routing regression test does not currently detect these omissions because its manually maintained required-path list is incomplete.

**Primary finding:** PR #256 can skip the dedicated prescription regression workflow when either `src/lib/prescription-draft.ts` or `src/features/clinic/consultation/components/PrescriptionTab.tsx` changes. It can also skip relevant Node/TypeScript module-runtime validation when `package.json` changes.

The repository-wide main CI remains a broad authoritative gate and runs `test:guard`, so these are dedicated-workflow routing false negatives, not proof that the entire CI system has no coverage.

## 2. Workflow-by-workflow findings

### 2.1 `.github/workflows/ci-insurance-claim-integrity.yml`

**Consumed inputs:** Six SQL files passed directly to `psql`:
- `db/tests/insurance_claim_rpc_fixture.sql`
- `db/roshan_phase5_insurance_claim_amount_integrity.sql`
- `db/roshan_phase5_insurance_coverage_validity.sql`
- `db/tests/insurance_claim_rpc_integration.sql`
- `db/tests/insurance_coverage_validity.sql`
- `db/tests/roshan_insurance_claim_amount_integrity_test.sql`

**PR paths:** The six consumed SQL files plus `.github/workflows/ci-insurance-claim-integrity.yml`.

**Missing paths:** None found for the current execution steps.

**Runtime/package inputs:** No npm install or Node test execution; neither `package.json` nor `package-lock.json` is a direct workflow input.

**Events:** `pull_request` is scoped; branch-specific `push` on `fix/insurance-claim-amount-integrity` is preserved and has no path restriction; no `workflow_dispatch`.

**Assessment:** Pass for current workflow execution contract. Expected CI savings are meaningful because unrelated database/test changes no longer start this PostgreSQL 17 job. Maintenance burden is low if SQL commands and filters are updated together.

### 2.2 `.github/workflows/ci-insurance-claim-validation.yml`

**Consumed inputs:** 
- `src/lib/insurance-validation.ts`
- `tests/insurance-claim-validation.test.ts`
- `package.json`
- `package-lock.json`

The workflow runs `npm ci`, the focused Node test, then `npm run typecheck`, `npm run lint`, and `npm run build`.

**PR paths:** All four listed inputs plus its own workflow file.

**Missing paths:** No missing direct input for the focused test or dependency installation. The typecheck/lint/build commands consume broader repository inputs than the narrowed filter represents. This is acceptable only insofar as main CI remains the authoritative broad gate; it is not a complete trigger contract for independently authoritative project-wide verification.

**Events:** `pull_request` is scoped; branch-specific `push` on `fix/insurance-claim-invoice-link` is preserved without path filtering; `workflow_dispatch` remains enabled and unrestricted by the PR path filter.

**Assessment:** Conditional pass. Good focused routing, but the broad verification steps are redundant/supplemental when triggered only by the narrow insurance inputs. Expected savings are high; maintenance cost is moderate because the workflow mixes a focused test with repository-wide checks.

### 2.3 `.github/workflows/ci-prescription-atomicity.yml`

**Consumed inputs:** 
- SQL files: `db/tests/prescription_rpc_fixture.sql`, `db/roshan_phase7_atomic_prescription.sql`, `db/tests/prescription_rpc_integration.sql`.
- Focused test: `tests/prescription-atomicity.test.ts`.
- Imported/read source files used by that test:
  - `src/lib/prescription-draft.ts` (imported and read directly).
  - `src/features/clinic/consultation/components/PrescriptionTab.tsx` (read directly).
- The test also reads its own workflow file.

**PR paths:** The three SQL files, focused test, and `.github/workflows/ci-prescription-atomicity.yml`.

**Missing paths:**
- `src/lib/prescription-draft.ts`
- `src/features/clinic/consultation/components/PrescriptionTab.tsx`
- `package.json` (implicit Node/TypeScript module interpretation dependency for the ESM-style `.ts` test).

**Package-lock:** Not consumed; no `npm ci` is run in this workflow.

**Events:** `pull_request` is scoped; branch-specific `push` on `fix/prescription-atomicity` is preserved without path filtering; no `workflow_dispatch`.

**False-negative scenario:** A PR that changes only either prescription source file, or only the root module configuration in `package.json`, will not trigger this dedicated workflow. The focused test is present in main `test:guard`, but this dedicated PostgreSQL/test job will be skipped for those source-only changes.

**Assessment:** Fail / changes required. Add the two source files and package manifest to the PR path contract. Savings are high, but the current narrow filter excludes real test dependencies and makes the routing contract unsound.

### 2.4 `.github/workflows/ci-privileged-role-guard.yml`

**Consumed inputs:**
- `db/tests/privileged_role_guard_fixture.sql`
- `db/roshan_security_privileged_role_guard.sql`
- `db/tests/privileged_role_guard_integration.sql`
- `tests/privileged-role-guard-sql.test.ts`

The focused TypeScript test reads the migration file. Its ESM-style imports execute under Node 22 with `--experimental-strip-types`.

**PR paths:** The three SQL files, focused test, and `.github/workflows/ci-privileged-role-guard.yml`.

**Missing paths:** `package.json` is an implicit runtime dependency for the repository's Node/TypeScript module interpretation and should be included. No missing direct SQL/test file was identified.

**Package-lock:** Not consumed; the workflow does not install npm dependencies.

**Events:** `pull_request` is scoped; branch-specific `push` on `test/privileged-role-guard-integration` is preserved without path filtering; no `workflow_dispatch`.

**False-negative scenario:** A package module-configuration change may skip the dedicated TypeScript/SQL validation job. The broad main CI remains an additional gate.

**Assessment:** Conditional pass; add `package.json` to make the execution dependency explicit. Savings are high; maintenance cost is low to moderate.

## 3. Manifest and lockfile impact

- PR #256 modifies `package.json` only to append `tests/ci-broad-workflow-routing.test.mjs` to `test:guard`.
- `package-lock.json` is unchanged; no dependency graph change is indicated by this PR.
- Insurance validation correctly includes both manifest and lockfile because it executes `npm ci`.
- Prescription atomicity and privileged-role guard do not execute `npm ci`; their direct package-level concern is module interpretation, so `package.json` is the relevant path, not the lockfile.
- Insurance integrity executes SQL only and has no direct npm manifest dependency.

## 4. Trigger and self-reference audit

| Workflow | pull_request paths | Own workflow included | push branch preserved | workflow_dispatch |
|---|---|---|---|---|
| Insurance integrity | Scoped | Yes | Yes: `fix/insurance-claim-amount-integrity` | No |
| Insurance validation | Scoped | Yes | Yes: `fix/insurance-claim-invoice-link` | Yes |
| Prescription atomicity | Scoped, incomplete | Yes | Yes: `fix/prescription-atomicity` | No |
| Privileged-role guard | Scoped, package path missing | Yes | Yes: `test/privileged-role-guard-integration` | No |

The prior incorrect self-workflow path entries in prescription and privileged-role guard are corrected in PR #256. Their actual workflow filenames are now present in their respective PR path lists.

Push events remain branch-only and are not subject to the PR path lists. The insurance-validation manual dispatch remains present. No claim is made that the three workflows without a `workflow_dispatch` event can be manually dispatched.

## 5. Regression test assessment

`tests/ci-broad-workflow-routing.test.mjs` checks that each workflow contains a manually enumerated set of expected paths, includes itself, retains `pull_request` and `push`, and removes broad `db/**` / `tests/**` entries.

It does **not** derive actual consumed files from workflow shell commands, TypeScript imports, or `readFileSync(new URL(...))` references. Its prescription contract omits the two source files identified above, and the contracts omit implicit package runtime dependencies. It also does not verify exact push branch values or `workflow_dispatch` preservation.

**Recommendation:** Keep a declarative expected-input contract, but make it complete and add checks for imported/read files and package-level runtime requirements. At minimum, explicitly enumerate the source files and `package.json` for prescription atomicity, and `package.json` for privileged-role guard. Ensure the test checks the intended event/branch contract rather than merely checking that a `push` block exists.

## 6. CI savings versus maintenance

- Narrow SQL-only workflows should substantially reduce unrelated PostgreSQL 17 service startup and integration execution.
- The insurance-validation workflow also avoids unrelated PRs, but its typecheck/lint/build steps make its execution footprint broader than its focused regression test.
- Savings cannot be quantified precisely without workflow run history and duration data; no numerical monthly savings estimate is asserted.
- The maintenance cost is acceptable only if dependency changes are reviewed alongside path filters. Otherwise, silent dedicated-workflow omissions are likely as tests evolve.

## 7. Baseline and evidence

- PR #256 head reviewed: `76f542c7a4a5ca1e3c2c67fa5d72e54e1ddc01a4`.
- Declared main baseline: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`.
- At review time, PR #256 was open and draft, based on main SHA `fe8d770f1bd666d00b1bf1b3385f21e109e50872`, while the declared main baseline was `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`. Reconcile the baseline relationship before final approval.
- Evidence reviewed: PR metadata and patch; all four workflow files; `tests/prescription-atomicity.test.ts`; `tests/privileged-role-guard-sql.test.ts`; `package.json` patch; `ci.yml` trigger and `test:guard` execution.
- The requested `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` could not be retrieved from either main or the PR head (GitHub returned 404). This report follows the Window 05 path previously assigned: `docs/parallel-reports/round-01/window-05.md`, and records findings, evidence, commit/PR linkage, outstanding issues, and next step rather than claiming the unavailable template was read.

## 8. Validation and scope

- Read-only review of PR #256.
- No repository changes were made to PR #256.
- No workflows, tests, package manifests, database files, QA, or production resources were modified.
- No GitHub Actions runs were initiated.
- No PR review was submitted and no merge was performed.
- Report publication is the only repository write in this round.

## 9. Remaining issues and next step

**Outstanding:** Correct prescription atomicity paths; add package manifest paths for prescription atomicity and privileged-role guard; strengthen the routing regression test; reconcile PR base with declared baseline.

**Recommendation:** Retain the narrow-filter design, but request changes to PR #256 before approval. A follow-up reviewer should verify the corrected path contracts and static test coverage without initiating additional CI runs unless explicitly authorized.

## 10. Report publication

- **Window:** 05 — CI Workflow Routing Review
- **Round:** 01
- **Report path:** `docs/parallel-reports/round-01/window-05.md`
- **Report branch:** `docs/window-05-ci-routing-review-round-01`
- **Report commit:** To be populated after publication.
- **Documentation PR:** To be populated after creation.
