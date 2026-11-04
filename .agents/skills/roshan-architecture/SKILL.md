---
name: roshan-architecture
description: Use when inspecting or changing Roshan architecture, modules, routes, data flow, UI boundaries, or cross-cutting behavior.
---

# Roshan Architecture
- Inspect the live repository and current branch, not an old handoff alone.
- Read relevant source, route tree, domain services, shared components, tests, and contracts.
- Consult Graphify only if its graph exists; inferred edges are hypotheses, verified against source.
- Respect the existing React, TypeScript, TanStack Start, and Supabase architecture and exact package versions.
- Keep domain behavior in established services/boundaries; UI components must not become hidden business-rule engines.
- Preserve separation of presentation, authorization, data access, and transactional database operations.
- Follow phone-first Arabic RTL and English LTR patterns.
- Reuse existing components, hooks, queries, RPCs, and helpers only after verifying their contracts.
- Never create parallel implementations, shadow data stores, duplicate route trees, or a second source of truth.
- Trace each flow through success, failure, retry, and recovery; identify the authoritative owner of each invariant.
- Reject speculative rewrites, gratuitous abstraction, premature microservices, and dependencies without a demonstrated gap.
