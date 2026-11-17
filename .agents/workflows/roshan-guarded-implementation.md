# Roshan guarded implementation

Use only when the owner explicitly assigns Antigravity an implementation task.

1. Confirm the exact task, allowed files, target branch, and whether another agent already owns the work. Re-read current main and the target branch head.
2. Create/use a dedicated feature branch or isolated worktree; do not edit main or another agent's working branch.
3. Inspect package.json, nearby tests, and relevant CI workflow before writing code. For behavior changes, write a failing regression test first.
4. Implement the smallest coherent patch. Include tests and documentation in the same logical batch. No unrelated cleanup or dependency upgrades.
5. Run the focused test and the repository-required guard/typecheck/lint/build commands that are feasible. Record exact commands and results. Do not claim tests passed if not run.
6. Review the complete diff for secrets, real patient/financial data, unsafe SQL, generated noise, and changes outside the assigned scope.
7. Commit once for the coherent task, push only to the assigned feature branch, and open a Draft PR. Do not merge it.
8. Stop before any hosted database mutation, production deployment, environment change, backup dispatch, or destructive action. Those require separate explicit owner authorization.
