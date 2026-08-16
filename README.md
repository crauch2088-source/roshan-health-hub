# Roshan Health Hub

ROSHAN MEDICAL CENTER ERP / EMR SYSTEM



Build a complete modern cloud-based Medical Center Management System called ROSHAN.



The system will be deployed initially for a medical center in Sudan and must be scalable to multiple branches in the future.



Use:



React



TypeScript



Tailwind CSS



Supabase



Responsive Design



PWA (installable Android app)



Clean Medical UI



Production-grade architecture



GENERAL DESIGN



Design Style:



Modern



Professional



Medical



Fast



Minimal



Elegant



Colors:



Use existing Roshan branding and logo.



Clean white background.



Soft medical blue.



Accent color from Roshan logo.



High readability.



Requirements:



Mobile-first.



Fully responsive.



Android installable (PWA).



Fast loading.



Arabic + English support.



RTL support.



USER ROLES



Create role-based access:



Super Admin



Admin



Reception



GP



Dentist



Specialist



Lab Doctor



Lab Assistant



Pharmacist



Hide menus based on permissions.



MAIN DASHBOARD



Display:



Patients today



Visits today



Appointments today



Revenue today



Expenses today



Net profit today



Pending laboratory orders



Pending pharmacy orders



Waiting patients



Upcoming appointments



Include charts:



Daily revenue



Monthly revenue



Visits by department



Laboratory activity



Pharmacy activity



RECEPTION MODULE



Reception can:



Register patient



Search patient



Edit patient



Delete patient (permission controlled)



Create visit



Create appointment



Apply discounts



Create invoice



Receive payment



Search by:



MRN



Name



Phone



Patient fields:



MRN



Full name



Gender



Date of birth



Age (calculated)



Phone



Address



Occupation



Marital status



Blood group



APPOINTMENT SYSTEM



Support:



Walk-in patients



Scheduled appointments



Statuses:



Scheduled



Confirmed



Arrived



Completed



Cancelled



No Show



Calendar View.



QUEUE SYSTEM



Automatic queue generation.



Example:



Q001 Q002 Q003



Waiting screen support.



Queue by department.



DOCTOR MODULE



Doctor dashboard:



Waiting patients



Current patient



Completed patients



Patient chart:



Chief Complaint



HPI



PMH



PSH



Drug History



Allergy History



Family History



Social History



Examination



Assessment



Plan



Vitals:



BP



Pulse



RR



Temperature



SpO2



Weight



Height



BMI (auto)



OBSTETRIC FEATURES



When LMP is entered:



Automatically calculate:



EDD



Gestational Age



Display instantly.



DIAGNOSIS MODULE



Support:



Multiple diagnoses



ICD10 Code



Primary diagnosis



Secondary diagnosis



PRESCRIPTION MODULE



Doctor can prescribe medication.



Support:



Internal pharmacy



External pharmacy



Patient may not purchase medications from Roshan pharmacy.



System must support this workflow.



PROCEDURES MODULE



Medical Procedures:



ECG



USS



Nebulization



Injection



Dressing



Dental Procedures:



Extraction



Filling



Root Canal Treatment



Scaling & Polishing



Crown



Bridge



Denture



Procedure reports printable.



LABORATORY MODULE



Dynamic laboratory system.



Laboratory doctor can:



Create tests



Create parameters



Create reference ranges



Edit parameters



Support optional parameters.



Example:



CBC may contain:



HB



WBC



RBC



Platelets



MCV



MCH



MCHC



Allow skipping parameters.



Do not force completion of all fields.



Laboratory workflow:



Order → Sample → Result Entry → Verification → Print Report



DEFAULT LAB TESTS



Include:



CBC



Blood Glucose



Urinalysis



Malaria Parasite



Pregnancy Test



Creatinine



Urea



ALT



AST



PHARMACY MODULE



Features:



Inventory



Stock control



Dispensing



External prescriptions



Internal prescriptions



Expiry tracking



Low stock alerts



Support:



Batch numbers



Purchase price



Selling price



BILLING MODULE



Support:



Consultation fees



Procedure fees



Laboratory fees



Pharmacy sales



Invoice system.



Printable invoices.



PAYMENT METHODS



Support:



Cash



Bankak (Bank of Khartoum)



Prepare system for future payment methods.



DISCOUNTS



Support:



Manual discounts



Student discounts



Partner discounts



Promotional campaigns



PARTNERSHIPS



Support:



Universities



Schools



Companies



Institutions



Each partner can have:



Custom discount



Agreement notes



ACCOUNTING



Income:



Consultations



Laboratory



Procedures



Pharmacy



Expenses:



Salaries



Rent



Electricity



Water



Internet



Maintenance



Other expenses



Financial dashboard:



Revenue



Expenses



Profit



REPORTS



Generate:



Daily revenue



Monthly revenue



Patient statistics



Department statistics



Laboratory statistics



Pharmacy statistics



Expense reports



Export:



PDF



Excel



ATTACHMENTS



Allow upload:



Images



PDFs



Scanned reports



Ultrasound reports



External laboratory reports



Attach to patient records.



CERTIFICATES



Generate:



Medical Certificates



Sick Leave Certificates



Fitness Certificates



Printable format.



AUDIT LOG



Track:



Create



Update



Delete



Store:



User



Time



Previous value



New value



SYSTEM SETTINGS



Allow Admin to manage:



Medical center name



Logo



Currency



Receipt footer



Invoice footer



Contact information



PRINTING



Professional printable layouts for:



Prescriptions



Laboratory reports



Invoices



Medical certificates



A4 optimized.



SUPABASE INTEGRATION



Use existing Supabase project.



Connect all existing database tables.



Do not recreate tables.



Use existing schema.



Generate:



Pages



Components



Forms



Dashboards



Workflows



Based on existing Supabase tables.



FINAL REQUIREMENT



Build a complete production-ready MVP.



Prioritize:



Reception workflow.



Doctor workflow.



Laboratory workflow.



Pharmacy workflow.



Billing workflow.



The application must feel like a real medical center ERP/EMR system and be deployable immediately after testing.







https://jewzonxplxhogqrnhosl.supabase.co















eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impld3pvbnhwbHhob2dxcm5ob3NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzQ1MzgsImV4cCI6MjEwMjExMDUzOH0.jYy4Gevuv9s-AOIOYGkQynryNblR-zW4vUPr-tARMMI















The Supabase database is already created and contains the following core modules:















Authentication & Roles:







- users







- roles







- permissions







- role_permissions















Organization:







- branches







- departments















Patients & EMR:







- patients







- visits







- vitals







- clinical_notes







- diagnoses







- followups







- certificates















Appointments & Queue:







- appointments







- queue_tickets















Laboratory:







- lab_tests







- lab_parameters







- lab_reference_ranges







- lab_orders







- lab_order_items







- lab_results















Pharmacy:







- medicines







- pharmacy_inventory







- prescriptions







- prescription_items







- suppliers















Procedures:







- procedures_catalog







- procedure_orders







- procedure_results















Billing & Finance:







- invoices







- invoice_items







- payments







- expenses







- corporate_accounts















Administration:







- audit_logs







- system_settings















Please inspect the existing schema directly from Supabase and map the application to the existing tables. Do not recreate tables. Use the existing database structure.























Connect the application to my existing Supabase project.















Use the provided URL and anon key.















Do not create a new database schema.















Inspect and use the existing tables already available in Supabase.















Start by wiring:







1. Authentication







2. Roles & permissions







3. Reception module







4. Patients







5. Visits







6. Appointments







7. Billing















Then continue with Doctor EMR, Laboratory and Pharmacy modules.







CRITICAL IMPLEMENTATION RULES



Existing Database



The Supabase database already exists and contains production tables.



DO NOT:



Create new database schemas.



Create duplicate tables.



Rename existing tables.



Rename existing columns.



Create alternative versions of existing modules.



INSTEAD:



Inspect the existing Supabase schema.



Use the existing tables.



Map UI components to existing database tables.



Authentication



Authentication is mandatory from day one.



Implement:



Supabase Authentication



Login page



Password reset



On first launch:



If no Super Admin exists, display First-Time Setup Wizard.



Allow creation of the first Super Admin account.



Link auth users to users table and roles table.



After first Super Admin creation:



Disable public signup.



Only Super Admin can create users.



Do not use mock authentication.



Do not use local authentication.



Use real Supabase Auth only.



Authorization



Implement strict role-based permissions.



Reception must not access:



Accounting settings



Laboratory settings



System settings



Pharmacist must not access:



Clinical notes



Diagnoses



Lab users must not access:



Financial reports



Dentist must only see:



Assigned patients



Dental workflows



Super Admin sees everything.



Data Persistence



No local storage.



No mock data.



No fake datasets.



All CRUD operations must use Supabase.



Every form must:



Create



Read



Update



Delete



real database records.



Reception Workflow Priority



Reception workflow must be completed first.



Required flow:



Patient → Visit → Queue → Invoice → Payment



must work end-to-end before any advanced modules.



Medical Workflow Priority



Doctor workflow:



Patient → Vitals → Notes → Diagnosis → Prescription → Lab Order → Procedure Order



must be fully connected to Supabase.



Laboratory Workflow



Laboratory system must be dynamic.



Lab doctor can:



Add tests



Add parameters



Add reference ranges



CBC parameters must be editable.



Parameters may be optional.



System must not require all parameters.



Pharmacy Workflow



Support:



Internal prescriptions



External prescriptions



Patient may purchase medications outside Roshan pharmacy.



Dispensing workflow must support this.



Billing Workflow



Support:



Consultation



Laboratory



Procedures



Pharmacy



Invoices must be printable.



Payments must support:



Cash



Bankak



Accounting Workflow



Track:



Revenue



Expenses



Profit



Expenses include:



Salaries



Rent



Electricity



Water



Internet



Maintenance



Mobile Requirements



The system will be used primarily on Android devices.



Must be:



Mobile-first



Responsive



Installable PWA



All forms must be usable on a phone.



Deployment Rule



Do not stop after building UI.



Verify:



Authentication works.



Database writes work.



Database reads work.



Permissions work.



Only then consider a module completed.







Before generating code, inspect the Supabase schema first.







Return a list of all detected tables and relationships.







Wait for confirmation before building.







Do not build the entire system in one pass.







Build in milestones:







Phase 1:



Authentication + Roles + Reception







Phase 2:



Doctor EMR







Phase 3:



Laboratory







Phase 4:



Pharmacy







Phase 5:



Billing + Accounting







After each phase:



Show completed features and wait for approval before continuing.







Do not silently fail.







Display all database, permission, validation and API errors clearly.







Never hide errors behind placeholder data.







Do not generate demo patients, demo invoices, demo appointments or mock medical records.







Use real database records only.







Before building any module:







Create First Run Setup Wizard.







If no Super Admin exists:



Create Super Admin account first.







No module should be accessible before authentication is configured.







Before generating code, inspect the existing Supabase schema and return all detected tables and relationships. Wait for confirmation before building.

ROSHAN FINAL MASTER EXECUTION PROMPT



You are building a production-grade Medical Center ERP/EMR called ROSHAN.



IMPORTANT:



A real Supabase database already exists.



Project ID:

jewzonxplxhogqrnhosl



Before generating any code:



1. Inspect the connected Supabase schema.

2. Return all detected tables and relationships.

3. Verify that all expected ROSHAN tables exist.

4. Do not create new schemas.

5. Do not rename existing tables.

6. Do not rename existing columns.

7. Do not create duplicate modules.

8. Do not use local storage.

9. Do not use mock data.

10. Do not use placeholder authentication.

11. Use real Supabase Auth only.



====================================================

DATABASE RULES

====================================================



Use existing tables only.



Map all UI components directly to existing tables.



All CRUD operations must use Supabase.



Every feature must perform real database writes and reads.



====================================================

AUTHENTICATION

====================================================



Authentication is mandatory.



Implement:



- First Run Setup Wizard

- First Super Admin Creation

- Login

- Logout

- Password Reset

- Session Persistence



Requirements:



- If no Super Admin exists, show Setup Wizard.

- Create first Super Admin using Supabase Auth.

- Store auth user linkage in users table.

- Disable public signup after first Super Admin creation.

- Only Super Admin can create users.



Never use mock authentication.



====================================================

SECURITY

====================================================



Implement RLS policy migration.



Show migration SQL before applying.



Revoke anonymous access to all patient and business data.



Only authenticated users may access data.



Role-based permissions are mandatory.



Reception:

- Patients

- Visits

- Queue

- Billing



Doctor:

- Clinical records

- Diagnoses

- Orders



Pharmacist:

- Pharmacy only



Lab users:

- Laboratory only



Admin:

- Administrative functions



Super Admin:

- Full access



====================================================

PHASE 1

AUTH + USERS + RECEPTION

====================================================



Build:



- User management

- Roles

- Permissions

- Patient registration

- Patient search

- Patient editing

- Visit creation

- Queue generation

- Appointment scheduling

- Invoice generation

- Payment registration



Verify:



Patient

→ Visit

→ Queue

→ Invoice

→ Payment



works end-to-end against Supabase.



====================================================

PHASE 2

DOCTOR EMR

====================================================



Build:



- Vitals

- BMI calculation

- Clinical Notes

- Diagnoses

- ICD10 support

- Prescriptions

- Lab Orders

- Procedure Orders



Support:



Chief Complaint

HPI

PMH

PSH

Drug History

Allergy History

Family History

Social History

Examination

Assessment

Plan



Obstetrics:



- LMP

- EDD calculation

- Gestational Age calculation



Verify all writes against Supabase.



====================================================

PHASE 3

LABORATORY

====================================================



Build:



- Lab Dashboard

- Worklist

- Sample collection

- Result entry

- Verification

- Printable reports



Use existing tables:



lab_tests

lab_parameters

lab_reference_ranges

lab_orders

lab_order_items

lab_results



Requirements:



- Dynamic laboratory system

- Editable CBC parameters

- Optional parameters

- No forced completion



Default tests:



CBC

Blood Glucose

Urinalysis

Malaria Parasite

Pregnancy Test

Creatinine

Urea

ALT

AST



====================================================

PHASE 4

PHARMACY

====================================================



Build:



- Inventory

- Dispensing

- Stock tracking

- Expiry alerts

- Internal prescriptions

- External prescriptions



Requirements:



Patients may buy medications outside Roshan Pharmacy.



Support both workflows.



Use existing tables only.



====================================================

PHASE 5

BILLING + ACCOUNTING

====================================================



Build:



Invoices

Invoice Items

Payments

Expenses

Corporate Accounts

Partners

Discounts



Payment methods:



- Cash

- Bankak



Expenses:



- Salaries

- Rent

- Electricity

- Water

- Internet

- Maintenance

- Other



Dashboard:



- Revenue

- Expenses

- Profit



====================================================

REPORTING

====================================================



Generate:



- Daily Revenue

- Monthly Revenue

- Department Statistics

- Laboratory Statistics

- Pharmacy Statistics

- Expense Reports



Export:



- PDF

- Excel



====================================================

ATTACHMENTS

====================================================



Support:



- Images

- PDFs

- Ultrasound Reports

- External Laboratory Reports



Attach to patient records.



====================================================

PRINTING

====================================================



Create professional A4 print layouts for:



- Prescriptions

- Laboratory Reports

- Invoices

- Medical Certificates



====================================================

MOBILE REQUIREMENTS

====================================================



This application will be used primarily on Android phones.



Requirements:



- Mobile-first

- Fully responsive

- PWA installable

- Fast loading

- Arabic + English

- RTL support



====================================================

FINAL EXECUTION RULE

====================================================



Do NOT stop after generating UI.



Verify:



- Authentication works

- Permissions work

- Database writes work

- Database reads work

- Printing works

- Navigation works



For every completed phase:



Create a completion report containing:



1. Completed features

2. Database tables used

3. Remaining issues

4. Security concerns

5. Testing results



Only mark a phase complete after real Supabase testing.



Do not skip validation.

Do not use mock data.

Do not use local storage.

Do not continue silently if errors occur.

Display all errors clearly.

CRITICAL IMPLEMENTATION RULES

Existing Database

The Supabase database already exists and contains production tables.

DO NOT:

Create new database schemas.

Create duplicate tables.

Rename existing tables.

Rename existing columns.

Create alternative versions of existing modules.

INSTEAD:

Inspect the existing Supabase schema.

Use the existing tables.

Map UI components to existing database tables.

Authentication

Authentication is mandatory from day one.

Implement:

Supabase Authentication

Login page

Password reset

On first launch:

If no Super Admin exists, display First-Time Setup Wizard.

Allow creation of the first Super Admin account.

Link auth users to users table and roles table.

After first Super Admin creation:

Disable public signup.

Only Super Admin can create users.

Do not use mock authentication.

Do not use local authentication.

Use real Supabase Auth only.

Authorization

Implement strict role-based permissions.

Reception must not access:

Accounting settings

Laboratory settings

System settings

Pharmacist must not access:

Clinical notes

Diagnoses

Lab users must not access:

Financial reports

Dentist must only see:

Assigned patients

Dental workflows

Super Admin sees everything.

Data Persistence

No local storage.

No mock data.

No fake datasets.

All CRUD operations must use Supabase.

Every form must:

Create

Read

Update

Delete

real database records.

Reception Workflow Priority

Reception workflow must be completed first.

Required flow:

Patient → Visit → Queue → Invoice → Payment

must work end-to-end before any advanced modules.

Medical Workflow Priority

Doctor workflow:

Patient → Vitals → Notes → Diagnosis → Prescription → Lab Order → Procedure Order

must be fully connected to Supabase.

Laboratory Workflow

Laboratory system must be dynamic.

Lab doctor can:

Add tests

Add parameters

Add reference ranges

CBC parameters must be editable.

Parameters may be optional.

System must not require all parameters.

Pharmacy Workflow

Support:

Internal prescriptions

External prescriptions

Patient may purchase medications outside Roshan pharmacy.

Dispensing workflow must support this.

Billing Workflow

Support:

Consultation

Laboratory

Procedures

Pharmacy

Invoices must be printable.

Payments must support:

Cash

Bankak

Accounting Workflow

Track:

Revenue

Expenses

Profit

Expenses include:

Salaries

Rent

Electricity

Water

Internet

Maintenance

Mobile Requirements

The system will be used primarily on Android devices.

Must be:

Mobile-first

Responsive

Installable PWA

All forms must be usable on a phone.

Deployment Rule

Do not stop after building UI.

Verify:

Authentication works.

Database writes work.

Database reads work.

Permissions work.

Only then consider a module completed.

Do not continue to Doctor, Laboratory or Pharmacy modules until Phase 1 is fully working and tested against the real Supabase database.







After generating the migration SQL, show it first before any further changes.

I approve the direction, with two additions before applying the migration:















1. Add a unique constraint on users.auth_user_id.







Each Supabase Auth user must map to exactly one application user.















2. Add a created_by and updated_by audit pattern where possible for future tracking.















For RLS:















- Revoke anonymous access to patient, visit, laboratory, pharmacy, billing and accounting data.







- Only authenticated users may access application data.







- Super Admin keeps full access.























Build:







- First Run Setup Wizard







- Super Admin creation







- Login







- Password reset







- Role-based navigation







- Reception workflow























ROSHAN FINAL MASTER EXECUTION PROMPT







You are building a production-grade Medical Center ERP/EMR called ROSHAN.







IMPORTANT:







A real Supabase database already exists.







Project ID:



jewzonxplxhogqrnhosl







Before generating any code:







1. Inspect the connected Supabase schema.



2. Return all detected tables and relationships.



3. Verify that all expected ROSHAN tables exist.



4. Do not create new schemas.



5. Do not rename existing tables.



6. Do not rename existing columns.



7. Do not create duplicate modules.



8. Do not use local storage.



9. Do not use mock data.



10. Do not use placeholder authentication.



11. Use real Supabase Auth only.







====================================================



DATABASE RULES



====================================================







Use existing tables only.







Map all UI components directly to existing tables.







All CRUD operations must use Supabase.







Every feature must perform real database writes and reads.







====================================================



AUTHENTICATION



====================================================







Authentication is mandatory.







Implement:







- First Run Setup Wizard



- First Super Admin Creation



- Login



- Logout



- Password Reset



- Session Persistence







Requirements:







- If no Super Admin exists, show Setup Wizard.



- Create first Super Admin using Supabase Auth.



- Store auth user linkage in users table.



- Disable public signup after first Super Admin creation.



- Only Super Admin can create users.







Never use mock authentication.







====================================================



SECURITY



====================================================







Implement RLS policy migration.







Show migration SQL before applying.







Revoke anonymous access to all patient and business data.







Only authenticated users may access data.







Role-based permissions are mandatory.







Reception:



- Patients



- Visits



- Queue



- Billing







Doctor:



- Clinical records



- Diagnoses



- Orders







Pharmacist:



- Pharmacy only







Lab users:



- Laboratory only







Admin:



- Administrative functions







Super Admin:



- Full access







====================================================



PHASE 1



AUTH + USERS + RECEPTION



====================================================







Build:







- User management



- Roles



- Permissions



- Patient registration



- Patient search



- Patient editing



- Visit creation



- Queue generation



- Appointment scheduling



- Invoice generation



- Payment registration







Verify:







Patient



→ Visit



→ Queue



→ Invoice



→ Payment







works end-to-end against Supabase.







====================================================



PHASE 2



DOCTOR EMR



====================================================







Build:







- Vitals



- BMI calculation



- Clinical Notes



- Diagnoses



- ICD10 support



- Prescriptions



- Lab Orders



- Procedure Orders







Support:







Chief Complaint



HPI



PMH



PSH



Drug History



Allergy History



Family History



Social History



Examination



Assessment



Plan







Obstetrics:







- LMP



- EDD calculation



- Gestational Age calculation







Verify all writes against Supabase.







====================================================



PHASE 3



LABORATORY



====================================================







Build:







- Lab Dashboard



- Worklist



- Sample collection



- Result entry



- Verification



- Printable reports







Use existing tables:







lab_tests



lab_parameters



lab_reference_ranges



lab_orders



lab_order_items



lab_results







Requirements:







- Dynamic laboratory system



- Editable CBC parameters



- Optional parameters



- No forced completion







Default tests:







CBC



Blood Glucose



Urinalysis



Malaria Parasite



Pregnancy Test



Creatinine



Urea



ALT



AST







====================================================



PHASE 4



PHARMACY



====================================================







Build:







- Inventory



- Dispensing



- Stock tracking



- Expiry alerts



- Internal prescriptions



- External prescriptions







Requirements:







Patients may buy medications outside Roshan Pharmacy.







Support both workflows.







Use existing tables only.







====================================================



PHASE 5



BILLING + ACCOUNTING



====================================================







Build:







Invoices



Invoice Items



Payments



Expenses



Corporate Accounts



Partners



Discounts







Payment methods:







- Cash



- Bankak







Expenses:







- Salaries



- Rent



- Electricity



- Water



- Internet



- Maintenance



- Other







Dashboard:







- Revenue



- Expenses



- Profit







====================================================



REPORTING



====================================================







Generate:







- Daily Revenue



- Monthly Revenue



- Department Statistics



- Laboratory Statistics



- Pharmacy Statistics



- Expense Reports







Export:







- PDF



- Excel







====================================================



ATTACHMENTS



====================================================







Support:







- Images



- PDFs



- Ultrasound Reports



- External Laboratory Reports







Attach to patient records.







====================================================



PRINTING



====================================================







Create professional A4 print layouts for:







- Prescriptions



- Laboratory Reports



- Invoices



- Medical Certificates







====================================================



MOBILE REQUIREMENTS



====================================================







This application will be used primarily on Android phones.







Requirements:







- Mobile-first



- Fully responsive



- PWA installable



- Fast loading



- Arabic + English



- RTL support







====================================================



FINAL EXECUTION RULE



====================================================







Do NOT stop after generating UI.







Verify:







- Authentication works



- Permissions work



- Database writes work



- Database reads work



- Printing works



- Navigation works







For every completed phase:







Create a completion report containing:







1. Completed features



2. Database tables used



3. Remaining issues



4. Security concerns



5. Testing results







Only mark a phase complete after real Supabase testing.







Do not skip validation.



Do not use mock data.



Do not use local storage.



Do not continue silently if errors occur.



Display all errors clearly.







Never permanently delete medical, laboratory, pharmacy, billing or patient records.







Use soft delete only.







Store:



- deleted_at



- deleted_by







Allow Super Admin recovery.







Every critical action must create an audit log:







- User



- Timestamp



- Action



- Table



- Record ID



- Previous value



- New value



Prevent duplicate invoices, duplicate payments and duplicate dispensing caused by page refreshes or double clicks.







All financial operations must be idempotent.







Pharmacy inventory must never allow negative stock.







Laboratory consumables and pharmacy stock must be validated before dispensing.







Completed visits must become read-only.







Edits after completion require authorized users and must be audit logged.







Create an admin page showing:







- Database status



- Last backup date



- Supabase connectivity



- Storage usage







Create a Follow-Up system:







- Follow-up date



- Follow-up reason



- Follow-up status



- Missed follow-up tracking







Display upcoming follow-ups on dashboard.







This is a real medical center system.







Data integrity, security, auditability and patient safety are more important than UI appearance.







Prioritize correctness over visual polish.

The schema map is confirmed.







Do not use the service_role key.







For authentication:







Add a new column to the users table:







auth_user_id uuid







This column will store the Supabase Auth user id.







Authentication flow:







1. First Run Setup Wizard.



2. Create the first Super Admin account using Supabase Auth.



3. Store auth.uid() in users.auth_user_id.



4. Link roles through role_id.



5. Disable public signup after first Super Admin creation.



6. All future users are created by Super Admin only.







Before starting Phase 1:







Generate the SQL migration needed for auth_user_id and required RLS policies.







Show the migration first and wait for approval before applying it.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/98035a62-054b-42ec-97b9-1c792891bf33).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
