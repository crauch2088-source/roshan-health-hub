# Roshan Health Hub — zero-additional-money operating plan

## Scope and outcome

Read-only review completed on 12 November 2026. AI implementation is paused. No source edits, builds, tests, installations, purchases, integration changes, secret changes, database actions, deployments, publishing, or backups were performed during this review. Only this required planning document is created. Approval of this report must not be treated as permission to resume implementation or release anything.

“No additional money” is achievable by remaining on Free and declining purchases. It does **not** mean unlimited agent work or zero credit consumption: planning itself uses credits.

## 1. GitHub connection: evidence versus uncertainty

- `docs/MASTER_PLAN.md:164–166` identifies the canonical repository as **https://github.com/crauch2088-source/roshan-health-hub**. Its historical records repeatedly identify `main` as the canonical branch. This is documentary evidence, not a live sync-status check.
- `AGENTS.md:17–24` contains Lovable's connection notice and warns that published-history rewrites can lose project history. It does not identify today's active synced branch.
- The sandbox checkout is at **75161cea594f5541fa31560aa144fc6b03638390**, on internal branch **edit/edt-972ea1b3-5463-47b9-b2b8-d2f933ce3672**. Its remotes are Lovable infrastructure, not a GitHub remote. The working tree is clean relative to that internal snapshot; this does **not** prove equality with GitHub `main` or that syncing is active.
- The Git-sync connection/status is not exposed to this agent. **Active sync, current repository, active branch, current GitHub head, and divergence are unverified.** Do not reconnect, disconnect, or infer that the internal branch is the GitHub branch.
- Decisive next evidence: on your phone, open this project's **… → Settings → Git**, and read the repository, branch, and sync status. A screenshot of those non-secret fields is sufficient; do not include credentials. Expect the documented repository above, but verify it rather than assume.

## 2. What Free permits without buying anything

Authoritative workspace lookup returned **Plan: Free**.

| Capability | Free availability and limit |
|---|---|
| Browse/search/copy code | Available; the Free Code editor is read-only. Direct editing/saving there requires a paid plan. |
| Agent code edits | Build mode can edit the existing project using available credits; cost is usage-based, not a fixed number of tasks. |
| Read-only discussion/planning | Chat mode has a separate daily allowance. Plan mode costs 1 credit per message; delegated research can add usage. |
| Agent tests/build/browser checks | Available within agent work and its credit budget; not an unlimited independent free compute service. |
| GitHub two-way sync | Available on all plans. No new connection is needed if the existing one works. |
| Drafts | Available on all plans; draft code is isolated and does not sync until accepted. Drafts are not equivalent to GitHub branches. Do not create one for this review. |
| GitHub CI | Existing workflow is present. Its account quota, repository visibility, current spend settings, and current results were not queried. Do not promise unlimited free runs. |

Balance lookup during this review: **4.70 build credits remaining**, daily grant **5.00**. Separate free Chat allowance: **100% remaining, 3.00 of 3.00 credits**. These are a snapshot, not a guaranteed balance after this planning response finishes.

## 3. Can agents work safely against the existing source of truth?

**Conditionally yes, but not yet proven safe for new edits.** First verify the Git settings and the exact repository head. Use this existing project only; no duplicates, imports, reconnections, or competing simultaneous editors.

The paused AI work is already present in the current sandbox snapshot: `src/lib/ai/{run-id.ts,gateway.server.ts,data-access.server.ts,assistant.functions.ts}`, `src/components/ai-panel.tsx`, AI package declarations, and an import in `src/start.ts`. It is **not a completed or validated integration**; the existing `start.ts` has no function middleware registration. Clean local Git status does not establish whether this work reached GitHub. Review that exact snapshot before authorizing continuation; do not remove or deploy it blindly.

Honor `AGENTS.md:5–11`: one coherent change bundle, one completed-stage CI run, no force-push/amend/rebase of published history, normal merges to incorporate newer safety fixes, and squash-merge feature PRs without rewriting the published main branch. The agent cannot manually control Lovable's internal commits or guarantee the requested one-commit policy in this sandbox; if strict atomic Git delivery is essential, use a verified repository workflow rather than assuming automatic sync satisfies it.

## 4. Exact phone-only, no-purchase workflow

1. Open **lovable.dev in your phone browser**; select the existing Roshan Health Hub project. Use browser desktop-site mode only if settings are difficult to reach.
2. Open **Settings → Git**. Read repository, active branch, and sync status; optionally use the read-only **Re-check**. Do not connect/disconnect or switch branches in this review.
3. Open **View on GitHub** in the browser. Read the matching branch's latest commit and authoritative `AGENTS.md` / `docs/MASTER_PLAN.md`. Compare with the sandbox SHA above. If inconsistent, stop edits and identify which version contains the paused work.
4. For discussion use **Chat**, and monitor its separate allowance. Reserve Plan messages for decisions, avoiding extra research agents and repeated confirmations.
5. Before any later Build task, give one narrow scope and a stop condition: no production database actions, no invented dosing, no secret/integration changes, no installs or deployment, no paid services. Check credits first. Wait for grants instead of purchasing when exhausted.
6. **For now, remain read-only.** Active Git sync can automatically push edits, and external deployment integrations may react. Before later edits/PRs, read Vercel's Git deployment settings and GitHub Actions billing/budget settings. If edits can trigger a deployment or a metered run, stop until a separately authorized workflow prevents it. A feature branch alone is not proof that Vercel preview deployments are disabled.
7. After that gate is resolved and a task is explicitly authorized, review a single complete diff and focused test evidence on the exact proposed commit, with one completed-stage validation run. Do not merge if merging triggers an unauthorized deployment. If strict atomic commits cannot be ensured through Lovable, keep Lovable read-only; GitHub browser editing/PR operation can be considered separately after its permissions and automation are verified.

No phone terminal, paid Code editor, paid development database, or additional AI subscription is required for the read-only workflow. Phone-only operation does not eliminate credit limits or external automation risks.

## 5. Limits, paywalls, and how to avoid charges

- Free build grants: **5 credits daily, capped at 30 per calendar month**, reset at **00:00 UTC / 02:00 Africa/Khartoum**. Daily grants do not roll over. After the monthly cap, wait until next month; do not interpret the remaining daily balance as monthly headroom. This lookup did not establish remaining monthly grant eligibility.
- The separate Chat allowance resets at the same time. Once exhausted, chat can draw available credits; it is not an unlimited number of messages.
- Free does not include credit top-ups or auto-top-up. Exhaustion blocks/pauses work rather than automatically buying credits. Decline Upgrade, Buy credits, and app-store purchase prompts. Do not change subscription or payment settings.
- Direct Code-editor saving is a paid-plan gate; use remaining free agent credits later or stay read-only, rather than upgrading.
- Lovable AI and Cloud have separate published monthly allowances (**4 AI credits / 20 Cloud credits**); these are not measured remaining balances or permission to activate services. Calling the new assistant can consume AI credits and then available shared credits. **No live AI requests were made in this review.**
- External GitHub, Vercel, and the existing database have their own quotas and billing rules. Free Lovable status does not prove these services cannot bill. Their current budgets and automatic triggers remain unverified; do not create resources, push changes, trigger CI, or deploy until checked.
- `.github/workflows/ci.yml:3–9` triggers on main pushes, another named branch, PRs, and manual dispatch. There is **no top-level path exclusion**, and its verify job runs install/audit/guard tests/typecheck/lint/build (`:337–414`). Therefore documentation-only commits are **not proven to skip frontend builds**, despite the authoritative policy requiring that. Do not commit this report to GitHub or trigger workflows manually; correcting that mismatch would need separate authorization.
- Existing CI defines disposable PostgreSQL 17 containers; that is not a reason to run database tests in this planning task. Production DB actions, migrations, backups, clinical dosing invention, deployments and publishing remain prohibited.

## Evidence sources and remaining gate

Project evidence: `AGENTS.md`, relevant sections of `docs/MASTER_PLAN.md`, `roadmap.md`, `package.json`, `src/start.ts`, `.lovable/project.json`, `.github/workflows/ci.yml`, AI file inventory, and read-only Git identity/status. The roadmap is stale relative to some current source and was not edited.

Official references:
- [Code editor](https://docs.lovable.dev/features/code-mode)
- [Build mode](https://docs.lovable.dev/features/agent-mode)
- [Credits and usage](https://docs.lovable.dev/introduction/credits-and-usage)
- [Git sync](https://docs.lovable.dev/integrations/git-sync-overview)
- [Project settings](https://docs.lovable.dev/features/projects/settings)
- [Drafts](https://docs.lovable.dev/features/drafts)
- [Out of credits](https://docs.lovable.dev/introduction/out-of-credits)
- [Subscription plans](https://docs.lovable.dev/introduction/subscription-plans)

**Next safe action: retrieve only the non-secret Git settings repository/branch/sync-status screenshot.** Until it is verified, keep implementation paused. This report establishes platform capabilities and source evidence, not current production health, successful tests, live sync, or external zero-billing guarantees.