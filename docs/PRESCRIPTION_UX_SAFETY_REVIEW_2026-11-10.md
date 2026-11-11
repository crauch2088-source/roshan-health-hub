# Prescription UX, Formulation and Dose-entry Safety Review
**Review date:** 2026-11-10  
**Snapshot main:** `d42baae4f5bdbb6319cd389630f0b4ad349150ab`  
**Scope:** prescription composer, medicine search identity, dosage form/route, frequency/duration, instructions, pediatric age/weight cues, pharmacy queue continuity and related open PRs.

> This is an engineering/source review, not clinical approval. No drug regimens, dose recommendations, duration protocols or product-route mappings were created.

## 1. Repository and check baseline

- `main` is `d42baae4f5bdbb6319cd389630f0b4ad349150ab`.
- `docs/MASTER_PLAN.md` blob at review time: `68390312c0231c23f87429df8d2f566731476bbe`.
- `docs/PLUGIN_TOOLING_MAP.md` blob at review time: `e7c5738612fa8929534a1c693149d8217af7582b`.
- The main combined status exposes a failed Vercel context linking to the Free-plan `build-rate-limit` page. The commit-workflow-runs lookup returned no PR-triggered Actions runs for this main SHA; this is not evidence of a green main Actions suite.
- No new service, paid tool, parallel app, or plugin was needed. Existing GitHub Actions, the repository's PostgreSQL 17 test jobs, and the connected read-only Supabase SQL tool were sufficient.

## 2. Verified current-main gaps

The following findings were confirmed against source at the snapshot SHA:

1. **Route inference:** `src/lib/prescription-draft.ts` sets `route = "oral"` for tablet, capsule, syrup and suspension. Dosage form alone is not a validated product-specific route instruction.
2. **Incomplete validation:** `validatePrescriptionDrafts()` requires name, dose, frequency, duration and positive quantity, but current main does not require dosage form or route.
3. **Custom-value dead ends:** the composer renders a “Custom” Select choice for dosage form, frequency, duration and route without a corresponding free-text input.
4. **Unqualified numeric dose presets:** the composer imports the generic `DOSES` list (values such as 1, 2, 2.5, 5, 10, 20, 50, 100) without units or medicine/indication context.
5. **Implicit quantity:** an empty draft starts with quantity `"1"`, which can silently look like a complete quantity.
6. **Medicine picker ambiguity:** the query already retrieves brand, generic name, strength and dosage form, but the current result display shows only display name and strength. Brand and formulation are not visible when choosing between similar products.
7. **Pharmacy continuity:** current main's pharmacy queue does not display persisted dosage form, route and additional instructions together.
8. **Age and weight:** current main warns pediatric prescribers to check the current visit weight and maximum daily dose, and explicitly says it does not calculate pediatric doses. It does not yet warn when age cannot be derived from a missing/invalid/future DOB.

## 3. Verified candidate work in PR #179

PR [#179](https://github.com/crauch2088-source/roshan-health-hub/pull/179) remains **Open / Draft**. Its current head is `b9232e3daef6060762a11a4fba7db905f737c5f6`, based on the reviewed main SHA, 34 commits ahead / 0 behind, 18 changed files (+922/-153).

The candidate already contains these safe changes:

- Removes automatic oral-route inference. Selecting a catalogue product pre-fills a recognized dosage form only; route stays blank.
- Requires an explicit dosage form and route before saving; does not claim that the selected route is compatible with the exact product.
- Removes the default quantity of one and requires a positive whole quantity.
- Replaces generic numeric dose presets with clinician-entered free text whose placeholder asks for dose and unit.
- Provides free-text fallbacks for custom dosage form, frequency, duration and route.
- Warns when patient age cannot be verified from DOB; invalid, impossible and future dates are tested as unknown.
- Uses weight recorded against the current visit for the pediatric cue. Missing/error states prompt manual review. No dose calculation or historical-weight reuse is introduced.
- Adds dosage form, route and saved instructions to the pharmacy queue's mobile and desktop summaries.
- Builds prescription printing from the persisted order and child rows; it copies saved values rather than inferring them, blocks missing required print fields, attributes patient/prescriber, and does not claim a digital signature. Additional instructions remain optional but are preserved verbatim.

### TDD change made in this review

A small, display-only product-disambiguation gap was fixed on the PR #179 branch:

- Added a regression asserting that medicine search results show brand and dosage form, as well as the existing generic/strength details, and that the search hint advertises these fields.
- The test-first commit `2f663920d37c2f211f20951c828e6fd187b0bce4` produced the expected RED result in CI run [1904](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42864482274): 278/279 tests passed; the new picker-identity assertion failed because brand/form were not rendered.
- Implementation commit `b9232e3daef6060762a11a4fba7db905f737c5f6` adds generic, brand, strength and dosage-form details to each result, suppresses duplicate values, and updates the bilingual search hint. It does not alter stored medicine identity, route, dose or regimen.
- Exact-head CI run [1905](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42865136031) passed the full 279/279 guard/unit tests; the build/typecheck/lint job succeeded. Prescription atomicity [716], privileged-role guard [719], clinical-child RPC-only writes [350], insurance integrity [720], insurance UI [619], Phase 48 Storage [84], and finance-only RPC isolation [532] all completed successfully.
- Exact-head Vercel status is successful. The canonical PG17 baseline/authenticated clinical-acceptance job remains intentionally skipped. No authenticated clinical E2E or staff acceptance was performed.

PR #179 remains Draft: a green source/CI/preview result is not browser print acceptance. Authorized non-staff RTL/LTR visual checks, page-break/print preview and actual A4 output still need evidence; clinical/staff acceptance remains deferred until the isolated free test environment and synthetic doctor identity are available.

## 4. Duration, frequency, dose and instructions — clinical boundary

- `DURATIONS` currently offers generic values from 1 to 90 days plus “ongoing”. These are generic data-entry shortcuts, not indication-specific, medicine-specific or sourced protocols. The candidate leaves the field blank by default and provides custom entry, but does not validate duration semantics or impose a maximum.
- No universal duration maximum/minimum was added. A blanket cap would be clinically unsound across acute, chronic, tapering, prophylactic and single-dose regimens.
- Frequency options are also generic entry shortcuts; they are not linked to a product or diagnosis and must not be represented as recommendations.
- Dose remains clinician-entered free text with an explicit unit cue. There is no weight-based calculator, dose table or auto-generated regimen.
- Additional instructions remain optional because their necessity depends on the medicine and context. The saved value is carried through the pharmacy queue and print model without normalization or invention.

Before introducing medicine/indication-specific duration, frequency or dose templates, obtain current primary-source protocols applicable to the exact population and indication, record source/version/review date, and obtain GP/pharmacist approval. Do not seed values from a generic list or an unverified catalogue row.

## 5. Formulation and route compatibility remain blocked by catalogue evidence

Read-only aggregate SQL on 2026-11-10 returned:

| Environment | Active, non-deleted medicines | Missing generic name | Missing brand | Missing strength | Missing dosage form |
|---|---:|---:|---:|---:|---:|
| QA | 0 | 0 | 0 | 0 | 0 |
| Production | 9 | 0 | 9 | 9 | 9 |

The query returned counts only; no product names, stock, prices, patient or financial rows were read.

Both environments reported:
- No `public.medicine_pack_verifications` table.
- No product-level route mapping column among `administration_routes`, `allowed_routes` or `route_options`.

PR [#210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) is an independent Draft candidate for shared medicine identity editing and append-only physical-pack attestation. Its exact head `fb354974f7f648d5985b3296e75403718f869b45` passed its five reported workflows (CI 1877 plus prescription atomicity 700, privileged-role guard 703, insurance integrity 704 and insurance UI 603); Vercel status was successful. It compares as 56 commits ahead / 1 behind current main. Its Phase 60 migration has not been applied to QA or Production, confirmed by the absent verification table. It improves identity and pack-attestation governance but does **not** supply validated product-specific route compatibility or clinical regimens. Keep it Draft pending current-main reconciliation, independent SQL/security review, migration-history review and its separate acceptance gates.

Until exact product identity, strength, dosage form and manufacturer labeling are verified, the UI must not infer or restrict routes as though the product is clinically verified. PR #179's explicit route selection is safer than inference, but it is not a route-compatibility engine.

## 6. Other active workstreams deliberately not duplicated

- PR #185 (Spec 056 evidence-based prescribing) remains Draft at `38c84ca983e574d380767395f931f8a2f23510b0`; it is 7 commits ahead / 23 behind current main. Its exact-head CI 1603 and Spec Kit validation 29 passed, but its Vercel status is failed. The specification is useful source material, but this stale branch should not be merged as-is; reconcile its feature artifacts with current main and the existing prescription implementation.
- PR #226 is a separate Phase 61 prescription-correction implementation, not a dose/formulation work item. Its latest observed head `d95edcaf2c7f760f06dcf5e00c4ef1fb43273bf1` is 7 ahead / 0 behind, but CI 1903, Phase 61 workflow 15 and insurance UI 617 failed. Related #221/#223/#224 are also correction-workflow drafts. This review made no changes to those branches.
- Older #125 and #183 are closed unmerged; the route/custom-field changes have been superseded into the current #179 candidate according to the Master Plan's 2026-11-04 record.

## 7. Safety and release boundaries

- No Production or QA DDL/DML, migration application, role/grant/Auth/Storage change, patient/clinical/financial record creation, or production deployment was performed.
- The only database operation was a read-only aggregate medicine-catalogue count.
- No clinical protocol, interaction rule, dose, frequency, route mapping or duration rule was seeded or activated.
- No authenticated clinical E2E or staff UAT was run; these remain deferred under the owner's environment/identity condition.
- No print output is described as signed. No physical printer compatibility is claimed.

## 8. Next safe actions

1. Keep PR #179 Draft until the exact-head checks remain green and the authorized preview can be inspected in Arabic RTL / English LTR, including the medicine picker, pharmacy queue and A4 print output. Do not bypass SSO or Vercel limits.
2. Reconcile PR #210 with current main and complete independent SQL/security/migration-provenance review before any hosted migration. Keep the physical-pack attestation separate from clinical route approval.
3. Build product-specific route compatibility only from verified exact-product labeling and pharmacist review. Until then, require explicit prescriber selection and make no compatibility claim.
4. Keep dose, frequency and duration clinician-entered. Do not introduce universal duration caps or diagnosis-based templates without current, indication-specific primary-source evidence and clinical approval.
5. Keep Spec 056 as the future governed decision-support specification; activate no dose rules until data completeness, sources, test coverage, review/expiry and clinical approval are demonstrable.
