# Implementation Plan: Clinical Document Printing

**Branch**: `001-clinical-document-printing` | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Phase 53 in `docs/MASTER_PLAN.md`, refined by source inspection in [research.md](./research.md).

## Summary

Deliver a safe, browser-native, one-record-at-a-time print experience for persisted receipts, invoices, saved prescription orders, and medical certificates. Reuse existing React routes, Supabase read models, settings, permissions, and print CSS. Do not introduce a PDF service, database migration, new dependency, or public verification endpoint in the initial slice. Close the known certificate print-scope and invoice page-isolation gaps, reconcile clinic identity setting keys, and establish verified receipt/prescription read models before enabling those document types.

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

- Clinical safety/data fidelity: PASS, provided prescription output is exact-source-only and is never represented as digitally signed.
- Patient privacy/least privilege: CONDITIONAL PASS; verify role assignment and cross-branch journeys before release.
- Database/accounting/inventory integrity: PASS; print layer is read-only and receipt fields are ledger-derived through the Phase54C receipt-status RPC.
- Migration/production safety: CONDITIONAL PASS; Phase54C is QA-only and cannot be promoted to Production before encrypted backup/restore.
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
6. Receipt view models derive posted amount, method, cashier, received timestamp, invoice reference/balance, and reversal state from persisted payment/ledger records. The Phase54C receipt-status RPC is mandatory for ledger integrity; Production receipt printing stays feature-gated until that RPC is deployed there.
7. Prescription view models preserve exact persisted medication names and instructions, show the persisted author and status, and do not claim a digital signature. Incomplete required fields disable official printing and explain what is missing without supplying a value.
8. Clinic identity is read through one canonical settings mapping with Arabic and English names, contact/address, and footer. The existing `center_*` versus `clinic_*` key mismatch is resolved before any template uses it.

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
- Use `get_invoice_payment_receipt_status(uuid[])` for ledger found/match/reversal checks; do not approximate this client-side.
- Add a receipt view model and receipt surface sourced only from a persisted payment.
- Provide receipt action from a persisted payment row; no action on the unsaved payment form.
- Test partial payments, reversals, retries, branch isolation, and exact ledger fidelity.
- **Production release dependency:** Phase54C must be applied to Production only after backup/restore evidence passes.

### Slice C — saved prescription order print
- Use the persisted prescription and child-item contract with existing `emr.read` / `pharmacy.read` RLS.
- Add a read-only prescription print view model from saved records.
- Display persisted author attribution and workflow status. Do not call the document digitally signed; the current schema has no signature/approval field.
- Block official printing when required saved medication instructions are missing; preserve all saved strings and quantities verbatim.

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

- **G0 — source contracts**: QA schema/RLS/permission review is complete for the source tables and receipt-status RPC. Verify role assignment and full authorized/cross-branch E2E before release.
- **G1 — identity**: canonical settings keys are identified (`center_name`, `center_name_ar`, `phone`, `address`, `invoice_footer`); verify logo and branch/global behavior, then test.
- **G2 — prescription lifecycle**: no digital signature/approval fields exist in the current schema. Treat the record as a saved prescription order with author attribution; do not claim a signature.
- **G3 — printer validation**: browser and printer model unknown; thermal formats remain opt-in until physical tests pass.
- **G4 — verification QR**: excluded from v1; separate design/review required if owner later requests it.
- **G5 — release**: all tests pass on exact PR head; Phase54C is deployed to Production only after encrypted backup/restore; manual clinical/finance acceptance is completed before release.

## Constitution re-check

No new service, dependency, database object, or broad permission is justified. The design remains presentation-only, source-bound, branch-aware, test-first, bilingual, and mobile-first. Production receipt output is explicitly blocked until the receipt ledger-integrity contract is available there.
