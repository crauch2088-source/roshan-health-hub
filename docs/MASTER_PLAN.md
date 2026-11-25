# Roshan Health Hub — Master Plan

**Status checked:** 2026-11-25. **Release decision: NO-GO for live clinical/financial use.**

This is the single strategic roadmap. GitHub Issues/PRs own individual tasks; PROJECT_STATE.md is the dated evidence snapshot; this file owns sequence and release gates. It replaces the append-only legacy master plan, which is preserved unchanged at `docs/archive/MASTER_PLAN_HISTORY.md`.

## 1. Product and architecture direction

Build one reliable, low-cost, phone-first clinic operating system for patient administration, clinical encounters, laboratory, pharmacy, inventory and finance. Retain the existing React/TypeScript/TanStack + Supabase/PostgreSQL + Vercel architecture.

Use a **modular monolith** with explicit domain boundaries and PostgreSQL transaction/RPC boundaries. Do not split into microservices, introduce event sourcing/CQRS, replace the EMR, or add a new runtime/platform unless a measured requirement proves the benefit. Keep multi-branch isolation at the data and authorization layers; do not expand operational scope until the first branch is accepted.

Clinical content must be governed as versioned, source-backed decision support. The WHO SMART/DAK approach is the preferred content model: workflows, personas, core data elements, terminology, decision-support logic, indicators and functional requirements. This does not mean adopting a new application or rewriting the database as FHIR.

## 2. Current stop-ship findings

### P0 — Pharmacy authorization

- Production `public.atomic_pharmacy_dispense` and the QA counterpart currently require broad permission bits but do not themselves enforce the canonical pharmacist role.
- Production `public.fn_dispense_prescription_with_invoice` checks `pharmacy.update` and `billing.create` but lacks the role boundary present in QA. QA's helper currently allows `pharmacist` and `legacy_pharmacist`; the canonical role policy must be resolved and applied consistently.
- PR #250 is the implementation candidate. Its exact head has passing configured workflows, but there is no independent second-person review and no evidence that the migration was applied to QA or Production.
- Require Doctor/Admin/Super Admin/legacy-role negative tests, no-side-effect assertions before idempotency writes, same-prescription different-key races, final-stock races, branch isolation, invoice atomicity and authenticated pharmacist acceptance.

### P0/P1 — Private helper ACL divergence

- Production `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` have NULL ACLs (PostgreSQL default PUBLIC EXECUTE); QA has owner-only ACLs.
- Track under Issue #218 and candidate PR #260. Verify all callers and schema USAGE before applying a forward-only correction. Do not grant browser roles direct access to private helpers.

### P1 — Migration and release governance

- Production and QA migration ledgers are materially different in count and baseline. Production is at 129 rows; QA is at 30. This is not a simple missing-migration count.
- Reconcile the complete ordered source chain, baseline provenance, already-applied hosted changes and dependencies. Phase 61B is present in QA as version `20261113232719` but the manifest lists `20261114120000` as not applied; Production has no Phase61B row or helper. Resolve this exact source/version mismatch before Phase61C. Never replay blindly, edit migration ledger rows or assume QA can be copied to Production.
- Main branch protection is not currently verified. Issue #253's latest direct evidence (2026-11-15) says protection was disabled; the current API integration returns 403, so recheck with an authorized read path before treating the issue as closed.

### P1 — Recovery and human acceptance

- PR #297 records a successful independent encrypted database restore, checksums, off-site copy/read-back and structural parity. Overall DR remains OPEN pending accepted RPO/RTO/retention/cadence, timed control-plane recovery, Storage/Vault recovery, and independent acceptance.
- Issue #199 remains open. Storage object bytes must be covered before the first real clinical attachment is stored.
- Clinical, pharmacy, laboratory, finance, reception and physical-printer acceptance must be completed by authorized staff. Automated tests cannot substitute for these approvals.

## 3. Execution sequence

### Stage 0 — Repository and evidence hygiene

- Establish one documentation entry point and one current project-state snapshot.
- Preserve legacy plans and reports in archive; remove duplicate active roadmaps and stale root-level status clutter.
- Classify open PRs by current base, code impact, exact-head evidence, dependencies and unique value. Close only superseded report PRs after preserving their findings.
- Reconcile PR #250, #260, #296, #297 and the RHH workstream against current main and hosted state.

### Stage 1 — P0 security and governance

- Complete independent SQL/security review of PR #250 and resolve canonical pharmacist role policy.
- Add missing role gates to every public dispense entry point and prove denied calls create no idempotency, stock, invoice or audit side effects.
- Reconcile Issue #218 / PR #260 helper ACLs and add caller/trigger regression tests.
- Confirm branch protection and required exact-head checks; no self-approval for high-risk SQL/security changes.

### Stage 2 — Pharmacy, inventory and finance integrity

- Reconcile PRs #293 and #294 with #250 and #210; verify dependency order and one coherent migration chain.
- Test cancellation before handover, quarantined returns after handover, immutable compensating movements, FEFO, expiry quarantine, write-offs, price history, idempotency and concurrent final-stock races.
- Reconcile invoice-payment idempotency (#280) with saved receipts (#181), preserving payment identity, exact SDG precision, immutable ledger and reversal rules.

### Stage 3 — Clinical correctness and terminology

- Review pediatric decision support (#292) with clinician-approved source/versioned protocols, weight, concentration, route, maximum dose and unknown-age handling.
- Complete ICD-10 validation (#291) with versioned source and local coding policy; do not auto-select a diagnosis or treatment from a fuzzy match.
- Ensure all clinical decision-support content follows the approval lifecycle in the clinical guideline policy document.

### Stage 4 — End-to-end workflow and device acceptance

- Resolve QA operational blockers (#296) and prove exact role × branch × operation behavior.
- Exercise Reception → GP → Lab → Pharmacy → Finance → Audit using synthetic QA accounts and records only.
- Verify mobile widths, Arabic RTL, English LTR, keyboard/accessibility, print previews and physical A4/thermal/mobile printing.
- Keep health telemetry (#290) PHI-safe and verify that readiness probes do not disclose internal or patient information.

### Stage 5 — Disaster recovery and controlled release

- Close the remaining DR scope in Issue #199 / PR #297, including timed control-plane recovery and an owner-approved policy.
- Verify exact main SHA, CI, deployment source, database migration state, role matrix, backups and recovery immediately before any delegated Production change.
- Promote only the canonical deployment after all stop-ship gates pass. Do not create synthetic Production transactions.
- Owner retains final clinical/staff acceptance and real-world launch decision.

## 4. Non-waivable release gates

1. No unauthorized dispense path; all public RPCs enforce the approved pharmacist role and branch scope.
2. All SECURITY DEFINER routines are reviewed by purpose, ACL, schema exposure, fixed search_path, caller privileges and side effects; advisor counts alone are not a verdict.
3. RLS, grants, branch attribution and private helper ACLs pass positive and negative role tests.
4. Migration provenance and forward-only order are reconciled; no manual ledger repair.
5. Financial and stock operations are atomic, idempotent, immutable/auditable and concurrency-tested.
6. Clinical decision support and ICD-10 rules are approved by a clinician and traceable to source/version.
7. Independent encrypted backup restore and required Storage/Vault/control-plane recovery are proven.
8. Authorized staff acceptance, Arabic/English mobile acceptance and physical printing are complete.
9. Exact-head CI passes; skipped mandatory checks are not passes; branch protection is verified.
10. The owner explicitly accepts the final operational release decision.

## 5. Scope exclusions until the gates close

- No microservices migration, new EMR replacement, full FHIR server, event-sourcing rewrite or new paid platform.
- No production synthetic test data or manual migration-ledger edits.
- No clinical protocol activation based only on a software implementation or web research.
- No agent-specific runtime/CLI integration as a project dependency; use the agent-neutral Spec Kit baseline.
- No optional UX polish ahead of P0 security, pharmacy/inventory correctness, DR and staff acceptance.

## 6. Time and progress accounting

The previously suggested 8–12 day compression is **not approved as a delivery commitment**. It was a planning hypothesis before the second audit exposed additional cross-environment and repository-cleanup work. Re-estimate only after PR deduplication, dependency reconciliation, independent reviews and owner-controlled acceptance tasks are separated. Do not publish a single completion percentage until engineering, clinical, operational and DR gates share one evidence-backed denominator.

## Execution update — 2026-11-25/26

- **Pharmacy authorization:** PR #250 is merged to main at `50c24eabc840c4171f12617a139b57b1ba3375b0` and Vercel Production has a READY deployment from that SHA. QA has Phase 61C applied as `20261125220954`. Production has not received Phase 57 → 57B → current Phase 61 → 61B → 61C. The frontend role guard is not a substitute for the backend migration. Independent second-person SQL/security review and authenticated pharmacist acceptance remain open.
- **Private helper ACL:** the original PR #260 candidate was closed after review found incorrect policy identifiers and missing permission predicates. Corrected PR #300 passed exact-head CI and Phase 55 PostgreSQL 17 tests, then was applied to QA as `20261125225912`. The corrected migration preserves the four live insurance RLS policy names and their `insurance.read` / `insurance.create` gates. Production remains unchanged pending independent review and release gates.
- **No Production database writes** were made in this execution round. The QA change was limited to function ACLs and RLS policy definitions; no business rows were changed.
