# Agent start here — Roshan Health Hub

Use this page to orient quickly. Do not begin by reading the entire historical execution log.

## Read in this order

1. .specify/memory/constitution.md — durable safety rules, clinical boundaries, production delegation, and the owner-approved reset of existing synthetic/test data.
2. docs/MASTER_PLAN.md — current verified status, active priorities, release gates, and the historical execution roadmap.
3. AGENTS.md — mandatory execution and verification behavior.
4. The relevant feature spec, migration manifest, source, tests, and specialist reference only after the live task is identified.
5. docs/PLUGIN_TOOLING_MAP.md — available integrations and safe routing; refresh live connection state before use.
6. docs/DB_MIGRATION_RECONCILIATION.md — migration evidence; its dated records must not be mistaken for current ledger state.

## First five minutes of every work session

- Read the current status block at the top of docs/MASTER_PLAN.md.
- Fetch live main SHA, active branch/PR head, PR reviews, exact-head CI and open issues. Historical notes are not live state.
- Identify the exact task and its acceptance evidence. Inspect the relevant code, schema, migration, callers and tests.
- Verify the intended environment/project identifiers before any external write.
- If a task is blocked, continue independent safe work rather than repeating failed attempts.

## Non-negotiable facts

- Existing rows in both QA and Production are synthetic/test data. The owner explicitly authorized resetting those existing rows and rebuilding affected schema objects under Constitution Section X. Never ask for that authorization again.
- That authority does not permit creating new synthetic patient, clinical, pharmacy, laboratory, inventory or financial transactions in Production.
- Preserve Supabase project identity, Auth access/recovery, credentials/secrets, environment bindings, deployment configuration and essential platform settings during data/schema reset work.
- Production engineering authority is delegated only within Constitution Section X and its preflight, recovery, exact-head validation, security, zero-cost and post-change safeguards.
- Clinical protocols, diagnoses, medication choices/doses/frequencies and decision-support policy require clinician approval.
- Green CI, merge, deployment and code review are not clinical/staff acceptance or launch approval.
- Report engineering release-candidate completion separately from operational readiness. Use evidence-backed, deduplicated progress only.

## Completion reporting

For each work batch, state:
- exact branch/commit/PR and changed files;
- what was implemented versus merely inspected;
- tests/checks actually run, with passed/failed/skipped/blocked distinctions;
- whether any QA/Production write occurred and exact target;
- remaining release blockers and residual risks;
- current engineering completion %, operational readiness %, and a defensible remaining-time estimate. Recalculate rather than copying stale estimates.

