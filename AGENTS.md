# Roshan Health Hub — agent operating rules

Read docs/AGENT_START_HERE.md first. It is the concise entry point and links to the authoritative project references.

## Authority and source-of-truth order

1. Owner-approved decisions and durable rules in .specify/memory/constitution.md.
2. Current evidence-backed status and execution roadmap in docs/MASTER_PLAN.md.
3. This file for operational execution rules.
4. Feature-specific specs/, migration manifests, tests, and specialist references.
5. Skills and dated execution logs are supporting guidance/evidence, never independent authority.

If sources conflict, prefer newer verified live repository/database/deployment evidence and the latest explicit owner decision. Record and reconcile the conflict; do not silently choose a stale note. The Constitution governs safety and authorization. The Master Plan governs current priorities.

## Mandatory execution behavior

- Start with the current main SHA, working branch/PR, exact-head CI, relevant issues, and latest status block in the Master Plan. Recheck the live target before every write.
- Inspect relevant implementation, schema, migrations, callers, tests, and dependencies before planning a change. Do not assume a historical phase note describes current code.
- For behavior changes, use test-first development: define observable acceptance criteria, add a regression test, implement the smallest complete fix, and verify it.
- Batch each logical task into one atomic commit containing code, tests, migrations, and documentation. Do not split one task into avoidable follow-up commits.
- Run focused validation first, then one exact-head CI run after the complete change is ready. Rerun only checks needed to validate a real correction. Report passed, failed, skipped, blocked, and untested separately.
- Use disposable PostgreSQL 17 for migration replay and integration tests. Use QA for controlled integration verification. Never create synthetic patient/clinical/pharmacy/lab/inventory/financial test transactions in Production.
- Production engineering changes are covered by the standing delegated authorization in Constitution Section X, including preflight, recovery, exact-head, security, zero-cost, and post-change gates. Existing synthetic/test-row reset and schema-rebuild authority is explicitly recorded there; do not ask the owner to repeat it. It does not authorize production test transactions or override clinical-policy and launch gates.
- Preserve migration history and provenance. Never edit the migration ledger to manufacture parity, weaken RLS/auth/audit/branch isolation to make tests pass, or expose secrets or real patient data.
- Protect free-tier limits: no paid services, quota bypasses, unnecessary builds/deployments, or duplicate integrations. Documentation/SQL-only changes must use the repository skip-build path where configured.
- Do not force-push, amend published commits, or rewrite Lovable-synced history. Use the existing branch and expected-SHA ref updates.
- Continue independent safe work when one task is blocked. Do not repeatedly retry a failing tool path; switch to a supported route or report the precise blocker.

## Clinical and operational boundaries

- Never invent or clinically approve diagnoses, medication choices, doses, frequencies, contraindications, or decision-support rules. Implement only clinician-approved specifications and authoritative, versioned evidence.
- A green CI run, merged PR, successful deployment, or code audit is not clinical/staff acceptance.
- Do not declare launch readiness until real staff workflow, clinical acceptance, security, backup/restore, and operational release gates are evidenced.
- Report engineering completion separately from operational readiness. Count only deduplicated, evidence-backed requirements; audits and documentation alone do not count as implementation completion.

## Specialist guidance

- For non-trivial work, read .agents/skills/roshan-engineering-orchestrator/SKILL.md and only relevant specialist skill(s).
- Use installed TDD/debugging/security/documentation skills when they add distinct value; avoid overlapping workflows.
- Graphify is optional analysis tooling only. It is not a runtime dependency and never replaces source/test/database verification.
- Spec Kit is agent-neutral; official none integration remains the repository baseline. Do not add paid agents, model credentials, or owner-operated local setup as a requirement.
