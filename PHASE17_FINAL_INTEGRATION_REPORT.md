# Phase 17 — Final Integration, Workflow Validation & Production Polish

## 1. Full audit

Audited the post–Phase 16 GitHub ZIP as the only source of truth: routes, NAV_GROUPS, PermissionGate coverage, PatientPicker, patients/profile, visits, appointments, queue, clinic/consultation, lab, pharmacy, billing, finance, insurance, reports/analytics, shared UI, i18n, and mutation/invalidation patterns.

## 2. What was already correct (VERIFIED — not changed)

| Area | Status |
|------|--------|
| PermissionGate on all authenticated feature routes (Phase 16) | VERIFIED |
| Finish visit completes `queue_tickets` + invalidates queue | VERIFIED |
| Clinic nav `visits.read` + Stethoscope | VERIFIED |
| PatientPicker modal + measured width + `pointer-events-auto` | VERIFIED |
| New Visit Select empty-value handling | VERIFIED |
| Unified PatientPicker on visits, appointments, followups, certificates, billing, insurance | VERIFIED |
| Finance receivables/supplier/cashbox via atomic RPCs | VERIFIED |
| Insurance claim payment via `post_insurance_claim_payment` | VERIFIED |
| Pharmacy FEFO via `fn_dispense_prescription` | VERIFIED |
| Prescription/lab orders carry `patient_id` + `visit_id` from consultation | VERIFIED |
| Consultation invoice anti-duplicate by `visit_id` | VERIFIED |
| Single NAV_GROUPS → NavRail / mobile / command palette | VERIFIED |
| Auth `can()` fail-closed | VERIFIED |
| Patient chart timeline + visits/labs/rx/invoices + New Visit shortcut | VERIFIED |

## 3. Genuine problems found

| ID | Severity | Problem |
|----|----------|---------|
| F1 | **HIGH** | Invoice detail payment used client multi-step insert + manual invoice update, bypassing `post_invoice_payment` used by Finance |
| A1 | **MEDIUM** | Appointments doctor `Select` used `value=""` when empty (Radix controlled broken state) |
| C1 | **MEDIUM** | Finish visit button label hardcoded Arabic only |
| C2 | **LOW** | Consultation summary labels (Patient/Age/Department/Doctor) English only |
| C3 | **LOW** | Finish visit did not invalidate patient chart visit queries (stale timeline until refresh) |

## 4. Root causes

**F1:** Historical dual path — Finance was refactored onto RPC + triggers (`FOR UPDATE`, outstanding check, cashbox ledger, `fn_recompute_invoice_paid`); invoice page kept raw inserts and a second client write of `paid_amount`/`status` (race with trigger, weaker validation, diverged cashbox invalidation).

**A1:** Same Radix Select empty-string issue previously fixed on Visits.

**C1–C3:** Consultation page never fully i18n’d; invalidate list incomplete for patient hub.

## 5. Files changed

- `src/routes/_authenticated/billing_.$invoiceId.tsx`
- `src/routes/_authenticated/appointments.tsx`
- `src/features/clinic/consultation/ConsultationPage.tsx`

## 6. Exact fixes

1. **Invoice payment** → `rpc("post_invoice_payment", { _invoice_id, _amount, _method, _reference })`; invalidate invoice, payments, invoices, patient-receivables, cashbox keys; removed unused `user`.
2. **Appointments doctor Select** → conditional value spread when empty.
3. **Consultation** → bilingual Finish button and summary labels; invalidate `patient-visits` and `patient-snapshot-visits` on finish.

## 7. Database changes

**None.**

## 8. Clinical workflow verification

PATIENT → search → New Visit → dept/doctor/type → Save → queue (DB trigger) → Clinic → Consultation → Finish (visit + queue ticket) → patient timeline refresh keys → Billing/invoice → **payment via same RPC as Finance** → cashbox via existing triggers.

IDs preserved in existing queries: `patient_id`, `visit_id`, `doctor_id`, `department_id`, `invoice_id` / `visit_id` on invoices.

## 9. Financial verification

- Invoice page and Finance receivables now share `post_invoice_payment`.
- Insurance claim pay remains RPC.
- Supplier/cashbox paths unchanged (already RPC).

## 10. Pharmacy verification

- FEFO RPC path unchanged; not modified this phase.

## 11. Insurance verification

- Claim payment already atomic; not modified.

## 12. Permission verification

- All routes still gated (Phase 16); no new codes; no weakening.

## 13. Navigation verification

- Single NAV_GROUPS; Clinic + Banknote expenses icon unchanged this phase.

## 14. Mobile verification

- Portal/pointer-events fixes retained; appointments Select empty fix helps mobile dialogs; no new nested-portal changes.

## 15. Search verification

- One PatientPicker + `patientPickerQuery` + debounce across modules; no second picker introduced.

## 16. i18n verification

- Consultation finish + summary labels bilingual; no new duplicate keys.

## 17. Typecheck / build

Not run (no `node_modules` in this environment).

## 18. Remaining limitations

1. Live mobile/device verification still required after deploy.
2. Queue ticket **creation** still depends on live DB trigger not fully represented in repo SQL.
3. ConsultationPage remains dense single-file formatting (behavior-focused fixes only).
4. Many screens still use inline `lang === "ar"` (pre-existing pattern).
5. Invoice payment success still relies on DB triggers for ledger/recompute after RPC insert (by design of phase 4).

## Phase 18

Not started. No speculative feature work recommended until live smoke test of payment + finish-visit + queue on production.
