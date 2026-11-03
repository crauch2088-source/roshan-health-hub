# Implementation Plan: Clinical Document Printing

**Branch**: `001-clinical-document-printing` | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Phase 53 in `docs/MASTER_PLAN.md`, refined by source inspection in [research.md](./research.md).

## Summary

Deliver a safe, browser-native, one-record-at-a-time print experience for persisted receipts, invoices, prescriptions, and medical certificates. Reuse existing React routes, Supabase read models, settings, permissions, and print CSS. Do not introduce a PDF service, database migration, new dependency, or public verification endpoint in the initial slice. The first implementation must close the known certificate print-scope and invoice page-isolation gaps, reconcile clinic identity setting keys, and establish verified receipt and prescription read models before enabling those document types.

## Technical Context

- **Language/Version**: TypeScript; repository-pinned Node runtime (see `.nvmrc` / package engines).
- **Primary Dependencies**: Existing React, TanStack Router, Tailwind, Supabase client, shadcn/ui; no new runtime dependency planned.
- **Storage**: Existing Supabase PostgreSQL records and `system_settings`; no new tables planned.
- **Testing**: Node test runner, Vitest/Playwright and PostgreSQL 17 integration workflows already present in the repository. Use synthetic fixtures only.
- **Target Platform**: Existing responsive web/PWA, desktop browser print dialog and supported Android browser print flow.
- **Project Type**: Single web application.
- **Performance Goals**: Print preview should be available from already-loaded persisted records without an additional full-table fetch; avoid unbounded queries.
- **Constraints**: Branch-aware RLS; role permission checks; no production data reads in test fixtures; Arabic RTL and English LTR; no inference of missing clinical/financial values; no production DB writes; cost-neutral dependencies.
- **Scale/Scope**: Four document types, one persisted record per print operation, A4 baseline and optional 58/80 mm profiles after physical validation.

## Constitution Check

- Clinical safety/data fidelity: PASS, provided prescription output is exact-source-only and incomplete orders are not represented as complete.
- Patient privacy/least privilege: CONDITIONAL PASS; actual read-model ACL/RLS and role matrix must be verified before implementation.
- Database/accounting/inventory integrity: PASS; print layer is read-only and receipt fields are ledger-derived.
- Migration/production safety: PASS; no migration is planned. Any future schema change requires its own reviewed migration and backup gate.
- Evidence-based/test-first engineering: PASS; tests precede UI changes and use synthetic records.
- Source-of-truth discipline: CONDITIONAL PASS; clinic identity key mismatch must be reconciled against `useSettings()` and settings storage.
- Mobile-first bilingual usability: CONDITIONAL PASS; RTL/LTR and print-width validation required.
- Cost/change efficiency: PASS; use existing browser APIs and avoid new services.

## Architecture and flow

1. A route loads exactly one persisted document through an existing, permission-protected query.
2. The route verifies that the record is not soft-deleted and belongs to the active authorized branch.
3. A shared print surface receives a typed, presentation-only view model. It does not mutate source data or calculate clinical instructions.
4. The print action is exposed only when the record and permission checks succeed.
5. Print CSS hides application chrome and renders only the selected document root.
6. Receipt view models derive posted amount, method, timestamp, cashier, invoice reference/balance, and reversal state from persisted payment/ledger records.
7. Prescription view models preserve exact persisted medication names and instructions. Incomplete required fields disable official printing and explain what is missing without supplying a value.
8. Clinic identity is read through one canonical settings mapping with Arabic and English names, contact/address, and footer. The existing key mismatch is resolved before any template uses it.

## Delivery slices

### Slice A — shared print foundation and existing invoice/certificate correction
- Add a typed shared print-document shell and a strict single-root print boundary.
- Add focused tests proving non-target page content is excluded.
- Correct certificate action to select and print only the chosen persisted certificate.
- Correct invoice print output to include only the invoice document, excluding payment entry/history and unrelated UI.
- Reconcile identity settings keys with the existing settings page contract.
- A4 first; no QR.

### Slice B — posted payment receipt
- Verify payment/invoice/ledger relations, soft-delete/reversal semantics, cashier attribution and permission policy.
- Add a receipt view model and receipt surface sourced only from a persisted payment.
- Provide receipt action from a persisted payment row; no action on the unsaved payment form.
- Test partial payments, reversals, retries, branch isolation, and exact ledger fidelity.

### Slice C — prescription print
- Verify the persisted prescription and child-item contract, branch ownership, soft-delete behavior, and any signed/approved state.
- Add a read-only prescription print view model from saved records.
- Do not treat a draft composer state as an official prescription.
- Block official print when required persisted instructions are missing; never infer them.

### Slice D — print quality and release verification
- Add Arabic/English visual regression fixtures and A4 output checks.
- Add 58/80 mm profiles only after physical printer/browser validation; do not promise them based only on CSS.
- Verify keyboard accessibility, print cancellation, session expiry, and reprint state.
- Update docs and Phase 53 status only after acceptance tests pass.

## Project Structure

```text
src/
  components/
    print/                    # shared print root, document header/footer, typed views
  lib/
    print/                    # pure view-model and completeness helpers
  routes/_authenticated/
    billing_.$invoiceId.tsx   # persisted invoice surface
    certificates.tsx          # selected persisted certificate surface
    ...                       # receipt and prescription entry points after contracts verified
src/styles.css                # print-only layout and page-break rules
tests/
  print/                      # view-model, isolation, and document completeness tests
```

Keep the implementation within existing app structure; do not create a separate package or backend.

## Gates and unresolved decisions

- **G0 — source contracts**: exact QA schema/RLS/permission review complete; no guesses from frontend-only checks.
- **G1 — identity**: canonical settings keys and bilingual fallback behavior agreed and tested.
- **G2 — clinical authorization**: explicit prescription approval/signature semantics verified; if no signature model exists, use existing persisted authorization semantics and label accurately rather than inventing a signature.
- **G3 — printer validation**: browser and printer model known; thermal formats remain opt-in until physical tests pass.
- **G4 — verification QR**: excluded from v1; separate design/review required if owner later requests it.
- **G5 — release**: all tests pass on exact PR head; no production database changes; manual clinical/finance acceptance is completed before release.

## Constitution re-check

No new service, dependency, database object, or broad permission is justified. The design remains presentation-only, source-bound, branch-aware, test-first, bilingual, and mobile-first. Implementation cannot pass G0–G2 by assumption.
