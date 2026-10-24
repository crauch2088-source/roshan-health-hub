---
name: graphify
description: Query and build a local knowledge graph for the Roshan Health Hub codebase, linking source code, SQL migrations, schema, tests, and docs for architecture questions and cross-layer impact analysis.
---

# Graphify for Roshan Health Hub

Use Graphify as a navigation aid for understanding this repository, not as the authority of record.

## Setup and first run

1. Install Python 3.10+ and `uv` from trusted official sources.
2. Install Graphify with SQL grammar support in an isolated tool environment:
   ```sh
   uv tool install 'graphifyy[sql]'
   graphify --version
   ```
3. From the repository root, install the project-scoped Codex skill:
   ```sh
   graphify install --platform codex --project
   ```
   This skill is checked in at `.agents/skills/graphify/SKILL.md`. Do not blindly overwrite it if the installer reports an existing file; compare output and preserve Roshan-specific safety rules.
4. Build the graph without model/API keys:
   ```sh
   graphify . --code-only
   graphify cluster-only . --no-label
   ```
   Code-only mode skips docs and images that would otherwise require semantic extraction. The SQL extra enables SQL grammar support, but inspect warnings because some SQL files may still yield no symbols. The cluster command creates `GRAPH_REPORT.md` and `graph.html` without model-based community naming. Generated files stay local under ignored `graphify-out/`.
5. Use traversal queries as leads:
   ```sh
   graphify query "lab result verification"
   graphify query "invoice payment writes"
   graphify query "clinical child table policies"
   ```
   Results can be broad. Use `--seed` and/or `--context` to narrow the traversal. This is not semantic Q&A; check source paths, call sites, SQL definitions, RLS policies, and current tests before trusting a conclusion.

## Roshan-specific safety rules

- Start with source code, migrations, schema definitions, and tests only. Never include production data dumps, patient files, real clinical notes, financial exports, credentials, tokens, `.env` files, or local secret stores.
- Deterministic source parsing does not mean every document-processing path is local. Keep `--code-only` unless document processing and data sensitivity have been reviewed first.
- Mark inferred relationships as unverified; confirm actual call sites, SQL definitions, and policies. Inspect parser warnings for SQL files with no extracted symbols.
- Never use graph output alone to authorize a database write, migration, permission change, clinical decision, or release.
- Do not add Graphify as an application dependency, server runtime, Supabase extension, or paid hosted service.
- Do not add graph generation to every CI run. Refresh locally after meaningful architecture changes; generated output remains uncommitted unless separately reviewed for a concrete safe use case.

## When to use it

Use `graphify query` before broad source searching for cross-layer impact questions, then open the identified source files and run the repository's documented verification commands. For simple symbol lookups, ordinary code search is sufficient.
