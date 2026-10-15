# Initial P0 UX and Workflow Audit Findings

**Audit date:** 2026-10-15  
**Scope:** static code review of selected production-branch source files; no authenticated runtime usability session has yet been completed.  
**Important:** findings below distinguish confirmed code behavior from risks that still need runtime/schema verification. This is not a full audit of every screen.

## F-001 — Lab result completion performs multiple client-side writes

- **Surface:** `src/routes/_authenticated/lab_.$orderId.tsx` — result save/complete and verification.
- **Evidence:** lines 210–216 insert/update each `lab_results` record and check that write; lines 219–226 update `lab_order_items` status but do not inspect the returned error; lines 229–236 update `lab_orders` status but do not inspect the returned error. Verification similarly updates result verification fields at lines 253–264 and then the order status separately at lines 266–271.
- **Confirmed behavior:** the workflow crosses multiple database requests rather than one transaction, and at least two status-update responses are not checked in the save path.
- **Risk:** a result may persist while its item/order status remains stale, or a status transition may partially complete. The user may see a misleading success state unless the shared mutation wrapper or later refetch exposes it.
- **Next validation:** inspect database constraints/triggers and the `useSave` mutation wrapper; simulate failure on each write; check whether partial states are visible and recoverable.
- **Recommendation:** design an atomic server-side operation for result persistence plus lifecycle transitions, with authorization and allowed-state checks inside the database function. Do not ship the client and SQL separately; reconcile the migration workflow first. Add integration tests for rollback and retry/idempotency.

## F-002 — New visit and initial invoice creation are a multi-step client workflow

- **Surface:** `src/routes/_authenticated/visits.tsx` — create visit with consultation fee.
- **Evidence:** lines 214–233 insert the visit; lines 243–262 then create the invoice; lines 263–271 then insert the invoice item. Each is a separate request.
- **Confirmed behavior:** the visit, invoice, and invoice item are created in sequential client-side calls.
- **Risk:** if a later request fails, earlier records may remain, producing a visit without its intended invoice or an invoice without its line item. Whether current DB triggers or cleanup logic mitigate this must be verified.
- **Next validation:** read the full mutation/error cleanup logic and relevant DB triggers/RPCs; force failure after each stage in a test database.
- **Recommendation:** consider one permission-checked, branch-aware, idempotent server-side transaction for visit + fee invoice + invoice line, preserving existing business rules. Test duplicate submissions and retry after network timeout.

## F-003 — Patient chart history queries have inconsistent explicit limits

- **Surface:** `src/routes/_authenticated/patients_.$patientId.tsx`.
- **Evidence:** visits (lines 116–125), labs (127–134), invoices (136–143), and prescriptions (286–295) are ordered but do not specify a page size in the visible query; appointments (145–155), follow-ups (157–165), and claims (168–178) explicitly use `.limit(50)`.
- **Confirmed behavior:** some chart sections are bounded explicitly while other history sections are not.
- **Risk:** large histories may hit server/API row caps, load excessive data, or become slow; incomplete data can look like complete history if pagination/truncation is not surfaced. Actual response limits and data volumes need checking.
- **Recommendation:** use consistent server-side pagination/infinite loading or summary queries; display loading/error/empty states per section; make truncation explicit; avoid loading all history just to render the first chart view. Add >1,000-row tests and query/performance checks.

## F-004 — Patient chart form is reset whenever the loaded record object changes

- **Surface:** `src/routes/_authenticated/patients_.$patientId.tsx`.
- **Evidence:** lines 112–114 call `setForm(record)` in an effect whenever `record` changes; save invalidates patient query keys at lines 312–316.
- **Confirmed behavior:** a new record object from a refetch resets the entire local form state to the fetched record.
- **Risk to validate:** if background refetch or another invalidation occurs while a user has unsaved edits, the draft may be overwritten. Need inspect query defaults and simulate refetch during editing before calling this a user-facing defect.
- **Recommendation:** track dirty state, merge only safe server updates, or ask before discarding dirty edits; preserve entered values after validation/server errors.

## F-005 — Pharmacy queue is capped at 200 records and refreshes periodically

- **Surface:** `src/routes/_authenticated/pharmacy.tsx`.
- **Evidence:** lines 82–97 query prescriptions with `.limit(200)`, filtered by status, and refetch every 20 seconds with previous data retained.
- **Confirmed behavior:** the queue query is explicitly capped at 200 and refreshes on an interval.
- **Risk to validate:** if the queue can exceed 200, older pending prescriptions may not be reachable; while a refetch is pending, the user may still see previous data. The page's search/filter scope and status ordering need review.
- **Recommendation:** server-side pagination and explicit result counts; show refreshing/stale state; add a deterministic queue order and aging indicators; test concurrency when two pharmacists attempt the same prescription. The dispensing RPC is documented in code as atomic and FEFO-aware; preserve that server-side safety boundary.

## F-006 — Dispense action is directly available on pending prescription cards

- **Surface:** `src/routes/_authenticated/pharmacy.tsx`.
- **Evidence:** lines 193–200 render a Dispense button for pending items and call `dispense.mutate` directly; the shared helper calls `fn_dispense_prescription` at `src/lib/pharmacy.ts` lines 123–134.
- **Confirmed behavior:** the button invokes the atomic dispense RPC without an intermediate UI confirmation in this component.
- **Risk to validate:** dispensing may be the intended single-step pharmacist action, so a confirmation dialog could add unnecessary friction. The important question is whether the card clearly exposes the patient, prescription, medicine, quantity, stock/shortage outcomes, and whether the RPC rejects wrong states/duplicate requests.
- **Recommendation:** do not add a confirmation merely for its own sake. Evaluate a clear pre-action summary and a post-action result showing actual batch/legacy quantities, partial fulfillment, and any exception; test stale status and double-submit cases.

## F-007 — Patient picker already has some useful safety-oriented interaction patterns

- **Surface:** `src/components/patient-picker.tsx`.
- **Evidence:** debounced query (lines 53–63), modal popover (82), selected label shows name plus MRN/phone (92–100), loading/empty states (130–151), duplicate-patient hint (137–148), and selection closes/reset search (155–168).
- **Positive behavior:** the picker has disambiguating identifiers, search feedback, a duplicate-creation hint, and explicit mobile/focus handling.
- **Next validation:** verify keyboard navigation and screen-reader announcement, name collisions, patients sharing phone numbers, Arabic/English matching, slow-network behavior, permissions, and the add-new path preserving search context.
- **Recommendation:** retain these useful foundations while measuring the real task; do not replace a functioning pattern without evidence.

## F-008 — Shared Dialog primitive has responsive sizing and an accessible close label

- **Surface:** `src/components/ui/dialog.tsx`.
- **Evidence:** Radix Dialog primitive; responsive viewport-based max height/width and contained scrolling at lines 46–63; close button with visible focus ring and screen-reader label at lines 67–83.
- **Positive behavior:** baseline implementation includes a mature dialog primitive and mobile sizing constraints.
- **Next validation:** test focus entry/return, Escape behavior, nested popovers, keyboard scroll, virtual keyboard, small screens, unsaved work, and any dialogs containing long forms. These behaviors may be provided by Radix; runtime testing is required before concluding otherwise.
- **Recommendation:** audit every call site and choose dialog vs drawer vs full page by task complexity and consequence, rather than replacing the shared primitive wholesale.

## Initial priority recommendation

1. Lab result atomicity/status handling (F-001).
2. Visit + invoice + invoice-item transaction integrity (F-002).
3. Patient chart history pagination and draft preservation (F-003/F-004).
4. Pharmacy queue pagination/stale-state behavior and dispense result feedback (F-005/F-006).
5. Runtime and accessibility validation of the patient picker and shared dialog primitives (F-007/F-008).

## Evidence and limitations

This static review is consistent with the workflow-fit and medication-safety principles in the [AHRQ CDS workflow guidance](https://digital.ahrq.gov/key-topics/clinical-decision-support/clinical-practice-improvement-and-redesign-how-change-workflow-can-be-supported-clinical-decision), the [2025 ONC SAFER Guides](https://healthit.gov/clinical-quality-and-safety/safer-guides/), the [WHO Medication Without Harm policy brief](https://www.who.int/publications/i/item/9789240062764/), and [WCAG 2.2 mobile guidance](https://www.w3.org/TR/wcag2mobile-22/). It does not replace runtime tests, production schema review, or clinical review. No production data/schema changes were made.
