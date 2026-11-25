# Phase 18 — Production QA & Clinical Workflow Hardening

## Audit (before changes)

Inspected the attached ZIP as the sole source of truth (post Phase 17).

### Already correct (not modified)

| Area | Verdict |
|------|---------|
| PermissionGate on all authenticated feature routes | OK |
| NAV_GROUPS → NavRail / mobile / command palette; Clinic `visits.read` | OK |
| PatientPicker unified (visits, appointments, followups, billing, insurance, certificates) | OK |
| PatientPicker modal + measured width + pointer-events-auto | OK |
| Visits department/doctor Select empty-value handling | OK |
| Appointments doctor Select empty-value handling | OK |
| Finish visit updates `visits` + `queue_tickets` + invalidates queue/patient visits | OK |
| Invoice detail payment uses `post_invoice_payment` RPC | OK |
| Finance receivables / accounting receivables use `post_invoice_payment` | OK |
| Insurance claim payment uses `post_insurance_claim_payment` | OK |
| Pharmacy dispense uses `fn_dispense_prescription` + isPending | OK |
| Soft-delete visit with confirm + queue cancel | OK |
| No direct `payments.insert` from client | OK |
| Consultation create-invoice isPending + anti-duplicate by visit_id | OK |

### Genuine issues found

| ID | Severity | Issue |
|----|----------|--------|
| S1 | **MEDIUM** | Several forms passed `value=""` into Radix Select (broken controlled state on mobile): insurance plan company, membership company/plan, claim membership picker, inventory receive medicine/supplier, users role |
| S2 | **MEDIUM** | Insurance membership dialog used `t("select_medicine")` as placeholder for company/plan (wrong label) |
| S3 | **LOW** | New-claim validation error reused `t("select_medicine")` when membership/items missing |

No critical clinical/financial path regressions found beyond the above hardening.

## Fixes implemented

### `src/routes/_authenticated/insurance.tsx` (bug fix + hardening)
- Conditional Select value for plan `company_id`, membership `companyId` / `planId`, claim `patientInsuranceId`
- Placeholders: `select_medicine` → `none`
- Claim create error message bilingual and accurate
- `ClaimsTab` uses `lang` from `useLang`

### `src/routes/_authenticated/inventory.tsx` (bug fix)
- Conditional Select value for `medicine_id` and `supplier_id` on stock receive dialog

### `src/routes/_authenticated/users.tsx` (bug fix)
- Conditional Select value for `role_id` on create-user dialog

## Clinical workflow verification (static)

Patients → PatientPicker → New Visit → Save → queue (DB trigger) → Clinic → Consultation → Finish (visit + queue ticket) → Invoice → `post_invoice_payment` → cashbox triggers → patient timeline invalidation. IDs and RPC paths as above remain consistent.

## Financial verification

All payment writes observed use Phase 4 RPCs; no parallel client payment insert restored.

## Permission / navigation verification

Unchanged; gates and NAV already aligned.

## Mobile / dialog verification

Empty Select fixes reduce non-responsive dropdowns inside dialogs (same class of bug fixed earlier on Visits/Appointments).

## Search verification

Single PatientPicker + `patientPickerQuery`; no second implementation added.

## Database

No migrations.

## Typecheck / build

Not executed (no `node_modules` / package install in this environment).

## Remaining limitations

1. Live device QA still required after deploy.
2. Queue ticket **creation** still assumes live DB trigger.
3. Many bilingual strings remain inline `lang === "ar"` (pre-existing).
4. Insurance still uses some generic placeholders (`none`) rather than dedicated “select company” keys (no new i18n keys added by design).

## Files modified

1. `src/routes/_authenticated/insurance.tsx`
2. `src/routes/_authenticated/inventory.tsx`
3. `src/routes/_authenticated/users.tsx`
4. `PHASE18_AUDIT_AND_CHANGES.md` (new)
