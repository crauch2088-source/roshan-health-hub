# Roshan Health Hub — QA Staff Acceptance Runbook

**Date:** 2026-10-23  
**Status:** Partially prepared; synthetic staff identities provisioned; authenticated execution blocked  
**Tracking issue:** [#95](https://github.com/crauch2088-source/roshan-health-hub/issues/95)  
**Production project:** `jewzonxplxhogqrnhosl` — read-only for this acceptance  
**Isolated QA project:** `hopfohcnrtbiqjkgeukz`  
**QA branch:** `qa/isolated-acceptance-20261023`

## Safety gates — read before testing

- [ ] Confirm the browser URL is the QA Preview URL, not the production alias.
- [ ] Confirm the frontend is configured only with the QA Supabase URL and QA publishable key.
- [ ] Confirm the signed-in account belongs to the synthetic QA cohort and its intended role.
- [ ] Use invented names, dates, phone numbers, emails, clinical notes, results, prescriptions, invoice values, and stock entries only.
- [ ] Never copy a real patient's name, MRN, phone, history, prescription, laboratory result, or invoice into QA.
- [ ] Do not use production to create, edit, delete, or test patient or financial records.
- [ ] Do not enable paid AI/provider integrations or submit clinical content to external AI services during acceptance.
- [ ] If the URL, Supabase project, or account role is uncertain, stop and record a blocker rather than continuing.

**Important:** a green CI run, a READY Vercel deployment, or a successful SQL query is not equivalent to authenticated end-to-end acceptance.

### Latest identity provisioning status — 2026-10-23

Five synthetic QA identities were created through the Supabase Dashboard UI and linked to active `public.users` records in the isolated project only:

| Persona | Synthetic login | Mapped role | QA link verified |
|---|---|---|---|
| Reception | `roshan.qa.reception@example.com` | `receptionist` | Yes |
| General physician | `roshan.qa.gp@example.com` | `doctor` / General Practice | Yes |
| Laboratory | `roshan.qa.lab@example.com` | `lab_tech` / Laboratory | Yes |
| Pharmacy | `roshan.qa.pharmacy@example.com` | `pharmacist` / Pharmacy | Yes |
| Admin/billing | `roshan.qa.adminbilling@example.com` | `admin` | Yes |

Observed role-permission link counts: receptionist 20, doctor 26, lab_tech 7, pharmacist 14, admin 109. These counts are configuration evidence only, not proof of effective authorization.

**Authentication blocker:** the Dashboard UI has no direct set-password action after creation, and the connected Supabase toolset has no supported Auth Admin update-user/password action. An Auth Admin mutation attempt was blocked by the execution layer. Passwords generated during account creation were not captured. Do not set password hashes with SQL or bypass the approved execution boundary. Therefore `AUTH-02` and all authenticated workflow/role tests remain `NOT RUN`. The official supported Auth Admin user-update path must be enabled before testing can proceed.

No patient, visit, queue, lab, prescription, stock, invoice, payment, or other clinical/financial fixture rows were created. Production project remains unchanged. Issue #95 remains open.


## Current baseline and prerequisites

Record fresh values before the session; do not assume historical counts remain current.

| Prerequisite | Expected | Observed before session |
|---|---|---|
| QA Supabase project | `hopfohcnrtbiqjkgeukz`, healthy | Healthy at last check |
| QA Auth users | Dedicated synthetic users for each tested role | 5 created and email-confirmed via QA Dashboard UI; passwords were not captured for subsequent login testing |
| QA app-user links | Each Auth ID maps to one active `public.users` row | 5 verified linked, active, expected role/department, branch `ROS-MAIN` |
| QA Preview | Deployment READY from `qa/isolated-acceptance-20261023` | NOT READY: four recent Vercel deployments for docs-only commits were CANCELED/ignored; no QA preview build confirmed |
| Production writes | None during acceptance | Required invariant |
| Staff UAT | Completed with evidence | Not run |

Before creating users, use the official Supabase Auth Admin API or an approved administrative UI. Do not insert directly into `auth.users`. Use only the QA project and synthetic identities. Verify the app-user relationship and role mapping against the live QA schema before writing `public.users`.

## Test personas

Use one synthetic account per role. If a role is not implemented or has no dedicated permission set, record it as a blocker; do not silently substitute a more privileged role.

| Persona | Required scope | Key negative test |
|---|---|---|
| Reception | Patient registration, duplicate detection, appointments, queue | Cannot access clinical administration, pharmacy stock controls, or finance administration without permission |
| General physician | Assigned visit, clinical notes, vitals, diagnosis, prescriptions, lab orders | Cannot administer users/roles or edit another branch's records |
| Lab technician/assistant | Lab worklist, order items, results, save/reopen | Cannot verify results unless explicitly granted verification permission |
| Lab verifier/doctor (if configured) | Review, verify, finalise results | Cannot alter protected results after verification |
| Pharmacist | Prescriptions, dispensing, stock movement | Cannot dispense the same order twice or access unrelated clinical notes beyond permitted scope |
| Billing/cashier | Invoice review, payment recording, receipts, reversal workflow | Cannot alter clinical notes or create unauthorised stock adjustments |
| Administrator | User/role configuration and permitted reports | A lower-privilege account cannot reach administrator routes by URL or API |
| Unauthenticated visitor | Public/login routes only | All protected routes and data APIs reject access |

## Execution protocol

For every test, fill in **Actual result**, **Outcome**, and **Evidence**. A test is not PASS without evidence (sanitised screenshot, request/response status, or audit record). Never capture tokens, passwords, patient identifiers from production, or secret environment values.

Allowed outcomes: `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`.

| ID | Role | Scenario / steps | Expected result | Actual result | Outcome | Evidence / issue |
|---|---|---|---|---|---|---|
| PRE-01 | Operator | Confirm QA URL, project ref, branch, and QA-only environment | All four match the approved QA environment |  | NOT RUN |  |
| PRE-02 | Operator | Confirm all accounts and records are synthetic | No real-person data used |  | NOT RUN |  |
| AUTH-01 | Unauthenticated | Open a protected route directly | Redirect to login or deny access; no protected payload rendered |  | NOT RUN |  |
| AUTH-02 | Each role | Sign in with the assigned synthetic account | Correct identity and role shown; no cross-role session residue |  | NOT RUN |  |
| AUTH-03 | Each role | Sign out, then use browser back and revisit a protected route | Protected content is not available after sign-out |  | NOT RUN |  |
| AUTH-04 | Each role | Attempt one route and one API action outside role scope | Denied server-side; hiding a menu alone is insufficient |  | NOT RUN |  |
| AUTH-05 | Operator | Submit an invalid password and repeat rapidly within reasonable limits | Clear error, no account disclosure, no unbounded retry behaviour |  | NOT RUN |  |
| REC-01 | Reception | Register a wholly synthetic patient with required fields | One patient created; stable MRN/identifier returned |  | NOT RUN |  |
| REC-02 | Reception | Submit the same synthetic identity twice | Duplicate is detected or explicitly handled; no silent duplicate |  | NOT RUN |  |
| REC-03 | Reception | Create an appointment and enqueue the patient | Correct branch/date/status and one queue ticket |  | NOT RUN |  |
| REC-04 | Reception | Double-click/retry queue creation after a simulated delay | No duplicate ticket or inconsistent visit link |  | NOT RUN |  |
| GP-01 | GP | Open the queued patient and start a visit | Correct patient, branch, visit, and queue relationship |  | NOT RUN |  |
| GP-02 | GP | Save vitals and a synthetic clinical note, navigate away, reopen | Values persist accurately; no duplicate note |  | NOT RUN |  |
| GP-03 | GP | Add diagnosis and a prescription with a test-only medication | Correct drug/formulation/dose/instructions; no unsupported defaults |  | NOT RUN |  |
| GP-04 | GP | Create a lab order linked to the active visit | Correct order/items and visit/patient linkage |  | NOT RUN |  |
| GP-05 | GP | Complete visit and repeat completion after refresh/retry | Completion timestamp remains stable; linked queue state is consistent |  | NOT RUN |  |
| LAB-01 | Lab | Open worklist and select the synthetic order | Only permitted branch/orders appear |  | NOT RUN |  |
| LAB-02 | Lab | Enter a result, save, refresh, and reopen | Value, units, comments, and status persist |  | NOT RUN |  |
| LAB-03 | Lab | Try to save an invalid result or missing required value | Validation blocks unsafe/incomplete finalisation with a useful message |  | NOT RUN |  |
| LAB-04 | Lab | Verify a result only as the role authorised to do so | Verification is atomic and records verifier/time |  | NOT RUN |  |
| LAB-05 | Lab | Try editing a verified result or verifying twice | Forbidden mutation is rejected; retry is idempotent |  | NOT RUN |  |
| LAB-06 | Lab lead | Review reference intervals, units, and qualitative/numeric typing | Only approved ranges are used; no invented clinical thresholds |  | NOT RUN |  |
| RX-01 | Pharmacist | Open the synthetic prescription | Correct patient/visit, item, formulation, dose, and quantity |  | NOT RUN |  |
| RX-02 | Pharmacist | Dispense a permitted quantity | One atomic stock movement and dispensing record; balance reconciles |  | NOT RUN |  |
| RX-03 | Pharmacist | Retry dispense or submit twice | No duplicate dispense or double stock decrement |  | NOT RUN |  |
| RX-04 | Pharmacist | Attempt an unauthorised or out-of-stock dispense | Server rejects it; inventory remains unchanged |  | NOT RUN |  |
| FIN-01 | Billing | Review/create invoice for synthetic workflow | Invoice lines and totals reconcile with permitted services/items |  | NOT RUN |  |
| FIN-02 | Billing | Record a synthetic payment once | One payment; outstanding balance and receipt agree |  | NOT RUN |  |
| FIN-03 | Billing | Retry the same payment request | No duplicate payment or double balance change |  | NOT RUN |  |
| FIN-04 | Billing | Reverse a permitted test transaction with a reason | Reversal is auditable and linked; original record remains traceable |  | NOT RUN |  |
| FIN-05 | Billing | Attempt a direct forbidden write / invalid amount | Rejected by database/RPC policy; ledger remains unchanged |  | NOT RUN |  |
| ADM-01 | Admin | Review roles and permissions | Expected least-privilege mapping; no unintended grants |  | NOT RUN |  |
| ADM-02 | Admin | Deactivate a synthetic account, then attempt access | Access is denied promptly and server-side |  | NOT RUN |  |
| SEC-01 | Lower-privilege role | Guess/open administrator URL directly | No sensitive page or data returned |  | NOT RUN |  |
| SEC-02 | User A | Request User B's record ID within same branch | Denied unless explicit role policy allows it |  | NOT RUN |  |
| SEC-03 | User A | Request a record belonging to another branch | Denied by RLS/server authorization |  | NOT RUN |  |
| SEC-04 | Unauthenticated | Call protected REST/RPC endpoints without a valid session | 401/403 or equivalent; no data mutation |  | NOT RUN |  |
| SEC-05 | Operator | Inspect browser console and network requests through full workflow | No uncaught errors, leaked secrets, unexpected production calls, or PHI in URLs/logs |  | NOT RUN |  |
| ERR-01 | Any | Simulate network loss while saving, then retry | Clear recovery; no silent loss or duplicate write |  | NOT RUN |  |
| ERR-02 | Any | Refresh/navigate back during a pending operation | No stale UI that falsely reports success |  | NOT RUN |  |
| UX-01 | Reception + GP | Repeat primary workflow at 320, 360, 390, and 430 px widths | No clipped controls or inaccessible primary actions |  | NOT RUN |  |
| UX-02 | All | Check Arabic RTL and English LTR, including identifiers/results | Layout direction correct; identifiers and numeric values readable |  | NOT RUN |  |
| UX-03 | All | Keyboard/focus check on login, forms, dialogs, and validation | Visible focus, labelled controls, recoverable validation |  | NOT RUN |  |
| AUD-01 | Admin | Review audit trail for the synthetic workflow | Actor/action/time/record references present without leaking secrets |  | NOT RUN |  |
| CLEAN-01 | Operator | Remove only approved synthetic fixtures using supported application/admin cleanup | No dangling relations; no production change; cleanup evidence retained |  | NOT RUN |  |

## Defect triage and evidence record

For each failure, create a GitHub issue or add a detailed comment to Issue #95 with:

- Test ID and exact build/commit SHA.
- Role, viewport, language, and route.
- Minimal reproduction steps with synthetic data only.
- Expected vs actual behaviour.
- Sanitised console/network evidence and relevant request status.
- Severity: **P0** data exposure/cross-branch access/financial corruption; **P1** core workflow unusable or unsafe; **P2** important defect with workaround; **P3** cosmetic/minor.
- Root cause, regression test, fix PR, and retest result.

Do not paste access tokens, passwords, service-role keys, cookies, or full environment dumps into issues.

## Acceptance exit criteria

Issue #95 must remain open until all of the following are true:

1. QA Preview is READY and its QA-only configuration is independently confirmed.
2. Each required role can authenticate through the normal application UI with its intended permissions.
3. All critical reception, consultation, laboratory, pharmacy, and billing tests pass.
4. Negative access tests, branch isolation, duplicate/retry behaviour, and audit checks pass.
5. No P0/P1 defect remains open; P2/P3 items have explicit disposition and owner.
6. The actual results and evidence are recorded in this runbook or linked issues.
7. Clinic staff complete the supervised practical acceptance session and confirm workflow usability.
8. The final sign-off records the tested commit SHA, Preview URL, date, participants/roles (no passwords), and remaining known limitations.

**No sign-off is implied by preparing this document.** All test rows start as NOT RUN. This runbook is an execution record, not a claim that any staff UAT has occurred.
