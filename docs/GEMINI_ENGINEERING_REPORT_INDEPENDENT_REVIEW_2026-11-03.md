# Independent technical review of the expanded Gemini engineering report

**Review date:** 2026-11-03  
**Repository snapshot:** `main` at `991f22b6890d5114b3e6ddf411d2c2dbc41eabb1`  
**Scope:** user-supplied `Roshan Engineering Architecture Review (1).md`, current repository source, merged PRs #153/#155/#156/#160, read-only production/QA Supabase evidence, and current official platform/API documentation.  
**Decision:** use the report as a research input, not as an execution script. Adopt selected improvements after evidence gates; reject or defer unsafe/stale recommendations.

## 1. Executive conclusion

The Gemini report contains several sound engineering directions, but it mixes old source snapshots with current code, treats some platform defaults as facts without checking project settings, overstates projected savings, and recommends destructive database operations that must not be repeated.

The most important corrections are:

1. **Do not drop and recreate the pharmacy idempotency table.** The live Phase 49 repair is already represented in production migration history and the current table shape was read back. A malformed prior table was renamed to a legacy quarantine name. The remaining legacy table is not a reason to drop either table without a separate dependency/data-retention review.
2. **Do not manually normalize or rewrite `schema_migrations`.** PR #160 has now recorded scoped SHA-256 source mappings for the four production Phase 49–52 migration statements that can be mapped. Two remediation rows remain quarantine evidence, not canonical migrations. Full migration-chain parity and full schema parity are still not proven.
3. **Do not replay production cleanup migration `20261102232941`.** Its original statement contains fixed production UUIDs; the public copy is deliberately redacted and non-executable. Static review found a broad soft-delete sweep and a stock reversal, without an explicit synthetic-record marker check or a check that both patient targets share a branch. Data-level correctness was not established because patient/financial rows were not read.
4. **The report's `addStock` example is stale.** Current inventory receiving calls `fn_receive_pharmacy_batch_atomic` with an idempotency key, validates positive whole-number quantity and expiry, and has a regression guard. The separate client-side inventory statistics query remains a real improvement candidate.
5. **The 82% CI savings claim is unproven.** Current `.github/workflows/ci.yml` has 18 job definitions and 15 PostgreSQL service declarations in this snapshot. A representative exact-head run recorded 18 jobs: 17 success and one intentional clinical-acceptance skip. No before/after billing-minute benchmark supports 82%.
6. **Backup/restore and authenticated clinical acceptance remain release gates.** Neither can be inferred from CI, migration fingerprints, or deployment readiness.

No production or QA database writes, grant changes, Auth/Storage changes, deployments, patient-row reads, or financial-row reads were performed during this review. The review is not a clinical sign-off.

## 2. Evidence hierarchy and verification method

Evidence was prioritized in this order:

1. Current `main` source and merged PR records, not old Drive exports or stale code excerpts.
2. Live Supabase migration ledgers and PostgreSQL catalog evidence for the two project refs.
3. Current test/workflow source and exact-head GitHub Actions job results.
4. Official current platform/API documentation.
5. The Gemini report's code excerpts and claims, treated as hypotheses until reproduced.

### Repository and PR state

- Current main snapshot used for this review: `991f22b6890d5114b3e6ddf411d2c2dbc41eabb1`.
- PR #153 patient-search error handling is merged; the current UI distinguishes a search failure from a successful empty result.
- PR #155 added the engineering improvement execution plan.
- PR #156 documented the live Phase 49–52 catalog/ledger reconciliation.
- PR #160 (`991f22b6890d5114b3e6ddf411d2c2dbc41eabb1`) documented scoped SHA-256 migration provenance and quarantine-only recovered artifacts. Its exact-head CI had 25 successful checks, one intentional skip and zero failures; the skipped canonical-baseline/authenticated-clinical-acceptance job remains deferred. Additional privileged-role, insurance, prescription atomicity, migration hash/delta and CodeQL runs succeeded.
- PR #160's production-target deployment was cancelled by the ignored-build-step rule because it contained documentation only. The existing canonical production alias remained attached to the previously READY application deployment for SHA `a00f8111f9d6f38e02cf850be398a1c16fee8265`; this documentation PR did not deploy a new application build.

### Live database snapshot

| Item | Production | QA |
|---|---:|---:|
| Project ref | `jewzonxplxhogqrnhosl` | `hopfohcnrtbiqjkgeukz` |
| Status at captured reconciliation | ACTIVE_HEALTHY | ACTIVE_HEALTHY |
| PostgreSQL | 17.6.1.155 | 17.11.0.003 |
| Migration-ledger rows | 129 | 17 |
| Latest migration | `20261102232941` | `20261102232905` |

The scoped reconciliation proves the following and no more:

- Production migration rows `20261102232823`, `20261102232849`, `20261102232852`, and `20261102232855` match the corresponding current Phase 49–52 source files after removing only the terminal `COMMIT;` wrapper and trailing whitespace.
- QA Phase 49 and Phase 50 match their source files; QA Phase 51 differs only by three leading explanatory comments and a blank line; QA Phase 52 matches the production Phase 52 statement and source after the same terminal-wrapper normalization.
- Production's four earlier 134-byte rows are placeholders, not the actual Phase 49–52 SQL.
- Production row `20261102232819` is an unmapped 223-byte table/index rename preserved only as a quarantine artifact.
- Production row `20261102232941` is an unmapped 3,285-byte cleanup/reversal block. Its original ledger SHA-256 is recorded as `e826d4947a497e61fcdde5b87ae4e1a8789523fa2979db048f6960b119e04c75`; the public copy redacts nine UUID occurrences across four distinct literals and is intentionally non-replayable.
- Six audited function-definition fingerprints, audited function flags, empty fixed search paths and EXECUTE ACLs match between the environments. The private idempotency table shape and the nine Phase 52 reporting indexes were also checked. This is not full schema parity, a full migration-chain replay, or runtime authorization testing.

## 3. Current source review: claims that changed since the report's source snapshot

### 3.1 Pharmacy receiving: already moved to an atomic RPC

The report quotes an older `addStock` path that increments `medicines.stock_quantity` in the browser and separately inserts `stock_movements`. That code is not the current receiving path.

Current `src/routes/_authenticated/inventory.tsx`:

- validates that quantity is finite, an integer and greater than zero;
- requires an expiry date;
- validates monetary input and precision;
- calls `supabase.rpc("fn_receive_pharmacy_batch_atomic", ...)`;
- passes a generated idempotency key;
- invalidates inventory, batch and medicine queries only after success.

`tests/inventory-receive-rpc.test.ts` guards against direct client inserts into `pharmacy_inventory` or `stock_movements`, direct stock-total updates, use of the legacy non-idempotent RPC, and omission of the idempotency key. The RPC was introduced in the production migration history as `20261018061746`.

**Decision:** do not re-implement the report's proposed atomic receiving RPC. Preserve the existing path and add any missing behavioral/concurrency tests only after inspecting the current SQL implementation.

### 3.2 Inventory statistics: still a legitimate candidate

The current inventory page still fetches `stock_quantity, reorder_level, cost_price` for every non-deleted medicine through `useRows`, then calculates low-stock count and total stock value in the browser.

This is an unbounded client-side aggregate. It can increase mobile transfer and rendering cost, and its result can be affected by any configured PostgREST row cap. The report's specific assertion that the current project necessarily truncates at exactly 1,000 rows was **not** verified. PostgREST's documented `db-max-rows` default is unlimited; a deployment can configure a hard cap. Do not hard-code “1,000” as a fact without reading the current Supabase API setting.

**Decision:** prioritize a bounded server-side aggregate only after defining the meaning of stock value and low-stock in the current batch/branch model. Prefer one permission-checked, branch-aware RPC returning exact aggregate values and coverage metadata; add synthetic PG17 tests for empty data, >1,000 medicines, branch isolation, NULL prices, and concurrent receiving/dispensing.

### 3.3 Patient search: report excerpt is stale

Current `src/lib/search.ts` centralizes search sanitization. `sanitizeTerm` removes commas, parentheses, percent, asterisk, backslash and quotes; patient list search is paginated and MRN-first. Patient picker queries are bounded. The current patient page calls `searchPatientsPaged`, not the older four-column `sanitizeSearch` snippet quoted in the report.

The older `sanitizeSearch` helper still exists in the audit and inventory screens, but the report's specific claim that the patient screen currently uses that old helper is not correct. The current search path does not prove that every search column has an optimal index; query-plan/index review can be a separate performance task. The available source evidence does not establish SQL injection.

**Decision:** reject the report's “current patient sanitizer vulnerability” claim as stale. Keep regression tests for filter escaping and MRN-first search. Review index coverage with `EXPLAIN (ANALYZE, BUFFERS)` on synthetic/local data before adding indexes.

### 3.4 CSV export: BOM is already implemented; export scope varies by caller

Current `csvExport` prepends UTF-8 BOM (`\uFEFF`). Therefore adding BOM is not a missing feature.

The shared `ExportButtons` component exports exactly the `rows` passed to it. Where a route passes the current page from `usePagedRows` (for example, the audit list), export is page-scoped, not automatically all matching rows. Other screens may pass a different collection.

**Decision:** do not re-add BOM. Add “export all filtered results” only as a route-specific, bounded, permission-preserving server export with a clear record count and tests. Avoid fetching unbounded PHI into the browser.

### 3.5 Search wildcard and filter safety

The current patient helper strips PostgREST filter grammar characters before composing `.or(...)`. The report's older example omitted the current shared helper. The audit/inventory local helpers are less comprehensive and deserve a small, isolated consistency review, but a wildcard in a search pattern is not by itself proof of SQL injection. Treat this as filter semantics and robustness, not a demonstrated database injection.

## 4. Live Supabase advisor snapshot and interpretation

A fresh advisor read at approximately 2026-11-03 08:24 UTC produced the following findings in both environments unless noted:

### Security

- `public.setup_required()` is SECURITY DEFINER and callable by `anon` (and authenticated). This is the intentional Phase 51 boolean-only bootstrap status contract, with an empty fixed search path and a private helper. Supabase flags it because anonymous callers can execute a SECURITY DEFINER function; the warning is not proof of data exposure. Keep its contract only after verifying the exact function body, owner, ACL and that it returns no user rows/counts/identifiers.
- Supabase reports 26 authenticated-callable SECURITY DEFINER functions. Many are the intended permission-checked clinical/financial RPC surface. A bulk revoke or blanket switch to SECURITY INVOKER would break required workflows. Review each function's caller identity, permission checks, branch checks, owner, fixed search path, dynamic SQL and exact grants.
- `pg_trgm` is installed in `public`, producing an extension-schema warning in both environments. Evaluate relocation only after checking dependent indexes/functions and testing the extension move in disposable PG17.
- `private.pharmacy_dispense_idempotency` has RLS enabled and no policies; the production legacy renamed table has the same informational finding. No direct browser-role table grants were found in the reconciliation. With no direct grants and a private schema, no-policy is a deliberate deny-by-default boundary, not a reason to add a permissive policy.
- Leaked-password protection is disabled in Supabase Auth in both advisor snapshots. This is a real hardening opportunity; enable it through the supported Auth settings after checking compatibility and staff password-reset impact.

### Performance

- Production advisor: 95 unused-index notices and two unindexed foreign-key notices on the production legacy idempotency table.
- QA advisor: 152 unused-index notices.
- “Unused” is not synonymous with “safe to drop”: the project is lightly used, statistics can reset, and many indexes are required for expected future clinical workload. Do not mass-delete indexes. Inspect index definitions, usage window, table size, query plans and constraints; treat legacy-table FK indexes separately after its retention/dependency decision.

## 5. Review of the 18 recommendations

| # | Gemini recommendation | Independent decision | Current evidence / safe next action |
|---:|---|---|---|
| 1 | Drop malformed Phase 49 idempotency table, rerun Phase 49, alter default privileges | **Reject as written** | Production has a repaired canonical table and a renamed legacy table. Never drop either with `CASCADE` without dependency and retention proof. Default privileges affect future objects for the role whose defaults are changed; they do not revoke existing grants. |
| 2 | Normalize QA/production migration ledger manually and run `plpgsql_check` over all functions | **Reject ledger edits; evaluate checker** | PR #160 has scoped source SHA-256 mappings. Keep placeholders and remediation rows documented. Do not edit migration history. Run `plpgsql_check` only in disposable PG17 after extension availability/compatibility review. |
| 3 | `age` + `pg_dump` encrypted backup and automated restore rehearsal | **Adopt as P0, not yet done** | Supabase Free does not include automatic daily database backups; official docs recommend regular CLI exports and off-site backups. Build a manual, least-privilege, encrypted backup and isolated restore drill. Include DB, Storage objects, configuration/roles and retention plan. Never upload plaintext or PHI dumps to GitHub/AI. |
| 4 | Merge PostgreSQL jobs, tmpfs, claim 82% savings | **Measure first; optimize selectively** | Current CI has 18 jobs and 15 PG service declarations; an exact run recorded 17 success + one intentional skip. Existing concurrency and npm cache are already present. Collect billable runner minutes and per-job duration before grouping. Preserve two-session concurrency and isolation tests. |
| 5 | Add pgTAP and supabase-test-helpers | **Conditional adopt** | Existing SQL/PG17 and role-guard tests already cover many contracts. Inventory gaps first; add pgTAP only where it improves RLS, grants, constraints or RPC assertions. Helpers are optional if JWT/session testing needs them. |
| 6 | Convert `addStock` and `inventory-stats` to atomic RPC | **Split decision** | `addStock` is stale; receiving already uses an atomic idempotent RPC. The all-medicines browser aggregate remains a valid optimization candidate, subject to branch/batch semantics. |
| 7 | Use Migra for schema drift | **Use Supabase CLI diff first; do not mandate Migra** | Current Supabase docs identify pg-delta as the default diff engine and Migra as legacy/optional. Generate diffs against a shadow database and review them; never auto-apply generated SQL to production. |
| 8 | Add zizmor, actionlint, Gitleaks | **Report-only evaluation; avoid redundant scanners** | Existing CodeQL, secret scanning/push protection, npm audit/lockfile checks and Dependabot cover several risks. Existing roadmap already recommends report-only actionlint/zizmor. Add Gitleaks only if a demonstrated gap remains. |
| 9 | Better Stack calls `setup_required()` to prevent Supabase pause | **Reject guarantee; retain health monitoring** | Free projects can pause after a low-activity seven-day window. Supabase says a few real requests per day is usually enough, but not guaranteed. A boolean setup RPC is not a robust application-readiness probe and cannot promise no pause. |
| 10 | Persist clinical drafts in IndexedDB | **Defer pending threat model** | On shared phones, offline PHI creates cross-user disclosure and stale-write risks. Require encryption/key lifecycle, session binding, short TTL, logout clearing, conflict handling, idempotent sync and audit before any clinical draft cache. |
| 11 | Export all CSV rows and add BOM | **Partially adopt** | BOM already exists. Full-result export is caller-dependent; implement only on screens where paginated export is demonstrably incomplete, using a bounded server-side export. |
| 12 | ReceiptLine + 58/80 mm thermal printing | **Evaluate after hardware decision** | No confirmed printer model, width, connection or Arabic glyph test. Validate on the actual Android/Honor browser and printer before adding a dependency. |
| 13 | NIH Clinical Tables autocomplete and allergy warnings | **Pilot terminology; separate allergy safety work** | Clinical Tables offers free APIs for ICD-10-CM, RxTerms and LOINC, but ICD-10-CM is US clinical modification, RxTerms is US RxNorm-derived terminology, and LOINC has terms of use. Do not equate these with Sudan's formulary or use naive text matching as allergy decision support. |
| 14 | Repomix, Knip, ast-grep | **Optional report-only tools** | Graphify is already integrated for optional code navigation. Repomix needs strict allowlists/secrets/PHI exclusion; Knip needs dynamic-route false-positive review; ast-grep rules should target proven direct-write violations. |
| 15 | Squawk + axe-core | **Squawk evaluate; axe already exists** | Playwright/Chromium and `@axe-core/playwright` are already used by the browser harness. Add no duplicate axe scanner. Run Squawk report-only against the actual migration dialect and PG17 before making it blocking. |
| 16 | FHIR R4 types and FHIRPath export | **Defer until an interoperability requirement exists** | Type packages do not provide a complete, valid FHIR implementation. A real exporter needs resource mapping, profiles, terminology, validation, consent and privacy review. |
| 17 | Replace ESLint/Prettier with Biome or use PGlite | **Defer** | Current stack uses ESLint 9/Prettier and has deliberately deferred ESLint 10 compatibility work. PGlite cannot replace full PG17 tests for extensions, roles, RLS and concurrency. |
| 18 | Replace Supabase with Medplum/OpenMRS or paid enterprise products | **Reject for current project** | No demonstrated requirement justifies a platform rewrite, operational migration or new recurring cost. Revisit only if the current platform becomes a measured blocker. |

## 6. Corrected execution order

### P0 — Database provenance and resilience (before any further production DB change)

1. Keep all recovered SQL under `docs/recovered-migrations/` quarantine. Never move it into the deployable migration directory.
2. Build a disposable PostgreSQL 17 fixture for the exact `20261102232819` table/index rename using synthetic names/objects.
3. Build a **parameterized synthetic equivalent**, not a replay of the redacted production SQL, for the `20261102232941` stock reversal and soft-delete contract. Test idempotency, branch attribution, both patient targets' branch equality, row-selection scope, rollback, and soft-delete-only behavior.
4. Complete an encrypted off-site logical backup and successful isolated restore rehearsal. Verify database schema/data, Storage objects, Auth/role configuration, extensions and required secrets separately. Document RPO/RTO and restore steps.
5. Do not perform further production DDL, manual migration-ledger repair, or data cleanup until provenance and backup/restore gates are accepted.

### P1 — Clinical workflow integrity and measured efficiency

1. Design the inventory statistics aggregate RPC after agreeing the stock semantics (medicine aggregate vs branch batch balances); preserve RLS/branch authorization and exact accounting.
2. Profile current GitHub Actions with actual billable minutes, runner OS, job durations, queue time and reruns. Group only compatible PG tests; keep concurrency and security tests isolated.
3. Triage Supabase advisor findings. Do not mass-revoke SECURITY DEFINER grants, add policies to private tables, or drop unused indexes.
4. Run actionlint/zizmor/Squawk report-only and add only actionable, non-duplicate checks.
5. Add pgTAP only for uncovered database contracts.

### P2 — Operational usability and terminology

1. Add route-specific complete filtered CSV export where needed; BOM already exists.
2. Trial NIH terminology search with no PHI sent, local catalog mapping, offline fallback and clinician review.
3. Decide receipt paper/printer hardware and test Arabic/English output on the actual phone/browser/printer.
4. Consider offline drafts only after a signed-off privacy/security model and explicit operational need.

### P3 — Interoperability and tooling experiments

FHIR export, Repomix/Knip/ast-grep expansion, Biome and PGlite remain optional experiments. They must not delay backup, migration reproducibility, inventory integrity or staff acceptance.

## 7. Release gates that remain open

- [ ] Encrypted off-site logical backup created, retained independently, and restore-tested in isolated PostgreSQL 17.
- [ ] Disposable PG17 tests for quarantined `20261102232819` and a synthetic, parameterized `20261102232941` contract pass.
- [ ] Full canonical migration-chain strategy and full schema parity are proven; scoped Phase 49–52 hashes are not a substitute.
- [ ] Authenticated QA workflow tests pass with an authorized synthetic clinician/staff identity.
- [ ] Staff UAT covers receptionist, GP, lab, pharmacy and finance on phone-sized devices, Arabic RTL and English LTR.
- [ ] Any production database change has a separate reviewed migration, verified backup, explicit rollout/rollback plan and post-change catalog readback.

The intentional CI skip for canonical-baseline/authenticated-clinical-acceptance is **not** a pass. A READY Vercel deployment is not a clinical release sign-off.

## 8. Owner decisions (only when the corresponding work is ready)

- Backup destination and custody of the `age` private identity. Never send the secret key in chat or commit it.
- Whether PostHog remains in use; if retained, technical aggregate telemetry only, with clinical-screen replay and PHI capture disabled.
- Actual printer model, width (58/80 mm) and connection method.
- Authorized synthetic QA identities and staff time for the combined UAT session.
- Before any data purge: confirm current production data classification from a read-only inventory and decide retention. Do not infer data contents from old report examples.

The currently planned operating model remains one active clinic branch; do not reopen the multi-branch decision unless the owner reports a real operational change.

## 9. Sources

### Repository evidence
- [PR #153 — patient search error handling](https://github.com/crauch2088-source/roshan-health-hub/pull/153)
- [PR #155 — engineering improvement execution plan](https://github.com/crauch2088-source/roshan-health-hub/pull/155)
- [PR #156 — live Phase 49–52 reconciliation](https://github.com/crauch2088-source/roshan-health-hub/pull/156)
- [PR #160 — scoped Phase 49–52 SHA-256 provenance recovery](https://github.com/crauch2088-source/roshan-health-hub/pull/160)
- [Live Phase 49–52 reconciliation](LIVE_PHASE49_52_RECONCILIATION_2026-11-03.md)
- [Phase 49 source](../db/roshan_phase49_atomic_pharmacy_dispense.sql)
- [Atomic inventory receiving regression guard](../tests/inventory-receive-rpc.test.ts)
- [Current patient search helper](../src/lib/search.ts)
- [Current inventory page](../src/routes/_authenticated/inventory.tsx)
- [Current CSV export helper](../src/lib/db.ts)

### Official platform and API references
- [Supabase Free Project Pausing](https://supabase.com/docs/guides/platform/free-project-pausing) — low activity over seven days; a few real user requests per day are typically enough but not guaranteed.
- [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups) — Free projects should regularly export via Supabase CLI and maintain off-site backups; database backups do not include Storage objects.
- [Supabase CLI local workflows](https://supabase.com/docs/guides/local-development/cli-workflows) — includes `db dump`, `db diff`, `migration list` and `db reset` behavior.
- [Supabase diff engines](https://supabase.com/docs/guides/local-development/diff-engines) — pg-delta is the default; Migra is legacy/optional.
- [GitHub Actions billing and usage](https://docs.github.com/en/actions/concepts/billing-and-usage) and [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) — included usage depends on repository visibility and account plan; standard runners in public repositories are free, while private-repository usage draws on plan allowance.
- [NLM Clinical Table Search Service](https://clinicaltables.nlm.nih.gov/), [ICD-10-CM API](https://clinicaltables.nlm.nih.gov/apidoc/icd10cm/v3/doc.html), [RxTerms API](https://clinicaltables.nlm.nih.gov/apidoc/rxterms/v3/doc.html), and [LOINC API](https://clinicaltables.nlm.nih.gov/apidoc/loinc/v3/doc.html) — dataset scope, versioning and terms must be checked before clinical use.
- [PostgREST configuration](https://docs.postgrest.org/en/stable/references/configuration.html) — `db-max-rows` is configurable; its documented default is unlimited, so the exact Supabase project cap must be verified rather than assumed to be 1,000.
- [Web Serial API compatibility](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) — limited availability and secure-context requirement.
- [age encryption tool](https://github.com/FiloSottile/age) — public recipient keys encrypt; private identity keys decrypt and require separate custody.

## 10. Final disposition

The Gemini report is **partially accepted as a source of candidate improvements, not accepted as a production execution plan**. Its highest-value contributions are the backup/restore programme, inventory statistics aggregate, measured CI optimization, additional database-contract tests, and terminology/printing exploration. Its most dangerous instructions—dropping the idempotency table, replaying/normalizing migration history, broad default-privilege changes, and unverified cleanup—are explicitly rejected.

The next work should be the two synthetic PostgreSQL 17 quarantine fixtures and the encrypted backup/restore design, followed by a focused inventory-statistics design. No production migration or data cleanup is part of this review.
