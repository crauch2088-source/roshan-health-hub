---
name: roshan-minimal-change
description: Use before refactoring, adding abstractions/dependencies, optimizing code, or expanding scope; apply Ponytail-inspired simplicity without weakening Roshan safety guarantees.
---

# Roshan Minimal Change

Ask: what is the smallest complete change that solves a demonstrated problem while preserving every existing contract?

1. Confirm the problem with source evidence, failing test, or measurable user need.
2. Search for an existing helper, component, query, RPC, permission, test utility, or dependency.
3. Prefer narrow extension over new abstraction; platform capability over new package.
4. Avoid speculative configurability, generic frameworks, duplicate state, wrapper layers, and premature optimization.
5. Remove code only when unreachable/redundant status and all callers are verified.
6. Explain maintenance and operational cost of any new dependency, service, workflow, runtime, or abstraction.

## Roshan safety override
Simplicity never permits weakening clinical validation, clinician confirmation, provenance, missing-value distinctions, authentication, permissions, RLS, branch isolation, audit history, atomic finance/stock RPCs, idempotency, exact precision, migration order, rollback planning, integration tests, release gates, accessibility, keyboard support, mobile usability, or RTL/LTR behavior.

Do not optimize away defensive checks because a happy-path test passes. Do not reduce test coverage to make a patch smaller. A simplification is accepted only when behavior is preserved or intentionally specified, tests pass, and maintainability improves without reducing security or clinical assurance.
