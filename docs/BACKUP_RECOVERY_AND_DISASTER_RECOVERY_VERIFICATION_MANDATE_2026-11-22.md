# Backup Recovery & Disaster Recovery Verification Mandate — 2026-11-22

## 1. Objective and execution mode

Neon is the primary autonomous executor. Execute this as one continuous, evidence-led recovery campaign on `fix/qa-operational-blockers-20261121` / PR #296. Do not stop after diagnosis or a proposed plan. Reconcile live state first, perform every safe engineering and QA task, run the required tests, document evidence, and return one consolidated report. Do not ask the owner to say “continue” between steps.

This mandate follows the verified QA pharmacy closure at HEAD `eda06ef234cba3d9261ac34613368b17d4fb3abe`. Re-check the live branch and PR head before writing; never assume this SHA is still current.

Primary target: diagnose failed manual backup workflow run `43764265014` (2026-11-15), validate the last reported successful encrypted database backup from run `43183851731` (2026-11-12), and establish a reproducible PostgreSQL 17 disaster-recovery verification path with defensible RPO/RTO evidence.

## 2. Non-negotiable safety boundaries

- Production Supabase project `jewzonxplxhogqrnhosl` and Production Vercel remain strictly read-only. No schema/data writes, migrations, restore, configuration changes, deployment, promotion, or destructive action.
- A backup/export of Production is data egress. Do not initiate a new Production export or copy a Production backup to another service/location unless the existing approved backup workflow, destination, access controls, retention, and data-handling policy explicitly authorize it. If authorization is unclear, stop that action and record the precise owner approval needed.
- Never retrieve, print, transmit, upload, paste, log, or expose private age identities, encryption keys, passwords, tokens, connection strings, or secrets. Do not ask the owner to send secrets in chat, PR comments, or issue text.
- Never place Production data or identifiable patient data in QA, GitHub artifacts, public logs, or an unapproved cloud runner. Treat all Production backups as sensitive, regardless of whether the database currently contains test records.
- QA project `hopfohcnrtbiqjkgeukz` may be used for synthetic-only tests. Use an isolated PostgreSQL 17 instance for restore drills; never restore over a shared QA or Production database.
- No merge to `main`, no PR merge, no branch retargeting, no weakening branch protection, no bypassing CI, and no clinical protocol activation.
- No paid services or new infrastructure charges. Do not create long-lived resources. Clean up temporary isolated resources and document cleanup.
- Preserve existing artifacts and reports. Never overwrite or delete the last known backup.

## 3. Phase A — Live-state and workflow diagnosis

1. Verify repository, PR #296 state, current head SHA, base SHA, branch, and recent commits through GitHub. Confirm PR remains open/draft/unmerged before changes.
2. Inspect the exact workflow definition and all scripts/actions invoked by `backup-runner`. Identify triggers, permissions, concurrency, retention, artifact destination, encryption/decryption mechanism, PostgreSQL version, dump format, and whether backup is database-only or includes storage/configuration.
3. Retrieve complete logs and job-level conclusions for failed run `43764265014`. Identify the first causal failure, not merely the final failed step. Classify it (authentication, network, timeout, disk, pg_dump/pg_dumpall compatibility, encryption, upload, artifact, permissions, or other) and cite exact job/step/log evidence.
4. Inspect successful run `43183851731`: verify conclusion, timestamp, workflow SHA, artifact name/ID, artifact size, retention/expiry, digest/checksum if available, encryption format, and whether the artifact remains downloadable. Do not download Production backup bytes to an unapproved environment.
5. Compare workflow revisions and environment/config references between the successful and failed runs. Do not expose secret values; report only secret names/presence and safe metadata.
6. Determine whether the workflow is truly scheduled and monitored, or only manually runnable. Check for missed schedules, stale credentials, expiry, concurrency locks, and alerting gaps.
7. Produce a concise root-cause statement with evidence and confidence level. If logs are unavailable, say so explicitly; do not infer a cause.

## 4. Phase B — Safe remediation

1. Fix the actual root cause in workflow/scripts/tests/docs on the PR branch only.
2. Least privilege: use read-only database credentials for backup extraction; narrowly scope GitHub permissions and artifact access. Avoid printing environment variables or command lines containing secrets.
3. Add robust failure handling: explicit PostgreSQL client/server compatibility checks, clear step boundaries, bounded retries only for transient failures, integrity verification, upload verification, and actionable failure summaries that redact sensitive values.
4. Ensure encrypted artifact creation is atomic: incomplete/failed runs must not be represented as successful backups. Preserve the last known good artifact.
5. Add/adjust automated tests for failure classification, secret redaction, artifact integrity/digest verification, encryption failure, upload failure, and restore compatibility where feasible.
6. Do not change Production secrets, database configuration, Vercel environment variables, backup destination policy, retention policy, or schedule without explicit owner authorization. If a necessary fix requires one of these changes, document it as an owner-gated action and continue with all independent safe work.
7. Do not dispatch a Production backup job unless Phase A confirms the existing workflow is approved for that exact action and it is read-only with an already approved destination. If not proven, do not dispatch.

## 5. Phase C — PostgreSQL 17 restore verification

Separate synthetic QA proof from Production-backup owner verification.

### C1. Synthetic QA restore drill (Neon may execute)

- Create or use a clearly labelled synthetic-only QA backup using the approved QA process and QA credentials.
- Use an isolated, temporary PostgreSQL 17 instance/container. Do not restore into the shared QA project.
- Verify the backup artifact checksum before restore.
- Restore using the documented process; capture exact PostgreSQL client/server versions, commands with secrets redacted, start/end timestamps, exit codes, database size, and validation results.
- Run structural and integrity checks: expected schemas/tables, extensions, migration/version markers, representative constraints/indexes/functions, row-count sanity for synthetic fixtures, and application-level smoke queries. Do not copy Production records into this drill.
- Record restore duration and the drill's measured RTO. Record backup timestamp and synthetic-data recovery point; do not mislabel it as Production RPO.
- Destroy the temporary instance and verify cleanup. Record evidence of cleanup.

### C2. Production backup decryption/restore (owner-gated unless an already-approved secure mechanism exists)

- Do not access the owner's private age identity or ask for it.
- Determine the exact supported local decryption and PostgreSQL 17 restore procedure from repository documentation/workflow source.
- Validate artifact metadata, digest, encryption envelope, and required tool versions without exposing key material.
- If an existing owner-controlled secure runner/secret mechanism is explicitly documented and authorized for restore-only verification, assess it; do not use it to reveal/export the private identity. Never move Production data to an unapproved environment.
- Otherwise prepare a precise owner-run procedure that keeps the private identity local to the owner and restores only to an isolated local PostgreSQL 17 instance. The owner must not paste secrets or decrypted Production data into ChatGPT, GitHub, PR comments, or Neon logs.
- Until that real Production artifact is decrypted and restored successfully, mark Production restore verification **OWNER REQUIRED / NOT VERIFIED**. A synthetic QA restore is not a substitute.

## 6. RPO/RTO and operational controls

Calculate only what evidence supports:
- **Backup age / observed RPO:** timestamp of the latest verified successful Production backup compared with the observation time. Clearly distinguish scheduled target from observed value.
- **RTO:** measured time from restore start to successful validation in the isolated PostgreSQL 17 drill. If only QA synthetic data is restored, label the result “QA drill RTO”, not Production RTO.
- Report backup frequency, last success, last failure, artifact retention/expiry, and alerting/monitoring status.
- Do not invent target RPO/RTO. If the repository has no approved objectives, recommend explicit proposed objectives and label them pending owner approval.

## 7. Independent verification and release gate

- Run relevant unit/integration/security tests, workflow lint/actionlint if present, secret scanning, and PostgreSQL 17 restore tests.
- Verify the final workflow cannot leak secrets in logs and does not write to Production.
- Re-run exact-head GitHub CI after final changes; report every check and SHA.
- Independently review the diff and the backup/restore threat model. Confirm no private key, password, real patient data, or Production dump was committed.
- Keep PR #296 open and Draft. Do not merge.
- Production release decision remains **NO-GO** until owner-gated Production restore proof, Android acceptance, staff/printer acceptance, clinical sign-off, and migration review are completed.

## 8. Required documentation and final report

Update, without deleting history:
- `docs/MASTER_PLAN.md` with a dated checkpoint and explicit remaining owner gates.
- A new report: `docs/parallel-reports/NEON_BACKUP_RECOVERY_DRILL_REPORT_2026-11-22.md`, following `docs/parallel-reports/TEMPLATE.md`.
- Workflow/runbook documentation with safe restore steps and secret-handling warnings.

The final report must include:
1. Final branch and exact HEAD SHA; PR state and base SHA.
2. Root cause of run `43764265014`, with workflow/job/step evidence.
3. Status and metadata of artifact from run `43183851731` (no secret values).
4. Exact code/workflow changes and tests added.
5. Whether a new Production backup was deliberately not run, and why.
6. QA synthetic PostgreSQL 17 restore evidence, measured QA RTO, validation, and cleanup.
7. Production backup decrypt/restore status and the exact owner action still required.
8. Observed Production backup age/RPO calculation and caveats.
9. CI results on exact final SHA.
10. Security review: permissions, data egress, secret redaction, artifact retention, and no Production writes.
11. Any owner approvals required, stated as the smallest precise action.
12. Updated Engineering RC and Operational Acceptance only if a documented rubric justifies recalculation; otherwise retain prior reported values as historical and state current scores unassessed.
13. Explicit Production decision: **NO-GO** unless all release gates are genuinely closed.

Do not claim “backup recovery complete” merely because the workflow passes or a synthetic QA restore succeeds. The Production disaster-recovery gate closes only after a verified restore of the approved Production backup under the approved owner-controlled security boundary.
