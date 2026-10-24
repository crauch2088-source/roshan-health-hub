# Graphify integration for Roshan Health Hub

Status: repository integration prepared; local CLI installation and graph generation must be completed in a development environment with shell access.

## Purpose

Graphify creates a queryable local knowledge graph across source code and supported project documents. Roshan can use it to navigate cross-layer relationships among React/TypeScript UI, RPCs, SQL migrations, schema, tests, and architecture documentation.

This is a developer/agent workflow only. It does not change application runtime behavior, Supabase schema, authentication, or production deployment.

## Install locally

Requirements: Python 3.10+ and the `uv` tool.

```sh
uv tool install graphifyy
graphify --version
graphify install --platform codex --project
graphify .
```

Official project: https://github.com/Graphify-Labs/graphify
Official install guide: https://graphiffy.com/docs/install

The PyPI distribution name is `graphifyy` (two trailing y characters); the installed CLI command is `graphify`. Codex invokes the skill as `$graphify` where supported.

## First-run acceptance checks

1. Confirm `graphify --version` works and the command is from the expected isolated environment.
2. Confirm generation creates `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`, and `graphify-out/graph.html`.
3. Ask at least three known-answer questions:
   - Trace laboratory result verification from UI to RPC, SQL definition, authorization boundary, and tests.
   - Trace invoice/payment writes and their atomicity/security checks.
   - Identify the migration, policies, and tests protecting a selected clinical workflow.
4. Manually verify each answer against the exact source paths and current tests. Record missed edges, unsupported file types, false inferred relationships, and the time needed to answer versus targeted search.
5. Keep generated files local and do not upload them to public services or commit them by default. Review `.gitignore` before the first run and make sure `graphify-out/` and any generated cache are ignored; do not blindly rewrite existing ignore rules.

## Security and scope

- Never include production data exports, patient identifiers, clinical notes, billing records, credentials, tokens, private keys, or `.env` files.
- Prefer code, tracked SQL migrations, schema definitions, tests, and reviewed documentation. Do not point the tool at the whole home directory or other unrelated folders.
- Graphify's local deterministic parsing of code does not imply that every supported document-processing path is local. If a document type requires a model, review the processing route before including it.
- Treat inferred graph edges as leads. Verify critical relationships in source and tests.
- Graphify does not replace CI, TypeScript checks, security review, migration-source parity checks, or read-only Supabase verification.

## Operating policy

- No production dependency, database extension, Vercel deployment, hosted graph database, or paid service is required.
- Do not run graph generation on every CI job. Refresh locally after meaningful cross-layer changes and query the graph when it helps.
- Keep generated graph artifacts out of commits unless a future, separately reviewed decision establishes a concrete need.
- If the first-run checks show little value beyond existing search/docs, leave Graphify optional rather than making it mandatory for every task.
