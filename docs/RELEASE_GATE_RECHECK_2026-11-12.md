# Roshan Health Hub — live release-gate recheck

**Observed:** 2026-11-12 06:11–06:17 UTC  
**Repository base:** \`main\` \`52d975180e505c922dbe7a9b3260365bf59179b1\`  
**Decision:** **NO-GO for Production pharmacy migrations or release promotion.** This is a read-only operational recheck plus documentation reconciliation. No hosted DDL/DML, privilege change, clinical/financial record write, backup dispatch, PR merge or deployment promotion occurred.

## 1. Repository and CI

- Current main: \`52d975180e505c922dbe7a9b3260365bf59179b1\`.
- Open PRs: 10. Open issues: 3 (\`#199\`, \`#217\`, \`#218\`).
- Latest main workflows at this snapshot:
  - [CI #43167067722](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067722): in progress.
  - [Push on main #43167067448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067448): in progress.
  - [Finance-only RPC isolation #43167067870](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067870): success.
- The immediately preceding main SHA \`a12cc5492d1f7169270115ce5bd179718160dd32\` had CI [#43165386576](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43165386576), push [#43165386573](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43165386573), and finance integration [#43165386595](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43165386595) successful.
- PR #210 remains Draft. Its exact head \`a018d988182b949803d919149a958d2d23a21b18\` passed CI [#43166072673](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43166072673) and its Phase 60 workflow [#43166061024](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43166061024). This is engineering validation, not physical-pack or pharmacist acceptance.
- PR #229 remains Draft. Its latest documented exact-head CI [#43113777098](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777098), Phase 61 PG17 [#43113777087](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777087), prescription atomicity [#43113777097](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777097), insurance integrity [#43113777177](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777177), privileged-role [#43113777134](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777134), Spec Kit [#43113777216](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777216), and insurance UI [#43113777163](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43113777163) succeeded on its prior head. Those checks do not replace independent review or human acceptance.

## 2. Live Supabase migration ledgers and effective pharmacy behavior

Both projects report \`ACTIVE_HEALTHY\`.

| Measure | Production | QA |
|---|---:|---:|
| PostgreSQL | 17.6.1.155 | 17.11.0.003 |
| Ledger rows | 129 | 24 |
| Latest version | \`20261102232941\` | \`20261111223309\` |
| Active prescription items with NULL quantity | 0 | 0 |
| Legacy \`COALESCE(pi.quantity,1)\` fallback | present | absent |
| Phase 57 NULL guard | absent | present |
| Phase 57B free-text/external guard | absent | present |
| Phase 61 correction tables | 0 | 2 |

QA-only phase rows:

- Phase 55: \`20261103155227\` — \`roshan_phase55_clinical_parent_guard_acl_reconciliation\`.
- Phase 57: \`20261104065852\` — \`roshan_phase57_pharmacy_quantity_required_guard\`.
- Phase 57B: \`20261111215510\` — \`roshan_phase57b_free_text_external_prescription_guard\`.
- Phase 61: \`20261111223309\` — \`roshan_phase61_prescription_item_correction_workflow\`.

Production has none of those four versions. Production still permits the legacy NULL-to-one dispensing fallback; zero current NULL rows do not remove the future risk.

### Ledger parity

A read-only comparison of every ledger row by version, name, statement byte length and MD5 gives:

- 3 shared version numbers.
- 126 Production-only versions.
- 21 QA-only versions.
- All 3 shared version numbers have different migration names and statement fingerprints.

The collisions are not equivalent migrations:

| Version | Production row | QA row | QA statement MD5 |
|---|---|---|---|
| \`20261102122437\` | \`superseded_placeholder_phase49_atomic_pharmacy_dispense\` | \`roshan_phase51_public_setup_required_anon\` | \`4b848d12b776028dd67cc0e6ffebc452\` |
| \`20261102133658\` | \`superseded_placeholder_phase50_clinical_visit_bill_completion\` | \`roshan_phase49_atomic_pharmacy_dispense\` | \`55f65a3816d431ff42a5272c9e338658\` |
| \`20261102133734\` | \`superseded_placeholder_phase51_public_setup_required_anon\` | \`roshan_phase50_clinical_visit_bill_completion\` | \`cf5948d78786d6038fa93a74ecf22256\` |

Do not repair this by replaying the historical QA ledger, inserting migration rows manually, or replaying the redacted Production cleanup row \`20261102232941\`. Phase 61's source remains in Draft PR #229, not in main; QA application does not imply Production or source-branch promotion.

### Phase 55 ACL divergence

For \`private.app_has_claim_branch(uuid)\` and \`private.sync_user_role_text()\`:

- Production: \`proacl IS NULL\`; effective EXECUTE is true for anon, authenticated and service_role.
- QA: explicit owner-only ACL; effective EXECUTE is false for anon, authenticated and service_role.

This is a real Production privilege gap. No privilege was changed in this run.

## 3. Supabase Advisors

| Project | Security | Performance | Health |
|---|---:|---:|---:|
| Production | 5 groups / 31 findings | 2 groups / 96 findings | 0 |
| QA | 5 groups / 34 findings | 2 groups / 148 findings | 0 |

Notable current categories:

- Both: \`pg_trgm\` in \`public\`; anon-callable SECURITY DEFINER \`setup_required()\`; leaked-password protection disabled.
- Authenticated-callable SECURITY DEFINER functions: 26 Production, 30 QA.
- RLS-enabled private tables without policies: 2 Production, 1 QA.
- Unindexed foreign keys: 2 Production, 7 QA.
- Unused-index notices: 94 Production, 141 QA.

These are triage findings, not proof that every SECURITY DEFINER RPC is exploitable. Preserve intended permission-checked RPCs; do not bulk-revoke grants or drop unused indexes.

## 4. Vercel deployment and canonical alias

- Latest main deployment attempt: [\`dpl_5t7C4Y7tNQRZXXS5ibjAcNS7nRYw\`](https://vercel.com/roshan45/roshan-health-hub/5t7C4Y7tNQRZXXS5ibjAcNS7nRYw), commit \`52d975180e505c922dbe7a9b3260365bf59179b1\`, state **CANCELED**. This is a documentation-only main commit; it is not a successful new app deployment.
- The canonical alias \`roshan-health-hub.vercel.app\` still resolves to READY deployment [\`dpl_GNX1VuGgArr8CsMPZn2KB9Hz4eQz\`](https://vercel.com/roshan45/roshan-health-hub/GNX1VuGgArr8CsMPZn2KB9Hz4eQz), app commit \`fb54651533ffd04b2f20387a976f88293110c513\`, with \`aliasError=null\`.
- No new production application code was deployed in this recheck.

## 5. Backup runner, encrypted archive and restore evidence

Private runner repository: [\`crauch2088-source/roshan-health-hub-backup-runner\`](https://github.com/crauch2088-source/roshan-health-hub-backup-runner).

- Current runner main: \`464456a25335f60bc1721e2c6b194aed53b7382d\`.
- Merged runner PRs: #5 \`e7c8c6718d5d7acc7f46a17a2c99c0b222caafcf\` (DB-credential preflight), #6 \`2bf3018a09edf53508521a1428bf9f7f2417feb1\` (Supabase CLI token preflight), and #7 \`464456a25335f60bc1721e2c6b194aed53b7382d\` (setup documentation).
- Latest main-branch backup run is [#21 / 43164547237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164547237), on the earlier runner SHA \`7a3409ad84b4394014aeff36431a95a69813b90d\`: validation passed, backup failed because both database-connection credential options were empty. No Production connection, dump, restore, artifact or Drive upload occurred.
- Branch test [#22 / 43164851066](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164851066) also failed at the DB-credential preflight before CLI setup. The current main's new \`SUPABASE_ACCESS_TOKEN\` preflight has not yet been exercised by a workflow run on SHA \`464456a\`.
- The current workflow requires \`SUPABASE_ACCESS_TOKEN\` for Supabase CLI authentication, exactly one of \`SUPABASE_DB_ACCESS_TOKEN\` or \`SUPABASE_DB_PASSWORD\` for the database connection, and \`AGE_RECIPIENT\`. No secret value was read. Prior run logs showed both DB credential options empty; the new CLI token's current presence is unverified.

### Existing off-site archive and restore

The canonical private Drive folder was re-resolved and listed read-only. The dated child \`2026-11-09\` contains:

- \`Roshan-Production-Backup-2026-11-08.zip\`
- Drive file ID \`1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv\`
- 305,317 bytes; Drive MD5 \`875a85ac23e8b7a671c371cca41f7732\`; not trashed.

The most recent full backup/restore evidence is older: [run #42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237), feature commit \`713ee4edf47429df9e02c475e5909e4c4f62a744\). Its job log confirms a full database archive, isolated local PostgreSQL 17 restore, encrypted artifact staging and successful ciphertext upload. The GitHub artifact has expired; the Drive ciphertext remains. Owner-device checksum, age decryption and archive readability were documented as passing on 2026-11-09; not repeated in this read-only run.

Both hosted projects currently report zero \`storage.objects\` rows and zero \`vault.secrets\` rows. The archive is database-only; it does not contain Storage object bytes or Vault secret values.

**Interpretation:** an earlier isolated restore did pass, and an encrypted off-site archive still exists. However, no full backup has passed on current runner main after its checksum/auth-preflight changes. The current backup gate therefore remains open pending owner-managed credential configuration and a new explicitly authorized full run plus restore verification.

## 6. Acceptance and release decision

- QA Phase 61: migration and bounded synthetic pharmacist/doctor request/reject smoke are recorded in PR #229; the test transaction was rolled back and no residual synthetic rows were reported.
- Not accepted: real pharmacist/prescriber UAT, 320–430px Android review, Arabic RTL/English LTR acceptance, printer output, staff workflow acceptance.
- Authenticated clinical end-to-end tests remain explicitly deferred until an isolated free environment and suitable synthetic doctor/pharmacist identities are available.
- Production Phase 57/57B, Phase 55 ACL reconciliation, Phase 61, Phase 58/59 receipt schema/RPC and any risky promotion remain blocked by their separate gates.

**Next highest-value task:** the owner must configure the current runner's CLI-auth secret plus exactly one database-connection credential, then authorize one manual encrypted backup. Until that is complete, continue source/effective-function reconciliation and disposable PostgreSQL 17 validation; do not write to Production or dispatch an external backup automatically.

