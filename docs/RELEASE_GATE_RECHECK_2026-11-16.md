# Roshan Health Hub — Live Release-Gate Recheck

**Snapshot:** 2026-11-16 11:57 Africa/Khartoum (UTC+2).  
**Purpose:** Record a fresh, evidence-based status check before further release work. This is not a release approval.

## Executive decision

**Production remains NO-GO for live clinical use.** The application and database foundation are substantial, encrypted backup/restore evidence exists from the previous successful run, and the current Phase 61C pharmacist-only dispensing candidate passes its exact-head automated workflows. However, the candidate has not been independently reviewed by a second person, has not been applied to hosted QA, and the Production database still exposes the old dispensing RPC grants. Production/QA migration histories are materially divergent, and operational acceptance is incomplete.

Readiness remains **62% Engineering Release Candidate / 15% Operational Acceptance**. This recheck itself earns no implementation-completion credit.

## Evidence refreshed in this session

### GitHub and candidate Phase 61C

- Current main head observed: 79d81f08f6567f5145f7143e3bf5afdd6e93bf59 (late-session evidence documentation, 2026-11-15 22:06 UTC).
- Phase 61C candidate branch: fix/phase61c-atomic-dispense-role-boundary-20261114.
- Candidate head: c43c0258eb80760191b1b523128ddcb2c7537344.
- Current compare against main reports diverged: 62 commits ahead, 5 behind, with 26 changed files. Do not merge or update this branch by force-push/rebase. Reconcile it with current main using a normal merge commit, inspect the complete resulting diff (especially the large documentation/constitution changes), and rerun exact-head checks before any merge decision.
- All 11 PR-triggered workflow runs associated with the exact candidate head are completed with conclusion success. The CI run and dedicated Phase 61 PostgreSQL 17 workflow passed. The canonical baseline/authenticated clinical-acceptance job remains an intentional skip; a skipped acceptance job is not a pass.
- The Phase 61C migration moves the atomic dispense implementation into the private schema, revokes direct API-role execution on the unchecked implementation, and exposes a fixed-empty-search-path SECURITY DEFINER wrapper that requires the canonical pharmacist role plus pharmacy.update and billing.create. It also applies the same canonical-role gate to the invoice-linked dispensing RPC.
- Read-only static review in this session found the wrapper's helper dependency present in QA: private.app_has_role_permission(text[],text) is SECURITY DEFINER, uses an empty search_path, and checks the active, non-deleted app user, canonical role code and permission code. This is supportive source/catalog evidence, not a substitute for the required second-person SQL/security review or hosted role-switch acceptance.
- PR #250 has two COMMENTED reviews authored by the repository owner account and zero inline review threads. They are not evidence of an independent second-person approval. Keep the PR Draft.

### Live Production and QA database state

- Production project jewzonxplxhogqrnhosl: PostgreSQL 17.6, 129 migration rows, latest 20261102232941.
- QA project hopfohcnrtbiqjkgeukz: PostgreSQL 17.11, 27 migration rows, latest 20261113232719.
- The ledgers remain materially divergent. The previous 2026-11-15 reconciliation recorded only three shared version IDs (with different names and statement fingerprints), 126 Production-only IDs and 24 QA-only IDs. Never edit migration-ledger rows or replay one environment's ledger into the other.
- QA has Phase 61B, but Phase 61C is not applied to QA or Production.
- Read-only Production ACL check confirms both public.atomic_pharmacy_dispense(uuid,boolean,uuid) and public.fn_dispense_prescription_with_invoice(uuid,boolean) are still owned by postgres, SECURITY DEFINER, fixed-empty-search_path functions and are executable by authenticated and authenticator (not anon). This is the live role-boundary gap Phase 61C is intended to close.
- Production's private app_has_claim_branch(uuid) and sync_user_role_text() helpers still have default/PUBLIC-effective EXECUTE ACLs, unlike QA. Their call sites must be handled separately: the claim helper is referenced by RLS policies, so a blanket revoke could break authenticated insurance reads/writes.
- Production security advisor output includes two intentionally isolated private idempotency tables with RLS/no policies, pg_trgm in public, the intentional boolean bootstrap signal setup_required(), 26 authenticated-callable SECURITY DEFINER functions requiring per-function authorization review, and leaked-password protection disabled. Do not treat these generic advisor counts as proof that all functions are exploitable; do not blanket-revoke intended RPCs.

### Backup and recovery

- A previous encrypted Production PostgreSQL backup and isolated PostgreSQL 17 restore rehearsal succeeded, with owner-side Android/Termux integrity and decryption checks recorded in earlier evidence.
- The latest attempted backup-runner workflow (2026-11-15, run 43764265014) failed preflight because neither SUPABASE_DB_ACCESS_TOKEN nor SUPABASE_DB_PASSWORD is configured in the private backup-runner repository's Actions secrets. The backup job was skipped; this attempt produced no new artifact or restore rehearsal.
- Do not paste secrets into chat or source control. An owner must configure exactly one approved credential directly in the private repository, then authorize a fresh manual backup. Verify the resulting encrypted artifact and restore before any Production migration rollout.
- Backup scope remains PostgreSQL database only; Storage object bytes, Vault secrets, platform settings and credentials are not included.

### Repository governance

- Issue #253 records that main was unprotected and had no required status checks as of its 2026-11-15 read-only inspection. Passing CI is therefore advisory until branch protection and exact required contexts are configured.
- Configure protections only after confirming repository plan/permissions and selecting required contexts from actual workflow runs. Do not guess check names or weaken clinical/security gates.

## Independent review notes — Phase 61C

The SQL wrapper design is directionally sound on static inspection: it narrows the dispense boundary by requiring the canonical pharmacist role in addition to both operation permissions, keeps the unchecked implementation private, and preserves the empty search_path discipline. The exact-head disposable PostgreSQL 17 workflow passes, including Admin, Super Admin and synthetic legacy-pharmacist denial paths.

The following remain release blockers:

1. A genuinely independent second-person review of the exact current head and the full branch diff.
2. A normal merge of current main into the candidate branch, with conflict resolution and a fresh exact-head CI/PG17 pass. The 62-ahead/5-behind state and broad 26-file diff must be reviewed, not waved through.
3. A separately approved QA-only Phase 61C migration, followed by catalog/ACL read-back and authenticated role-switch/PostgREST tests proving Admin, Super Admin and legacy_pharmacist are denied while the canonical pharmacist is allowed.
4. Successful pharmacist acceptance of valid FEFO dispensing, invoice atomicity, idempotency/replay behavior, audit evidence, and rejection paths with zero stock/invoice/payment side effects.
5. Complete migration source/ledger/effective-catalog reconciliation and a fresh verified encrypted Production backup/restore before any Production rollout.
6. Staff UAT across reception → GP → lab → pharmacy → billing, plus Android/mobile RTL/LTR and physical A4/thermal-printer acceptance.

## Next execution order

1. Obtain the owner-controlled backup-runner credential setup and complete a fresh encrypted backup/restore.
2. Obtain an independent second-person review of PR #250; meanwhile keep it Draft and Production read-only.
3. Reconcile the candidate branch with current main using a normal merge commit; review all changed SQL, tests, workflows, Spec Kit/constitution and documentation files; rerun one exact-head CI/PG17 validation.
4. Only after those gates, apply Phase 61C to QA (not Production), then perform authenticated pharmacist/Admin/Super Admin/legacy-role acceptance and read back effective grants.
5. Continue the broader QA/Production migration and catalog reconciliation. Do not replay historical migration rows or apply the QA ledger to Production.
6. Complete real staff and physical-device acceptance before changing the NO-GO decision.

## Safety boundary

This session's database inspections were SELECT-only. No Production or QA DDL/DML, ACL/RLS/Auth/Storage changes, patient/clinical/financial writes, migration applications, PR merges, deployment promotions, backup dispatches, paid upgrades or quota bypasses were performed. The documentation candidate is a separate docs-only branch/PR; it does not change application behavior or deployment state.
