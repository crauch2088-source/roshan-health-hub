# ROSHAN Medical Center — ERP / EMR

## What I verified just now

Your database at `jewzonxplxhogqrnhosl.supabase.co` is reachable with the anon key, and these tables respond successfully: `patients`, `users`, `roles`, `visits`, `invoices`, `lab_tests`, `medicines`. All of them returned **zero rows**, so the schema exists but is empty of data.

Two findings that matter:

1. **This Lovable project has no backend integration wired yet.** There is no Supabase integration and no generated client files, so right now I cannot read column definitions, foreign keys, or RLS state, and I cannot run migrations for you.
2. **Anonymous read currently succeeds on `patients`.** That means patient data is exposed to anyone holding the anon key (which is public by design). This must be closed by the RLS migration before any real patient is entered.

## Step 0 — Connect the database (blocking)

Nothing else can be built correctly until this is done. Two ways:

- **Recommended:** connect your existing Supabase project through Lovable's Supabase integration. I then get the real schema (columns, types, relationships), can generate typed clients, and can apply the migration and RLS policies directly.
- **Fallback:** I hardcode the URL + anon key in the app. Everything still reads/writes, but I cannot see your columns, so I must guess field names — and you would run every SQL statement yourself in the Supabase SQL editor.

I will proceed on the recommended path unless you tell me otherwise.

## Step 1 — Schema map and confirmation

Once connected I dump every table with columns, types, nullability, foreign keys, RLS status and existing policies, and check it against the expected ROSHAN table list. Any missing table or missing column needed by a workflow gets reported, not invented.

## Step 2 — Migration SQL (shown before applying)

Additive only. No renames, no drops, no duplicate tables.

- `users.auth_user_id uuid` + **unique constraint** + FK to `auth.users(id)`.
- `created_by` / `updated_by` (uuid) and `deleted_at` / `deleted_by` on clinical, lab, pharmacy, billing and patient tables that lack them — soft delete only, never hard delete.
- `has_role(uuid, text)` and `current_app_user()` security-definer helpers so policies never recurse.
- Enable RLS on every application table. Revoke `anon` on patient, visit, clinical, lab, pharmacy, billing and accounting tables. Authenticated access scoped by role; Super Admin full access.
- Explicit `GRANT`s per table for `authenticated` and `service_role`.
- Trigger-based audit rows into `audit_logs` (user, timestamp, action, table, record id, old value, new value).
- Uniqueness/idempotency guards: invoice number, payment reference, dispensing per prescription item — so refreshes and double-clicks cannot duplicate money.

You review this SQL before I apply it.

## Step 3 onward — Application build

Arabic default with full RTL, English toggle, mobile-first, installable PWA, Roshan logo and brand colours (deep navy + teal), white clinical surfaces.

**Auth & shell:** first-run setup wizard (only offered while no Super Admin row exists), Super Admin creation via real Supabase Auth, login, password reset page, session persistence, signup closed afterwards, users created by Super Admin only. Role-based navigation that hides what a role may not touch.

**Reception:** patient registration (MRN, name, gender, DOB, auto age, phone, address, occupation, marital status, blood group), search by MRN/name/phone, edit, permission-gated soft delete, visit creation, automatic queue tickets per department (Q001…), appointments with calendar view and the six statuses, discounts, invoice, payment (Cash / Bankak). Verified end-to-end: Patient → Visit → Queue → Invoice → Payment.

**Doctor EMR:** waiting/current/completed lists, vitals with auto BMI, LMP → EDD + gestational age computed live, full history set (Chief Complaint, HPI, PMH, PSH, drug, allergy, family, social, examination, assessment, plan), multiple diagnoses with ICD-10 and primary/secondary, prescriptions (internal or external pharmacy), lab orders, procedure orders. Completed visits become read-only; later edits need authorization and are audit logged.

**Laboratory:** dynamic test builder (tests, parameters, reference ranges, all editable), optional parameters with no forced completion, worklist → sample → result entry → verification → printable report. Default test set seeded as catalogue configuration (not fake patient data).

**Pharmacy:** inventory with batch numbers, purchase/selling price, expiry tracking, low-stock alerts, dispensing against internal prescriptions and external prescriptions, stock validated before dispensing, negative stock impossible.

**Billing & accounting:** invoices and items across consultation, procedures, lab and pharmacy; payments; expenses by category (salaries, rent, electricity, water, internet, maintenance, other); corporate accounts and partner discounts (universities, schools, companies) with custom discount and agreement notes; revenue / expense / profit dashboard.

**Dashboard, reports, extras:** today's patients, visits, appointments, revenue, expenses, net profit, pending lab and pharmacy orders, waiting patients, upcoming appointments and follow-ups; charts for daily and monthly revenue, visits by department, lab and pharmacy activity. Reports with PDF and Excel export. Attachments (images, PDFs, scans, ultrasound, external lab reports) on patient records. Certificates (medical, sick leave, fitness). A4 print layouts for prescriptions, lab reports, invoices, certificates. Audit log viewer. System settings (name, logo, currency, receipt/invoice footer, contact). Admin system-status page (database status, connectivity, storage usage, last backup).

No mock data, no local storage as a data store, all errors surfaced visibly.

## Honest note on sequencing

You asked me not to stop. I will run straight through without pausing for approval between modules — with one exception: the migration SQL in Step 2, which you asked to review and which I will not apply blind. This is a large system, so I will build in dependency order (auth → reception → EMR → lab → pharmacy → billing → reports) and report what is verified against the live database versus what still needs your testing.

## Technical notes

TanStack Start + React 19 + TypeScript + Tailwind v4. Server functions (`createServerFn`) for all privileged reads/writes with bearer-token auth middleware; protected pages under the `_authenticated` route gate; the browser Supabase client only for auth and realtime. Roles live in their own tables and are checked server-side via a security-definer function — never from client state. `service_role` key is not used in application code paths. PWA is manifest + guarded service worker so previews are unaffected.
