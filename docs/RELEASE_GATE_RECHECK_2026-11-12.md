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



## Follow-up live recheck — 2026-11-12 06:34 UTC

This addendum supersedes the 06:11–06:17 UTC snapshot above where live values have advanced. All database queries were read-only; no backup dispatch, hosted write, merge, or deployment promotion occurred.

### Repository and exact-head checks

- Main remains 52d975180e505c922dbe7a9b3260365bf59179b1. There are 11 open PRs (#236, #210, #229, #233, #181, #222, #179, #213, #157, #185, #112) and 3 open Issues (#199, #217, #218).
- Main CI [43167067722](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067722) completed: 20 successful jobs, one intentional skip of the canonical PG17 baseline plus authenticated clinical-acceptance job, zero failures.
- Finance-only RPC isolation [43167067870](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067870) passed 2/2 jobs. Push-on-main / CodeQL [43167067448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067448) passed both JavaScript/TypeScript and Python analyses.
- This PR's current head before this follow-up was 8a51e02dc6ffa0371dacb82a462d95c85325e77a. Its CI [43167950986](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167950986) completed with 20 successful jobs, one intentional clinical-acceptance skip, and zero failures; CodeQL [43167947240](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167947240) passed both analyses. Prescription atomicity [43167951120](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167951120), insurance integrity [43167950968](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167950968), and privileged-role guard [43167951089](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167951089) all passed. The Vercel Preview Comments status is not a deployment.

### Live migration ledgers and effective database contracts

A fresh read-only row-by-row comparison by version, name, stored statement byte length and MD5 now shows:

| Measure | Production | QA |
|---|---:|---:|
| Ledger rows | 129 | 26 |
| Latest version | 20261102232941 | 20261112061251 |
| PostgreSQL | 17.6.1.155 | 17.11.0.003 |

- Shared version numbers: 3; all 3 have different names, byte lengths and MD5 fingerprints.
- Production-only rows: 126. QA-only rows: 23.
- QA-only current rows include Phase 55 20261103155227, Phase 57 20261104065852, Phase 57B 20261111215510, Phase 61 20261111223309, Phase 58 20261112061219 and Phase 59 20261112061251.
- Production contains none of those six QA versions. Do not infer parity from version collisions or repair the ledgers manually.

Effective pharmacy behavior was checked by reading function definitions and effective EXECUTE privileges:

- The authenticated atomic entry point atomic_pharmacy_dispense(uuid,boolean,uuid) delegates to fn_dispense_prescription_with_invoice(uuid,boolean) in both projects; anon cannot execute either entry point.
- QA's delegated function rejects NULL quantity, free-text/unlinked items and external prescriptions, and contains no NULL-to-one fallback.
- Production's delegated function still contains COALESCE(pi.quantity,1) and lacks those three guards. Thus the deployed client wrapper is not enough to protect Production's database RPC path.
- The legacy fn_dispense_prescription(uuid) still contains the old fallback in both projects, but authenticated and anon cannot execute it. The prescription_items.quantity column remains nullable in both databases; Phase 57 is an RPC-level guard, not a NOT NULL column constraint.

Other phase-specific live checks:

- Phase 55 helpers private.app_has_claim_branch(uuid) and private.sync_user_role_text(): Production has default/PUBLIC-effective EXECUTE (anon, authenticated and service_role all true); QA is owner-only (all three roles false).
- QA Phase 61 functions request_prescription_item_correction(uuid,text) and resolve_prescription_item_correction(uuid,text,jsonb,text) exist, authenticated EXECUTE is true and anon EXECUTE is false. Production has neither function.
- QA has 7 public currency_code columns and get_invoice_payment_receipt_status_v2(uuid[]) (authenticated EXECUTE, anon denied). Production has zero currency_code columns and no receipt-status functions. Phase 58/59 are therefore QA-applied, not Production-applied.

### Current Supabase Advisors

| Project | Security | Performance | Health |
|---|---:|---:|---:|
| Production | 5 groups / 31 findings | 2 groups / 96 findings | 0 |
| QA | 5 groups / 34 findings | 2 groups / 148 findings | 0 |

- Production: 2 RLS-enabled private tables without policies, 1 extension-in-public warning, 1 anon-callable SECURITY DEFINER warning, 26 authenticated-callable SECURITY DEFINER functions, leaked-password protection disabled; performance includes 2 unindexed foreign keys and 94 unused-index notices.
- QA: 1 RLS-enabled private table without policies, 1 extension-in-public warning, 1 anon-callable SECURITY DEFINER warning, 30 authenticated-callable SECURITY DEFINER functions, leaked-password protection disabled; performance includes 7 unindexed foreign keys and 141 unused-index notices.
- These findings require targeted review; no blanket grant revocation, index deletion, Auth setting change or extension move was performed.

### Vercel

- Latest main deployment attempt dpl_5t7C4Y7tNQRZXXS5ibjAcNS7nRYw for docs-only main SHA 52d975180e505c922dbe7a9b3260365bf59179b1 is CANCELED.
- Canonical alias roshan-health-hub.vercel.app still targets READY deployment dpl_GNX1VuGgArr8CsMPZn2KB9Hz4eQz, application SHA fb54651533ffd04b2f20387a976f88293110c513, aliasError null.
- No application deployment or promotion occurred.

### Backup runner and off-site restore evidence

- Backup-runner main is 464456a25335f60bc1721e2c6b194aed53b7382d. Its latest main-branch run is still #21 / 43164547237, executed on the earlier runner SHA 7a3409ad84b4394014aeff36431a95a69813b90d. Validation passed; the backup job failed at preflight because both database credential options were empty. No database connection, dump, restore, artifact or Drive upload occurred.
- Run #22 / 43164851066 on branch fix/backup-credential-preflight-20261112 failed in the credential preflight before Supabase CLI setup; the backup job was skipped.
- Runner PR #8 remains Draft. Its latest secret-free preflight test run #2 / 43168592739 passed on test branch SHA 72b5a4773ac8a0fb4b26d2f7985fe98b97488d9. The earlier test run #1 / 43168433912 failed before the correction. These are validation tests, not a backup.
- No backup workflow has run on current runner main 464456a. Current runner setup requires SUPABASE_ACCESS_TOKEN, exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD, and AGE_RECIPIENT. Secret values were not read; owner configuration remains the blocker.
- Google Drive read-only metadata confirms the encrypted archive Roshan-Production-Backup-2026-11-08.zip remains present, not trashed, 305,317 bytes, MD5 875a85ac23e8b7a671c371cca41f7732, in dated folder 2026-11-09 under the canonical Roshan Health Hub - Encrypted Backups folder.
- The earlier full backup run #42535939237 (runner feature SHA 713ee4edf47429df9e02c475e5909e4c4f62a744) has a successful backup job: its “Create and locally restore encrypted backup” and “Upload encrypted artifact only” steps both passed. This is evidence that an isolated PostgreSQL 17 restore actually passed on that feature revision. Its GitHub artifact is no longer listed; the encrypted Drive copy remains. This does not certify current runner main.
- The archive is PostgreSQL-only and does not include Storage object bytes or Vault secret values.

### Updated release disposition

- Verified: main CI/CodeQL/finance checks; QA Phase 55/57/57B/61/58/59 applications; prior encrypted off-site database archive; prior isolated PostgreSQL 17 restore; canonical Vercel alias.
- Blocked: Production Phase 55 ACL correction and Phase 57/57B/58/59/61 migrations; full source/ledger/effective-catalog reconciliation; full backup and restore on current runner main; independent SQL/security review; pharmacist/prescriber, staff, Android RTL/LTR, printer and device acceptance.
- Authenticated clinical E2E remains explicitly deferred until an isolated free test environment and suitable synthetic doctor/pharmacist identities are available.
- Next highest-value owner action: configure the current runner's required CLI-auth token and exactly one database credential in private GitHub Actions settings. Do not send secret values to ChatGPT. Only after that owner setup and explicit authorization should a manual encrypted backup be dispatched. Meanwhile, continue disposable PostgreSQL 17 forward-migration rehearsal and source-to-live-ledger reconciliation.

No Production or QA DDL/DML, privilege/Auth/Storage change, patient/financial write, external backup dispatch, PR merge or deployment promotion occurred in this follow-up.

## Backup-runner preflight hardening follow-up — 2026-11-12 06:47 UTC

- Backup-runner PR [#8](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/8) remains Draft on head cc400eca29400e37971bccbf4aaff9957986f53d, based on runner main 464456a25335f60bc1721e2c6b194aed53b7382d.
- The follow-up validates the configured AGE_RECIPIENT with the age CLI before Supabase CLI setup or any database connection. The validator rejects an invalid age1 checksum/encoding instead of accepting a prefix-only regular expression; the manual workflow installs age before preflight.
- Secret-free exact-head run [43170543850](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43170543850) passed: ShellCheck/syntax, all 8 credential-preflight cases (including malformed recipient rejection and a generated valid age recipient), and the existing Python helper suite (22/22 tests).
- This is code/test validation on a Draft PR, not a full backup. The current runner main SHA remains 464456a25335f60bc1721e2c6b194aed53b7382d; the new age-recipient validation has not yet been merged or exercised by a full backup on main. No secrets were read and no Supabase connection, dump, restore, artifact upload or Drive write occurred.
- Next: independent review of PR #8; then owner-managed Actions credential setup and explicit authorization before a manual full backup/restore on the reviewed current runner main.

## Scoped QA source-to-ledger verification — 2026-11-12 06:55 UTC

The live QA ledger was compared to the tracked source SQL for Phases 55, 57, 57B, 58, 59 and 61. All six executable bodies match their recorded QA migration statements: Phase 55 matches after removing one terminal source newline; Phase 57, 58, 59 and 61 match raw; Phase 57B matches after removing only four leading comments, BEGIN/blank wrapper and trailing COMMIT/blank wrapper. The Phase 57B line diff contained no executable SQL changes. Exact versions, Git blob SHAs, byte lengths and MD5 values are in db/MIGRATIONS_MANIFEST.md.

Phase 61 source is on Draft PR #229 (head 9c54ee0655acfafdbb1f3509f4de7ed10be6a420), not main. This verifies only the six current QA forward phases; it does not resolve the 129-versus-26 historical ledger divergence or the three mismatched shared version IDs. Production still has none of these six phase versions.

### Open PR state correction

- PR #210 head a018d988182b949803d919149a958d2d23a21b18 remains Draft/non-mergeable against stale base 8c5b6a41780f60fc4dec864ca4c65980d77c765b. Its exact-head CI 43166072673 passed 21 jobs with one intentional clinical-acceptance skip; Phase 60 workflow 43166061024 passed 2/2. This supersedes the stale MASTER_PLAN note that exact-head CI was pending.
- PR #181 remains Draft. Phase 58/59 are now applied in QA (20261112061219 and 20261112061251), but not Production; receipt UI promotion still depends on Production schema/RPC rollout and acceptance. The prior statement that the schema/RPC were absent in both hosted environments is stale.
- PR #229 (head 9c54ee0655acfafdbb1f3509f4de7ed10be6a420) and PR #233 (head f237623a42797a7345e0d6ecfba3dc081b3d9aa1) remain Draft and non-mergeable against base 8c5b6a41780f60fc4dec864ca4c65980d77c765b. Their historical exact-head checks do not establish current-main integration or operational acceptance.

### PR #236 final evidence before this follow-up

- Head 0c9dfd221c9dfedda8f78aa44373e08c63b30f94, based on main 52d975180e505c922dbe7a9b3260365bf59179b1.
- CI 43170730789 passed 20 jobs; one intentional authenticated clinical-acceptance job was skipped; zero failures.
- CodeQL 43170720794 passed both analyses.
- Prescription atomicity 43170730799, insurance integrity 43170730816 and privileged-role guard 43170730898 passed.
- PR remains Draft; no merge or deployment promotion.

## Additional Phase49–52 cross-project source mapping — 2026-11-12 06:56 UTC

The source-to-ledger audit now also verifies the canonical Phase49, Phase50, Phase51 and Phase52 bodies in both Production and QA. All eight environment applications map to the tracked source files after only transaction-wrapper/comment normalization. QA Phase49/50 are raw exact; QA Phase51 excludes three explanatory header comments and a final blank line; QA Phase52 and Production Phase49–52 exclude only outer BEGIN/COMMIT wrappers. Exact versions, Git blobs, byte lengths and MD5 fingerprints are in db/MIGRATIONS_MANIFEST.md.

This confirms executable-body parity for the named Phase49–52 rows and, together with the Phase55/57/57B/58/59/61 audit, the ten named forward-phase environment applications. It does not resolve full historical ledger parity: the three shared version collisions, 126 Production-only rows, 23 QA-only rows, the quarantined 20261102232819 row and redacted cleanup/reversal 20261102232941 remain. Do not replay or manually repair historical ledger entries.


## Live release-gate follow-up — 2026-11-12 (post-runner run #23)

This follow-up supersedes earlier same-day statements that no workflow had run on the current backup-runner main. It records read-only checks performed after the 06:56 UTC source-mapping update.

- Main remains `52d975180e505c922dbe7a9b3260365bf59179b1`. Main CI [43167067722](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067722) completed with 20 successful jobs, one skipped combined job (`Canonical PG17 baseline replay and authenticated clinical acceptance`), and zero failures. Finance-only RPC isolation [43167067870](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067870) passed 2/2; Push on main / CodeQL [43167067448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43167067448) passed Python and JavaScript/TypeScript analyses.
- Open PRs: 11 (`#236 #233 #229 #222 #213 #210 #185 #181 #179 #157 #112`). Open Issues: 3 (`#199 #217 #218`). PR #236 remains Draft and mergeable. Main branch protection is disabled (`protected=false`, no required status checks); this was recorded, not changed.
- PR #236 parent head before this follow-up: `870d4e531bf96fc18b78481e6191adbc8a364dca`. Exact-head CI [43171835143](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43171835143) passed 20 jobs with the same one intentional skip and zero failures. Prescription atomicity [43171835079](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43171835079), privileged-role guard [43171835166](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43171835166), and insurance integrity [43171835299](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43171835299) passed. Vercel's PR status is success; this is not a deployment.
- Live ledgers remain Production 129 rows/latest `20261102232941` and QA 26 rows/latest `20261112061251`. Three version numbers collide and all three have different names/fingerprints; 126 rows are Production-only and 23 QA-only. The scoped source map now covers Phase49–52 in both environments and Phase55/57/57B/58/59/61 in QA, but the full historical ledger is not reconciled.
- Effective Phase57 behavior remains divergent: Production's `fn_dispense_prescription_with_invoice(uuid,boolean)` has no NULL guard and contains three `COALESCE(pi.quantity,1)` fallbacks; QA explicitly rejects NULL and has zero such fallbacks. `prescription_items.quantity` remains nullable in both projects. QA also has Phase57B `20261111215510` and Phase61 `20261111223309`; Production has neither. QA-only Phase58/59 are `20261112061219` / `20261112061251`.
- Phase55 helpers `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()`: Production has `proacl IS NULL`, making EXECUTE effective for anon/authenticated/service_role; QA denies those roles. No grants changed. The dedicated Phase55 PostgreSQL 17 workflow last passed on main ancestor `e1153f3fff07b75d93ac983d7a8a640d1b9236ab`, run [42801142634](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42801142634); it was not rerun on this documentation-only main head.
- Supabase Advisors observed at 2026-11-12 07:09 UTC: Production Security 5 groups/31 findings, Performance 2/96, Health 0; QA Security 5/34, Performance 2/148, Health 0. Findings remain targeted-review items, not authorization for bulk revocation or index deletion.
- Vercel's latest Production-target attempt for main `52d975180e505c922dbe7a9b3260365bf59179b1` is CANCELED (`dpl_5t7C4Y7tNQRZXXS5ibjAcNS7nRYw`), as expected for documentation-only work. Canonical alias `roshan-health-hub.vercel.app` resolves to READY `dpl_GNX1VuGgArr8CsMPZn2KB9Hz4eQz`, application SHA `fb54651533ffd04b2f20387a976f88293110c513`, `aliasError=null`. No app deployment or promotion occurred.
- Backup-runner main is `464456a25335f60bc1721e2c6b194aed53b7382d`. Latest main run #23 [43169973322](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43169973322) has overall conclusion success, but `validate` passed while the credential-preflight step was skipped and the `backup` job was skipped; it produced no artifact. This is not a backup and does not prove the current secrets are configured. Draft runner PR #8 head `cc400eca29400e37971bccbf4aaff9957986f53d` passed secret-free validator CI [43170543850](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43170543850), including ShellCheck/syntax, eight preflight cases and 22/22 existing Python helper tests; this is not a backup either.
- The existing encrypted archive remains present in Drive: [Roshan-Production-Backup-2026-11-08.zip](https://drive.google.com/file/d/1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv/view?usp=drivesdk), 305,317 bytes, MD5 `875a85ac23e8b7a671c371cca41f7732`, not trashed. Its parent is dated folder `2026-11-09` under `Roshan Health Hub - Encrypted Backups`; the similarly named legacy `Roshan Health Hub Backups` folder is empty. Prior full run [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) on feature SHA `713ee4edf47429df9e02c475e5909e4c4f62a744` passed both `Create and locally restore encrypted backup` and `Upload encrypted artifact only`. This proves a prior isolated PostgreSQL 17 restore, not a fresh restore on current runner main. The GitHub artifact is no longer listed; the Drive ciphertext remains. The archive is database-only and excludes Storage object bytes and Vault secret values.
- No Production/QA DDL/DML, privilege/Auth/Storage change, patient/financial write, backup dispatch, PR merge or deployment promotion occurred.

**Disposition: Production remains NO-GO.** Next owner action is to configure `SUPABASE_ACCESS_TOKEN`, exactly one of `SUPABASE_DB_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD`, and `AGE_RECIPIENT` in the private runner settings without sharing values; then explicitly authorize a manual backup and verify its ciphertext/checksum plus a new isolated PostgreSQL 17 restore. Until that authorization, continue historical source-to-ledger reconciliation and disposable PostgreSQL 17 tests. Authenticated clinical E2E remains deferred until the isolated free environment and synthetic doctor/pharmacist identities are available.
