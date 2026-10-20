# Production browser smoke checklist — five minutes

**Purpose:** owner-operated release check. Use a dedicated synthetic test patient and a non-production/test account where possible. Never enter real patient data solely for this check. Automated PostgreSQL 17 tests use disposable data and do not connect to production.

## Before you start (30 seconds)
- Open the canonical production URL and sign in with a role-specific test account.
- Open browser DevTools → Console; clear it. Record the deployed commit SHA.
- Set the viewport to a phone-sized **390 × 844 px**.

## Five-minute workflow
1. **Language and layout (45 sec):** switch Arabic → English → Arabic. Confirm direction changes between RTL and LTR; navigation and dialogs stay in viewport; IDs, MRNs, invoice numbers, dates, lab values and reference ranges remain legible left-to-right.
2. **Reception (45 sec):** search a synthetic patient, create/open a visit, and verify the queue ticket appears once. Use only the assigned branch.
3. **Doctor and laboratory (90 sec):** open the visit, save a synthetic clinical note and order a test. As the lab role, save a result and use Verify only after checking value, unit and age/sex-appropriate reference range. Confirm verified values become read-only where intended.
4. **Certificate and pharmacy (60 sec):** issue a certificate linked to that visit and open print preview (cancel printing if this is only a smoke test). Dispense a test prescription only if the account and stock are explicitly marked for testing.
5. **Billing and attachment (60 sec):** confirm the linked invoice; create/record a test payment only in a designated test workflow. If direct upload is enabled, upload a synthetic PDF/PNG/JPEG and open the signed URL; otherwise confirm local print fallback remains available.
6. **Finish (30 sec):** confirm no unexpected console.error, no unhandledrejection, no duplicate invoice/queue ticket, and no visible data from another branch. Sign out.

## Pass/fail and safety
- Mark PASS only if relevant steps succeed without runtime errors or cross-branch data exposure. Record failing screen, role, language, viewport and timestamp; redact patient identifiers before sharing.
- Do not use production patient records, real prescriptions, real payments, or clinical actions unless the owner explicitly designated a safe synthetic operational test record and approved those side effects.
- Green CI and a Vercel READY deployment do not prove this live authenticated browser check has been completed.
