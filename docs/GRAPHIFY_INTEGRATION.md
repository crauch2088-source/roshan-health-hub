# Graphify integration for Roshan Health Hub

Status: repository integration prepared; isolated CLI smoke test passed; full Roshan repository graph generation and cross-layer acceptance review remain pending in a trusted shell-enabled development environment.

## Purpose

Graphify can help navigate relationships among React/TypeScript UI, RPCs, SQL migrations, schema, tests, and architecture documentation. It is a developer/agent navigation aid, not an authoritative source of truth and not a runtime dependency.

## Install locally

Requirements: Python 3.10+ and `uv`.

```sh
uv tool install graphifyy
graphify --version
graphify install --platform codex --project
```

The PyPI distribution is named `graphifyy` (two trailing `y` characters); the installed CLI is `graphify`. Official project: https://github.com/Graphify-Labs/graphify. Official installation guide: https://graphiffy.com/docs/install.

## First graph and acceptance checks

Run from the repository root in an isolated developer environment. Keep production data, patient identifiers, clinical notes, financial exports, credentials, tokens, private keys, `.env` files, and local secret stores out of the indexed corpus.

```sh
graphify .
graphify cluster-only .
graphify query "lab result verification"
graphify query "invoice payment writes"
graphify query "clinical child table policies"
```

Important CLI behavior verified with `graphifyy` 0.9.95:

- `graphify .` extracts code and writes `graphify-out/graph.json` plus analysis/manifest files.
- `graphify cluster-only .` then clusters the existing graph and generates `graphify-out/GRAPH_REPORT.md` and `graphify-out/graph.html` as well as updating `graph.json`.
- `graphify query` performs graph traversal from terms matched to nodes; it is not a guaranteed semantic question-answering engine. Treat results as navigation leads and verify important claims against source paths and tests.
- Without a configured model backend, community labels may remain generic. Do not add a paid API key solely to make this optional integration work.

Before accepting the first real project graph:

1. Confirm the CLI version and command execution in the expected isolated environment.
2. Confirm the files above are generated locally and remain untracked unless separately reviewed.
3. Review `.gitignore` before running; do not blindly overwrite existing ignore rules. Ensure `graphify-out/` and generated caches are ignored.
4. Inspect graph nodes/edges and manually trace at least three cross-layer paths: lab-result verification from UI through RPC/schema/tests; invoice/payment write paths and atomicity/security checks; a clinical workflow's migrations, policies, and tests.
5. Record missing edges, false inferences, unsupported file types, and time-to-answer versus targeted source search. Verify each important claim against source code and current tests.

## Security and scope

- Prefer tracked source code, SQL migrations, schema definitions, tests, and reviewed documentation. Do not point Graphify at the entire home directory or unrelated folders.
- Code parsing can be local and deterministic, but supported document-processing paths may use a model or remote service. Review processing behavior before including non-code documents.
- Inferred graph edges are hypotheses, not proof of a relationship.
- Graphify does not replace CI, TypeScript checks, security review, migration-source parity checks, or read-only Supabase verification.

## Operating policy

- No production dependency, database extension, hosted graph database, Vercel deployment, or paid service is required.
- Do not run graph generation on every CI job. Refresh locally after meaningful cross-layer changes and use it when it helps.
- Keep generated graph artifacts local by default; commit them only after a separate review establishes a concrete, safe use case.
- If the first-run review adds little value beyond source search and existing docs, keep Graphify optional rather than making it mandatory for every task.
