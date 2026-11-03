# OpenCode Cloud Workspace — Roshan Health Hub

**Status:** repository bootstrap merged to main via PR #154 (`e3fa0febb7d27b21bfdf169d75a945b5aad5b71e`); Codespace creation and model sign-in still require the repository owner's interactive GitHub/provider authorization.

## Purpose and scope

This repository configuration prepares OpenCode to run inside GitHub Codespaces and be used from a browser or phone. It does not add an application runtime dependency, change the clinical product, connect a database, or alter production infrastructure.

- Repository: https://github.com/crauch2088-source/roshan-health-hub
- Base at bootstrap: `8ab4340f7fccbd22c79b9f7665230d748d2c66d6`
- Node runtime: 22.x, matching the application.
- OpenCode CLI: installed in the Codespace by the devcontainer after creation.
- Default agent: `plan` (read-only planning mode).
- Project agents: architect, reviewer, QA, and implementer.

## Create the cloud workspace

1. Open the repository on the bootstrap branch and choose **Code → Codespaces → Create codespace on this branch**.
2. Select a **2-core** machine initially. Do not select a larger machine unless a measured task requires it.
3. Let the devcontainer finish. It runs `npm ci`, installs the official OpenCode CLI package `@opencode/cli`, and prints the installed version.
4. Confirm the CLI is available:

   ```bash
   opencode --version
   ```

GitHub documents included monthly Codespaces usage for personal accounts (Free: 120 core-hours and 15 GB-month storage; Pro: 180 core-hours and 20 GB-month storage). Actual remaining quota depends on account plan, billing cycle, and prior use. This setup does not enable billing or add a payment method. Stop the Codespace when finished and use the shortest practical idle timeout.

## Protect the browser session

Before exposing the OpenCode server through a forwarded port:

1. In GitHub **Settings → Codespaces → Secrets**, create a secret named `OPENCODE_PASSWORD` scoped to this repository.
2. Use a long, unique password. Do not put it in chat, repository files, shell history, or screenshots.
3. In the Codespace terminal, start the authenticated web UI:

   ```bash
   test -n "$OPENCODE_PASSWORD" || { echo "Missing OPENCODE_PASSWORD Codespaces secret"; exit 1; }
   opencode web --hostname 0.0.0.0 --port 4096
   ```

4. Open forwarded port 4096. Its devcontainer visibility is configured as **private**. Do not change it to public.

The password is read from the Codespaces secret at runtime. No server starts automatically, and no unauthenticated network listener is started by the devcontainer.

## Connect a free model

OpenCode provider credentials must be entered interactively inside OpenCode; never paste an API key into ChatGPT or commit it.

1. Create a free-tier API key in Google AI Studio: https://aistudio.google.com/apikey
2. In the OpenCode interface, run `/connect`, choose Google, and enter the key directly into the provider prompt.
3. Run `/models` and select a model that the provider currently marks as available on its free tier. Prefer a Flash-class model for the initial read-only audit.
4. Verify a simple read-only prompt before enabling implementation work.

Groq is an optional alternative provider if its current free-tier limits are more suitable: https://console.groq.com/keys

Free-tier availability, model names, rate limits, and data-use terms can change. Verify them at the provider before use. Do not send real patient information, clinical records, production database exports, credentials, private keys, or secrets to any free-tier model. Provider free-tier terms may permit use of submitted prompts to improve their services.

OpenCode stores provider authentication in its user-level data directory (not this repository). Do not copy its auth file into the workspace or commit it.

## Roshan operating protocol

1. Start with `AGENTS.md`, then read `docs/MASTER_PLAN.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, and `docs/PLUGIN_TOOLING_MAP.md`.
2. Begin with the built-in `plan` agent and read-only architecture discovery.
3. Use `@roshan-architect` and `@roshan-reviewer` for independent read-only analysis; use `@roshan-qa` to plan and run approved local tests; use `@roshan-implementer` only for an explicitly assigned implementation.
4. Keep each task on a fresh `opencode/<task>` branch. Never work directly on `main`.
5. The project policy requires one atomic commit per logical task, with tests and docs included.
6. Pushes are denied except explicit approval-gated pushes to `opencode/*` branches. PR merges are denied.
7. Supabase CLI, direct SQL clients, production deployment commands, and database backup/restore commands are denied by the project policy.
8. Never use `--auto` or another auto-approval mode. Review every requested edit and shell command.
9. Test only against local fixtures or isolated QA resources with synthetic data. This workspace receives no Supabase or Vercel secrets.

## Important limitations

- This PR prepares the repository; it cannot create a Codespace or inspect your personal remaining Codespaces quota through the connected GitHub integration.
- The GitHub integration available to this assistant can inspect and modify repository content, branches, and PRs, but does not expose the Codespaces create/start API. The owner must create the Codespace from GitHub's UI.
- The free model key must be entered by the owner directly in OpenCode. No credentials have been requested or stored by this setup.
- Do not merge this bootstrap PR until the Codespace has been created, the CLI version verified, the browser port authenticated/private, and a free provider successfully answers a read-only prompt.

## Official references

- OpenCode installation: https://opencode.ai/v2/docs/commands/
- OpenCode agents: https://opencode.ai/v2/docs/agents/
- OpenCode permissions: https://opencode.ai/v2/docs/permissions/
- OpenCode providers: https://opencode.ai/v2/docs/providers/
- OpenCode web UI: https://dev.opencode.ai/v2/docs/cli/web
- GitHub Codespaces usage: https://docs.github.com/en/codespaces/troubleshooting/troubleshooting-included-usage
- GitHub Codespaces billing: https://docs.github.com/en/billing/concepts/product-billing/github-codespaces

<!-- LIVE-PHASE49-52-RECONCILIATION-2026-11-03 -->
## Merge update — 2026-11-03

- PR #154 merged to main at `e3fa0febb7d27b21bfdf169d75a945b5aad5b71e`; CI run [41531738728](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41531738728) succeeded.
- The devcontainer, project policy and agents are on main. Codespace creation, `OPENCODE_PASSWORD`, provider authentication and the first read-only smoke prompt remain owner-interactive. This run did not create a Codespace, set a secret, authenticate a provider or enable a paid resource; operational success remains unverified.
