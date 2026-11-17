# Google Antigravity CLI — Roshan setup

**Status:** repository-side integration prepared; local CLI installation and Google OAuth sign-in are still owner-side steps. No CLI was installed remotely and no account credentials were accessed.

## 1. Why Antigravity CLI

The owner has Google AI Pro through Google One. Google's official transition notice says Gemini CLI stopped serving individual Google AI Pro/Ultra and individual free-tier requests on 2026-06-18. Antigravity CLI (agy) is the supported consumer path and supports personal Google Account OAuth. Do not try to reuse Google AI Pro as Gemini CLI authentication.

Official references:
- [Antigravity CLI getting started](https://antigravity.google/docs/getting-started)
- [Antigravity CLI best practices](https://antigravity.google/docs/cli/best-practices/)
- [Rules and workspace instruction discovery](https://antigravity.google/docs/rules/)
- [Google's Gemini CLI transition announcement](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/)

## 2. Install on Windows (PowerShell)

Open PowerShell on the computer that will hold the repository and run the official installer:

~~~powershell
irm https://antigravity.google/cli/install.ps1 | iex
~~~

Close and reopen PowerShell, then verify:

~~~powershell
agy --version
~~~

If Windows cannot find agy, add the installer's documented directory to the user PATH:

~~~text
%LOCALAPPDATA%\agy\bin
~~~

For Linux/macOS, use the official installer shown on the Google getting-started page; do not copy an installer from a third-party mirror.

## 3. Sign in with Google AI Pro

1. Open the Roshan repository folder in a trusted local workspace.
2. Run agy from that repository folder.
3. Complete the browser sign-in using the same personal Google Account that owns Google AI Pro through Google One.
4. Select the personal Google account / Google OAuth path (oauth-personal), not Gemini Enterprise, API key, or a paid Google Cloud project.
5. Confirm the signed-in account and current quota in the CLI's /usage command. Plan limits can change; do not assume unlimited usage.

Never paste a Google password, OAuth token, API key, service-role key, or backup identity into the repository, prompts, issue comments, or terminal logs.

## 4. Apply conservative local permissions

Google's CLI best-practices guide documents the user settings file at:

%USERPROFILE%\.gemini\antigravity-cli\settings.json

Create the directory if needed and use this conservative starting configuration:

~~~json
{
  "toolPermission": "strict",
  "enableTerminalSandbox": true
}
~~~

Strict mode asks before non-read operations; terminal sandboxing limits command execution. Do not switch this repository to unrestricted/auto permissions. Review every requested shell command and file diff before approval.

## 5. Open Roshan and use the included agent workflows

From PowerShell:

~~~powershell
cd path\to\roshan-health-hub
agy
~~~

The CLI automatically discovers root AGENTS.md and the workspace rules under .agents/rules/. The reusable prompts under .agents/workflows/ define:

- roshan-independent-review — evidence-based, read-only independent review.
- roshan-guarded-implementation — test-first implementation on an explicitly assigned feature branch, ending in a Draft PR (never merge).

The root AGENTS.md, docs/MASTER_PLAN.md, docs/DB_MIGRATION_RECONCILIATION.md, and docs/PLUGIN_TOOLING_MAP.md remain authoritative. These Antigravity instructions supplement rather than replace them.

## 6. Roshan safety and collaboration contract

- Start as a reviewer/verifier, not an autonomous production operator.
- Inspect current branches and PRs before choosing a task; avoid overlapping active agents.
- No Production/QA DDL, DML, grants, RLS, Auth, Storage, migration application, or synthetic patient/financial transactions.
- No merge, deployment, Vercel/Supabase settings changes, backup dispatch, or destructive action without separate explicit approval.
- Work on a dedicated feature branch/worktree only when implementation is assigned. Never write to main.
- Use PostgreSQL 17 disposable CI/local tests only for database regression tests.
- Report exact SHAs, evidence classes, test commands/results, blockers, and unverified acceptance gates.
- Preserve the existing quota-safe policy: one atomic commit and one CI run per completed stage; documentation-only work must not trigger frontend deployment.

## 7. Device note

The CLI must run on a supported desktop OS with the repository checked out locally; it does not install directly inside the Android ChatGPT app. On a low-memory laptop, start with small read-only review tasks and avoid indexing multiple worktrees simultaneously. If the machine becomes unresponsive, stop the CLI rather than disabling sandbox or permission checks. A cloud development environment can be considered later, but it must be explicitly selected and its access/cost reviewed first.

## 8. Acceptance checklist

- [ ] Official agy installer completed on the owner's machine.
- [ ] agy --version returns a version.
- [ ] Personal Google AI Pro account signed in via OAuth.
- [ ] /usage confirms plan quota.
- [ ] Strict tool permission and terminal sandbox enabled.
- [ ] Roshan workspace rules/workflows discovered.
- [ ] First read-only review completed without accessing secrets or hosted write paths.

Until these checks are completed by the owner, record the CLI as **configured in repository, not yet installed/authenticated locally**.
