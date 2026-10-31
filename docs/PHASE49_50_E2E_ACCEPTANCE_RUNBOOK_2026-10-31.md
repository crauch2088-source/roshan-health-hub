# Roshan Phase 49–50 E2E Acceptance Runbook

**Status:** Prepared; browser/staff execution is pending.
**Environment:** Isolated QA project only — `roshan-health-hub-qa` (`hopfohcnrtbiqjkgeukz`).
**Production policy:** Do not execute these scenarios against production. Use synthetic patients and test accounts only. Never put patient names, phone numbers, medical details, tokens, or passwords in test logs or screenshots.

## Purpose and evidence boundary

The PostgreSQL 17 integration suite validates transaction, RLS, idempotency, FEFO and invoice invariants. This runbook validates the actual browser workflow, role-specific controls, Arabic/English presentation and mobile usability. The repository currently has no Playwright/Cypress dependency, so these browser scenarios are manual acceptance steps; they have not been represented as automated browser E2E or as already executed.

## Test actors and setup

| Actor | Required capabilities | Must not be able to do |
|---|---|---|
| Reception | `queue.read`, `queue.update` | Complete a clinical visit, change clinical note/vitals, create a bill |
| Pharmacist | `pharmacy.read`, `pharmacy.update`, `billing.read`, `billing.create` | Dispense outside assigned branch, edit stock aggregate directly |
| GP / clinician | `visits.read`, `visits.update`, `visits.create`, `queue.read`, `queue.update` | Bypass branch checks or create duplicate consultation charges |
| Super Admin | Approved administrative permissions | Use an unassigned branch implicitly for stock attribution |

Create one synthetic QA patient in the active QA branch, one in-progress visit with a consultation fee, and one prescription. Create a medicine master record first; it must start with zero stock. Create valid batches through the Batches workflow. Expired and NULL-expiry legacy rows used by PHARM-EXP-03 must be seeded only by the disposable QA SQL fixture (the NULL-expiry fixture temporarily disables the trigger inside a rolled-back transaction); never create these rows through the UI or in production.

## Acceptance scenarios

| ID | Role / route | Action | Expected result |
|---|---|---|---|
| PHARM-EXP-01 | Pharmacist · Inventory | Open the new medicine form | No initial stock, batch number or medicine-level expiry fields; saved medicine has stock 0 |
| PHARM-EXP-02 | Pharmacist · Batches | Attempt to receive a batch without expiry | UI blocks submission; direct RPC attempt is rejected by the database trigger |
| PHARM-EXP-03 | Pharmacist · Pharmacy | Dispense a prescription where valid batches coexist with an expired batch and a legacy unknown-expiry batch | FEFO consumes only the earliest eligible unexpired batch(es); expired and NULL-expiry quantities remain unchanged |
| PHARM-EXP-04 | Pharmacist · Dashboard / Inventory / Reports | Review expired and unknown-expiry stock | Expired and unknown-expiry are visibly distinct; unknown is never shown as healthy; no invalid date is rendered |
| PHARM-IDEM-01 | Pharmacist · Pharmacy | Submit dispense, simulate lost response, retry with the same request UUID | The RPC returns the cached original result; no second stock movement or invoice line is created |
| PHARM-IDEM-02 | Pharmacist · Pharmacy | Retry the same prescription with a new request UUID | Rejected because the prescription is already dispensed; stock and invoice remain unchanged |
| PHARM-IDEM-03 | Pharmacist · Pharmacy | Reuse a request UUID with a different prescription or payload | Rejected as an idempotency-key conflict; no mutation |
| PHARM-BRANCH-01 | Pharmacist · Branch A | Attempt to dispense a Branch B patient's prescription | Rejected; no batch decrement, invoice, or stock movement |
| PHARM-BRANCH-02 | Super Admin | Dispense for a patient with an explicit branch while the admin has no default branch | Every consumed batch and stock movement is attributed to the patient's branch, not NULL |
| PHARM-LEDGER-01 | Pharmacist · Browser/API | Attempt direct INSERT/UPDATE/DELETE on `pharmacy_inventory` and `stock_movements` | Denied; read remains permission- and branch-scoped; all writes go through RPC |
| PHARM-LEDGER-02 | Pharmacist · Browser/API | Attempt direct update of `medicines.stock_quantity` | Rejected by the database guard; receive/dispense RPCs remain able to maintain the aggregate |
| CLIN-QUEUE-01 | Reception · Queue | Mark a ticket called, then in progress | Queue ticket changes; clinical visit status and clinical fields are not written by reception |
| CLIN-QUEUE-02 | Reception · Queue | Inspect an in-progress ticket | Clinical completion action is hidden; attempting the completion RPC is denied by `visits.update` guard |
| CLIN-COMP-01 | GP · Consultation / Queue | Complete the in-progress visit | One primary consultation invoice line is created (if fee > 0); visit and linked queue ticket become completed with the same server timestamp |
| CLIN-COMP-02 | GP · Consultation / Queue | Retry completion after the first response is lost | Same primary invoice is returned; no duplicate consultation line; queue timestamps are repaired from the visit timestamp |
| CLIN-COMP-03 | GP · Consultation / Queue | Complete a visit whose consultation invoice line already exists and invoice is paid | Retry is a no-op for billing and does not add a second charge |
| STOR-ENTITY-01 | Lab Doctor · Lab | Upload a report to the correct branch/order path | Allowed only when the lab order exists and its patient/visit/order branch all agree |
| STOR-ENTITY-02 | Lab Doctor · Lab | Upload against a nonexistent order or another branch's order | Denied; no cross-branch object is created |
| STOR-ENTITY-03 | Doctor · Certificate | Upload against a real certificate linked to the correct patient/visit branch | Allowed |
| STOR-ENTITY-04 | Doctor · Certificate | Upload against a nonexistent certificate or mismatched branch | Denied |
| STOR-ENTITY-05 | Any clinical role | Attempt to use the generic clinical-attachments bucket | Denied until the entity contract is formally defined; do not weaken the fail-closed policy |

## Browser presentation and accessibility checks

Run the same critical routes at a 360×800 mobile viewport and a desktop viewport, in Arabic RTL and English LTR:

- `/queue`, `/clinic/<visit-id>`, `/pharmacy`, `/inventory`, `/reports`, and the lab/certificate upload routes.
- Confirm there is no horizontal overflow, hidden submit control, clipped modal, or ambiguous destructive action.
- Confirm expiry warnings have text labels and are not communicated by colour alone.
- Confirm loading, empty, permission-denied, network-retry and server-error states are distinguishable.
- Confirm keyboard focus remains visible and controls have accessible names.

## Evidence to record

For each scenario record only: scenario ID, QA build SHA, role code, synthetic entity IDs, request UUID (where relevant), result, UTC timestamp, and a redacted screenshot if needed. For database evidence record counts and state transitions, not raw clinical notes or patient JSON.

## Release gates

- Automated PG17 migration/integration tests and source regression tests pass on the exact PR head.
- Typecheck, lint and production build pass on the exact PR head.
- Browser scenarios PHARM-EXP-01 through CLIN-COMP-03 pass in QA.
- Storage scenarios STOR-ENTITY-01 through STOR-ENTITY-05 pass in QA.
- Reception, pharmacist and clinician sign off their role workflows.
- No production migration is applied until the manual backup/restore gate and explicit release approval are complete.
