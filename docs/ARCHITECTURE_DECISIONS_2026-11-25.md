# Roshan Health Hub — Second Architecture Review and Decisions

**Research and repository review date:** 2026-11-25. These are architecture recommendations, not authorization to change clinical policy or production systems.

## Executive decision

Do not replace Roshan's current stack or start a greenfield rebuild. Keep the current modular monolith and concentrate effort on transaction integrity, least privilege, clinical-content governance, reproducible migration history, and real-world acceptance. The second review found no evidence that microservices, a full FHIR server or a new EMR would solve the present blockers.

## 1. Architecture: modular monolith, not microservices

Roshan is operated by a small clinic team with one active branch and a constrained engineering/operational budget. A single deployable application with clear domain boundaries minimizes deployment, observability, authentication and data-consistency overhead.

Keep explicit modules for identity/branch access, patient administration, clinical encounters, medication/decision support, laboratory, pharmacy/inventory, finance and reporting. Use database transactions/RPCs for multi-table business operations that must be atomic. Do not add distributed messaging or event sourcing until there is a demonstrated cross-service scale or reliability need.

## 2. Clinical content: adopt the WHO SMART/DAK method

The strongest conceptual improvement found is not another dosing library. It is a governed, software-neutral clinical content model based on WHO SMART Guidelines and Digital Adaptation Kits (DAKs). The WHO DAK implementation guide published 4 November 2026 describes localization, stakeholder orientation, validation, software updating, training, monitoring and change management. DAKs structure recommendations into personas, scenarios, workflows, core data elements, terminology, decision-support logic, indicators and functional/non-functional requirements.

Apply that approach to each Roshan protocol. Store or document: source organization, guideline title/version/date, local adaptation rationale, clinical setting, intended population, inclusion/exclusion, decision inputs, dose basis, route, formulation/concentration, frequency/duration, maximum dose, contraindications, renal/hepatic adjustments where relevant, warnings, output text, terminology mapping, test cases, clinician reviewer, approval date and retirement/supersession state.

Use a controlled lifecycle: Draft → Evidence checked → Locally adapted → Clinician reviewed → Approved for activation → Active → Retired. No code merge or passing unit test moves a protocol into Active. The medical approver owns clinical policy.

## 3. Interoperability: FHIR-compatible semantics, not a full rewrite

Preserve a clean mapping from Roshan's existing records to standard concepts such as Patient, Practitioner/PractitionerRole, Organization/Location, Encounter, Condition, Observation, MedicationRequest, MedicationDispense, ServiceRequest and DiagnosticReport. Add stable terminology identifiers and provenance where clinically meaningful.

Do not convert the database wholesale to FHIR resources or introduce a FHIR server until a real exchange partner, reporting mandate or national integration requirement exists. The near-term goal is semantic consistency and an export/mapping boundary, not a schema migration.

## 4. Security: measure against OWASP ASVS 5.0, then target risk

Use OWASP ASVS 5.0.0 as a verification catalogue. Adopt a practical Level 2 baseline for the web application and explicitly select higher-assurance controls for authentication, sensitive clinical data, pharmacy dispensing, financial posting, branch isolation and audit. This is a proposed assurance profile, not a certification claim.

For Supabase/PostgreSQL, review each function and table across all of these dimensions: schema exposure, schema USAGE, EXECUTE grants, SECURITY DEFINER/INVOKER, fixed empty search_path, fully qualified object names, role/branch checks, RLS policies, direct table grants, transaction effects and audit behavior. A SECURITY DEFINER count or advisor warning is an inventory signal, not a vulnerability verdict. Never revoke all authenticated EXECUTE grants in bulk.

The live second review confirmed a concrete pharmacy role gap and Production/QA private-helper ACL divergence. Fix those targeted contracts first; do not turn general advisor warnings into broad migrations.

## 5. Data and transaction integrity

Preserve one authoritative transaction boundary for each high-risk operation: dispense + stock movements + invoice; payment + receipt identity; inventory adjustment + immutable ledger; lab completion + audit; clinical encounter completion + billing. Require idempotency keys for retriable operations and prove both same-key replay and different-key concurrency. Denied calls must leave no idempotency row or business side effect.

Use append-only ledgers and compensating entries for reversals. Do not silently edit historical financial or inventory rows.

## 6. Backup and recovery: database is only one recovery domain

Separate the recovery inventory into database contents, Storage object bytes, Auth/users and recovery paths, Vault/secrets, project settings/control plane, DNS/deployment/environment bindings, and external backup destination. A successful PostgreSQL restore does not prove recovery of Storage, secrets or control-plane configuration.

Supabase's backup documentation distinguishes database backups from Storage object data; object bytes must be separately protected. The Production review currently reports zero Storage objects and zero Vault secrets, but the recovery procedure must be in place before the first real clinical attachment or secret-dependent feature is used.

RPO 24h, RTO 4h, daily cadence and 30-day retention remain proposals pending explicit owner acceptance and timed rehearsal.

## 7. Delivery efficiency

Use one canonical task per user-visible outcome, one builder per mutable file/migration set, independent review for high-risk SQL/security, and one exact-head CI pass after a coherent change. Parallelize disjoint tasks; do not parallelize edits to shared migrations or core workflows. Avoid repeated status reports that do not change the evidence.

Keep agent tooling optional and development-only. Do not add new CLI runtimes or paid services as project dependencies. Spec Kit remains agent-neutral.

## Decisions to carry forward

1. Keep the current modular monolith.
2. Introduce DAK-style clinical content governance before expanding decision support.
3. Keep FHIR as a semantic/interoperability mapping target, not a database rewrite.
4. Use OWASP ASVS 5.0 as a risk-based checklist; make no compliance claim.
5. Fix concrete grants/RPC/role gaps individually and test both allowed and denied paths.
6. Treat database, Storage, Vault and control-plane recovery as separate DR scopes.
7. Do not promise a compressed timeline until the PR backlog and owner acceptance gates are normalized.

## External references

- WHO, [Digital adaptation kits: implementation facilitation guide](https://www.who.int/publications/i/item/9789240120280), 4 November 2026.
- WHO, [SMART Guidelines](https://www.who.int/teams/digital-health-and-innovation/smart-guidelines).
- WHO, [Digital adaptation kit for child health in humanitarian emergencies](https://www.who.int/publications/i/item/9789240089907), 2024.
- OWASP, [Application Security Verification Standard](https://asvs.owasp.org/), stable version 5.0.0.
- Supabase, [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
- Supabase, [Database backups](https://supabase.com/docs/guides/platform/backups).
- Martin Fowler, [Monolith First](https://martinfowler.com/bliki/MonolithFirst.html).