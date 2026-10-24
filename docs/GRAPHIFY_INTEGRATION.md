# Graphify integration for Roshan Health Hub

Status: repository integration prepared; isolated CLI smoke test passed; a local code-only graph was generated from the current branch. Full cross-layer acceptance review remains incomplete.

## Purpose

Graphify can help navigate relationships among React/TypeScript UI, RPCs, SQL migrations, schema, tests, and architecture documentation. It is a developer/agent navigation aid, not an authoritative source of truth and not a runtime dependency.

## Install locally

Requirements: Python 3.10+ and `uv`.

```sh
uv tool install 'graphifyy[sql]'
graphify --version
graphify install --platform codex --project
```

The PyPI distribution is named `graphifyy` (two trailing `y` characters); the installed CLI is `graphify`. The `[sql]` extra adds SQL parsing support. Official project: https://github.com/Graphify-Labs/graphify. Official installation guide: https://graphiffy.com/docs/install.

## First graph without paid API keys

Run from the repository root in an isolated developer environment. Use code-only mode by default: Graphify otherwise attempts semantic extraction of documentation/images and asks for a model API key. Do not configure a paid API key just to run this optional workflow.

```sh
graphify . --code-only
graphify cluster-only . --no-label
graphify query "lab result verification"
graphify query "invoice payment writes"
graphify query "clinical child table policies"
```

Verified CLI behavior with `graphifyy` 0.9.95:

- `graphify . --code-only` extracts code locally and writes `graphify-out/graph.json` plus analysis/manifest files; non-code docs/images are skipped.
- Install the `[sql]` extra to enable the SQL grammar. Some SQL files may still yield no symbols; read parser warnings and do not assume every migration was fully represented.
- `graphify cluster-only . --no-label` clusters the existing graph and generates `graphify-out/GRAPH_REPORT.md` and `graphify-out/graph.html` without paid model-based community naming. Labels remain generic `Community N`.
- `graphify query` performs breadth-first graph traversal from terms matched to nodes; it is not a semantic question-answering engine. Queries can return many loosely related nodes. Narrow them with explicit `--seed` and/or `--context` options, and treat results as navigation leads.
- A real code-only smoke run on this branch generated a local graph with 3,430 nodes and 8,990 edges. This confirms the CLI can process the repository; it does not prove complete coverage or validate every inferred relationship.

Before accepting the graph for regular engineering use:

1. Confirm the CLI version and command execution in the expected isolated environment.
2. Confirm `graphify-out/graph.json`, `GRAPH_REPORT.md`, and `graph.html` are generated locally. The repository ignores `graphify-out/`; keep these generated artifacts uncommitted unless separately reviewed.
3. Review extraction warnings, especially SQL files that yield no symbols and any skipped/sensitive files.
4. Manually trace at least three cross-layer paths: lab-result verification from UI through RPC/schema/tests; invoice/payment write paths and atomicity/security checks; a clinical workflow's migrations, policies, and tests.
5. Record missing edges, false inferences, unsupported file types, and time-to-answer versus targeted source search. Verify each important claim against source code and current tests.

## Security and scope

- Prefer tracked source code, SQL migrations, schema definitions, and tests. Do not point Graphify at the entire home directory or unrelated folders.
- Never include production data dumps, patient identifiers/files, real clinical notes, financial exports, credentials, tokens, private keys, `.env` files, or local secret stores.
- Code parsing can be local and deterministic, but non-code document extraction may require a model or remote service. Keep `--code-only` unless the processing route and data sensitivity have been explicitly reviewed.
- Inferred graph edges are hypotheses, not proof of a relationship.
- Graphify does not replace CI, TypeScript checks, security review, migration-source parity checks, or read-only Supabase verification.

## Operating policy

- No production dependency, database extension, hosted graph database, Vercel deployment, or paid service is required.
- Do not run graph generation on every CI job. Refresh locally after meaningful cross-layer changes and use it when it helps.
- Keep generated graph artifacts local by default; commit them only after a separate review establishes a concrete, safe use case.
- If the first-run review adds little value beyond existing source search and docs, keep Graphify optional rather than making it mandatory for every task.
