# Roshan Health Hub — Project State Snapshot

**Snapshot:** 2026-11-25 (read-only checks). Refresh all mutable values before any write or release decision.

## Repository

- Repository: `crauch2088-source/roshan-health-hub`.
- `main`: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- Open pull requests: **47**. Open issues: **4** (#199, #217, #218, #253).
- PR #299 is an open Draft documentation review. Its initial exact-head workflow run `45420778569` completed successfully; its Vercel deployment was intentionally ignored/cancelled because the change is documentation-only.
- Main workflow run `44872060499` and finance write-isolation run `44872060315` completed successfully on the mainline snapshot. Do not infer that skipped conditional acceptance jobs passed.
- Branch protection: latest issue evidence on 2026-11-15 says `main` was unprotected. A fresh branch-protection API read returned 403 (`Resource not accessible by integration`); current protection state is therefore **NOT VERIFIED**.

## Deployment/source parity

- Canonical Production alias resolves to a READY deployment built from `a9040601702972bdf144fc96b9658eebd5a6d31a`.
- Comparing that deployment SHA with current `main` shows 15 commits ahead and zero behind, and every changed path is documentation/specification only. No `src/`, `db/`, workflow or package files changed in that range. Therefore the older deployment SHA does **not** currently demonstrate application-code drift; runtime source appears code-equivalent to main.
- Do not trigger a deployment for documentation-only changes. Recheck the alias and code diff before any release.

## Repository hygiene findings

- The former `docs/MASTER_PLAN.md` was 562,393 bytes, 3,167 lines and 362 headings; it mixed an execution-policy copy, an old plan and append-only dated history.
- The former root `README.md` was 63,288 bytes / 432 lines and contained historical status snapshots dating mostly from 2026-10-17/18 and 2026-10-31.
- Twelve early phase/audit reports and a five-line legacy roadmap occupied the repository root. They are historical evidence, not active roadmap files.
- A prior documentation reorganization exists on PR #250, but its PROJECT_STATE/TASK_REGISTRY snapshot is dated 2026-11-14/15 and must not be reused without refresh.

## Supabase environments — read-only catalog

| Measure | Production | QA |
|---|---:|---:|
| Project ref | `jewzonxplxhogqrnhosl` | `hopfohcnrtbiqjkgeukz` |
| Public base tables | 56 | 58 |
| RLS enabled | 56/56 | 58/58 |
| FORCE RLS | 44/56 | 46/58 |
| Migration rows | 129 | 30 |
| Latest migration | `20261102232941` | `20261122152027` |
| SECURITY DEFINER functions (public + private) | 94 | 107 |
| SECURITY DEFINER executable by authenticated | 54 | 58 |
| SECURITY DEFINER executable by anon | 3 | 1 |
| SECURITY DEFINER with fixed empty search_path | 94/94 | 107/107 |

Production latest migration: `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal`. QA latest migration: `roshan_qa_secdef_search_path_hardening_20261122`.

**Interpretation:** the ledgers are not directly comparable by count; QA is a later curated baseline with environment-specific migrations. All catalogued SECURITY DEFINER routines currently have an empty fixed search_path, but this does not prove their bodies, grants or callers are safe.

## Security findings requiring action

1. `public.atomic_pharmacy_dispense(uuid, boolean, uuid)` in both Production and QA checks `pharmacy.update` and `billing.create` but does not enforce the canonical pharmacist role itself.
2. Production `public.fn_dispense_prescription_with_invoice(uuid, boolean)` checks the two broad permission bits but has no role gate. QA's wrapper enforces `pharmacist` or `legacy_pharmacist`; decide whether the legacy role is still valid and make both environments consistent.
3. Production `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` have `proacl = NULL` (default PUBLIC EXECUTE). QA has explicit owner-only ACLs. The private schema and callers still need a complete access-path review; this is tracked by Issue #218 / PR #260.
4. Supabase Security Advisor: Production reports 26 authenticated SECURITY DEFINER RPC warnings; QA reports 30. These are review inventory, not 26/30 confirmed vulnerabilities. Review each exposed function by body, ACL, role, schema and side effects.
5. `public.setup_required()` is SECURITY DEFINER and callable by anon in both environments; the current body returns a boolean from the private setup helper. This is an intentional public setup probe candidate, but must remain minimal and regression-tested.
6. `pg_trgm` is installed in public in both environments. Move only after dependency and migration review; it is not a reason for a blanket emergency migration.
7. Security Advisor reports two Production private tables and one QA private table with RLS enabled but no policies. These are private internal tables; verify schema/API exposure and grants rather than adding browser policies by reflex.
8. Auth leaked-password protection is warned in both environments. Check plan/feature availability and owner policy before treating it as a release blocker.

## PR and operational state

- PR #250: open Draft, head `832a8d38fba10409a44cd9eac7a4e34760aceaac`, base main `3bc317b0`. Twelve configured workflows on the exact head completed successfully. Reviews are owner-authored COMMENTED notes only; no independent second-person approval is recorded. The migration is not applied to either hosted environment.
- PR #260: private helper ACL test/phase 55 candidate; no review submissions recorded.
- PR #296: QA-only operational remediation; exact head `e8e1c961a70af606fc0eff732326e957085e13cd`, eight configured workflow runs completed successfully. QA ledger contains its 2026-11-21 operational-blocker migration and the 2026-11-22 search_path hardening migration; Production remains unchanged.
- PR #297: independent encrypted database backup/restore and off-site read-back evidence. Database restore evidence is strong; overall DR remains OPEN for policy acceptance, timed control-plane recovery and Storage/Vault scope.
- PR #299: initial full-project review and roadmap; this cleanup/re-review update is being added to the same isolated documentation PR.
- PR #295 contains useful clinical-guideline policy material but is based on old main `79d81f08` and contains stale claims (including PR status claims inconsistent with live GitHub). Do not merge it wholesale.

## Backup and disaster recovery

PR #297 records independent PostgreSQL 17 restore, checksum/integrity validation, eight critical row-count matches, structural parity (10 schemas, 99 tables, 394 indexes, 359 constraints, 78 triggers, 226 RLS policies, 246 functions/procedures, zero invalid indexes), and encrypted off-site Drive read-back. It also records zero Production Storage objects and zero Vault secrets at the time checked.

Overall DR remains OPEN: owner approval of cadence/RPO/RTO/retention, timed end-to-end control-plane recovery, Storage object-byte recovery before first real attachment, Vault/secrets recovery, and independent acceptance are outstanding. Proposed RPO 24h / RTO 4h / 30-day retention are proposals, not approved policy.

## Evidence limitations

- This is a dated read-only snapshot, not a guarantee that live state has not changed after 2026-11-25.
- No Production or QA writes, migrations, grants, deployments, settings changes or data changes were performed during this review.
- No direct clinical/staff acceptance or physical-printer acceptance was performed by this review.
- Branch protection is not currently verified because the integration was denied access.
- SECURITY DEFINER counts are catalog inventory only; they are not a substitute for function-by-function review.