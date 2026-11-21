# Roshan Health Hub — Master Plan

Purpose: authoritative strategic roadmap and release sequence. Live mutable facts are cached in docs/PROJECT_STATE.md and must be refreshed from GitHub, Supabase, and Vercel before action.
Last roadmap review: 2026-11-15. Repository: crauch2088-source/roshan-health-hub.

## Current execution snapshot

- Current main: f8c8b2d1767643561599764405b4cdbfd4db2c79. Its latest commit is documentation-only (PR #251 UX comparison). Current-head Finance-only RPC isolation run 43644032032 and CodeQL run 43644032038 passed. The latest full CI is 43527161767 on prior application SHA a9040601702972bdf144fc96b9658eebd5a6d31a; do not label it a full CI run on f8c8b2d.
- Critical security candidate: PR #250 Phase 61C, branch fix/phase61c-atomic-dispense-role-boundary-20261114, code/test head f3a81b0ef8b110127433b828e75c2d92909e9e73, Draft and mergeable. Exact-head CI 43686671277: 18 jobs passed, one canonical baseline/authenticated clinical acceptance job intentionally skipped, zero failures. Dedicated Phase 61 PG17 run 43686671156 passed; all 10 exact-head workflow runs concluded success. Independent reviews and inline review threads remain 0/0.
- PR #250 now includes explicit disposable-PG17 denial coverage for legacy_pharmacist on both atomic and nested invoice-linked dispensing. The candidate wrapper requires the canonical pharmacist role and both pharmacy.update and billing.create. It is not applied to hosted QA or Production.
- PR #210 is the separate Phase 60 medicine catalogue identity/pack-attestation candidate, not Phase 61C. Its current head is f041ac9fa0e3cb4114346984e3d1393ad972e18f; exact-head CI 43646371012 has 19 successful jobs, one intentional clinical-acceptance skip, and zero failures. Keep Draft; the human pack-attestation workflow and independent review remain open.
- Phase 61 correction workflow and deterministic medication-engine foundation are in main through PR #249. The medication engine is arithmetic/matcher foundation only, not a complete drug recommender or active protocol engine. Never invent doses or activate clinical protocols.
- Live migration ledgers: Production 129 rows/latest 20261102232941; QA 27 rows/latest 20261113232719. Three version collisions have different names and statement payloads; 126 Production-only and 24 QA-only. Never edit ledger rows or replay mismatched history to manufacture parity.
- QA has Phases 55, 57, 57B, 58, 59, 61 and 61B. Production lacks these forward corrections. QA Phase 57 rejects missing prescription quantity; Production still has three COALESCE(pi.quantity,1) fallbacks. Phase 57B free-text/external guards are present in QA and absent in Production.
- Live role audit: each project has one active canonical pharmacist and zero active legacy_pharmacist users. The legacy role has only pharmacy.edit, pharmacy.view and reports.view in both projects. Do not grant permissions; Phase 61C intentionally excludes the legacy role from dispensing pending a separate reviewed compatibility decision.
- Production Phase 55 private helper ACLs remain PUBLIC-effective; QA is owner-only. Supabase advisors: Production 31 security / 95 performance / 0 health; QA 34 / 147 / 0. Triage findings by function/table and call sites; no blanket revokes or index drops.
- Canonical Vercel alias roshan-health-hub.vercel.app maps to READY deployment dpl_G9jScsLW3jDXFePVZLQgedwMMKRH on SHA a9040601702972bdf144fc96b9658eebd5a6d31a. Newer docs-only Production deployment attempt dpl_5YyUYp838yV3ws7uCVurH9bJQvxA for f8c8b2d was CANCELED; no new application deployment occurred.
- Backup runner main is f171732b61fe0460c61a36aa63b861065f9ea9d1; CI 43190851147 is validation-only. Last complete encrypted backup and isolated PostgreSQL 17 restore is run 43183851731 on runner SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8. Its GitHub artifact expired, but the 305284-byte encrypted Drive copy remains present in folder 2026-11-12 (MD5 22271054f6c10b1baf1d23ac4bdac24e). Owner-side decryption of this latest copy remains unverified; backup scope excludes Storage object bytes and Vault secrets.
- Last evidence-weighted baseline: 62% Engineering RC / 15% Operational Acceptance. This run's documentation and audit work does not increase either percentage. Conditional estimate to Engineering RC remains 20–35 focused engineering hours; calendar release ETA is not defensible while independent review, migration reconciliation and human acceptance remain open.

## Execution order

1. Obtain independent second-person SQL/security review of PR #250's complete Phase 61C migration and tests. Keep Draft; do not apply to QA or Production before review and the documented QA release gate.
2. Reconcile Production/QA migration source, statement fingerprints, Phase 55 helper ACLs, Phase 57/57B quantity/free-text/external guards, and Phase 58/59 currency provenance. Preserve both migration ledgers; plan only reviewed forward-only changes.
3. After independent review, prepare a QA-only Phase 61C application and read-back gate. Production remains read-only and NO-GO.
4. Complete owner-side offline decryption verification of the retained Drive archive; use a fresh full backup/restore only through the documented owner-controlled credential and confirmation process. Do not trigger a backup write during routine audits.
5. Keep authenticated clinical E2E deferred until a free isolated environment and suitable synthetic doctor/pharmacist identities exist. Then collect clinician, pharmacist, reception, finance, mobile RTL/LTR, keyboard and physical-print acceptance.
6. Continue Phase 60 catalogue attestation (PR #210) only after its exact-head checks, independent SQL/security review and pharmacist physical-pack acceptance. The attestation is a human assertion, not barcode/lot/expiry verification or a dispensing hard-stop.

## Completion and release semantics

- Separate implemented source, QA-applied changes, Production-applied changes, deployed changes and operationally accepted workflows.
- A skipped or unavailable mandatory check is not a pass. CI, source review, a deployment status, an uploaded archive or a runner validation job cannot substitute for the specific gate they do not test.
- Do not declare launch readiness until migration/source parity, independent security review, backup/restore, all required checks, and clinical/pharmacy/staff acceptance are evidenced.
- No Production DDL/DML, privilege revocation, clinical/financial records, external backup writes, merge or deployment promotion without the documented release gates.

## Reference map

| Need | Canonical reference |
|---|---|
| Current live evidence | docs/PROJECT_STATE.md and dated docs/RELEASE_GATE_RECHECK_*.md |
| Migration provenance and collisions | docs/DB_MIGRATION_RECONCILIATION.md |
| Integration routing | docs/PLUGIN_TOOLING_MAP.md |
| Task priority | GitHub Issues/PRs and docs/TASK_REGISTRY.md |
| Test/acceptance routing | docs/VERIFICATION_MATRIX.md |
| Durable safety/owner authority | .specify/memory/constitution.md |
| Agent startup and operating rules | docs/AGENT_START_HERE.md, docs/AGENT_EXECUTION_PROTOCOL.md and AGENTS.md |

Historical execution narrative is preserved in docs/archive/MASTER_PLAN_HISTORY.md. Historical snapshots are evidence, not current status.