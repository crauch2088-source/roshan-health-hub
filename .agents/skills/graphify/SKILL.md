---
name: graphify
description: Query and build a local knowledge graph for the Roshan Health Hub codebase, linking source code, SQL migrations, schema, tests, and docs for architecture questions and cross-layer impact analysis.
---

# Graphify for Roshan Health Hub

Use Graphify as a navigation aid for understanding this repository, not as the authority of record.

## Setup and first run

1. Install Python 3.10+ and `uv` from trusted official sources.
2. Install Graphify in an isolated tool environment:
   ```sh
   uv tool install graphifyy
   graphify --version
   ```
3. From the repository root, install the project-scoped Codex skill:
   ```sh
   graphify install --platform codex --project
   ```
   This skill is checked in at `.agents/skills/graphify/SKILL.md`. Do not blindly overwrite it if the installer reports an existing file; compare output and preserve Roshan-specific safety rules.
4. Build and prepare the graph:
   ```sh
   graphify .
   graphify cluster-only .
   ```
   `graphify .` extracts nodes/edges to `graphify-out/graph.json`; `graphify cluster-only .` generates `GRAPH_REPORT.md` and `graph.html` too. Generated files should stay local by default.
5. Use traversal queries as leads, for example:
   ```sh
   graphify query "lab result verification"
   graphify query "invoice payment writes"
   graphify query "clinical child table policies"
   ```
   The query command traverses nodes matched by terms; it is not guaranteed semantic Q&A. Check source paths, call sites, SQL definitions, RLS policies, and current tests before trusting a conclusion.

## Roshan-specific safety rules

- Start with source code, migrations, schema definitions, docs, and tests only. Never include production data dumps, patient files, real clinical notes, financial exports, credentials, tokens, `.env` files, or local secret stores.
- Deterministic source parsing does not mean every document-processing path is local. Skip PDFs and other non-code material until the processing route and sensitivity have been reviewed.
- Mark inferred relationships as unverified; confirm actual call sites, SQL definitions, and policies.
- Never use graph output alone to authorize a database write, migration, permission change, clinical decision, or release.
- Do not add Graphify as an application dependency, server runtime, Supabase extension, or paid hosted service.
- Do not add graph generation to every CI run. Refresh locally after meaningful architecture changes; generated output remains uncommitted unless separately reviewed for a concrete safe use case.

## When to use it

Use `graphify query` before broad source searching for cross-layer impact questions, then open the identified source files and run the repository's documented verification commands. For simple symbol lookups, ordinary code search is sufficient.
