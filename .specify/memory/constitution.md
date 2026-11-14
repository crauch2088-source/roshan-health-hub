# Roshan Health Hub Constitution

## Core Principles

### I. Clinical Safety and Data Fidelity
Clinical documents and workflows must reflect saved, authorized source records. Never invent, infer, silently normalize, or fill missing medication instructions, diagnoses, amounts, signatures, or clinical facts. Surface missing required clinical values explicitly.

### II. Patient Privacy and Least Privilege
Protect patient, staff, financial, and operational data. Enforce least privilege, branch scope, and row-level security at the authoritative data layer. Never place real patient/clinical/financial records, credentials, production exports, private keys, or secrets in specifications, test fixtures, model prompts, logs, or public URLs. Use synthetic data only.

### III. Database, Accounting, and Inventory Integrity
Preserve immutable financial and stock ledgers, atomic business operations, idempotency, exact amount precision, branch attribution, and auditable state transitions. Browser clients must not bypass approved RPC/write boundaries or perform protected direct table writes.

### IV. Migration and Production Safety
Treat migrations as ordered, reviewed, non-replayable production changes unless proven otherwise. Verify source provenance, dependencies, rollback/recovery, and disposable PostgreSQL 17 behavior before release. Production changes may be executed under the standing delegated authorization in Section X when every applicable release gate passes. Unverified backup/restore or migration provenance remains a blocker.

### V. Evidence-Based, Test-First Engineering
For behavior changes, define observable acceptance criteria, add regression coverage, and verify the exact candidate commit. Use focused tests, TypeScript/lint/build checks, disposable PostgreSQL 17 integration tests, and security/authorization tests as applicable. Report tests only as passed when actually executed; distinguish deferred, skipped, blocked, and untested work.

### VI. Source-of-Truth Discipline
docs/MASTER_PLAN.md is the project execution roadmap; AGENTS.md is operational guidance; this Constitution defines durable principles; specs/ contains feature-specific requirements/design artifacts. Do not create competing roadmaps or duplicate authoritative facts. Resolve contradictions using current source, tests, read-only evidence, and the latest approved project decision.

### VII. Mobile-First, Bilingual Usability
Design for phone-sized screens first. Support Arabic RTL and English LTR consistently, preserve keyboard and screen-reader usability, and test critical flows at narrow viewports. Avoid extra clicks and unsafe ambiguity in clinical, reception, laboratory, pharmacy, and financial workflows.

### VIII. Cost and Change Efficiency
Prefer free and already-connected capabilities. Do not add paid services, production dependencies, duplicate CI jobs, or forced deployments without demonstrated need and owner approval. Batch related work into one atomic commit and avoid repeated checks that add no new evidence.

## Development and Review Constraints

- Feature specifications must define user-visible behavior, scope, failure states, authorization expectations, and measurable acceptance criteria before implementation planning.
- Technical plans must be based on current repository architecture and verified database contracts, not a greenfield redesign or stale summaries.
- Tasks must map to requirements and verification evidence. A checked task without evidence is not complete.
- Security, privacy, clinical correctness, branch isolation, and financial consistency are release constraints, not optional polish.
- Spec Kit artifacts do not independently authorize production changes or supersede this Constitution's standing delegated authorization and its release gates.

## Governance

This Constitution is the durable engineering baseline for Roshan Health Hub. docs/MASTER_PLAN.md remains the execution source of truth. Amendments require a documented reason, explicit owner-approved decision, and review of affected specifications, tests, and operating guidance. If a requirement conflicts with clinical safety, patient privacy, or production protection, stop and resolve it before implementation.

## IX. Accelerated Execution Without Safety Erosion
Time-boxed delivery is an optimization constraint, never a clinical or security exception. Parallelize independent work, sequence dependent work explicitly, and measure completion from a deduplicated evidence-backed ledger. A Release Candidate is distinct from operational acceptance and Production authorization. A skipped test is not a pass; a merged change is not clinical validation; a successful deployment is not staff acceptance. The owner retains authority over clinical policy, residual-risk acceptance outside the delegated envelope, and operational launch. Production engineering execution is delegated under Section X. The binding execution procedure is documented in [docs/48H_ACCELERATED_EXECUTION_CHARTER.md](../../docs/48H_ACCELERATED_EXECUTION_CHARTER.md).

## X. Standing Delegated Production Authorization

The owner explicitly grants the engineering agent standing authority, effective 2026-11-12, to make and release production changes for Roshan Health Hub when the agent independently determines that the change is timely, necessary, evidence-supported, and within the safeguards below. This is an ongoing authorization; a separate conversational approval is not required for each qualifying routine production change.

### Authorized within the delegated envelope
- Apply reviewed, forward-only production database migrations and compatible application changes after exact-candidate CI, disposable PostgreSQL 17 validation, migration provenance/reconciliation, dependency checks, and a documented recovery/rollback strategy pass.
- Execute narrowly scoped production configuration, grants, RLS/policy, RPC, Edge Function, and Storage changes when the intended access model is proven, least privilege is preserved, and pre/post-change verification is available.
- Deploy or promote the canonical production application after exact-commit checks pass, target project/branch/environment are reverified, and deployment/rollback paths are understood.
- Perform routine, non-destructive operational maintenance and read-only diagnostics that are necessary to verify a release.
- Use synthetic data only in QA/disposable environments. Production must never be used for synthetic clinical, patient, pharmacy, laboratory, inventory, or financial testing.

### Mandatory preflight and execution rules
1. Verify the live repository head, target Supabase/Vercel project identifiers, current migration ledger, relevant schema/security state, and exact candidate commit immediately before action.
2. Review the complete diff and affected dependencies. Never rely on stale summaries, old approvals, or a green CI run from a different commit.
3. Require applicable focused regression tests, disposable PostgreSQL 17 tests, security/authorization/branch-isolation checks, and exact-head CI. A skipped or unavailable mandatory check is not a pass.
4. For database changes, preserve forward-only migration history, inspect grants/RLS/function security semantics, run relevant advisors, and capture read-only before/after evidence. Do not edit migration ledger history to force parity.
5. Prefer additive, reversible, idempotent changes. Record the recovery path and objective stop conditions before execution. If safe rollback is impossible, require a proven forward-recovery plan.
6. Batch related work into one atomic Git change and avoid redundant CI/deploy runs. Respect all free-tier quotas; never purchase, upgrade, bypass a quota, or create a paid resource.
7. Verify the actual production result after the change using read-only checks and safe health/smoke checks that do not create or alter live clinical/financial records. Report the exact commit, migration/deployment identifiers, checks run, and any residual risk.

### Owner-approved synthetic-data reset and schema rebuild authority (2026-11-14)

The owner explicitly confirms that **all data currently present in both Roshan Supabase environments (QA and Production) is synthetic/test data**. No real patient records have been trialed or entered, and the current records carry no real clinical, financial, inventory, or other business obligations. This is a durable project fact and standing authorization; the owner must not be asked to repeat it in later sessions.

Within that scope, the engineering agent is authorized to perform the following without a separate per-operation conversational approval when technically necessary for implementation, migration reconciliation, testing infrastructure, or recovery:

- Delete, truncate, reset, replace, or reseed existing synthetic/test rows in QA and Production.
- Rebuild or recreate affected application tables, indexes, constraints, functions, triggers, policies, and other database objects; apply/reapply corrective migrations where the migration history and recovery plan support it.
- Reset synthetic fixtures and test-only workflow state to establish a known-good baseline.

**Boundaries that remain mandatory:**

1. This authorization does not permit creating new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production as a testing strategy. Use disposable PostgreSQL or QA for test execution; Production resets are for removing existing test residue or necessary, validated schema repair.
2. Preserve the Supabase projects themselves, project identity, credentials/secrets, Auth access and owner/admin recovery path, environment bindings, deployment configuration, integrations, and essential platform settings. Do not delete or rotate these as a side effect of a data reset.
3. Before a destructive Production reset or schema rebuild, verify the exact project/ref, inventory the target objects and dependencies, capture a recoverable backup or equivalent export where available, define the recovery/forward-repair path, and confirm that the target scope contains only the synthetic data described above. If any real or legally/operationally binding data is discovered or the scope is uncertain, stop and ask.
4. Prefer narrow, repeatable, documented operations over a full database reset. Preserve migration history; never edit the migration ledger to manufacture parity. Capture read-only before/after evidence and verify application health, permissions, RLS, branch isolation, and critical schema invariants.
5. This authorization does not waive clinical-policy approval, independent security review where required, exact-head validation, zero-cost constraints, or the real staff/clinical acceptance gate.

**Authorization record:** Explicit owner approval in conversation on 2026-11-14. This standing authorization supplements Section X and is an explicit exception for the currently existing synthetic/test dataset only. It does not expand authority over any future real patient or business records.

### Actions still requiring a fresh, specific owner decision
- Deleting, truncating, anonymizing, bulk-editing, or otherwise irreversibly altering real or potentially real patient, clinical, staff, inventory, audit, or financial records; the existing synthetic/test data explicitly covered by the owner authorization above is excluded. Deleting user accounts or revoking access in a way that could lock out the clinic remains owner-gated.
- Changing clinical protocols, diagnosis logic, medication choices/doses/frequencies, decision-support recommendations, or other medical policy. The agent may implement only a clinician-approved specification; it must not invent or clinically approve such policy.
- Accepting a known unresolved critical/high security risk, disabling or weakening RLS/authentication/audit controls, exposing secrets, or relaxing branch isolation.
- Any action whose target, scope, data impact, cost, or recovery path cannot be established with high confidence.
- Declaring clinical/staff operational acceptance or authorizing the clinic's real-world launch.

### Stop conditions
Stop before the affected production action if evidence conflicts, the live target is ambiguous, migration history is unreconciled, a required test is unavailable/failing, recovery is unverified, the change risks data loss or patient harm, or the actual cost could exceed zero. Continue independent non-production work where safe, and report the blocker precisely.

This delegation does not authorize paid services, quota bypasses, unsafe shortcuts, or the use of production as a test environment. It does not transfer clinical judgment or real-world launch authority from the owner.

**Authorization record:** Explicit owner approval in conversation on 2026-11-12. This section supersedes older blanket statements that every Production engineering change requires a separate per-change conversational approval, but does not waive any technical, clinical, privacy, security, financial, recovery, or release gate.

**Version**: 1.3.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-14
