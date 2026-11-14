# Release-gate recheck — 2026-11-13

This report is a read-only checkpoint. It separates source code, QA-applied migrations, Production-applied migrations, deployed application code, backup/restore evidence and operational acceptance.

## Repository and GitHub Actions

- Main: c04864f82c0aadc113860964b7b03f6b1ad145d1.
- Open PRs: #236, #233, #229, #210, #185, #181 and #179 (all Draft/non-mergeable at this read). Open Issues: #199, #217 and #218.
- Main CI [43196963014](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43196963014): 18 successful jobs, zero failures, one intentional authenticated clinical-acceptance skip.
- CodeQL [43196962915](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43196962915): Python and JavaScript/TypeScript passed. Finance integration [43196963021](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43196963021) and clinical-child RPC integration [43196963257](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43196963257) succeeded.
- Main's combined GitHub status still has a Vercel FAILURE context whose target is the Hobby build-rate-limit page. This is not a failure of the canonical READY production deployment. No quota bypass or paid upgrade was attempted.
- Seven open PRs and three open Issues were read directly. PR #229 is at head 9c54ee0655acfafdbb1f3509f4de7ed10be6a420, 40 ahead / 15 behind main, and non-mergeable. Its Phase 61 PostgreSQL 17, CI, prescription, insurance, privileged-role, Spec Kit and insurance-UI workflows passed; no submitted reviews or inline threads exist. Its Phase 61 SQL file remains on the Draft branch, not main.

## Production and QA Supabase

| Measure | Production | QA |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows | 129 | 26 |
| Latest migration | 20261102232941 | 20261112061251 |
| Phase 55 ACL migration | absent | 20261103155227 |
| Phase 57 quantity guard | absent | 20261104065852 |
| Phase 57B free-text/external guard | absent | 20261111215510 |
| Phase 61 correction workflow | absent | 20261111223309 |
| Phase 58 SDG provenance | absent | 20261112061219 |
| Phase 59 receipt provenance | absent | 20261112061251 |

The ledgers share only three version IDs; all three have different names and stored statement fingerprints. Production-only versions: 126. QA-only versions: 23. Production contains four superseded 134-byte Phase 49–52 placeholders. QA has a later duplicate Phase 50 row and four forward migrations added after the 2026-11-10 source-map snapshot. Do not reconcile these ledgers by manual INSERT, blind replay or timestamp rewriting.

### Pharmacy guard read-back

- Production: quantity nullable; 0 active non-deleted NULL-quantity items; three NULL-to-one fallbacks; no quantity, free-text or external-prescription guard.
- QA: quantity nullable; 0 active NULL-quantity items; zero fallbacks; all three guards present.
- The UI fail-closed path does not fix the Production RPC. Phase 57 and 57B are QA-applied only.
- Phase 55 private helper ACLs: Production has PUBLIC-effective EXECUTE on private.app_has_claim_branch(uuid) and private.sync_user_role_text(); QA is owner-only for both and denies anon/authenticated/service_role.

### Effective catalog snapshot

Catalog signatures differ across both projects. Production has 56 public / 4 private tables, 842 public columns, 222 constraints, 254 indexes, 210 policies, 69 triggers and 143 public/private functions. QA has 58 public / 2 private tables, 873 public columns, 245 constraints, 258 indexes, 212 policies, 81 triggers and 152 functions. Both have five public views and zero invalid/not-ready indexes. QA-only Phase 61 tables and Phase 58/59 currency provenance are expected forward differences; Production's two additional private tables include quarantined legacy/remediation artifacts. Full object-level semantic reconciliation remains open. Exact category fingerprints are recorded in LIVE_EFFECTIVE_CATALOG_RECONCILIATION_2026-11-10.md.

## Supabase advisors

Observed 2026-11-13 around 06:57 UTC:

| Project | Security | Performance | Health |
|---|---:|---:|---:|
| Production | 5 groups / 31 findings | 2 groups / 96 findings | 0 |
| QA | 5 groups / 34 findings | 2 groups / 147 findings | 0 |

Production security: 29 WARN and 2 INFO; QA: 33 WARN and 1 INFO. Performance findings are INFO-only (Production 2 unindexed FKs + 94 unused indexes; QA 7 unindexed FKs + 140 unused indexes). The intentional boolean setup_required() SECURITY DEFINER exposure, private RLS/no-policy idempotency tables, and callable authenticated SECURITY DEFINER RPCs require function-by-function review, not blanket revocation or policy creation.

## Vercel

- Canonical READY Production deployment: dpl_GNX1VuGgArr8CsMPZn2KB9Hz4eQz.
- Deployed app SHA: fb54651533ffd04b2f20387a976f88293110c513.
- Canonical alias roshan-health-hub.vercel.app is present and verified; aliasError=null.
- Main is 16 commits ahead of the deployed app SHA, but the delta has no src/ files and package.json dependency sections are unchanged (only test:guard script changed). The runtime application source is unchanged; no deployment was triggered.

## Backup runner, encrypted artifact and restore

- Backup-runner main: f171732b61fe0460c61a36aa63b861065f9ea9d1.
- Latest runner-main CI [43190851147](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43190851147) passed validator and offline Android-verifier tests.
- Latest full backup/restore [43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) ran on parent SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8. Both jobs passed. The job step “Create and locally restore encrypted backup” passed; “Upload encrypted artifact only” passed. The single later commit to runner main changes README.md and the offline Android verification script/tests only; the backup workflow itself is unchanged.
- GitHub artifact 13927247998: 305,284 bytes, SHA-256 digest 54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9, expiry 2026-11-13 08:35:58 UTC (not expired at the 06:56 UTC check).
- Off-site Drive copy: [roshan-production-backup-43183851731.zip](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk), 305,284 bytes, MD5 22271054f6c10b1baf1d23ac4bdac24e, not trashed, in the dated 2026-11-12 child folder. Metadata read-back succeeded.
- The runner-side PostgreSQL 17 isolated restore rehearsal passed. Owner-side decryption of this latest artifact remains unverified; the private age identity was not accessed. The archive covers PostgreSQL only, not Storage object bytes or Supabase control-plane/secrets.

## Gate disposition

- **Passed:** main CI and CodeQL (with clinical acceptance deliberately skipped); Phase 57/57B source and QA application; Phase 55/61/58/59 QA applications; backup artifact existence; runner-side PostgreSQL 17 restore; encrypted off-site Drive copy; canonical Vercel deployment/alias.
- **Failed or divergent:** main Vercel status context is rate-limit failure; Production/QA migration ledgers and effective catalog are not in parity; Production Phase 55/57/57B/58/59/61 changes are absent; Phase 55 helper ACL drift persists.
- **Blocked/unverified:** owner-side decryption of the latest artifact; independent second-person SQL/security review; complete migration-source and object-level semantic reconciliation; explicit Production change window and forward-recovery approval; operational pharmacist/prescriber, staff, Android and printer acceptance.
- **Explicitly deferred:** authenticated clinical E2E until an isolated free environment and suitable synthetic doctor/pharmacist identities are available. The previously documented transactionally rolled-back Phase 61 synthetic request/reject smoke is not broad clinical or staff acceptance.

## Next concrete task

Reconcile Draft PR #229 with current main using a normal two-parent merge commit; resolve only the actual overlaps, preserve Phase 57/57B fail-closed behavior and Phase 61 authorization/no-side-effect contracts, then run one exact-head CI/PG17 pass. Keep Draft for independent SQL/security review and mobile pharmacist/prescriber acceptance. Do not merge the PR or apply Production migrations.

No Production/QA writes, backup dispatch, PR merge or deployment promotion occurred during this recheck.
