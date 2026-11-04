# Roshan Agent Tooling Research — 2026-11-04

**Purpose:** Evaluate codebase-graph, agent-skill, repository-analysis, and ChatGPT app capabilities for Roshan.  
**Decision scope:** Guidance and optional developer tooling only. No production integrations or paid services are approved by this document.

## Executive decision

1. **Keep the existing Graphify integration.** It directly addresses cross-file and cross-layer navigation, has already been smoke-tested on Roshan, and can run locally in code-only mode without a model API key.
2. **Route Graphify selectively through the Roshan orchestrator.** Use it for cross-module architecture questions, multi-hop data-flow tracing, broad refactors, and pre-change blast-radius analysis. Do not make it mandatory for small edits.
3. **Do not add GitNexus or Serena now.** They offer overlapping code-intelligence capabilities, but each adds material setup, operational, or licensing considerations. Revisit only against a demonstrated gap and a disposable-branch proof of value.
4. **Do not install another ChatGPT app for this work.** The relevant connections already available include GitHub, Supabase, Linear, Vercel, Context7, PostHog, and Superpowers. Use these before adding another integration.
5. **No Graphify Cloud, hosted graph database, production PostgreSQL introspection, new app dependency, or always-on graph CI.** The current local workflow is the lowest-risk fit.

## 1. Existing Graphify: fit and operating limits

Repository integration:
- Skill: `.agents/skills/graphify/SKILL.md`
- Operating guide: `docs/GRAPHIFY_INTEGRATION.md`
- Existing local smoke result recorded by the project: 3,430 nodes and 8,990 edges.
- Existing guide records SQL parser gaps and query precision limitations; the graph is a navigation aid, not a complete representation.

Current upstream Graphify repository describes local Tree-sitter parsing, cross-file calls/imports/inheritance, graph query/path/explain, subsystem communities, and optional semantic processing for non-code documents. It also documents SQL and PostgreSQL extras and newer PR-oriented commands. These upstream capabilities do not prove that the Roshan-installed version supports them or that the Roshan graph contains complete SQL relationships.

Roshan policy:
- Keep `--code-only` as the default.
- Use the graph to discover candidate files and relationships, then inspect source and tests.
- Never send patient/financial records, credentials, tokens, private keys, or `.env` files.
- Never point it at Production PostgreSQL or use graph output to approve SQL, RLS, grants, atomicity, clinical safety, or release decisions.
- Generated `graphify-out/` remains local/ignored. Do not assume it exists or matches the current branch.
- Do not add graph generation to every CI run or add Graphify to the application runtime.

**Version note:** The upstream repository is actively evolving and now documents features beyond the 0.9.95 CLI version recorded in the existing Roshan integration guide. Do not blindly upgrade. First compare the exact installed CLI version, review release notes and dependency changes, then run a disposable local smoke test and the three Roshan cross-layer acceptance traces. No paid backend is required for the code-only path.

## 2. Repository alternatives evaluated

### GitNexus — strong feature overlap, not selected

Repository: https://github.com/nxpatterns/gitnexus

Strengths documented upstream:
- Local repository indexing and a knowledge graph exposed through MCP.
- Impact/blast-radius, call-path tracing, change detection, API impact, route/tool maps, and optional program/data-flow analysis.
- Project skills for exploring, debugging, impact analysis, and refactoring.

Reasons not to add now:
- It overlaps substantially with Graphify's existing purpose; running both would create competing graph indexes and duplicate context.
- Its current README identifies a PolyForm Noncommercial license. Roshan's ownership, intended real-world use, and future operating model warrant legal review before adopting it; do not assume it is safe for unrestricted commercial use.
- The CLI has native/runtime and indexing requirements that need a separate compatibility and resource test on the project's actual environment.
- A public web UI or hosted deployment is not an acceptable place for private Roshan source or operational data without a separate security review.

Revisit only if Graphify fails a measured need such as precise change-impact mapping or API-contract impact. Evaluate in an isolated clone, compare false positives/false negatives against known Roshan paths, and review licensing before any adoption.

### Serena — complementary semantic IDE, not a Graphify replacement

Repository: https://github.com/oraios/serena

Strengths documented upstream:
- MCP tools for symbol-aware code retrieval, references, editing, refactoring, and debugging.
- Useful for precise cross-file symbol operations where text search is fragile.

Reasons not to add now:
- It solves a different layer (semantic IDE operations) and is not a repository-wide SQL/data-flow knowledge graph replacement.
- Its repository declares GPL-3.0-or-later; review licensing and deployment implications before adopting or redistributing.
- It adds another MCP server/runtime and setup surface. The existing GitHub tools and source/test workflow cover current repository editing needs.

Revisit if repeated work demonstrates costly or unsafe symbol-level rename/refactor tasks that the existing toolchain cannot handle. Test against a disposable branch; do not introduce it as a general prerequisite.

### Other categories

- Static dependency analyzers and import-graph tools can help with narrow language-specific checks, but they do not automatically model Roshan's clinical, database, branch-isolation, and transaction contracts.
- Security analyzers (for example, Semgrep/CodeQL-style checks) should be evaluated separately against current CI coverage and false-positive burden; do not add overlapping workflows without a specific uncovered risk.
- Repository summarizers and hosted code-chat products are not substitutes for exact source, migration, test, and database evidence.

## 3. Agent skills and workflow research

The current Roshan skills system already adapts useful principles from:
- https://github.com/addyosmani/agent-skills — task planning, incremental implementation, testing, review, security, and shipping workflows.
- https://github.com/DietrichGebert/ponytail — simplicity/YAGNI and avoiding needless dependencies/abstractions.

The right next step is to make the orchestrator select tools by task type, not to multiply skills:
- Graphify: cross-layer discovery and impact leads.
- Roshan specialist skills: clinical, database, security, pharmacy/lab, QA, and release invariants.
- General TDD/debugging skills: test-first implementation and reproducible diagnosis.
- GitHub connector: authoritative repository, PR, and CI operations.
- Supabase connector: direct database operations only within separately authorized gates.
- Context7: current upstream library documentation when implementation depends on a versioned API.

## 4. ChatGPT apps / plugins inventory

The official ChatGPT developer-tools directory currently lists integrations including GitHub, Supabase, Exa, Render, Parallel Search, Vercel, and Railway. Plugin discovery for this workspace also confirmed these relevant apps as already installed/available:

| App / capability | Workspace status | Roshan use |
|---|---|---|
| GitHub | Installed | Source, branches, PRs, reviews, CI, commits |
| Supabase | Installed | Schema, SQL, migrations, logs and database work under release gates |
| Linear | Installed | Issue/project tracking if the project elects to use it; do not duplicate GitHub Issues without a migration decision |
| Vercel | Installed | Deployment inspection and release evidence; preserve build quota |
| Context7 | Installed | Version-current library/API documentation |
| PostHog | Installed | Existing product analytics, feature flags, errors and logs; useful after real user traffic begins |
| Superpowers | Installed | General agent workflow and TDD methodology |
| TinyFish | Installed | Browser-based workflows when a supported site requires interaction; not a substitute for source-level tests |
| Figma | Installed | Design review and handoff if editable design work is needed |
| Product Design | Installed | UX audit/prototyping; use only when the task is explicitly design-focused |

No additional app is recommended for installation at this stage. The most relevant tools are already connected. In particular:
- Do not add another GitHub/Supabase/Vercel connection.
- Do not add a second issue tracker merely because Linear is available; avoid split sources of truth.
- Datadog/other observability services can introduce recurring cost and operational overhead. PostHog is already connected; first validate its existing free/available capabilities and actual production event volume before considering another service.
- A ChatGPT app connection is not blanket authorization to modify production. Continue to honor Roshan's explicit release gates and data-handling rules.

Directory reference: https://chatgpt.com/plugins?c=lifestyle&category=developer-tools  
Official Supabase app information: https://openai.com/business/plugins/supabase/

## 5. Recommended adoption sequence

| Priority | Action | Decision |
|---|---|---|
| P0 | Add conditional Graphify routing to the existing orchestrator and architecture skill | Implement in this PR |
| P0 | Add a contract test preventing Graphify from becoming mandatory or authoritative | Implement in this PR |
| P1 | Refresh Graphify locally after a meaningful cross-layer change and measure its value against targeted source search | Optional local evaluation |
| P1 | Review the current Graphify CLI release notes and test a version update in an isolated environment | Only if current version is stale or missing useful features |
| P2 | Benchmark GitNexus only if Graphify has a demonstrated impact-analysis gap; legal review first | Not selected |
| P2 | Trial Serena only if symbol-aware refactoring becomes a recurring bottleneck; license review first | Not selected |
| P2 | Reassess observability apps only after real production usage and measured monitoring gaps | Not now |

## Sources reviewed

- Graphify upstream: https://github.com/Graphify-Labs/graphify
- Graphify Roshan integration: `.agents/skills/graphify/SKILL.md` and `docs/GRAPHIFY_INTEGRATION.md`
- GitNexus upstream and license notice: https://github.com/nxpatterns/gitnexus
- Serena upstream and license notice: https://github.com/oraios/serena
- Addy Osmani Agent Skills: https://github.com/addyosmani/agent-skills
- Ponytail: https://github.com/DietrichGebert/ponytail
- ChatGPT developer tools directory: https://chatgpt.com/plugins?c=lifestyle&category=developer-tools
- Official Supabase app listing: https://openai.com/business/plugins/supabase/

This is a point-in-time assessment, not a guarantee that third-party features, licensing, pricing, or app availability will remain unchanged. Re-check upstream terms before adoption.
