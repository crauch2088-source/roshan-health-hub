# Roshan Health Hub Constitution

## Core Principles

### I. Clinical Safety and Data Fidelity
Clinical documents and workflows must reflect saved, authorized source records. Never invent, infer, silently normalize, or fill missing medication instructions, diagnoses, amounts, signatures, or clinical facts. Surface missing required clinical values explicitly.

### II. Patient Privacy and Least Privilege
Protect patient, staff, financial, and operational data. Enforce least privilege, branch scope, and row-level security at the authoritative data layer. Never place real patient/clinical/financial records, credentials, production exports, private keys, or secrets in specifications, test fixtures, model prompts, logs, or public URLs. Use synthetic data only.

### III. Database, Accounting, and Inventory Integrity
Preserve immutable financial and stock ledgers, atomic business operations, idempotency, exact amount precision, branch attribution, and auditable state transitions. Browser clients must not bypass approved RPC/write boundaries or perform protected direct table writes.

### IV. Migration and Production Safety
Treat migrations as ordered, reviewed, non-replayable production changes unless proven otherwise. Verify source provenance, dependencies, rollback/recovery, and disposable PostgreSQL 17 behavior before release. Never apply candidate SQL, change production privileges, mutate Auth/Storage, deploy, or alter live business data without explicit owner authorization and documented release gates. Unverified backup/restore or migration provenance remains a blocker.

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
- Spec Kit artifacts do not authorize production changes or supersede owner-approved release gates.

## Governance

This Constitution is the durable engineering baseline for Roshan Health Hub. docs/MASTER_PLAN.md remains the execution source of truth. Amendments require a documented reason, explicit owner-approved decision, and review of affected specifications, tests, and operating guidance. If a requirement conflicts with clinical safety, patient privacy, or production protection, stop and resolve it before implementation.

## IX. Accelerated Execution Without Safety Erosion
Time-boxed delivery is an optimization constraint, never a clinical or security exception. Parallelize independent work, sequence dependent work explicitly, and measure completion from a deduplicated evidence-backed ledger. A Release Candidate is distinct from operational acceptance and Production authorization. A skipped test is not a pass; a merged change is not clinical validation; a successful deployment is not staff acceptance. The owner retains authority over clinical policy, residual-risk acceptance, Production changes, and launch. The binding execution procedure is documented in [docs/48H_ACCELERATED_EXECUTION_CHARTER.md](../../docs/48H_ACCELERATED_EXECUTION_CHARTER.md).

**Version**: 1.1.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-10
