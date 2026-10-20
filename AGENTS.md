# Execution policy — quota-safe, atomic delivery

These rules govern every Roshan Health Hub task and override older conflicting workflow notes.

1. **One atomic commit per logical task.** Prepare the complete implementation, tests, and documentation together; create one Git tree, one commit, then advance the branch ref with an expected-SHA lease. Never split a single task into repeated test/fix/docs commits.
2. **One CI run per completed stage.** Finish the coherent change bundle before pushing and triggering CI. If CI fails, fix the actual failure and rerun only the necessary validation; do not create redundant commits merely to iterate on formatting or documentation.
3. **Protect free Vercel quota.** Documentation-, SQL-, migration-, and script-only commits must skip frontend builds. Always squash-merge PRs. Never bypass quota limits, deploy unnecessarily, or upgrade paid services.
4. **Batch read-only Supabase diagnostics.** Combine catalog, migration-ledger, policy, and role checks into one read-only CTE/JSON query wherever practical. Do not run repeated equivalent diagnostics; never use production as a synthetic test database.
5. **Closed phases stay closed.** Do not re-verify or reopen Phases 29–33 unless relevant code or migration content changes, or new evidence identifies a concrete regression.
6. **Consolidate database changes.** Prefer one comprehensive migration per logical phase. Use an Expand/Contract pair only when compatibility or deployment sequencing demonstrably requires it. Keep baseline fixtures and CI assertions aligned; never apply candidate migrations to production without an explicit release gate.
7. **Resolve conflicts without rewriting published history.** Preserve newer main safety fixes, merge main into the existing feature branch with a normal fast-forwardable merge commit, then squash-merge. Never force-push or amend published commits.

---

<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->


## Phase 34 release gate

- Keep all Phase 34 SQL, TypeScript, tests, and docs in one atomic tree commit on `feat/phase34-consolidated-realtime-storage-lab-verify`.
- Do not apply the candidate to production unless the exact PR head passes all GitHub Actions checks. Keep behavior tests isolated on disposable PostgreSQL 17; no production test data.
- Never use direct table writes to mark lab orders verified. Use `verify_lab_order(uuid)` only. Preserve the append-only audit contract.
