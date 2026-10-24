---
name: graphify
description: Query and build a local knowledge graph for the Roshan Health Hub codebase, linking source code, SQL migrations, schema, tests, and docs. Use for architecture questions and cross-layer impact analysis.
---

# Graphify for Roshan Health Hub

Use Graphify as a navigation aid for understanding this repository, not as the authority of record.

## Setup

1. Install Python 3.10+ and the `uv` tool using a trusted official distribution.
2. Install Graphify in an isolated tool environment:
   ```sh
   uv tool install graphifyy
   ```
3. From the repository root, install the project-scoped Codex skill:
   ```sh
   graphify install --platform codex --project
   ```
   This integration is checked into `.agents/skills/graphify/SKILL.md`; do not overwrite it blindly. If the installer reports these files already exist, compare generated files and preserve Roshan-specific security and workflow instructions.
4. Build the first graph locally from the repository root:
   ```sh
   graphify .
   ```
5. Query it, for example:
   ```sh
   graphify query "Which UI, RPCs, SQL tables, migrations, and tests participate in lab-result verification?"
   graphify query "What code paths write invoices and how are they protected?"
   graphify query "Which policies and tests protect clinical child tables?"
   ```
6. Inspect `graphify-out/GRAPH_REPORT.md`, `graphify-out/graph.json`, and `graphify-out/graph.html`. Verify each important claim against the cited source and current tests.

## Roshan-specific safety rules

- Start with source code, migrations, schema definitions, docs, and tests only. Do not include production data dumps, patient files, real clinical notes, financial exports, credentials, tokens, `.env` files, or local secret stores.
- Graphify's deterministic source parsing is not the same as proving every relationship. Mark inferred relationships as unverified and check the actual call sites, SQL definitions, and policies.
- Never use a graph result alone to authorize a database write, migration, permission change, clinical decision, or release.
- Do not add Graphify as an application dependency, server runtime, Supabase extension, or paid hosted service. Keep its executable and generated output outside production.
- Do not add a graph-generation step to every CI run. Refresh locally when architecture changes materially; generated output is local by default and must not be committed unless a later explicit review establishes a safe, useful reason.
- If processing PDFs or other non-code material requires a model or remote service, skip that content unless its sensitivity and processing route have been reviewed first.

## When to use it

Use `graphify query` before broad source searching for cross-layer questions, impact analysis, or locating related implementation and tests. Then use targeted file reads and the repository's documented verification commands. For simple symbol lookups, a normal search is sufficient.
