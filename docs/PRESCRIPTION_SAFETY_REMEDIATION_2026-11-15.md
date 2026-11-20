# Prescription safety and print reconciliation — 2026-11-15

**Status:** Draft candidate rebased onto current main in PR #258; source only, not applied to hosted databases.  
**Current main base:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`  
**Latest code/test commit:** `a25680c01ef42f147704cde71daeabb1d226d58b` (parent `b97a6f8dc609973e3a02b715bb2eceb4962de05e`; PR #258)

## 1. Why PR #179 was not merged wholesale

PR #179 had diverged substantially from current main and contained older pharmacy/prescription code that predates the current Phase 61 pharmacist-role and correction-workflow boundaries. The safe prescription-composer, age-validation and print-isolation changes were selectively ported to a fresh current-main branch. The current pharmacy route and role gates were retained; old PR #179 pharmacy code was not overlaid.

PR #255 is closed unmerged. PR #258 is the current replacement candidate, rebased on main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`. PR #179 remains open but stale; do not merge it or close it until PR #258 is accepted and the owner approves supersession.

## 2. Clinical input safety changes

- New prescription drafts start with a blank quantity; no implicit one-unit order is created.
- Selecting a medicine may populate its catalogue dosage form, but it does **not** infer route from dosage form.
- Dose, frequency, duration, dosage form, route and positive whole quantity must be explicitly present before an item can be added/saved.
- Custom text fields are available for dosage form, frequency, duration and route. Dose remains an explicit free-text field including its unit.
- The route selector warns that its generic choices are not checked against the selected product; the prescriber must verify the actual product label.
- Duration shortcuts are data-entry conveniences, not treatment recommendations.
- Quantity parsing rejects scientific notation, fractions, zero, negative values and values outside the RPC integer range.
- Date-only DOB parsing validates the actual calendar date and rejects malformed/future dates. If age cannot be verified, the composer warns the clinician to verify DOB and age-specific precautions.
- Pediatric missing-weight handling remains a warning, not a universal save block. The UI asks the clinician to verify a current visit-linked weight before weight-based dosing. No automated dose calculation, dose/frequency recommendation, route inference or pediatric protocol was added.
- A blanket pediatric hard block is intentionally deferred until the catalogue has a clinically validated medication-specific weight-based classification and an audited exception policy. This avoids blocking non-weight-based medicines or inventing a universal rule.

## 3. Server-side Phase 63 guard

The candidate migration `db/roshan_phase63_prescription_item_completeness_guard.sql` adds a private trigger to `public.prescription_items` before inserts and updates to clinical instruction fields. It requires:
- medication name;
- dose (accepting the legacy `dosage` twin and normalizing the blank twin; if both are non-empty, their trimmed values must match or the write is rejected with SQLSTATE `23514`);
- frequency;
- duration;
- dosage form;
- administration route; and
- a positive whole quantity no greater than the RPC integer limit.

It skips soft-deleted rows so historical incomplete records can be preserved or archived. It does not calculate or infer clinical values. Because the trigger runs at the table boundary, it also protects writes performed by the SECURITY DEFINER prescription RPC, not only the React form. Direct EXECUTE on the trigger function is revoked from API roles.

A dedicated PostgreSQL 17 fixture and regression test cover valid writes, missing fields, invalid quantities, legacy dose/dosage normalization, rejection of conflicting non-empty `dose`/`dosage` values on both INSERT and UPDATE, soft-deleted rows, and trigger-function ACL. Conflicting values fail closed rather than silently choosing one representation.

## 4. Printing changes

- Saved prescription printing builds from one persisted prescription and its saved items, not an unsaved composer draft.
- Official prescription print is blocked when required saved identity/clinical fields are missing, the prescription or patient branch is missing/mismatched against the visit branch, or the persisted status is not exactly `pending` or `dispensed`.
- Invoice printing is target-scoped and blocked for soft-deleted invoice/patient records or a known invoice/patient branch mismatch.
- Certificate printing is target-scoped and blocked for soft-deleted patients or a known certificate/visit/patient branch mismatch.
- Printed documents are copies, not digital signatures or proof of dispensing.

## 5. Exact-head verification

The current rebased candidate is PR [#258](https://github.com/crauch2088-source/roshan-health-hub/pull/258), based on main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`. The behavior/test commit is `a25680c01ef42f147704cde71daeabb1d226d58b`.

- Exact-head CI run [#43818933478](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818933478): completed successfully; 20 jobs, 19 successful and the canonical baseline/authenticated clinical acceptance job intentionally skipped; zero failures.
- The dedicated **Phase 63 prescription item completeness guard (PostgreSQL 17)** job `133137266910` passed, including the new conflicting INSERT/UPDATE regression assertions.
- The same run passed blocking dependency audits, role-guard tests, TypeScript, lint and production build.
- Exact-head check summary: 32 checks, 31 success and one intentional skip; CodeQL run [#43818926213](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818926213) passed JavaScript/TypeScript and Python; Vercel Preview Comments passed.
- The one skipped check is **Canonical PG17 baseline replay and authenticated clinical acceptance**. It remains deferred and is not counted as a pass.
- PR #258 remains Draft. No independent clinical/security review, authenticated QA/mobile print acceptance, physical A4 printer test or staff acceptance is claimed.

The earlier PR #255 head `86134c0df686830db194fa7f29686a90f89f11ca` is historical; use PR #258 and the exact code commit above for current review.

## 6. Release boundary

- Phase 63 remains a source candidate in Draft PR #258; it is not applied to hosted QA or Production.
- No production migration, merge, deployment promotion, patient/clinical/financial data write or stock mutation was performed.
- This is application/database completeness validation, not a clinical protocol approval.
- Any automated dosing engine requires a separate clinician-approved source and validation of age, weight, indication, formulation, route, strength, maximum dose, renal/allergy constraints and explicit prescriber override.
- Operational release still requires authenticated synthetic role/branch E2E, Arabic RTL/English LTR browser review, mobile print preview, physical A4 printer verification and clinic staff acceptance.


## 7. Follow-up review finding — legacy dose twin consistency (2026-11-16)

- A current-main review found that the initial Phase 63 trigger copied a missing dose/dosage twin but accepted conflicting non-empty values. The trigger now rejects mismatches after trimming on INSERT and UPDATE; the PostgreSQL 17 integration test asserts rejection and verifies no persisted side effect.
- This is a data-consistency guard only. It does not select a dose, convert units, recommend treatment, or activate a medication protocol.
- Next: independent clinical/security review of PR #258, followed by a separately approved isolated-QA gate. Do not apply Phase 63 to QA/Production before review and documented acceptance.


## 8. Window 01 Round 02 — age/weight context and instruction continuity (2026-11-17)

**Implementation scope on PR #258; exact-head CI pending at commit time**

- Prescription age context is calculated from the patient's date-only DOB and the encounter's `visits.visit_date` in the clinic timezone `Africa/Khartoum`. This avoids using today's age for a backdated visit and retains day-level age for patients under one year. Missing, malformed, future DOBs and invalid/missing encounter dates fail closed to an unverified-age cue.
- The composer shows only the weight recorded against the current visit, with loading/error/missing states. Pediatric and unknown-age contexts are visible; the weight remains a non-blocking cue. No patient-master or historical weight is substituted.
- No dose calculator, drug-specific regimen template, route inference, frequency recommendation or pediatric protocol was added. Generic frequency and duration choices are explicitly labelled as data-entry shortcuts. No universal duration ceiling was invented.
- Catalogue dosage-form values remain unverified metadata; the composer now tells the prescriber to confirm the exact formulation against the physical pack and manufacturer label. Route remains an explicit choice and is not inferred from dosage form.
- The unsaved prescription summary now shows formulation, route, patient instructions and quantity. The read-only pharmacy queue now displays persisted dosage form, route, dose (with legacy `dosage` fallback), frequency, duration and patient-facing instructions. The correction RPCs, dispense transaction and financial paths were not changed.
- No schema migration, hosted database write, production deployment or real patient/financial data access was performed.

Exact-head tests and CI evidence will be recorded in the Window 01 Round 02 report after the completed change is verified.


## 9. Window 01 Round 02 — exact-head verification and residual gates (2026-11-17)

**Verified code head:** `895c482db3bf7dc14aa8d9b357076e5a50ba7896`  
**Main base:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`  
**Comparison:** 19 commits ahead / 0 behind. PR #258 remains Draft.

### Prescription UX and clinical boundary rechecked

- Encounter age uses the visit date in `Africa/Khartoum`, not the device's current date. Missing, malformed, future or inconsistent dates produce an unverified-age cue. Day-level age is retained below one year.
- The composer displays only the weight linked to the current visit, including loading, unavailable and query-error states. It does not fall back to a patient-master or older-visit weight.
- Pediatric missing-weight handling is deliberately advisory, not a universal save block: the current composer has no structured dose-basis field and cannot distinguish a fixed-dose order from a weight-based order. A blanket block would therefore reject clinically legitimate fixed-dose orders. The UI explicitly tells the prescriber to verify measured current weight before weight-based dosing and to check applicable per-dose/daily ceilings. Any future hard stop must be driven by a structured, audited dose basis and enforced server-side.
- Dose remains clinician-entered free text with a unit cue; no dose presets, dose calculator, diagnosis-based template, or pediatric regimen was introduced in this composer.
- Dosage form and route are explicit fields. Selecting a catalogue item does not infer route. The UI warns that catalogue formulation is not independent proof of product identity/strength and that generic route choices are not checked against the selected product; the exact physical pack and manufacturer label must be verified.
- Frequency and duration shortcuts are labelled as data-entry aids, not recommendations. Custom entry remains available. No universal duration cap was added because acute, chronic, tapering, prophylactic and single-dose courses do not share a safe global maximum.
- Patient instructions are a multiline optional field and are shown in the unsaved summary, pharmacy queue and saved print model. The queue displays the persisted value; it does not generate or rewrite instructions.
- Phase 63 is a completeness/integrity guard only. It requires explicit clinical fields and a positive whole quantity; it does not recommend or calculate a regimen.
- The arithmetic-only calculator and deterministic matcher remain separate from the composer. The kernel does not choose a medicine, indication, route, frequency, duration, concentration or protocol. No protocol is active.

### TDD and exact-head verification

The latest exact code head is `895c482db3bf7dc14aa8d9b357076e5a50ba7896`.

- Prescription atomicity workflow [#44149288200](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288200): **PASS** — focused regression test and PostgreSQL integration.
- Phase 63 PostgreSQL 17 job [#134272837767](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288280): **PASS**.
- Insurance UI validation [#44149288191](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288191): **PASS** — focused regression, TypeScript, lint and production build. This also confirms the follow-up Prettier-only corrections.
- Insurance integrity [#44149288243](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288243), privileged-role guard [#44149288071](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288071), Phase 48 Storage [#44149288265](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288265), finance-only RPC isolation [#44149288323](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288323), and clinical child-RPC-only writes [#44149288338](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288338): **PASS**.
- Main CI [#44149288280](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44149288280): **BLOCKED at the production dependency audit only**. `npm audit --omit=dev --audit-level=moderate` reports 11 high-severity `picomatch` findings (GHSA-fc5q-39xc-vjpf) through the TanStack/Vite dependency chain. The main CI's later typecheck/lint/build steps were skipped after this blocking audit; the separate Insurance UI workflow above ran and passed all three. This PR does not change dependency versions or the lockfile; its `package.json` change only registers the print-model regression test. Do not force a breaking dependency upgrade in this clinical PR; resolve the audit in the dependency workstream.
- Exact-head Vercel Preview status: **success**.
- Canonical baseline replay/authenticated clinical acceptance remains intentionally skipped. No authenticated prescriber/pharmacist E2E, staff UAT, mobile visual review or physical A4/thermal printer acceptance is claimed.

### Release and next-step boundary

- PR #258 remains Draft. Its source/test checks and preview do not authorize merge, QA/Production migration, deployment promotion or real clinical use.
- Keep the medicine-catalogue identity/physical-pack work (PR #210) separate from clinical route approval. Its catalogue fields do not create a verified route-compatibility matrix.
- Before any drug-specific template or decision-support activation: retrieve the applicable current primary Federal/Gezira protocol; verify issuer, edition, approval, jurisdiction, population, setting, relevant sections and redistribution rights; verify the exact product/strength/formulation; create source-linked golden cases; and obtain independent GP and pharmacist approval.
- Keep dose, frequency and duration clinician-entered until those source, product and governance gates are met. No universal duration cap, dose table, interaction rule or pediatric regimen is authorized by this review.
- Next engineering step: resolve the independent dependency-audit blocker separately, then complete independent review of the Phase 63 trigger and the prescription/print candidate. Next acceptance step: authorized Arabic RTL / English LTR mobile review, saved-print preview and physical printer checks, followed by isolated synthetic GP/pharmacist acceptance. No production write is part of that step.
- No QA/Production DDL/DML, migration application, permission/Auth/Storage change, patient/clinical/financial record creation, stock mutation or production deployment was performed in this run.
