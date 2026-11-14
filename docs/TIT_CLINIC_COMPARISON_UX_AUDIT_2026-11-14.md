# TIT Clinic System comparison and Roshan workflow audit — 2026-11-14

## Purpose and evidence boundary

This review was requested after the user supplied a one-minute Facebook Reel advertising the TIT Technology clinic system. It compares only what is visible in that supplied video with the current Roshan source code at `main` commit `a9040601702972bdf144fc96b9658eebd5a6d31a`.

Evidence categories are deliberately separated:
- **VIDEO OBSERVED**: a screen, label, or workflow visibly appears in the supplied Reel.
- **SOURCE VERIFIED**: the corresponding behavior is present in the checked-in Roshan source.
- **NOT VERIFIED**: the Reel or source inspection does not prove runtime quality, security, offline correctness, or real staff acceptance.

This is a source-backed workflow review, not a screenshot/DOM/keyboard/browser acceptance audit. No visual acceptance status is upgraded by this document.

## Vendor and repository identification

The video end card identifies **TIT Technology / شركة TIT تكنولوجي للحلول التقنية والبرمجيات**, shows `www.tit-technology.com`, and advertises phone `0966637450`.

GitHub repository searches were run for:
- `TIT Technology Sudan`
- `tit-technology`
- `clinic.tit-sys.com`
- the advertised clinic-system wording and related terms

No public GitHub repository could be reliably attributed to the clinic product. Search results with similar “Titan Technology” names were unrelated or unverified and are not treated as the vendor's source code. The official website could not be independently inspected in this pass; no login, demo, or source link is therefore asserted.

## What the supplied video actually shows

The video advertises an online/offline clinic system and displays role labels for reception, doctor, laboratory, finance, and offline operation. The captured workflow/screens include patient registration, visits/queue, clinical consultation, lab requests/results, prescriptions, financial collection/reporting, and administration/settings. The video also displays a claim that the product can continue working offline.

The following are **not established by the advertisement**: offline conflict resolution, encryption and local-data protection, multi-device synchronization correctness, audit immutability, role/branch isolation, dispensing atomicity, backup restoration, or clinical decision-support quality.

## Roshan source audit at `a9040601702972bdf144fc96b9658eebd5a6d31a`

### Patient registration

- `src/routes/_authenticated/patients.tsx` uses `create_patient_atomic` for patient creation and supports a permission-gated “save and create visit” path.
- That path navigates to `/visits?patient=<id>`; it does not ask reception to search for the same patient again.
- Registration requires a name and gender; phone, date of birth, and national ID are optional in the current form.
- Duplicate-detection behavior and its real-world usability were not validated in a browser in this pass.

### Visit creation and queue

- `src/routes/_authenticated/visits.tsx` preselects a patient from the patient-chart deep link, obtains department/doctor choices through `get_visit_form_options`, and leaves queue/visit numbering to PostgreSQL.
- `src/routes/_authenticated/queue.tsx` exposes waiting/called/in-progress/completed/cancelled states, queue metrics, search/filtering, and periodic refresh.
- Reception queue actions are separated from clinician-only completion/cancellation. Completion uses `complete_visit_atomic` and is not treated as a simple queue-status edit.
- A new lab-order shortcut intentionally returns the user to the visit context with an explanatory hint; the actual order must originate from an active visit.

### Clinical consultation

- `src/features/clinic/consultation/ConsultationPage.tsx` provides note, vitals, laboratory, prescription, and history tabs.
- Patient context includes allergies, chronic conditions, and blood group; missing data is represented as unrecorded rather than silently normal.
- Unsaved clinical-note navigation is guarded. The consultation has bilingual tab semantics and keyboard navigation in source tests.
- The optional local review checklist is not a clinical hard-stop and should not obstruct emergency care.

### Laboratory

- `src/features/clinic/consultation/components/LaboratoryTab.tsx` owns ordering from the active visit, with debounced/sanitized catalogue search, loading/error handling, selected-test subtotal, and an idempotent atomic order/invoice path.
- `src/routes/_authenticated/lab.tsx` exposes a five-stage worklist progression based on persisted order status.
- `src/routes/_authenticated/lab_.$orderId.tsx` handles order detail/results. Verification is a distinct protected action; abnormal-result acknowledgement and unsaved-result blocking are covered by the redesign source tests.
- The existing plan explicitly says governed critical-value escalation is not yet established by a validated schema/threshold policy. Do not infer that it exists.

### Prescriptions and pharmacy

- `PrescriptionTab.tsx` requires clinician-prescriber role plus permission, uses a visit-linked weight observation for pediatric safety warnings, and validates medicine, dose, frequency, duration, and quantity.
- Current prescribing does **not** silently calculate or auto-fill clinical doses. This is an intentional safety decision, not a missing default to be added casually.
- `src/routes/_authenticated/pharmacy.tsx` limits dispensing in the UI to pharmacist roles with permission, preserves retry request IDs, and delegates FEFO dispensing to the server operation.
- The latest pharmacy work includes pharmacist-role authorization hardening, but the 2026-11-14 release evidence says Phase 61C is still CI-tested and not applied to hosted QA/Production pending independent SQL/security review. Do not describe the candidate as live.

### Billing and dashboard

- `src/routes/_authenticated/billing.tsx` requires a patient and either a linked visit or an explicitly selected standalone invoice; it uses an idempotency request ID and the atomic invoice RPC.
- `src/routes/_authenticated/dashboard.tsx` combines operational and financial overview metrics with links gated by the user's permissions.
- The dashboard and queue use refresh/polling behavior. This is not proof of offline-first behavior.

## Comparative assessment

| Workflow capability | TIT video | Roshan source at reviewed main |
|---|---|---|
| Reception/patient registration | VIDEO OBSERVED | SOURCE VERIFIED |
| Visit/queue progression | VIDEO OBSERVED | SOURCE VERIFIED |
| Doctor consultation | VIDEO OBSERVED | SOURCE VERIFIED |
| Lab order and results | VIDEO OBSERVED | SOURCE VERIFIED |
| Prescription workflow | VIDEO OBSERVED | SOURCE VERIFIED |
| Finance/collection/reporting | VIDEO OBSERVED | SOURCE VERIFIED |
| Role separation | Role labels visible; enforcement NOT VERIFIED | Permission gates and server-side safeguards exist; full staff acceptance NOT VERIFIED |
| Offline operation | Vendor claim visible; behavior NOT VERIFIED | No end-to-end offline-first/sync guarantee established by this audit |
| Multi-branch isolation | NOT VERIFIED | Implemented in source/schema but current hosted QA/Production parity/release gates remain open |
| Clinical decision support | NOT VERIFIED | Safety-oriented validation exists; automated protocol dosing is not enabled |
| Backup/restore and audit integrity | NOT VERIFIED | Engineering controls exist; owner-side and release gates remain open |

## Findings and decisions

1. **Do not copy the whole TIT feature set from a marketing video.** The video demonstrates a compact product workflow, not implementation quality.
2. **Preserve Roshan's existing workflow architecture.** Patient → visit → queue → consultation → lab/pharmacy → invoice/payment is already represented in source; rebuilding these modules would add risk without evidence.
3. **Keep the safety boundaries.** No automatic clinical dose selection, no receptionist clinical completion, no direct stock-ledger writes, no production test transactions, and no offline cache of clinical data without an explicit threat model.
4. **Highest-value next step is visual acceptance, not speculative refactoring.** The existing UX route matrix records 27 authenticated routes and 3 public routes, with browser/visual/keyboard acceptance still NOT TESTED. Capture current-main screenshots and exercise representative role journeys at 360–430 CSS px in Arabic RTL and English LTR, including loading/empty/error/retry and modal states.
5. **No runtime source change is justified by this pass alone.** The supplied advertisement does not expose a reproducible Roshan defect, and static source review cannot establish that a UI change is necessary. Avoid adding code merely to make the comparison appear productive.

## Focused acceptance sequence

1. Reception: patient search/duplicate handling → registration → save-and-open-visit → queue ticket.
2. Queue: waiting → called → in progress; verify reception cannot complete/cancel the clinical visit.
3. Clinician: correct patient/visit context → allergy/history/vitals → note → lab order → prescription; verify unsaved-note warning and no dose auto-invention.
4. Laboratory: receive order → collect sample → enter partial results → save → verify; test abnormal acknowledgement, critical-result policy boundary, retry, and immutable verified results.
5. Pharmacy: pharmacist-only correction/dispense → FEFO batch selection → stock and invoice atomicity → retry without duplicate dispensing.
6. Billing: linked visit invoice → payment/receipt → finance ledger consistency.
7. Repeat relevant screens at 360, 390, and 430 CSS px in RTL/LTR; keyboard/focus and screen-reader labels; record screenshots and exact commit/deployment identity.

## Explicit limitations

- No authenticated current-main browser session or current-main visual screenshots were available in this pass.
- No TIT source repository, demo credentials, or inspectable vendor technical documentation were identified.
- No live clinical workflow was run and no patient/financial data was created or changed.
- The report does not certify clinical readiness, offline capability, or production release readiness.


## Public production smoke — follow-up continuation, 2026-11-14

### Deployment identity

Vercel production deployment lookup returned the latest READY production deployment:
- Deployment: `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH`
- URL: `roshan-health-5sz95objk-roshan45.vercel.app`
- Branch: `main`
- Git SHA: `a9040601702972bdf144fc96b9658eebd5a6d31a`
- State: `READY`

The deployed source SHA matches the reviewed `main` baseline. The documentation-only PR #251 is not included in production.

### Read-only public page fetch

A public fetch of `/auth` at 390×844 viewport metadata returned:
- HTML document language `ar`, direction `rtl`, and responsive viewport metadata.
- Staff sign-in title, clinic logo, email and password fields, submit button, password-reset control, and English language toggle.
- Public registration closed notice.
- Skip-to-content link targeting `#auth-card`.
- Email/password autocomplete tokens `username` and `current-password`; password minimum length 6.
- No public registration link on the sign-in page.

The page fetch included a screenshot request, but the scraper returned `screenshot.data: null`; therefore **no screenshot was actually captured** and no visual pass is claimed. A single 390×844 viewport was requested; 360/430 widths, English LTR, keyboard interaction, touch target sizing, overflow, and live browser console remain NOT TESTED. Static HTML alone cannot prove interactive language switching or reset behavior.

A read-only fetch of `/setup` returned Arabic setup metadata and a transient server-rendered `جارٍ التحميل…` state. This is not enough to determine the hydrated client state or whether setup is complete; the prior matrix's historical completed-setup smoke is not revalidated by this fetch. Do not submit or interact with the setup form.

The root route returned the clinic title and a transient loading message; redirect behavior was not confirmed in this pass.

### Tooling limitation

An attempted authenticated-capable browser automation run was not started: the TinyFish wallet balance was `-$0.07`. No wallet top-up was made, in keeping with the project's no-paid-services constraint. This is an external tooling/budget limitation, not an application failure.

### Updated findings

1. Production currently serves the reviewed `main` SHA `a904060` in a READY Vercel deployment.
2. Public auth-page HTML has useful baseline accessibility/metadata features, but this is not a browser visual or interactive acceptance pass.
3. The setup route needs a permitted hydrated-state check in an isolated QA session; do not infer setup status from the server-rendered loading placeholder.
4. No production writes, sign-ins, account creation, patient/financial transactions, or configuration changes were performed.
5. Keep PR #251 as Draft and Issue #95 open until authenticated visual and role acceptance evidence is collected.
