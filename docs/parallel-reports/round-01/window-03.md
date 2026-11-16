# Window 03 — Round 01 Report

## 1. Identity and scope

- Window: **03 — Medicine Catalogue Identity & Pack Attestation**
- Original task / Issue / PR: Independent review of [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210), “feat(pharmacy): medicine catalogue identity correction and pack attestation”.
- Round: **01**
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (latest commit returned by repository commit search at review time; 2026-11-15T22:06:07Z).
- Current task branch / PR: `feat/medicine-catalogue-identity-rebased-20261109` / [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210).
- Current candidate head: `f041ac9fa0e3cb4114346984e3d1393ad972e18f`.
- Scope: Read-only review of medicine identity, catalogue permissions, pack-attestation SQL/UI, packaging and unit semantics, historical references, dispensing/FEFO/invoice impact, tests and CI.
- Explicit exclusions: No implementation change to PR #210; no branch on the task PR; no hosted QA/Production migration, DDL/DML, ACL/RLS change, business-data write, deployment, merge, issue closure or release approval. The only repository write for this window is this isolated report on a documentation-only branch/PR.

## 2. Executive verdict

- Status: **CHANGES REQUIRED**
- What is actually complete: Read-only review of the candidate SQL migration, PostgreSQL 17 integration test, catalogue helper, inventory route, catalogue unit tests, PR metadata/review, commit comparison and available exact-head CI evidence. This report is published separately because the task is review-only.
- What remains incomplete: Duplicate identity prevention/normalization; safe handling of identity corrections after stock/batches/history exist; explicit historical prescription/receipt rendering verification; full product/pack/base-unit/conversion model; additional role and edge-case tests; independent SQL/security review and authenticated pharmacist acceptance.
- Work type: **Review-only work**, not implementation.
- Merge recommendation: **Do not merge PR #210 in its current state. Keep Draft / Request Changes.** Preserve the useful column-level authority separation and append-only attestation design; close the identified product-identity and historical-integrity gaps before reconsideration.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status (verified / not rechecked) |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main baseline commit](https://github.com/crauch2088-source/roshan-health-hub/commit/79d81f08f6567f5145f7143e3bf5afdd6e93bf59) | Verified via latest repository commit search |
| Task branch/head SHA | `feat/medicine-catalogue-identity-rebased-20261109` / `f041ac9fa0e3cb4114346984e3d1393ad972e18f` | [candidate head](https://github.com/crauch2088-source/roshan-health-hub/commit/f041ac9fa0e3cb4114346984e3d1393ad972e18f) | Verified from PR #210 body and branch file reads |
| PR state | PR #210 remains the open candidate; body directs Keep Draft | [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) | Verified by open-PR search; Draft instruction recorded in PR body |
| PR base divergence | Requested baseline to candidate: 81 commits ahead / 5 behind; merge base `f8c8b2d1767643561599764405b4cdbfd4db2c79` | [compare view](https://github.com/crauch2088-source/roshan-health-hub/compare/79d81f08f6567f5145f7143e3bf5afdd6e93bf59...feat/medicine-catalogue-identity-rebased-20261109) | Verified |
| Exact-head CI | Run `43646371012`: 19 successful jobs, one intentional skip, zero failures, as recorded in PR body; Vercel status success | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43646371012) | Exact head `f041ac9` per PR metadata; CI evidence verified from recorded run/status |
| Later predecessor evidence | Run `43761411536` belongs to commit `e53216a826474e3ae865ab9faeeab99926e0614f`, not the current PR head `f041ac9` | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43761411536) | Verified; **not counted** as current-head validation |
| Review state | One COMMENTED review by repository owner; zero inline review threads. It is not an independent review. | PR #210 review list / [PR #210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) | Verified |
| Migration/environment | Phase 60 is a candidate SQL migration. PR body states it has not been applied to hosted QA or Production. | Candidate SQL header and PR #210 body | Verified from repository evidence; no live DB access performed in this session |

The candidate is not a linear child of the requested baseline. The merge base is `f8c8b2d...`; the requested baseline is five commits ahead of the candidate branch. This matters for integration and exact-head claims. The 7-workflow run `43761411536` for `e53216a...` is predecessor evidence and must not be substituted for the current candidate head's CI.

## 4. Work actually performed

Read-only inspection of the following candidate files:

- `db/roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql`
- `db/tests/phase60_medicine_catalogue_authority_integration.sql`
- `src/lib/medicine-catalogue.ts`
- `src/routes/_authenticated/inventory.tsx`
- `tests/medicine-catalogue.test.ts`
- `tests/inventory-receive-rpc.test.ts`
- `docs/DRUG_REFERENCES_SIMPLE_MODEL_2026-11-03.md`
- `docs/PHASE56_CATALOGUE_IDENTITY_EDIT_2026-11-04.md`

Reviewed PR #210's description, current candidate head, commit comparison, review submission and inline-thread state, and the exact-head CI record. No code, test, migration, shared project document or other window's report was changed.

Important implementation observations:

1. Phase 60 adds `pharmacy.catalogue_identity.update` for the `admin` and `pharmacist` roles; the established `app_has_perm()` Super Admin bypass remains.
2. It replaces the medicine UPDATE policy, revokes table-wide UPDATE from authenticated, and grants UPDATE only on `name, generic_name, brand_name, strength, dosage_form`.
3. It adds an RLS-protected `medicine_pack_verifications` table, server-side identity snapshot and SHA-256 fingerprint, insert audit trigger, and UPDATE/DELETE/TRUNCATE rejection triggers.
4. `verify_medicine_physical_pack(uuid)` checks permission and completeness of generic name, strength and dosage form, locks the selected medicine row FOR SHARE, and writes the snapshot. It does not accept or verify a photo, barcode, manufacturer label, lot or expiry evidence.
5. The UI helper treats `pharmacist` and `super_admin` as pack verifiers. This matches the explicitly owner-approved Super Admin bypass described in the PR body, but it means the capability is not strictly pharmacist-exclusive.
6. The catalogue helper trims the required strings and constructs a display name. It does not create a canonical product key, normalize equivalent strengths/forms, or detect duplicate products.
7. The insert/update TypeScript contracts keep stock, unit and prices out of the identity-only update payload. The SQL does not provide a pack-size or unit-conversion model.
8. The inventory receive UI takes a medicine ID and a quantity, with integer step 1; the inspected code does not define a conversion between purchased pack, stock unit and dispensing unit.

## 5. Findings

### F-01 — No database-enforced duplicate product identity policy

- Severity: **High**
- Status: **Verified — candidate-only**
- Affected file/function/SQL object: `src/lib/medicine-catalogue.ts`; `public.medicines`; Phase 60 migration.
- Evidence and exact source/commit: Candidate helper validates required text fields and generates a display name, but contains no canonical identity key or duplicate lookup. Phase 60 SQL adds no unique index/constraint or race-safe insert guard for medicine identity. The tests cover required fields and output shape, not equivalent-product collisions.
- Reproduction or test: Static source/test inspection. Example equivalent spellings such as `500 mg` vs `500mg`, case/whitespace variants, and dosage-form synonyms are not reconciled by this helper or migration.
- Impact: Duplicate catalogue rows can split batch history, inventory, pricing, dispensing selection and FEFO stock across multiple medicine IDs. A naïve unique key on generic/strength/form alone would also incorrectly collapse different manufacturers, brands, salts or release types.
- Recommended correction: Define a canonicalization and duplicate-review policy before adding a safe database constraint/guard. Model ingredient composition/salt, strength quantity + unit, dosage form/release characteristics, route where clinically relevant, and manufacturer/product identity distinctly. Do not auto-merge existing rows.
- Required regression test: Concurrent duplicate creation; case/whitespace and unit-equivalent strengths; different manufacturers; combination products; SR/XR variants; and explicit reviewer resolution of near-duplicates.
- Dependency / owner: Window 03 / pharmacy catalogue owner; coordinate product model before any pack conversion work.

### F-02 — Identity can be changed after stock or batch history exists

- Severity: **High**
- Status: **Verified — candidate-only**
- Affected file/function/SQL object: `public.medicines` UPDATE policy and column grants in `db/roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql`; `pharmacy_inventory.medicine_id` references.
- Evidence and exact source/commit: The replacement policy permits identity-column UPDATE on any active medicine row for an identity editor. No condition checks existing stock, batches, dispensing records or invoices; no immutable product revision/replacement workflow is added. The five editable columns include generic name, brand, strength and dosage form.
- Reproduction or test: Static SQL inspection. An authorized identity editor can change the identity of a medicine row that already has historical batches; the referenced medicine ID remains the same.
- Impact: Existing batches and downstream records may become associated with a different clinical/commercial identity in current joined views. A correction typo and a substantive product substitution are not equivalent operations. This can mislead receiving, dispensing, stock review and audit users even though quantity and batch rows are not directly edited.
- Recommended correction: Permit safe display-name correction under a documented rule, but block or escalate substantive identity changes once stock/batch/dispense history exists. Use a new product identity plus explicit supersession/alias linkage for a true product change. Preserve immutable identity snapshots in historical transaction records.
- Required regression test: Attempt each identity-field mutation before stock, with positive stock, with zero stock but historical batches, after dispense, and after invoice; assert the permitted/rejected behavior and preserved history.
- Dependency / owner: Window 03 / pharmacy owner; coordinate with prescription/dispensing windows before schema changes.

### F-03 — Pack identity and conversion are not modelled

- Severity: **High**
- Status: **Verified — candidate-only**
- Affected file/function/SQL object: `medicines.unit`; `MedicineCatalogueDraft`; inventory receive UI and batch quantity path.
- Evidence and exact source/commit: `unit` remains free text and is intentionally excluded from the identity-update payload. No pack-size, base-unit, purchase-unit, dispensing-unit or conversion-ratio fields/table/function are added. Receive quantity is captured as an integer without a defined pack-to-unit multiplier.
- Reproduction or test: Static inspection of catalogue helper, SQL migration and inventory route. No tests cover carton/strip/tablet, bottle/mL or vial/dose conversions.
- Impact: A number entered as packs can be interpreted as dispensing units, producing incorrect stock balances, dispense quantities, cost per unit and invoice quantities. This is a gap in the current model, not evidence that Phase 60 itself has changed existing conversion behavior.
- Recommended correction: Keep the pack-to-base-unit model as a separately reviewed workstream. Define immutable product-pack identities and explicit positive rational/integer conversion ratios, with a canonical dispensing unit. Do not infer conversion from display name or free-text `unit`.
- Required regression test: Multi-level pack conversion, liquid concentration/volume, fractional dose vs inventory unit, rounding, return/reversal, FEFO consumption and invoice amount consistency.
- Dependency / owner: Window 03 specification, then pharmacy inventory/dispensing owner; no scope expansion inside Phase 60.

### F-04 — Attestation is a saved-identity acknowledgement, not physical pack evidence

- Severity: **Medium**
- Status: **Verified — candidate-only**
- Affected file/function/SQL object: `verify_medicine_physical_pack(uuid)`; `medicine_pack_verifications`; UI role helper and labels.
- Evidence and exact source/commit: The RPC receives only a medicine UUID. It snapshots five saved database fields and hashes the JSON. It does not receive a barcode, image, manufacturer, lot, expiry or evidence reference. The PR body accurately discloses this limitation. The Super Admin exception is explicitly owner-approved and reflected in the helper, although the SQL comment “pharmacist duty” can be read as stricter than the effective policy.
- Reproduction or test: Direct inspection of RPC signature/body and `isMedicinePackVerifierRole()`.
- Impact: Users may over-interpret “physical pack verification” as evidence that the physical package was checked against the product, label, barcode, lot or regulatory registration. Super Admin can create an attestation via the established permission bypass; this is intentional but must not be described as pharmacist-exclusive.
- Recommended correction: Use precise UI/API wording such as “record review of saved medicine identity” unless actual evidence capture is implemented. Document the Super Admin exception consistently in SQL comments, UI and role matrix. If physical verification is required, define evidence fields and workflow separately.
- Required regression test: RPC direct-call authorization for pharmacist, Admin, legacy Admin, Doctor and Super Admin; append-only guarantees; identity change after attestation; and UI wording/role consistency.
- Dependency / owner: Pharmacy governance / security reviewer.

### F-05 — Historical prescription/receipt rendering after identity edits is not proven

- Severity: **Medium**
- Status: **Not established / verification gap**
- Affected file/function/SQL object: Prescription items, dispense records, invoice items and medicine-name joins/renderers.
- Evidence and exact source/commit: Phase 60 permits changing `medicines.name` and other identity fields. The inspected PR does not add tests demonstrating whether old prescription/receipt outputs use immutable name snapshots or live joins to the medicine catalogue. No prescription/receipt rendering contract was proven by the available PR tests.
- Reproduction or test: Not run; no authenticated application test or historical-record fixture was executed in this review.
- Impact: If historical outputs resolve the current medicine name dynamically, an identity correction can rewrite the apparent product name on old prescriptions/receipts. If they store immutable snapshots, that risk is reduced. Current evidence does not settle which behavior applies to every output.
- Recommended correction: Trace all historical render paths and define immutable snapshot semantics for prescribed/dispensed/invoiced identity. Do not mutate existing prescription or invoice history as part of catalogue correction.
- Required regression test: Create synthetic prescription, dispense and invoice records; change catalogue display name; re-open/reprint all historical artifacts and assert the expected immutable name and product identifier.
- Dependency / owner: Window 01/04 for printing/receipts, coordinated by Window 03 for catalogue semantics.

### F-06 — Exact-head CI and independent review must not be conflated

- Severity: **Medium**
- Status: **Verified**
- Affected file/function/SQL object: PR #210 branch history and workflow evidence.
- Evidence and exact source/commit: Current candidate head is `f041ac9...`; its PR body identifies run `43646371012` as exact-head CI. The separate run `43761411536` is for `e53216a...`, not the current head. The PR has one owner-authored COMMENTED review and zero inline threads; this is not an independent security review. The PostgreSQL 17 Phase 60 job in the exact-head run completed successfully.
- Reproduction or test: Compared the exact PR head and commit workflow metadata; inspected job results and review list.
- Impact: Predecessor CI or an owner-authored review cannot be represented as fresh independent approval of the current candidate.
- Recommended correction: After candidate changes/reconciliation, run one coherent exact-head CI pass and obtain an independent SQL/security review. Keep Draft until that and authenticated pharmacist acceptance are complete.
- Required regression test: Exact-head workflow including PostgreSQL 17 Phase 60 role/RLS/ACL/append-only assertions, plus any new tests required by F-01 through F-05.
- Dependency / owner: PR author and independent security reviewer.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result: PASS / FAIL / SKIP / NOT RUN / BLOCKED | Notes |
|---|---|---|---|
| Exact candidate CI | [43646371012](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43646371012) | **PASS** (19 jobs); **SKIP** (1 intentional) | Recorded against current candidate head `f041ac9...`; no failures reported. The skipped canonical baseline/authenticated clinical acceptance job is not a pass. |
| Phase 60 PostgreSQL 17 integration | Job in run `43646371012`: “Shared medicine catalogue authority and pack attestation (PostgreSQL 17)” | **PASS** | Disposable v112 baseline and role fixtures; Phase 60 assertions passed. |
| CI run for predecessor `e53216a...` | [43761411536](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43761411536) | **PASS** — predecessor only | Seven PR-triggered workflows succeeded; not current-head evidence and not counted as current validation. |
| Catalogue unit tests | `tests/medicine-catalogue.test.ts` | **NOT RUN** in this review | Source inspected; existing exact-head CI is the available execution evidence. |
| Inventory receive tests | `tests/inventory-receive-rpc.test.ts` | **NOT RUN** in this review | Source inspected; no local test command executed. |
| Historical prescription/receipt rendering | No exact command/run available | **NOT RUN** | Required regression remains open. |
| Duplicate/normalization/pack conversion tests | No current suite | **NOT RUN / NOT PRESENT** | Material coverage gap. |
| Hosted QA/Production migration rehearsal | None | **NOT RUN** | Explicitly outside scope; no hosted database connection/write performed. |

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-01/window-03.md` | This isolated review report; no application code changed | To be filled after report commit |

- Branch: `docs/window-03-round-01-report-20261116`
- Commit(s): 5451ed33f3f1979be3c32b4206c729f6e2ff20d7
- PR: Documentation-only report PR; to be filled after creation.
- Report file path: `docs/parallel-reports/round-01/window-03.md`
- Report commit SHA: 5451ed33f3f1979be3c32b4206c729f6e2ff20d7
- Was the report committed with the implementation or through a separate docs-only PR? **Separate docs-only PR**, because the original task is review-only and PR #210 was not modified.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Secret or credential changes: **No**
- PR merge / issue closure / release approval: **No**
- PR #210 source, tests or review state modified: **No**
- Other windows' report files or shared continuation protocol modified: **No**

## 9. Risks, dependencies, and owner decisions

1. **High — duplicate product identity:** decide the canonical identity dimensions and manufacturer/brand relationship before adding uniqueness or automated matching.
2. **High — post-stock identity mutation:** decide whether material identity edits are blocked after batches/dispensing, or require a replacement product plus supersession mapping.
3. **High — pack conversion:** separate design required for pack SKU, base stock unit, dispensing unit, conversion ratios and cost/price semantics. Do not infer it in Phase 60.
4. **Medium — attestation wording:** owner-approved Super Admin exception is intentional; ensure the capability is not labelled pharmacist-exclusive and not represented as barcode/regulatory verification.
5. **Medium — historical snapshots:** prescription, dispense, receipt and invoice display semantics require focused synthetic regression evidence.
6. **Integration dependency:** PR #210 is 81 commits ahead and 5 behind the requested current-main baseline. Reconcile current main in the existing candidate branch using the repository's normal history-preserving process; do not create a duplicate implementation or silently discard mainline changes.
7. **Acceptance dependency:** independent SQL/security review and authenticated pharmacist workflow acceptance remain outstanding.

## 10. Next action

**Window 03 / PR owner:** reconcile the existing PR #210 branch with current `main` without force-pushing, then implement and test the narrow high-priority identity-safety gate: prevent substantive identity changes on medicines with stock/batch/dispense history (or route them through a new product identity/supersession workflow). Include duplicate detection only after the canonical identity policy is agreed. Run focused PostgreSQL 17 regressions and one exact-head CI pass; obtain independent SQL review before changing the merge recommendation. Keep pack conversion as a separately scoped specification.

## 11. Session closeout

- Work completed in this session: Adopted the parallel continuation protocol; rechecked current main, PR #210 head/base comparison, review state and exact-head CI; inspected Phase 60 SQL, role helper, catalogue contracts/tests and inventory receive path; published this report through a separate documentation-only PR.
- Work not completed: No candidate code/test fix, no duplicate policy implementation, no historical-output execution, no pack conversion implementation, no independent security approval or pharmacist acceptance.
- Exact current state at close: Main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; PR #210 candidate head `f041ac9fa0e3cb4114346984e3d1393ad972e18f`; PR remains a Draft candidate with material findings.
- Recommended continuation when the owner says **"أكمل"**: Recheck main and PR #210 head, review threads and CI; resume with the post-stock identity-change safety design and regression tests. Do not repeat the completed read-only review or overwrite this Round 01 report.
