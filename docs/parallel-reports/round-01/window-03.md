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
| `docs/parallel-reports/round-01/window-03.md` | This isolated review report; no application code changed | `5451ed33f3f1979be3c32b4206c729f6e2ff20d7` (initial content commit) |

- Branch: `docs/window-03-round-01-report-20261116`
- Commit(s): `5451ed33f3f1979be3c32b4206c729f6e2ff20d7` (initial report creation), `de495bd1ad3fa5ab6fdf95bdfaf626bbbeb7eca9` (metadata update)
- PR: [#263 — Window 03 Round 01 medicine catalogue report](https://github.com/crauch2088-source/roshan-health-hub/pull/263)
- Report file path: `docs/parallel-reports/round-01/window-03.md`
- Report commit SHA: `5451ed33f3f1979be3c32b4206c729f6e2ff20d7` (initial report-content commit; subsequent report-only metadata commits are visible in PR history)
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


---

## Continuation addendum — 2026-11-16 (current-head recheck)

This addendum supersedes only the stale candidate-head/CI statements above; the original review findings and historical record are preserved.

### Current repository and PR state

- **Main:** 79d81f08f6567f5145f7143e3bf5afdd6e93bf59, rechecked from the live main ref.
- **PR #210:** Open, Draft, GitHub reports mergeable; base f8c8b2d1767643561599764405b4cdbfd4db2c79; current head e53216a826474e3ae865ab9faeeab99926e0614f.
- **Comparison:** current main → candidate is **81 commits ahead / 5 behind**, with merge base f8c8b2d1767643561599764405b4cdbfd4db2c79. The candidate remains diverged from current main.
- **PR #210 review state:** one owner-authored COMMENTED review, zero inline review threads. This is not independent SQL/security approval.
- **Role-policy clarification:** the PR's latest execution note explicitly records the Super Admin pack-attestation bypass as owner-approved and reflected in UI/PG17 assertions. Treat this as an intentional exception, not an unresolved exploit finding; do not describe verification as pharmacist-exclusive.
- **Round 01 report:** PR [#263](https://github.com/crauch2088-source/roshan-health-hub/pull/263) remains open Draft; this addendum is appended to the same Window 03 file. No other window's report was edited.

### Exact-head validation correction

The current PR #210 head is now e53216a...; therefore workflow run [43761411536](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43761411536), which was predecessor evidence when Round 01 was first written, is **now exact-current-head evidence**.

- All 7 PR-triggered workflows completed successfully on e53216a...; the main CI run reports 19 successful jobs and one intentional skip, with zero failures.
- The dedicated **Shared medicine catalogue authority and pack attestation (PostgreSQL 17)** job passed: it replayed the disposable v112 baseline, applied Phase 60 only in the CI database, and passed role/RLS/append-only assertions.
- The canonical PG17 baseline replay/authenticated clinical acceptance job was intentionally skipped. This is not authenticated browser or pharmacist acceptance.
- The Vercel status on this commit is success; no deployment promotion is claimed.
- This corrects the time-relative statement in §5/§6 above: the run was not exact-head evidence for f041ac9... at that earlier checkpoint, but it is exact-head evidence now because the PR head advanced to e53216a....

### Additional verified findings

#### F-07 — Historical prescription views prefer mutable catalogue names over the saved prescription snapshot

- Severity: **High**
- Status: **Verified — current mainline display behavior; the Phase 60 edit makes the consequence directly reachable**
- Affected paths:
  - db/roshan_phase7_atomic_prescription.sql
  - src/routes/_authenticated/patients_.$patientId.tsx
  - src/routes/_authenticated/pharmacy.tsx
- Evidence:
  - The current prescription RPC reads the selected medicine's name and persists it in prescription_items.medication_name at prescription creation time.
  - The patient history query selects prescription_items(id, dosage, medicines(name)), omits medication_name, and renders the related live medicines.name.
  - The pharmacy query selects both medication_name and medicines(name), but its display expression prefers medicines.name and only falls back to the saved medication_name.
- Impact: after a catalogue display-name correction, historical patient prescription history and pharmacy prescription views can show the new catalogue name instead of the name saved with the original prescription. This is a display-integrity defect; it does not prove that the stored prescription row itself was mutated.
- Recommended correction: treat prescription_items.medication_name as the historical display snapshot for an already-issued prescription. Select and render that snapshot first in historical views; expose current catalogue identity separately only where operationally needed.
- Required regression: create a synthetic linked prescription with a saved medication-name snapshot, change the catalogue medicines.name, and assert that patient history, pharmacy history, and any reprint continue to show the saved prescription name. Also test a null/legacy snapshot fallback explicitly.
- Dependency: Window 01 owns prescription printing; Window 03 owns catalogue identity semantics. Coordinate rather than editing Window 01 files from this window.

#### F-08 — Candidate identity mutation is not blocked after stock, batches, or prescription history exist

- Severity: **High**
- Status: **Verified — candidate-only**
- Affected paths: db/roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql; src/routes/_authenticated/inventory.tsx.
- Evidence:
  - Phase 60 grants direct UPDATE on name, generic_name, brand_name, strength, and dosage_form, but adds no trigger/RPC guard based on stock_quantity, pharmacy_inventory, stock_movements, prescription_items, or invoice history.
  - The candidate UI mutation performs .update(result.data).eq("id", vars.id).is("deleted_at", null) after a permission check; it does not inspect stock, batches, or linked history.
- Impact: a correction that changes strength, dosage form, or generic identity can redefine the medicine row referenced by existing batches and prescriptions without changing their foreign keys. Existing operational rows and historical displays may then appear to refer to a different product.
- Recommended correction: distinguish a harmless display-label correction from a substantive product-identity change. Once stock or clinical/financial history exists, block substantive identity mutation and require a new medicine identity with an explicit supersession/retirement relationship. Do not alter old stock, batches, prescriptions, or invoices.
- Required regression: test a zero-history medicine, a medicine with on-hand stock, a medicine with historical batches but zero current stock, a medicine linked to prescription items, and a medicine linked to invoice/dispense history. Only the explicitly allowed correction class should remain editable.
- Dependency: Window 03 / pharmacy product governance. The implementation is outside this review-only task's authorization.

#### F-09 — No duplicate-product guard or canonical identity key

- Severity: **High**
- Status: **Verified — candidate-only**
- Affected paths: src/lib/medicine-catalogue.ts; db/roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql; tests/medicine-catalogue.test.ts.
- Evidence: the candidate helper trims the generic name, strength, brand and dosage form and builds a display name. It performs no duplicate lookup or canonical-key construction. Phase 60 adds no database uniqueness constraint or race-safe duplicate guard. The tests cover required fields, output shape and search-filter escaping, but not duplicate identity.
- Impact: equivalent products can be created as separate catalogue rows, splitting stock, batches, prices, FEFO selection and dispense choice. A naïve key of generic + strength + dosage form would itself be unsafe because salt/composition, route, concentration, release characteristics, manufacturer and brand can distinguish products.
- Recommended correction: define a canonical product-identity policy first, then enforce the agreed duplicate semantics atomically at the database boundary. Do not add a simplistic unique constraint.
- Required regression: normalization equivalence tests, legitimate distinct-product tests (including salt/release/manufacturer differences), and concurrent duplicate-create tests in disposable PostgreSQL 17.
- Dependency: owner/pharmacy governance decision on canonical identity dimensions.

#### F-10 — Pack-to-unit conversion remains unmodelled

- Severity: **Medium**
- Status: **Verified — candidate limitation**
- Affected paths: public.medicines.unit; inventory receive flow; Phase 60 candidate schema.
- Evidence: unit remains free text; no pack SKU, pack quantity, base stock unit, dispensing unit, conversion ratio or conversion-history model is added. The attestation event does not provide conversion evidence.
- Impact: a carton/strip/tablet relationship cannot be represented safely or converted deterministically for receiving, stock, dispensing and cost calculations.
- Recommended correction: keep commercial pack identity and pack-to-base-unit conversion in a separate specification/workstream. Require explicit units and exact positive integer/decimal conversion semantics as clinically and commercially appropriate; never infer from display names or free-text unit.
- Required regression: one-to-many pack conversion, invalid/zero ratios, fractional stock constraints, historical conversion changes, and purchase/dispense reconciliation.
- Dependency: separate product/pack specification and pharmacy owner decision.

### Updated verdict and scope boundary

- PR #210 remains **CHANGES REQUIRED / Keep Draft**.
- Exact-head CI is now green on the current candidate, including the Phase 60 PostgreSQL 17 integration. This does not resolve F-07 through F-10 or replace independent review and pharmacist acceptance.
- The original Window 03 task is review-only. No implementation branch or code change was authorized in this continuation. The post-stock guard and historical snapshot correction should be delivered only under a separately authorized implementation task, with Window 01 owning its printing surface.
- No local tests were executed by this reviewer; CI results above are GitHub workflow evidence. No hosted database query/write or migration was performed.

### Updated next action

**Window 03 / owner-coordinator:** authorize a separate implementation task for (1) snapshot-first historical prescription display and (2) a database-enforced prohibition on substantive identity changes after stock or linked history exists. Agree canonical duplicate identity dimensions before adding any uniqueness policy. Keep pack conversion separate. Until those changes and independent SQL/security review are complete, retain **CHANGES REQUIRED** for PR #210.

---

## Continuation addendum 2 — 2026-11-16 (protocol and call-site verification)

### Continuation protocol and template actually read

- Read docs/PARALLEL_ENGINEERING_CONTINUATION.md from the open Draft PR #261 branch docs/parallel-engineering-continuation-20261116, head ca0a5822f5af1c9c091ef293eb7ee10eeb856d74.
- Read docs/parallel-reports/TEMPLATE.md from that same branch. Both files return 404 on current main because PR #261 has not been merged. The protocol is followed here as the owner explicitly directed, but it must not be described as already merged into main.
- PR #261 is open Draft. The protocol's key rule is that each window's original scope remains unchanged and no continuation implicitly authorizes scope expansion.
- Window 03 original task explicitly excludes implementation changes to PR #210. Therefore this continuation remains review/verification and report-only. The prior question offering implementation was not an authorization to disregard that exclusion; the owner's "أكمل" resumes the assigned task within its original boundary.
- The existing report file follows the 11 required template sections. This addendum preserves the original Round 01 record and does not edit another window's file.

### Current exact evidence rechecked

- Main remains 79d81f08f6567f5145f7143e3bf5afdd6e93bf59.
- PR #210 remains open Draft, current head e53216a826474e3ae865ab9faeeab99926e0614f, base SHA f8c8b2d1767643561599764405b4cdbfd4db2c79; compare main→candidate remains 81 ahead / 5 behind.
- Exact-head run 43761411536 has **20 jobs: 19 PASS, 1 intentional SKIP, 0 FAIL**. The dedicated Phase 60 PostgreSQL 17 job passed. Six other PR-triggered workflows also completed successfully; the separate canonical PG17 baseline/authenticated clinical acceptance job is the one skipped. Do not call the skipped job a pass.
- Review state remains one owner-authored COMMENTED review and zero inline threads; no independent SQL/security approval is present.
- PR #263 remains open Draft and mergeable. Its current head is c6a4eed11cb8f364e4699bad868c631fde02ce84; compare against main is 5 commits ahead / 0 behind, with exactly one changed file: this window's report.

### F-07 refinement — patient history also drops free-text prescription names

The historical display defect is broader than a renamed catalogue item:

- db/roshan_phase7_atomic_prescription.sql stores the prescribed name in prescription_items.medication_name when creating a catalogue-linked prescription.
- Current main's patient-history query in src/routes/_authenticated/patients_.$patientId.tsx selects prescription_items(id, dosage, medicines(name)) and does not select medication_name.
- The patient-history renderer maps only medicines.name; it never falls back to the saved medication_name.
- Consequently, a catalogue-linked historical prescription can display the current joined medicine name rather than the saved name, and a free-text/external prescription item with no linked medicine_id can display as blank/“—” even though its saved medication_name exists.
- The pharmacy view is not identical: its query selects medication_name, but its linked-medicine display paths prefer medicines.name and fall back to the saved name.
- This is a static source verification; no browser E2E or synthetic DB regression was executed in this review.

Required regression should cover both cases: (a) a linked prescription where medicines.name changes after prescription creation, and (b) a free-text prescription item with medicine_id IS NULL. Patient history must show the immutable medication_name snapshot in both cases. Pharmacy history should use the same snapshot-first rule for already-issued prescriptions.

### F-08 refinement — existing stock guard is real, but does not protect identity fields

- Main already has private.guard_medicine_stock_aggregate() in db/roshan_phase49_atomic_pharmacy_dispense.sql.
- Its trigger is BEFORE INSERT OR UPDATE OF stock_quantity ON public.medicines; it rejects authenticated direct changes to stock_quantity. It does not fire for name, generic_name, brand_name, strength, or dosage_form.
- Phase 60's column-level ACL correctly prevents the identity editor from directly changing price or stock. That protection should be retained.
- The remaining F-08 finding is narrower and still valid: the candidate permits edits to the five identity columns on any active medicine row, without checking whether batches, stock movements, prescription items, dispenses or invoices already reference that medicine.
- No claim is made that Phase 60 bypasses the existing stock-quantity trigger. The concern is semantic re-identification of the medicine row, not direct mutation of stock aggregates.

### Additional scope/decision note

The protocol's Round 01 handoff suggests duplicate identity policy and regression work, but the original Window 03 request is explicitly review-only. The current continuation therefore records precise evidence and required tests without modifying the candidate, creating an implementation branch, or changing source/tests. A separate explicit implementation task is required to lift that exclusion.

### Updated next action

**Window 03 / owner:** retain PR #210 as Draft / CHANGES REQUIRED; request an independently authored SQL/security review and ask the owner to authorize a separate implementation scope if fixes are desired. Within the current review-only task, no further source mutation is permitted. The next verification deliverable is the owner's decision on the canonical medicine identity dimensions and whether historical prescription snapshots are the authoritative display source.

---

## Continuation addendum 3 — 2026-11-16 (latest PR discussion and operational evidence)

### Latest repository state

- PR #210 remains open Draft, head e53216a826474e3ae865ab9faeeab99926e0614f, base main SHA f8c8b2d1767643561599764405b4cdbfd4db2c79, GitHub mergeable=true. The branch is still 81 commits ahead / 5 behind current main. Mergeable=true is GitHub's mergeability calculation, not an approval to merge.
- PR #263 remains open Draft, head 51207783355d48076c062f43e26317eb88b3e9ce, now GitHub mergeable=true. It is 6 commits ahead / 0 behind main and contains exactly one file, the Window 03 report. The previous mergeable=false response was transient; latest response is true.
- PR #263's Vercel check is success. It is documentation-only; this is not an application deployment or production promotion.
- PR #261 (continuation protocol) remains open Draft and unmerged. The protocol and template remain available on its branch, not on main.

### Newly recorded operational evidence from PR #210 discussion

- A read-only Production catalogue query reported 9 medicine rows, with all 9 missing at least one of brand_name, strength, or dosage_form. QA reported 0 medicine rows at the time of that check.
- This demonstrates an operational data-completeness problem relevant to the identity editor, but it does not establish any physical product's actual formulation, route, concentration, manufacturer, or pack size.
- No backfill or catalogue correction is authorized by that evidence. Do not infer missing medicine attributes from names, stock units, or common formulations.
- The PR discussion also records a prior rollback-only QA smoke in which direct authenticated updates to medicines.selling_price were permitted for pharmacist and Admin under the broad pharmacy.update policy; the synthetic transaction was rolled back and no synthetic records remained. The same discussion reports that the stock_quantity trigger rejected direct stock changes. Phase 60's column-level UPDATE restriction addresses the demonstrated broad price-field exposure while preserving the existing stock guard.
- These are statements in the PR discussion/owner execution notes, not independently reproduced by this reviewer in the current continuation. Label them as reported evidence, not as fresh tests run in this session.

### Review independence and attestation wording

- PR #210's visible discussion contains owner-authored implementation notes and self-described independent-review findings, but the GitHub review state still has one owner-authored COMMENTED review and zero inline threads. No separately attributable second-person SQL/security approval has been verified.
- The pack attestation remains an immutable actor/time/identity snapshot of the saved database identity. It is not proof that the physical package was correctly identified; the owner discussion itself says the current Production catalogue has incomplete identity fields and that missing attributes must not be guessed.
- Keep the release gate explicit: actual pharmacist inspection/acceptance of physical packs in authenticated QA is still required. Do not substitute passing CI or a successful Vercel preview for that acceptance.

### Updated disposition

- **PR #210:** retain Draft / CHANGES REQUIRED pending independently attributable SQL/security review, source/ledger reconciliation, and authenticated pharmacist acceptance. The reported 9/9 incomplete Production catalogue rows should be handled as a controlled, source-verified catalogue remediation task; no bulk inference or write was performed.
- **PR #263:** documentation PR remains safe to review as a one-file report change. Do not merge it automatically; owner controls merge authorization.
- No implementation files, tests, hosted database, permissions, catalogue rows, deployments, or role mappings were changed in this continuation.
