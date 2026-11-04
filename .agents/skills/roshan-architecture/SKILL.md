---
name: roshan-architecture
description: Use when inspecting or changing Roshan architecture, modules, routes, data flow, UI boundaries, or cross-cutting behavior.
---

# Roshan Architecture
- Inspect the live repository and current branch, not an old handoff alone.
- Read relevant source, route tree, domain services, shared components, tests, and contracts.
- For cross-module or cross-layer investigations, consult the existing Graphify skill when a graph for the current branch is available; use it to find candidate paths, callers, and affected modules before broad manual search.
- Verify Graphify findings against actual source, call sites, SQL/migrations, schema, and tests. Check graph freshness and parser warnings; inferred edges are not proof.
- If Graphify is unavailable, stale, or unhelpful, proceed with targeted source search. Do not make Graphify a prerequisite for simple or localized work.
- Use Graphify's local `--code-only` mode by default. Never include production data, patient/financial records, credentials, tokens, or `.env` files; never connect the graph tool to Production PostgreSQL.
- Graphify is not authoritative for SQL/RLS/grants, transaction atomicity, clinical safety, or release decisions. Inspect the actual definitions and verification evidence directly.
- Respect the existing React, TypeScript, TanStack Start, and Supabase architecture and exact package versions.
- Keep domain behavior in established services/boundaries; UI components must not become hidden business-rule engines.
- Preserve separation of presentation, authorization, data access, and transactional database operations.
- Follow phone-first Arabic RTL and English LTR patterns.
- Reuse existing components, hooks, queries, RPCs, and helpers only after verifying their contracts.
- Never create parallel implementations, shadow data stores, duplicate route trees, or a second source of truth.
- Trace each flow through success, failure, retry, and recovery; identify the authoritative owner of each invariant.
- Reject speculative rewrites, gratuitous abstraction, premature microservices, and dependencies without a demonstrated gap.
