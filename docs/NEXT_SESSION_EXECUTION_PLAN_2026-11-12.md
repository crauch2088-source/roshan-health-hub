# Roshan Health Hub — next-session execution plan
**Prepared:** 2026-11-12  
**Execution status:** Partially executed on 2026-11-12. Fresh backup, restore rehearsal, artifact verification/Drive transfer, exact source checks and disposable PG17 tests completed; Production release remains NO-GO.  
**Canonical starting point:** `crauch2088-source/roshan-health-hub` `main@07c3b691fd4fe92058594814b6e76744b7f4ec92`  
**Related private runner:** `crauch2088-source/roshan-health-hub-backup-runner` `main@464456a25335f60bc1721e2c6b194aed53b7382d`

> This is an execution runbook, not a promise that every gate will pass. The next session should execute each safe stage, continue independent work when a gate blocks one stage, and stop only the affected unsafe operation. Never represent a skipped step as completed.

## 1. Objective and expected outcome

The next session is to make measurable engineering progress, not repeat a general audit. Its first priority is to produce a **fresh, encrypted Production database backup using the current private runner, verify the runner's PostgreSQL 17 restore rehearsal, and place the encrypted artifact in the canonical private Google Drive backup folder**. In parallel, prepare and validate the narrow forward-only Production pharmacy correction package and reconcile the known Production/QA security and migration differences.

The next session should finish with one of these evidence-based outcomes:

1. **Preferred:** fresh backup run succeeds; local PostgreSQL 17 restore passes; encrypted artifact is verified and copied to the dated canonical Drive folder; the pharmacy migration package passes exact-source and disposable-PG17 checks; all release gates are re-evaluated. Apply a Production migration only if every gate in Section 8 is satisfied.
2. **Partial but useful:** backup is blocked by a concrete credential/runner/restore issue, but the exact failure is captured; the independent migration, security, and CI work proceeds without Production mutation.
3. **No-go:** source provenance, restore, data scope, exact-head CI, or post-change verification cannot be established. Do not mutate Production. Deliver the prepared candidate, test evidence, precise blocker, and next smallest action.

No paid services, subscriptions, upgrades, top-ups, quota bypasses, or paid Supabase branches are allowed. Do not use Lovable credits. Do not use Production as a test database.

## 2. Verified starting facts

### 2.1 Canonical application repository

- Repository: `crauch2088-source/roshan-health-hub`; default branch `main`.
- Exact reviewed main head: `07c3b691fd4fe92058594814b6e76744b7f4ec92`.
- Latest plan document blob at this base: `36528c6234d38c428cfed423aaf188f100bd8ae1`.
- The latest main commit has a successful Vercel status, but that is not evidence of database migration, clinic acceptance, or a new application deployment.
- `docs/MASTER_PLAN.md` is the project roadmap; `AGENTS.md` is the execution policy; `.specify/memory/constitution.md` contains the standing delegated Production authorization.
- The standing authorization is valid for qualifying, evidence-supported Production engineering changes without asking for per-change conversational permission. It does not waive backup, restore, exact-head tests, least privilege, recovery, audit, or human clinical/staff acceptance.

### 2.2 Live Supabase migration ledgers — direct read on 2026-11-12

| Environment | Project ref | PostgreSQL | Migration rows | Latest |
|---|---|---:|---:|---|
| Production | `jewzonxplxhogqrnhosl` | 17.6 | 129 | `20261102232941` — `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` |
| QA | `hopfohcnrtbiqjkgeukz` | 17.11 | 26 | `20261112061251` — `roshan_phase59_receipt_currency_provenance` |

QA currently contains these relevant phases; Production contains none of them:

| Phase | QA version | QA migration name | Production |
|---|---|---|---|
| 55 | `20261103155227` | `roshan_phase55_clinical_parent_guard_acl_reconciliation` | absent |
| 57 | `20261104065852` | `roshan_phase57_pharmacy_quantity_required_guard` | absent |
| 57B | `20261111215510` | `roshan_phase57b_free_text_external_prescription_guard` | absent |
| 58 | `20261112061219` | `roshan_phase58_single_sdg_currency_provenance` | absent |
| 59 | `20261112061251` | `roshan_phase59_receipt_currency_provenance` | absent |
| 61 | `20261111223309` | `roshan_phase61_prescription_item_correction_workflow` | absent |

Use the live ledger again at the beginning of the next session. These values are a checkpoint, not permission to assume the state has not changed.

### 2.3 Confirmed Production pharmacy defect

The live Production definition of `public.fn_dispense_prescription_with_invoice(uuid,boolean)` still contains `COALESCE(pi.quantity,1)` and lacks the Phase 57B free-text/external-prescription guards. QA has the explicit NULL quantity rejection and Phase 57B guards. There were zero active pending prescription items with NULL quantity at the last check; that does not remove the latent defect.

This is a high-priority dispensing-safety defect. Do not repair it with a frontend default, a data backfill, or a manually edited migration ledger.

### 2.4 Backup runner and credentials — inspected live, values never viewed

Private repository: `crauch2088-source/roshan-health-hub-backup-runner`.

- Current runner `main`: `464456a25335f60bc1721e2c6b194aed53b7382d`.
- Open Draft PR #8: `test(backup): cover credential preflight without secrets`; head `cc400eca29400e37971bccbf4aaff9957986f53d`; exact-head CI run [43170543850](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43170543850) succeeded. PR is mergeable. It adds fail-closed validation for the CLI token, exactly one DB credential, and a valid age recipient before database access. It still needs a careful code/diff review before merge.
- Repository Actions secret names, inspected read-only through the existing signed-in GitHub browser profile:
  - `SUPABASE_ACCESS_TOKEN`: present.
  - `SUPABASE_DB_PASSWORD`: present.
  - `SUPABASE_DB_ACCESS_TOKEN`: absent.
- Repository Actions variable names:
  - `AGE_RECIPIENT`: present.
  - `SUPABASE_DB_POOLER_PORT`: absent; the workflow defaults to port `5432`.
- No secret values were viewed, copied, or changed. Do not read or expose secret values. The current configured path is the database-password fallback, with exactly one database credential.
- Manual workflow run [43169973322](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43169973322) reported overall success, but its confirmation input was false: credential preflight was skipped and the backup job was skipped. **It created no backup artifact and is not backup evidence.**
- Earlier run [43164547237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164547237) failed because the database credential was not configured at that time. The current secret-name inspection is newer evidence; do not repeat the old failure narrative as the current credential state.
- The current runner workflow is manual-only and requires `confirm_production_backup=true`. It validates scripts/CLI flags, creates a database dump and local restore rehearsal, encrypts the archive with age, and uploads only encrypted artifact bytes with one-day retention.
- The script aborts if `storage.objects` is non-empty or `vault.secrets` contains rows. PostgreSQL dumps do not include Storage object bytes, Vault encryption root keys, Supabase project settings, API/JWT keys, Edge Function secrets, or custom-domain/control-plane configuration.

### 2.5 Connected transfer capability

- Composio GitHub connection: active.
- Composio Google Drive connection: active.
- The canonical destination is the private Drive folder named **Roshan Health Hub - Encrypted Backups**. Its previously recorded folder URL is in the backup-runner README; re-find the exact folder by name and verify its ID before upload.
- The available connected workflow supports listing artifacts for a run, downloading the GitHub artifact as a file reference, creating a dated child folder, and resumable Drive upload. The ordinary Drive upload has a 5 MB limit; use the resumable upload for the encrypted ZIP.
- Do not upload plaintext dumps, SQL exports, database connection strings, age private identities, or any clinical/financial records outside the encrypted artifact.

## 3. Tool and agent routing for the next session

Use connected capabilities in this order:

1. **GitHub native MCP:** verify repository refs, fetch complete diffs/files, inspect issues/PRs, create one atomic commit per logical change, inspect exact-head CI/status, and merge only reviewed PRs.
2. **Supabase MCP:** read-only ledger/catalog/function/ACL checks; apply DDL only through the supported migration action after the recovery and test gates. Use one batched read-only SQL diagnostic where possible.
3. **Composio GitHub:** use the discovered `GITHUB_CREATE_A_WORKFLOW_DISPATCH_EVENT` action for the manual backup workflow, then `GITHUB_GET_A_WORKFLOW_RUN`, `GITHUB_LIST_JOBS_FOR_A_WORKFLOW_RUN`, and artifact-list/download actions. Do not use a browser click path when the connected GitHub action can do it deterministically.
4. **Composio Google Drive:** use `GOOGLEDRIVE_FIND_FOLDER`, `GOOGLEDRIVE_LIST_CHILDREN_V2` or `GOOGLEDRIVE_FIND_FILE`, `GOOGLEDRIVE_CREATE_FOLDER`, `GOOGLEDRIVE_RESUMABLE_UPLOAD`, and metadata read-back. Verify the exact destination before upload.
5. **Parallel orchestration:** use `functions.exec` to batch only logically independent reads/reviews. Keep dependent operations sequential (review → merge → dispatch → wait → artifact download → upload → verify).
6. **TinyFish browser agent:** reserve for a browser-only check that cannot be done with GitHub/Composio APIs. The GitHub browser profile is signed in, but the agent wallet was nearly exhausted during this planning round; do not top up or use paid credits. No browser agent is required for workflow dispatch or Drive transfer.
7. **Independent coding subagents:** no separate subagent-spawn tool is exposed in the currently connected toolset. Do not claim to have spawned a second reviewer. Perform an explicit second-pass review against tests, migration source, call sites, and security contracts; use a separate human reviewer only if the repository's required review policy demands one.

Reload the Supabase and TDD skills at the start of the next session if the session context does not retain them. Use TDD before changing any behavior.

## 4. Workstream A — fresh encrypted Production backup and off-site copy

### A1. Revalidate the target and credentials

- Confirm the private runner repository still points to the expected `main` and inspect its exact head.
- Re-fetch the workflow file, runner script, README, PR #8 diff, and CI result. Do not rely on this document alone.
- Verify the names/presence of the required secrets/variable only if needed; never retrieve secret values. Required configuration is:
  - `SUPABASE_ACCESS_TOKEN`
  - exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`
  - `AGE_RECIPIENT` repository variable
- Current observed configuration satisfies the name-presence rule via `SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_PASSWORD` + `AGE_RECIPIENT`. The PR #8 validator must still confirm that the recipient is a valid age recipient.
- Check GitHub Actions free quota/availability through available account usage metadata if exposed. Do not upgrade or purchase minutes. If no safe free execution allowance is available, stop before dispatch.

### A2. Review and merge backup-runner PR #8

Review the full diff, not just the PR summary:

- Confirm the preflight fails closed for missing CLI token, zero or two DB credentials, missing/invalid age recipient.
- Confirm it never echoes secret values and runs before Supabase CLI setup or any Production connection.
- Confirm the workflow calls the same tested validator and installs age before validating the recipient.
- Confirm the tests cover both allowed DB credential paths and malformed recipient checksum cases.
- Confirm the manual-only trigger and explicit boolean confirmation remain intact; no push, PR, or schedule trigger may run a Production backup.
- Confirm exact-head CI is green for the current PR head, not merely a prior commit.
- If review and checks pass, squash-merge PR #8. If the head changed or checks are stale, refresh evidence first; do not merge stale checks.

### A3. Dispatch the real backup

After PR #8 is merged and main is re-read:

- Dispatch `.github/workflows/manual-encrypted-production-backup.yml` on `main` using `GITHUB_CREATE_A_WORKFLOW_DISPATCH_EVENT`.
- Explicitly set `confirm_production_backup=true`. Do not omit the input or accept its false default.
- This is a read-only Production database extraction and encrypted artifact creation; it does not apply migrations or change patient/business data.
- Capture the returned/latest workflow run ID and exact head SHA. Wait for terminal status; inspect job and step conclusions.
- Required evidence:
  - credential preflight actually ran and passed (not skipped);
  - validation job passed;
  - backup job passed;
  - the script completed the local PostgreSQL 17 restore rehearsal and critical table-count comparisons;
  - encrypted artifact was created and uploaded;
  - the workflow summary confirms encrypted-only artifact and no Production writes.
- If any credential preflight fails, stop before database connection and report the exact missing/invalid configuration name only. Never ask for a secret value in chat.
- If the runner aborts because Storage or Vault is non-empty, stop and prepare separate recovery handling. Do not bypass those checks or claim the database archive covers those services.

### A4. Artifact integrity and Drive placement

Only after a successful backup job:

1. List artifacts for that exact workflow run; verify the artifact name, non-expired status, run association, and size.
2. Download the artifact ZIP using its returned artifact ID. Do not invent an ID or reuse an artifact from a prior run.
3. Search the exact canonical Drive folder **Roshan Health Hub - Encrypted Backups**. Verify the folder is real, not trashed, and the correct destination. Do not use the legacy folder **Roshan Health Hub Backups**.
4. Search for a dated child folder for the current backup date. Reuse it if it exists; otherwise create it under the verified canonical parent ID.
5. Upload the downloaded encrypted ZIP via `GOOGLEDRIVE_RESUMABLE_UPLOAD` to that dated child folder. Do not use the 5 MB-limited ordinary upload for a larger artifact.
6. Read back Drive metadata by returned file ID. Verify name, parent folder, non-zero size, and web link. Compare uploaded size with the downloaded artifact size where available.
7. Record the GitHub run URL, artifact ID/name/size, Drive folder/file ID/link, timestamp, restore result, and any known scope limitations in the backup evidence document and Master Plan.
8. Let the one-day GitHub artifact expire naturally after off-site verification; do not delete the Drive copy.

**Cryptographic limitation:** the workflow's local restore test occurs before encryption. A successful run proves the dump can be restored and that the encrypted artifact was emitted; it does not, by itself, prove that the encrypted bytes can be decrypted with the owner's offline private age identity. Never upload that private identity to GitHub, ChatGPT, Drive beside the artifact, or an agent. If no safe owner-side decryption test is available, explicitly keep the owner-side ciphertext-decryption gate open and do not claim full disaster-recovery acceptance.

## 5. Workstream B — Production pharmacy forward-only correction

### B1. Re-read live state immediately before testing

Batch one read-only diagnostic across both projects for:

- migration rows and latest versions;
- exact function definition for `public.fn_dispense_prescription_with_invoice(uuid,boolean)`;
- function owner, `prosecdef`, `proconfig/search_path`, volatility, and effective EXECUTE grants for PUBLIC, anon, authenticated, service_role and authenticator;
- branch/user/permission helpers referenced by the function;
- required table/column/index/policy/trigger presence;
- active pending NULL-quantity prescription item count;
- Storage object and Vault secret counts relevant to backup scope.

Stop if the live state differs materially from this checkpoint. Do not create test patients, prescriptions, invoices, stock movements, or payments in Production.

### B2. Exact-source provenance

Use the dedicated runbook `docs/PRODUCTION_PHARMACY_MIGRATION_RUNBOOK_2026-11-12.md` and exact tracked SQL:

- Phase 57 source: `db/roshan_phase57_pharmacy_quantity_required_guard.sql`; QA stored statement 10,954 bytes, MD5 `921970d4d86b32dccd430a0ea0ef8745`; source blob `9db6768999352c32081f69b5e665c3cc95452616`.
- Phase 57B source: `db/roshan_phase57b_free_text_external_prescription_guard.sql`; QA stored statement 11,525 bytes, MD5 `bfd2df24224752a1488f2f05494f4211`; source blob `57516e08de8e314f687c21f2f292199d3adff178`.

Compare exact source bytes with the QA stored SQL payloads (length and MD5/SHA-256); do not normalize whitespace, strip wrappers, reconstruct from function bodies, or infer equality from a Git blob SHA. Re-read the live QA stored statements and source blobs during execution.

### B3. Disposable PostgreSQL 17 acceptance

Use the existing exact-head GitHub Actions PostgreSQL 17 workflow/fixtures; do not create a paid Supabase branch. Verify both migrations in order, Phase 57 then Phase 57B, and add a regression test first if a missing assertion is found.

Required positive/negative coverage:

- valid catalogue-linked prescription, positive whole-unit quantity, permitted user and correct branch;
- NULL, zero, negative, fractional, non-finite, and over-limit quantity;
- free-text/unlinked item, including mixed catalogue + free-text order (whole request must fail, no partial dispense);
- external prescription rejected from internal-stock dispensing;
- wrong branch, inactive/soft-deleted medicine, invalid visit/patient linkage;
- expired stock, insufficient aggregate stock, FEFO selection, concurrent/idempotent repeat;
- invoice construction/payment failure or rollback boundary;
- no unintended invoice/header/line, stock batch decrement, stock movement, item dispense flag, parent prescription status, or audit side effect on rejected attempts;
- preserve permissions, branch isolation, atomic invoice/stock behavior, wrapper idempotency, SECURITY DEFINER, fixed empty search_path, owner and intended authenticated-only RPC grants.

Do not loosen a test because it fails. Diagnose the actual behavior and fix the narrowest source/test mismatch.

### B4. Prepare the Production migration package

- Keep exactly two pharmacy migrations in the hotfix package, in order: Phase 57 then Phase 57B.
- Do not include Phase 61, Phase 58/59, Phase 60, or unrelated finance changes.
- Confirm the supported migration application mechanism can record a forward-only migration without hand-editing `supabase_migrations.schema_migrations`. Never copy QA ledger rows or use raw INSERT/UPDATE to manufacture migration history.
- If the available Supabase migration API cannot preserve a coherent migration name/version/source record, stop and use the repository's reviewed official migration route; do not improvise.
- Capture before-state definition/ACL/fingerprint. Apply one migration at a time only after all gates pass; read back its ledger row and effective function before proceeding to the next.
- After both, run read-only postchecks and compare the exact intended semantic delta. Do not restore the old unsafe function as rollback; use a reviewed forward fix if postchecks fail.
- No quantity backfill or default. Existing invalid prescriptions remain pending for clinician correction.

## 6. Workstream C — Phase 55 ACL and broader security review

Separate this from the pharmacy hotfix unless a test proves a hard dependency:

1. Inspect the exact Phase 55 migration and current Production/QA definitions for:
   - `private.app_has_claim_branch(uuid)`
   - `private.sync_user_role_text()`
   - `private.phase36_guard_clinical_visit_links()`
2. Verify effective EXECUTE for PUBLIC, anon, authenticated, service_role and authenticator, schema USAGE, owner, fixed empty search_path, trigger dependencies, and all SQL/frontend call sites.
3. Confirm the Phase 55 migration's trigger behavior change is required and compatible, not merely the two helper ACL revokes.
4. Add/confirm PG17 assertions that direct browser-role execution of private helpers is denied while intended trigger/RPC workflows still succeed.
5. Review Supabase Security Advisor findings function-by-function. Treat SECURITY DEFINER warnings as triage signals, not automatic proof of exploitability. Do not blanket-revoke intended authenticated RPCs or switch them to SECURITY INVOKER without authorization and caller tests.
6. Review `public.setup_required()` as an intentional minimal bootstrap boolean separately: inspect current exact grants and body, verify it reveals no user/clinic data, and preserve the onboarding contract if still required.
7. Private pharmacy idempotency tables with RLS and no browser policies may be intentionally inaccessible; verify no client path requires direct access before adding policies.
8. Do not move `pg_trgm` or change leaked-password protection if doing so requires a paid plan or creates unverified compatibility risk.

No Production ACL/RLS change until the fresh backup/restore and exact tests are complete.

## 7. Workstream D — reconcile open PRs without multiplying work

Review only where it directly supports the release sequence:

| PR | Next-session disposition |
|---|---|
| #8 backup-runner credential preflight | Review exact diff and CI; squash-merge if clean, then dispatch backup |
| #210 Phase 60 medicine identity/pack attestation | Keep Draft until independent SQL/security review and exact-head CI are reconfirmed; no need to merge before backup |
| #229 Phase 61 pharmacist-to-prescriber UI | Keep Draft; requires independent review and real pharmacist/prescriber Android RTL/LTR acceptance; do not activate in Production |
| #233 medication arithmetic foundation | Keep arithmetic-only; no drug recommendations or protocols; do not activate clinical rules |
| #181 payment receipt UI | Hold until Phase 58/59 schema and RPC exist in the target environment and frontend compatibility is proven |
| #236 release-gate documentation | Reconcile against current main; do not merge its stale/diverged base blindly |
| #179 saved-prescription printing | Reconcile only if time remains; physical A4/thermal printer acceptance remains open |
| #213 backup destination documentation | Reconcile with the new actual backup run and Drive artifact; avoid duplicate/stale reports |
| #157 dependency update | Defer; stale base requires full current-main and lockfile/security review |
| #185 prescribing specification | Reconcile with #233; no clinical protocol activation |
| #112 old UX plan | Superseded planning material; do not spend this session rebasing it |

Use one coherent PR/atomic commit per logical task. Do not generate repeated per-file commits or trigger a Vercel build for SQL/docs-only changes. Always squash-merge. Do not merge a Draft PR simply because its tests once passed.

## 8. Production GO / NO-GO decision

A Production database change is eligible only when all applicable conditions are evidenced:

- [ ] exact current Production project/ref and mainline commit verified immediately before action;
- [ ] fresh encrypted backup from the current runner succeeded;
- [ ] local PostgreSQL 17 restore rehearsal passed and core table counts were compared;
- [ ] ciphertext artifact and manifest/checksum integrity verified;
- [ ] artifact copied to the canonical Drive destination and metadata read back;
- [ ] owner-side decryption limitation explicitly resolved or retained as a no-go gate according to the runbook;
- [ ] Storage/Vault scope verified empty or separately recoverable; control-plane configuration residuals documented;
- [ ] exact source provenance and QA SQL body comparison pass;
- [ ] exact-head disposable PostgreSQL 17 tests pass, including no-side-effect assertions;
- [ ] current Production function owner/security/search_path/ACL captured and intended post-state proven;
- [ ] migration mechanism preserves forward-only history without ledger fabrication;
- [ ] post-change read-only verification and forward-recovery strategy are ready.

If all technical gates pass and the owner-side authorization covers the action, the agent may proceed without another conversational approval. Do not cross any owner-gated clinical/staff acceptance or unresolved critical-risk boundary. If one gate fails, stop only the Production migration; continue the safe QA/CI/docs work.

## 9. Operational and clinical acceptance — explicitly not part of automated completion

Keep these separate from engineering completion:

- Real prescriber/pharmacist acceptance of the correction workflow on Android (320–430 px), Arabic RTL and English LTR.
- Real doctor, lab, receptionist and pharmacist workflows with proper roles and branch assignment.
- A4 and thermal printer physical output, paper sizing, margins, readability, and reprint behavior.
- Clinic staff sign-off and real-world opening decision.
- Clinician-approved medication protocols, if ever pursued. The current medication engine remains deterministic arithmetic only; no model/agent may infer a drug, dose, route, frequency, duration, concentration, or protocol.

Automated tests and a green deployment do not satisfy these gates.

## 10. Execution sequence and session time allocation

The next session should use this order, with parallel read-only work where safe:

| Stage | Target time | Work |
|---|---:|---|
| 0 | 10–15 min | Verify main/runner heads, latest PRs, exact live ledgers, skills, free-quota constraints |
| 1 | 15–25 min | Review PR #8 diff and exact-head CI; merge only if safe |
| 2 | 30–60 min | Dispatch manual backup with confirmation true; monitor all jobs and restore steps |
| 3 | 15–30 min | List/download artifact; create/reuse dated Drive folder; resumable upload; metadata verification |
| 4 | 30–45 min | Parallel read-only Production/QA source, function, ACL, Storage/Vault, and advisor reconciliation |
| 5 | 45–90 min | Exact Phase 57/57B provenance comparison and disposable PG17 tests; correct missing assertions only |
| 6 | 20–40 min | Phase 55 ACL/trigger review and targeted PG17 tests |
| 7 | 15–25 min | Update migration manifest/runbook/MASTER_PLAN with only verified evidence; one atomic docs commit |
| 8 | 10–15 min | Final gate matrix, residual risk, exact identifiers, engineering/operational progress recalculation |

These are planning estimates, not a promise that a long-running GitHub job or external service will finish inside the window. A blocked backup should not consume the entire session; continue independent safe work.

## 11. Required final report from the next session

Return a compact but evidence-rich report containing:

- exact main and backup-runner commit SHAs;
- PR #8 disposition and exact-head checks;
- manual backup workflow run ID, whether the confirmation preflight actually ran, job/step conclusions, restore result, artifact ID/name/size;
- canonical Drive folder/file IDs, destination link, metadata and upload-size verification;
- explicit distinction between pre-encryption restore rehearsal and owner-side encrypted-artifact decryption;
- current Production/QA migration counts and latest versions;
- Phase 57/57B source hashes and PG17 test results;
- Phase 55 ACL review result and any Production change identifiers;
- any Production migration actually applied, exact migration names/versions, and post-apply evidence — otherwise say none;
- unresolved blockers, owner actions, and residual risks;
- weighted Engineering RC and Operational Acceptance recalculated only from verified deliverables. Audit/planning/documentation does not earn implementation-completion credit.

## 12. Absolute stop rules

- Never ask the user to paste a password, PAT, service-role key, age private identity, or other secret into chat.
- Never print secret values or put them in source control, PR comments, logs, or Drive.
- Never replay QA's full ledger into Production or manually edit migration history.
- Never use Production for synthetic test patients, prescriptions, visits, stock, invoices, payments, or clinical workflows.
- Never bypass RLS, branch isolation, audit, idempotency, atomic stock/finance operations, or clinical confirmation.
- Never apply Phase 61 UI/workflow, Phase 58/59 receipts, Phase 60 catalogue changes, or medication protocols as part of the two-migration pharmacy hotfix.
- Never claim backup success from a run where the confirmation input was false or the backup job was skipped.
- Never claim encrypted-artifact decryption from a restore that occurred before encryption.
- Never buy credits, upgrade a plan, create a paid Supabase branch, or bypass a free-tier limit.
- If target, source, data impact, recovery, or cost is uncertain, stop that action and keep unrelated safe work moving.

---

**Planning checkpoint only:** no Production/QA DDL or DML, no secrets or variables changed, no backup dispatched, no artifact transferred, no application deployment promoted, and no PR merged during preparation of this plan.


## 13. Execution checkpoint — 2026-11-12

### Completed

- [x] Re-read canonical main, runner head, live ledgers and current PR/CI state.
- [x] Merged application documentation PR #243 as main commit `5159d469b34b794bb68b2fbe245552cd509188a6`; main CI [#43183563642](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43183563642) passed.
- [x] Reviewed and merged backup-runner PR #8; runner main is `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`; exact-head CI [#43183801681](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183801681) passed.
- [x] Dispatched manual Production backup with `confirm_production_backup=true`; run [#43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) succeeded, including preflight, local PostgreSQL 17 restore rehearsal and encrypted-only artifact creation.
- [x] Verified ZIP SHA-256 against GitHub digest, verified internal ciphertext SHA-256 against `SHA256SUMS`, and confirmed ZIP contains only encrypted archive plus checksum manifest.
- [x] Uploaded encrypted ZIP to the canonical dated Drive folder; read-back confirms exact file size, parent folder, MD5 and non-trashed state.
- [x] Deleted `SUPABASE_DB_PASSWORD` after the one-time backup and verified it is absent from Actions secrets.
- [x] Re-read Production and QA function definitions/ACLs and Storage/Vault counts; no database writes performed.
- [x] Confirmed exact QA stored payload hashes for Phase 55, 57 and 57B.
- [x] Main CI passed the Phase 57/57B PostgreSQL 17 pharmacy integration; dedicated Phase 55 PostgreSQL 17 workflow [#43184305893](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43184305893) passed.

### Remaining — do not bypass

1. Owner-side decryption of the retained encrypted artifact with the offline private age identity; never upload or paste that identity.
2. Independent second-person review/sign-off of the Production Phase 55 and Phase 57/57B payloads. The PR #8 review was a self-review only.
3. Explicit Production release window/approval and immediate exact-head live preflight.
4. Confirm the supported forward-only migration application route preserves version/name/source provenance without QA ledger copying or manual ledger edits.
5. If and only if all gates pass, apply Phase 55 separately from the two-migration pharmacy hotfix; apply Phase 57 then Phase 57B in order, with read-only verification after each.
6. Recalculate all readiness only after verified post-apply results; real staff, Android, RTL/LTR and physical printer acceptance remain separate owner gates.

### Current live stop facts

- Production: PostgreSQL 17.6, 129 migrations, latest `20261102232941`; Phase 55/57/57B absent.
- QA: PostgreSQL 17.11, 26 migrations, latest `20261112061251`; Phase 55/57/57B present.
- Production dispensing function still has the NULL-to-one fallback; QA has all three guards.
- Production private claim-branch and role-sync helpers remain PUBLIC-effective; QA ACLs are owner-only.
- Storage: 3 buckets and 0 objects in each environment; Vault secrets: 0 in each environment.
- No Production or QA DDL/DML/ACL/RLS/Auth/Storage/business-data writes were made. The only secret mutation was deletion of the one-time GitHub Actions `SUPABASE_DB_PASSWORD` secret.

Full backup and source evidence: [`docs/BACKUP_EVIDENCE_2026-11-12.md`](BACKUP_EVIDENCE_2026-11-12.md).
