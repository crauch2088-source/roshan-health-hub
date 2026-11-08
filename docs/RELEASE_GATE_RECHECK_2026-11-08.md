# Release-gate recheck — 2026-11-08

Audit time: 2026-11-08 08:24 Africa/Khartoum  
Scope: current repository, GitHub Actions, both Supabase projects, Supabase advisors, Vercel production deployment/aliases, private backup runner and the existing private Drive destination.

This is a read-only operational audit. No database DDL/DML, privilege changes, Auth/Storage mutations, backup dispatch, external backup write, deployment, merge, or clinical/financial record creation was performed. No secret values or patient/financial rows were read.

## 1. Repository and CI

- Default branch: `main`.
- Main SHA: `17eb097052019ec32a4ec18395a73c023ac4cc18` — `docs: record 2026-11-07 release gate recheck`.
- GitHub reports the main branch as **not protected**; required status checks are not enforced by branch protection. This is a release-governance gap, not a reason to bypass the existing CI.
- Main commit check suite: 23 check runs, **22 success, 1 skipped, 0 failures**.
  - CI run [42354307485](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42354307485): 18 jobs succeeded; the job named “Canonical PG17 baseline replay and authenticated clinical acceptance” was skipped. The skip is not a clinical acceptance pass.
  - Finance-only RPC write-isolation run [42354307457](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42354307457): 2/2 jobs succeeded.
  - CodeQL push run [42354306221](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42354306221): JavaScript/TypeScript and Python analyses succeeded.
  - Within CI, the Phase 37 disposable PostgreSQL 17 baseline/forward replay, migration-source parity manifest, atomic pharmacy dispense/invoice integration, Phase 49 quarantined remediation contract, clinical security hardening, typecheck, lint and build all succeeded.
- Open pull requests in this repository: 11 — #191, #189, #185, #179, #188, #187, #186, #181, #157, #112 and #103. Open non-PR issue: [#199 — release gates](https://github.com/crauch2088-source/roshan-health-hub/issues/199).
- [PR #191](https://github.com/crauch2088-source/roshan-health-hub/pull/191), Phase 57 pharmacy missing-quantity guard: Draft, mergeable, head `de6e43fb794c3afaf6ccfe527f809cf144ce2ece`. Exact-head CI [42355337661](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42355337661): 18 success, 1 intentional clinical-acceptance skip, 0 failures. Supporting prescription atomicity, privileged-role, insurance integrity and insurance UI workflows passed.
- [PR #189](https://github.com/crauch2088-source/roshan-health-hub/pull/189), medicine catalogue identity: Draft, mergeable, head `360c3ae693ace3b510bb2f80df1ea3c2e3f82ac2`. Exact-head CI [42355329812](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42355329812): 18 success, 1 intentional clinical-acceptance skip, 0 failures. Role-scope and physical-pack audit-attestation limitations remain unresolved.
- The private backup-runner repository has a separate open Draft PR #2; see section 6.

## 2. Supabase projects and live migration ledgers

Both projects report `ACTIVE_HEALTHY`.

| Environment | PostgreSQL | Migration rows | Latest migration |
|---|---:|---:|---|
| Production `jewzonxplxhogqrnhosl` | 17.6.1.155 | 129 | `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` |
| QA `hopfohcnrtbiqjkgeukz` | 17.11.0.003 | 22 | `20261104065852 roshan_phase57_pharmacy_quantity_required_guard` |

The live ledgers are **not identical**: Production retains the full historical chain and reconciliation/archive entries; QA starts from a platform-preserving baseline and applies a selected forward sequence. The main-branch migration-source parity CI job passed, but that CI contract does not prove identical live migration ledgers or complete environment parity.

### Phase 57 pharmacy quantity guard

- QA has Phase 57 migration `20261104065852` applied. Its current `fn_dispense_prescription_with_invoice(uuid, boolean)` explicitly rejects an active catalogue-linked prescription item where `pi.quantity IS NULL`, raises `prescription quantity is required`, and no longer substitutes a one-unit default.
- Production does **not** have Phase 57. Its live dispensing function still contains the `COALESCE(pi.quantity,1)` fallback in the three invoice/aggregate/dispense paths. Production can still interpret a missing quantity as one unit.
- `prescription_items.quantity` remains nullable in both databases. Current aggregate-only read checks found zero active non-deleted prescription items with NULL quantity in either environment; that does not remove the future-risk or replace the guard.
- Both projects currently report 0 Storage objects, 0 Vault secrets and 3 Storage buckets. These are current preflight counts only; they do not prove a backup or restore.

**Release decision:** do not apply Phase 57 to Production until the encrypted off-site backup and isolated restore gates pass, migration/source parity is reviewed, and the production rollout is independently validated.

## 3. Supabase advisors

### Health
- Production: 0 health findings.
- QA: 0 health findings.

### Security
- Production: 5 finding groups — 2 private RLS-enabled tables with no policies (INFO; private tables intentionally deny direct browser access), 1 `pg_trgm` extension in `public` (WARN), 1 anon-executable SECURITY DEFINER `public.setup_required()` (WARN; intentional boolean-only bootstrap contract, still merits explicit review), 26 authenticated-executable SECURITY DEFINER RPCs (WARN; inspect per-function authorization, do not blanket-revoke), and leaked-password protection disabled (WARN).
- QA: 5 groups — 1 private RLS-enabled table with no policies (INFO), the same `pg_trgm` and anon `setup_required()` warnings, 28 authenticated-executable SECURITY DEFINER RPCs, and leaked-password protection disabled.
- These advisor categories are triage signals. No blanket grant revocation or RLS policy change is authorized by this audit.

### Performance
- Production: 95 unused-index INFO findings and 2 unindexed foreign keys on the quarantined legacy private idempotency table.
- QA: 144 unused-index INFO findings.
- Do not drop indexes from these low-severity reports without workload and query-plan evidence. Assess the two legacy-table FK indexes only after confirming the quarantined table's retention/dependency status.

## 4. Vercel deployment and canonical alias

- Project: `roshan-health-hub`, ID `prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`.
- Latest Production-target deployment for current main SHA `17eb097...`: `dpl_2vNcNDHf555SEhtVxPwtF2WZyUxU`, **CANCELED** by the expected documentation-only build skip.
- Latest READY Production deployment: `dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv`, commit `6daf1f15be23aa391bd40bc38f671c00c842b446` (PR #193 A4 print CSS).
- The canonical alias `roshan-health-hub.vercel.app` is attached to that READY deployment; Vercel reports `aliasError=null`. The READY deployment also has the project and main aliases.
- This distinguishes the latest repository commit (documentation-only) from the currently deployed application commit. It is not authenticated UI, physical A4, staff, or clinical acceptance.

## 5. Backup runner and off-site artifact

- Private runner main SHA: `9bc9bd7c203614e7173d1413936d92a483a691ad`.
- Latest workflow on runner **main**: [42358343245](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42358343245), 2026-11-07 09:07 UTC. `validate` succeeded; `backup` was skipped; no GitHub artifact exists.
- Latest workflow overall: [42361589067](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42361589067), 2026-11-07 09:53 UTC, on Draft PR #2 head `a49628332857df4ace2be821d2c9da902589689f`. `validate` succeeded; `backup` was skipped; no GitHub artifact exists.
- Private runner [PR #2](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/2) adds a fail-closed database-password fallback alongside temporary JIT access, SSL-only URL construction and regression tests. It remains Draft; validation success is not a backup.
- The connected Google Drive account is active. The existing private folder “Roshan Health Hub Backups” exists, is owned by the connected account, is not shared and is not trashed. Direct-child listing returned no files; no shared drives were listed. No encrypted off-site backup artifact or checksum is present.
- No successful backup job, isolated PostgreSQL 17 restore rehearsal, decryptability check or Drive upload is evidenced.
- Presence of owner-managed Actions secrets/variables was not inspected. Secret values and the private age identity were not read. No backup workflow was dispatched during this audit.

## 6. Release-gate matrix

| Gate | Current state | Evidence / blocker |
|---|---|---|
| Main CI and CodeQL | Completed with one explicit skip | Main checks 22 success / 1 skipped / 0 failed; clinical acceptance skip is not a pass. |
| Migration source CI contract | Passed | Main CI migration-source parity manifest succeeded. |
| Live Production/QA ledger parity | Incomplete | 129 vs 22 rows and different baseline/forward histories; Phase 57 is QA-only. |
| Phase 57 in QA | Applied | Migration `20261104065852`; explicit NULL rejection present. |
| Phase 57 in Production | Not applied / blocked | Production still has the three NULL-to-one fallbacks. |
| Supabase health advisors | Clear | 0 findings in both projects. |
| Supabase security/performance advisors | Open findings | Warnings/INFO groups documented above; no blanket remediation. |
| Production Vercel alias | Ready | Canonical alias attached to READY deployment `dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv`; current-main docs-only deployment canceled. |
| Encrypted off-site backup | Not done | Both latest runner jobs skipped backup; GitHub artifacts absent; Drive folder empty. |
| Isolated restore rehearsal | Not done | No completed backup/restore job or restore evidence. |
| QA authenticated pharmacist/doctor acceptance | Deferred | No approved synthetic doctor/pharmacist identity and authorized acceptance path. |
| Staff UAT and physical A4/mobile print | Not accepted | No staff workflow sign-off or physical printer evidence. |
| Main branch protection | Not enabled | GitHub reports `protected=false`, no required status checks. |

## 7. Next highest-value task

1. Complete owner-controlled backup setup: verify SSL enforcement without changing it blindly, configure exactly one approved database credential secret path and the public `AGE_RECIPIENT` variable directly in the private runner settings, keeping all values out of ChatGPT. Review Draft PR #2 before relying on its fallback.
2. Only after the owner confirms setup, dispatch the manual backup with its explicit confirmation; verify the encrypted artifact, SHA-256, off-site Drive copy and isolated PostgreSQL 17 restore; then revoke temporary credentials.
3. Reconcile and independently review the live migration chain, then plan the Production Phase 57 rollout under the documented release gate.
4. Keep authenticated clinical/pharmacy E2E deferred until the isolated free test environment and suitable synthetic doctor/pharmacist identities are available. Complete staff UAT and physical A4/mobile print acceptance separately.
5. Obtain owner-approved branch rules requiring the CI checks before allowing direct main changes.

No Production or QA business data was changed. No Production migration, privilege change, deployment, backup dispatch or merge was performed.
