# Independent release audit — Gemini report reconciliation

**Date:** 2026-11-15  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Reviewed main commit:** `f8c8b2d1767643561599764405b4cdbfd4db2c79`  
**Review type:** read-only source, PR, CI metadata, and hosted PostgreSQL catalog/ACL verification.

## 1. Purpose and evidence rules

This document records a second-pass reconciliation of the Gemini audit supplied on 2026-11-15. The Gemini report is treated as a set of hypotheses, not as an authoritative release decision.

Evidence labels:
- **CONFIRMED — live DB:** returned by a read-only query against the named hosted Supabase project.
- **CONFIRMED — main source:** present in the checked-in source at the reviewed main commit.
- **CONFIRMED — PR candidate:** present only on the named open PR branch; not treated as merged or deployed.
- **PARTIALLY CONFIRMED:** the underlying limitation exists, but the report overstates its meaning or omits relevant scope.
- **NOT CORROBORATED:** not found in the reviewed main source, current migration ledgers, or the PR records inspected.
- **NOT TESTED:** requires an authenticated runtime, synthetic role test, restore rehearsal, or human acceptance.

This is an AI-assisted source/database cross-check. It is **not** a second-person professional security sign-off, a clinical safety approval, or a go-live authorization.

## 2. Current baseline and hosted migration state

The reviewed main HEAD is `f8c8b2d1767643561599764405b4cdbfd4db2c79`. Its only combined status returned by the GitHub status endpoint was the Vercel check, successful. This is a documentation-only main commit; that status is not a complete application acceptance run.

A batched SELECT-only catalog query returned:

| Item | Production | QA |
|---|---|---|
| PostgreSQL | 17.6 (repository ledger evidence) | 17.11 (repository ledger evidence) |
| Latest migration | `20261102232941` — synthetic patient cleanup / stock-ledger reversal | `20261113232719` — Phase 61B clinical role boundary |
| Phase 58/59 receipt-currency provenance | Not recorded | Recorded |
| Phase 61B | Not recorded | Recorded |
| Phase 61C atomic-dispense role wrapper | Not recorded | Not recorded |
| `get_invoice_payment_receipt_status_v2(uuid[])` | Not present | Present |
| `fn_receive_pharmacy_batch_atomic(...)` | Present | Present |
| `get_pharmacy_inventory_summary(...)` | Not present | Not present |

The QA ledger state above is newer than the historical 2026-11-13 manifest section and is directly supported by the 2026-11-15 read-only query. Do not use old QA row counts or the stale Phase 61B status in earlier manifest paragraphs as the latest state. The Production/QA migration histories remain materially divergent; do not repair them by copying ledger rows, blind replay, or timestamp reassignment.

No DDL, DML, migration application, ACL change, deployment, or business-data write was performed in this review.

## 3. Confirmed security and data-integrity findings

### F-01 — direct authenticated stock-quantity updates remain possible

**Severity: HIGH — confirmed live in both environments.**

The read-only catalog query returned all of the following in both Production and QA:
- `has_table_privilege('authenticated', 'public.medicines', 'UPDATE') = true`
- `has_column_privilege('authenticated', 'public.medicines', 'stock_quantity', 'UPDATE') = true`
- The active `medicines_update` RLS policy uses `app_has_perm('pharmacy.update')` in both `USING` and `WITH CHECK`.

This means an authenticated caller who satisfies that permission policy can update `medicines.stock_quantity` directly through the Data API, bypassing the intended batch-receipt/stock-ledger workflow. The exact set of users who currently hold that permission was not enumerated in this query; the permission gate is nevertheless present and the SQL grants are real.

Important correction to Gemini's wording:
- **Main UI does not contain a direct stock-increment/addStock write.** The inspected `src/routes/_authenticated/inventory.tsx` creates a new medicine with `stock_quantity: 0`; the receive-stock action calls `fn_receive_pharmacy_batch_atomic`.
- The vulnerability is therefore a **database privilege/RLS boundary**, not proof that the current inventory UI itself increments stock directly.
- The same inventory screen calculates low-stock count and stock value in the browser from a plain `useRows` query without exact-count pagination. This is a separate completeness/performance risk for large catalogues; actual truncation at the live project row cap was not measured.

**Relevant candidate remediation:** PR #210's Phase 60 migration revokes broad authenticated UPDATE on `medicines` and grants UPDATE only on identity fields. Its PostgreSQL integration test explicitly asserts that authenticated no longer has table-level UPDATE, only five identity columns remain writable, and an Admin's attempt to change `selling_price` plus `stock_quantity` fails with insufficient privilege. This is a meaningful candidate regression, not live protection: PR #210 is still open, has no recorded review submissions, and is not applied to either hosted environment. Independent review and exact-head test verification remain required.

### F-02 — Production private-helper EXECUTE ACL drift

**Severity: HIGH — confirmed live in Production; QA is hardened.**

Production currently has:
- `private.app_has_claim_branch(uuid)`: SECURITY DEFINER, fixed empty `search_path`, `proacl IS NULL`, and `authenticated` has effective EXECUTE.
- `private.sync_user_role_text()`: SECURITY DEFINER, fixed empty `search_path`, `proacl IS NULL`, and `authenticated` has effective EXECUTE.
- `authenticated` has USAGE on schema `private`.

QA has explicit owner-only ACLs for both functions and `authenticated` does not have effective EXECUTE. Production's default function ACL therefore exposes direct authenticated execution of these private helpers, unlike QA. The anonymous role lacks USAGE on `private`; this review does not claim an anonymous API exploit.

This corroborates Issue #218. Do not apply its correction as a standalone hotfix: first complete the documented migration/source reconciliation, dependency/call-site review, encrypted backup and isolated restore gates, and obtain explicit owner authorization for any Production migration.

### F-03 — live atomic dispense entry point is not yet pharmacist-role-bound

**Severity: CRITICAL release gate — confirmed live in both environments.**

The live `public.atomic_pharmacy_dispense(uuid, boolean, uuid)` in both Production and QA is SECURITY DEFINER with an empty fixed `search_path`, executable by `authenticated`, and its body checks broad `app_has_perm('pharmacy.update')` plus `app_has_perm('billing.create')`. It does not itself require the canonical `pharmacist` role before entering the idempotency workflow. The nested RPC differs by environment: Production's `public.fn_dispense_prescription_with_invoice(uuid, boolean)` has the same broad permission-only checks and is directly executable by authenticated users. The live Production role-permission matrix gives both `pharmacy.update` and `billing.create` to `admin`, `super_admin`, `legacy_admin`, and `pharmacist`. Therefore a non-pharmacist Admin-class account can invoke the Production dispensing workflow directly; this is a confirmed authorization-boundary failure, not merely a missing UI guard. Production's nested function also still contains `COALESCE(pi.quantity, 1)` fallbacks. QA's nested RPC is already wrapped by Phase 61B and checks the role (`pharmacist` or `legacy_pharmacist`) plus both permissions; the live legacy-pharmacist permission set lacks those two permissions, so it is denied. QA's outer atomic RPC remains broad until Phase 61C, but the nested guard currently rejects non-pharmacists within the same transaction.

PR #250 contains a forward-only Phase 61C wrapper that:
1. moves the unchecked implementation into `private`;
2. revokes direct API-role execution on the unchecked function;
3. checks the canonical `pharmacist` role together with both required permissions at the public RPC boundary; and
4. retains the existing FEFO, branch, invoice and idempotency implementation.

That candidate is **not applied to QA or Production**. The current PR records passing disposable PostgreSQL 17 checks, but the PR has zero submitted review records and zero inline review threads. It must remain a release blocker until the exact integrated migration is independently reviewed and replayed in QA.

The current live RPC also accepts `p_separate_invoice boolean` from its caller and passes it into the idempotency payload and nested dispense function. This is a client-supplied business choice, but the Production function's own comment documents the expected rule: a finalized primary invoice requires an explicit secondary-invoice choice. It is **not established as a vulnerability** by this review. Keep it as a contract-test item: both allowed invoice paths must be validated by the server-side invoice helper, and an idempotency replay with a changed choice must be rejected.

### F-04 — inventory receive path is RPC-backed; the report's UI-write claim is overstated

**Severity: correction to audit report.**

Main source confirms:
- `BatchesTab` validates quantity and amount inputs and calls `fn_receive_pharmacy_batch_atomic`.
- The medicine-creation form inserts a catalogue row with zero stock.
- No `.update()` call against `medicines.stock_quantity` was found in the inspected inventory source.

The database-level direct-update privilege in F-01 remains a real risk despite the current UI path being RPC-backed.

### F-05 — prescription validation is completeness-only; no automatic dose engine is present on main

**Severity: clinical release gate / intentional safety boundary.**

Main `PrescriptionTab.tsx` imports `validatePrescriptionDrafts` from `src/lib/prescription-draft.ts`. That validator checks required fields (medicine name, dose, frequency, duration, and positive whole-number quantity); it does not calculate or recommend a dose. Pediatric missing-weight handling is a warning, not a hard save block, and the UI explicitly tells clinicians that pediatric doses are not calculated automatically.

No Phase 63 validator migration/RPC or dedicated Phase 63 source integration was found in the reviewed main migration ledger or the inspected main prescription component. The Gemini assertion that a Phase 63 validator exists but is not wired into main is therefore **not corroborated** by the current main evidence. If the report's ZIP contained an unmerged validator, it must be supplied as a precise branch/commit before it can be reviewed.

Do not add automated dosing merely to satisfy a checklist. Any future decision-support engine requires a separately approved clinical source, formulation/route/strength identity, weight/age/renal/allergy constraints, dose ceilings, explicit prescriber override, and clinical validation.

### F-06 — QA nested dispense wrapper retains a legacy-role alias

**Severity: MEDIUM — no current QA permission path demonstrated; latent role-boundary weakness.**

The live QA `public.fn_dispense_prescription_with_invoice(uuid, boolean)` wrapper uses the allowlist `['pharmacist','legacy_pharmacist']` and requires both `pharmacy.update` and `billing.create`. The current live `legacy_pharmacist` permission set contains only `pharmacy.edit`, `pharmacy.view`, and `reports.view`; it lacks both required permissions, so the role is denied today. PR #250's integration test models that exact permission matrix and confirms denial on both the atomic and nested RPCs.

However, the PR test itself comments that the Phase 61B legacy alias remains an independent-review item. If those two permissions were ever granted to `legacy_pharmacist`, the nested RPC's allowlist would permit it even though Phase 61C's outer atomic wrapper is canonical-`pharmacist` only. If the intended policy is strictly canonical pharmacist, remove the legacy alias in a separate forward-only correction or add a durable database guard preventing that role from acquiring the required permission pair. This is a latent future-configuration risk, not a currently demonstrated QA bypass.

## 4. PR-by-PR reconciliation

| PR / issue | Current evidence | Reconciliation |
|---|---|---|
| **#250 — Phase 61C dispense role boundary** | Open; base main `f8c8b2d`; candidate head `27a9a592`; 0 reviews, 0 inline threads. Exact-head issue record reports passing CI/PG17 tests with an intentional clinical-acceptance skip. | Candidate addresses F-03 but is not deployed. Review `p_separate_invoice` policy and retest after integration. |
| **#210 — Phase 60 catalogue identity / pack attestation** | Open; head `f041ac9`; 0 reviews, 0 inline threads. | Migration restricts medicine UPDATE to identity fields, addressing F-01 if merged/applied. Its SQL tests explicitly assert the column ACL and deny an Admin's price/stock update. The PR explicitly defines verification as a saved-identity attestation, not proof of a physical pack, batch, expiry, manufacturer label, or branch. Treat it as a limited attestation, not a physical-pack verification hard-stop. The helper also allows the explicit Super Admin bypass. |
| **#181 — payment receipt model and print** | Open; head `a49e261`; changed-file list contains no SQL migration; receipt model builds a read-only document from a saved payment, invoice and Phase 59 ledger status. Two review submissions are authored by the repository owner account; 0 inline threads. | The dedicated receipt-table/sequential-receipt-number concern is partly supported: this PR adds no receipt-table migration or server sequence. Whether a separate receipt entity/number is required is a product/accounting decision; saved payment + immutable ledger provenance may be sufficient if the approved receipt policy says so. The Gemini statement that Phase 58/59 are not applied to QA is stale: the live QA ledger contains both; Production does not. |
| **#179 — prescription print/workflow** | Open; 39 commits ahead / 29 behind main; six overlapping paths identified in the current issue body; 0 reviews, 0 inline threads. | Do not merge or overlay as-is. Three-way reconcile the prescription composer, pharmacy screen, package/test guards and print paths against current main and Phase 61 boundaries; run fresh exact-head checks. Historical green checks predate current main. |
| **#218 — Production private helper ACL** | Open. Read-only Production catalog confirms the two helper ACL gaps; QA is owner-only. | Confirmed P1/P0-class release blocker; remediation must wait for migration reconciliation, backup/restore, review and owner approval. |

### PR #181 — important correction

The current QA database has `get_invoice_payment_receipt_status_v2(uuid[])` and Phase 58/59 migration rows. Production does not. The PR #181 issue text saying these phases are absent from hosted QA is out of date relative to the 2026-11-15 read-only query. Always prefer the current live catalog over stale PR narrative.

## 5. Gemini report claims not accepted as established facts

1. **“inventory.tsx still has client-side addStock.”** Not supported by the inspected main UI. The current receive-stock action is RPC-backed. The separate database direct-update grant in F-01 is confirmed and is the stronger, precise finding.
2. **“Phase 62 inventory summary RPC is unapplied.”** No such RPC was found in either live environment; the current inventory screen uses client-side aggregation. The Phase 62 name and SQL artifact were not found in the reviewed main manifest. Treat this as an uncorroborated Phase label, not a verified migration that merely awaits application.
3. **“Phase 63 validator exists but is not wired.”** No Phase 63 artifact or main integration was established. Main has completeness validation only. Request the exact artifact/commit if Gemini used an unmerged bundle.
4. **“Phase 58/59 are absent from QA.”** False as of the 2026-11-15 live read: both are recorded in QA. They remain absent from Production.
5. **“PR #181 has no SQL.”** Confirmed for the PR's changed-file list. The absence of a dedicated receipt table/sequence is a design question to resolve, not automatically a database exploit.
6. **“PR #210 verifies the physical medicine pack.”** Overstated. Its own scope says the event attests to saved catalogue identity only; it is not physical label, batch, expiry, or branch verification.
7. **“Admin / Super Admin are allowed prescribers in the current main PrescriptionTab.”** Not supported. Main's `isClinicalPrescriber` allowlist contains `doctor`, `legacy_gp`, `legacy_specialist`, and `legacy_dentist`; it does not contain `admin` or `super_admin`. PR #179's historical test notes also describe Admin prescription-authoring denial. Admin's identity-edit permission in PR #210 is a separate catalogue role, not prescriber authority.

## 6. Review and release gates still open

Priority order for the next engineering pass:

1. **P0 — stock authority:** complete an independent review of PR #210's column-level UPDATE policy and PostgreSQL tests. Prove authenticated users with `pharmacy.update` cannot update `medicines.stock_quantity` directly, while catalogue identity edits still work for the explicitly approved roles. Do not apply to hosted DBs until approved.
2. **P0 — dispense role boundary:** independently review PR #250 SQL and test the exact integrated Phase 61B → 61C upgrade on disposable PostgreSQL 17. Prove Admin/Super Admin and legacy roles cannot enter dispensing or create idempotency/stock/invoice side effects; canonical pharmacist can dispense and retry idempotently. Contract-test both `p_separate_invoice` paths and reject a replay whose invoice-choice payload changes.
3. **P0 — Production helper ACL:** complete source/call-site and migration-order review for Issue #218; only after verified encrypted backup + isolated restore and explicit owner approval.
4. **P1 — finance/receipt policy:** define whether the receipt must have its own immutable sequential number/table or whether the saved payment ID plus persisted ledger/currency evidence is the canonical receipt. Confirm Phase 58/59 on QA and prepare a separate Production rollout only after backup/restore and migration reconciliation.
5. **P1 — migration divergence:** reconstruct the exact forward delta from Production's latest ledger to the approved target. Do not copy QA history or replay unknown/redacted Production SQL.
6. **P1 — clinical and staff acceptance:** retain no-auto-dose behavior unless a separately validated clinical decision-support specification is approved. Complete synthetic authenticated role E2E and later on-site staff/printer UAT before operational sign-off.

## 7. Explicit safety boundary and status

- This review performed SELECT-only SQL against Production and QA.
- No patient, visit, prescription, stock, invoice, payment, or other business row was created or modified.
- No migration, grant, RLS policy, role mapping, Storage setting, deployment, merge, PR state, or issue state was changed.
- AI review does not replace an independent human PostgreSQL/security review or clinical governance.

**Decision:** Roshan remains **NOT READY for real-world clinical use** until the critical stock-authority, pharmacist-only dispensing, Production ACL, migration/backup, and human acceptance gates are closed with exact evidence. Gemini's numerical overall score (23/100) is its own scoring output; this reconciliation does not validate that number or adopt it as a measured project percentage.



## 8. Post-audit follow-up correction — 2026-11-15

The initial F-01 statement that authenticated direct `medicines.stock_quantity` updates remain possible is corrected by a later catalog/trigger inspection:

- Both Production and QA have an enabled `BEFORE INSERT OR UPDATE OF stock_quantity` trigger named `trg_guard_medicine_stock_aggregate`, invoking `private.guard_medicine_stock_aggregate()`. The function uses an empty fixed search path and rejects authenticated direct non-zero stock inserts and stock-quantity changes with `medicine_stock_is_rpc_managed`.
- A rollback-only synthetic QA transaction confirmed that both Pharmacist and Admin stock-quantity updates are rejected by this trigger. The same transaction confirmed that direct `medicines.selling_price` updates still succeed for those roles under the broad table UPDATE grant and `medicines_update` RLS policy. The transaction was rolled back; follow-up SELECTs confirmed zero synthetic Auth users, app users or medicine rows remain.
- A read-only Production catalog query confirmed the same enabled stock trigger, broad `selling_price` UPDATE privilege/policy, and `pharmacy.update` plus `billing.create` role grants for Admin, Super Admin, legacy Admin and Pharmacist. No Production DML was attempted.
- Therefore the precise Phase 60 exposure is broad direct catalogue-field mutation (including price), **not** an unguarded direct stock-quantity update. PR #210's column-level UPDATE restriction remains a valid candidate boundary; its PG17 test should continue to prove that only the five approved identity columns remain directly writable.

A second rollback-only synthetic QA JWT test confirmed the current outer `atomic_pharmacy_dispense` path allows Admin and Super Admin to reach its argument guard, while the Phase 61B nested invoice-linked RPC rejects them; the canonical Pharmacist reaches the nested implementation's deliberate NULL-argument guard. No dispense or financial/inventory side effect occurred. The four synthetic users were rolled back and verified absent. This supports the need for PR #250 Phase 61C.

The fresh Production backup dispatch `43764265014` stopped at preflight because `SUPABASE_DB_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` are both missing from the backup-runner repository. No database dump began. The prior encrypted artifact remains in Drive but is dated 2026-11-12; owner-side decryption remains unverified.

The new Phase 63 candidate on PR #255 adds a database trigger and UI/client completeness guard; exact code-head CI passed 345/345 unit/guard tests and the dedicated PostgreSQL 17 Phase 63 integration job. It remains unmerged and unapplied to hosted QA/Production. This follow-up is an AI-assisted evidence correction, not independent human security sign-off or clinical acceptance.

No hosted Production DDL/DML, migration, ACL change, deployment, merge or business-data write was performed during this follow-up.
