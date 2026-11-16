# Window 04 — Round 02 Report

## 1. Identity and scope

- Window: **04 — Financial receipt integrity**
- Original task / Issue / PR: Read-only review of invoice-payment receipt persistence and printing; PR **#181**
- Round: **02**
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `feat/phase53-payment-receipts-qa-20261103` / [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181)
- Current task head: `a49e261b0661239c1e0a18f5734453010499f71c`
- Scope this round: Revalidate current GitHub refs, PR state, payment UI/RPC contract, exact-head checks, and prior report delivery.
- Explicit exclusions retained from original review-only task: No application/SQL/test implementation changes; no hosted QA/Production writes, migrations, ACL/RLS changes, financial transactions, deployment promotion, approval, or merge.

## 2. Executive verdict

- Status: **CHANGES REQUIRED**
- What is complete this round: Current main and task refs independently resolved; PR #181 ancestry and divergence measured against current main; current exact-head check runs enumerated; payment UI and SQL idempotency contract re-inspected; report PR #267 and its checks revalidated.
- What remains incomplete: The UI still omits `_idempotency_key`; current-main integration requires rebase/reconciliation; role permission parity and other Round 01 findings remain unresolved; Phase 58/59 Production dependency remains unconfirmed in the latest evidence available to this window.
- Work type: **Review-only revalidation**. The coordinator handoff's next-action list includes implementation, but the original task scope explicitly prohibited code changes. The continuation protocol also says the original scope remains unchanged and to stop on scope conflicts. Therefore no implementation was performed without explicit owner authorization to change the scope.
- Recommendation: Keep PR #181 Draft and do not merge or promote.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Current main branch SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main commit](https://github.com/crauch2088-source/roshan-health-hub/commit/79d81f08f6567f5145f7143e3bf5afdd6e93bf59) | Verified via branch API |
| Task branch SHA | `a49e261b0661239c1e0a18f5734453010499f71c` | [task head](https://github.com/crauch2088-source/roshan-health-hub/commit/a49e261b0661239c1e0a18f5734453010499f71c) | Verified via branch API |
| PR #181 | Open, Draft, not merged; base metadata SHA `f8c8b2d1767643561599764405b4cdbfd4db2c79` | [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Verified |
| Current ancestry vs main | 38 ahead / 5 behind; merge base `f8c8b2d...` | [Compare main...PR head](https://github.com/crauch2088-source/roshan-health-hub/compare/79d81f08f6567f5145f7143e3bf5afdd6e93bf59...a49e261b0661239c1e0a18f5734453010499f71c) | Verified |
| Explanation of earlier 0-behind claim | PR head is 38 ahead / 0 behind the old base `f8c8b2d...`; current main is 5 commits ahead of that base | [Compare old base...main](https://github.com/crauch2088-source/roshan-health-hub/compare/f8c8b2d1767643561599764405b4cdbfd4db2c79...79d81f08f6567f5145f7143e3bf5afdd6e93bf59) | Verified |
| PR #181 checks | 31 check runs: 30 success, 1 skipped; no failed or pending checks | [PR #181 checks](https://github.com/crauch2088-source/roshan-health-hub/commit/a49e261b0661239c1e0a18f5734453010499f71c/checks) | Verified, exact task head |
| Relevant DB concurrency check | PostgreSQL 17 invoice-payment idempotency concurrency: success | [workflow job](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644562777/job/132599322167) | Verified, exact task head |
| Skipped check | Canonical PG17 baseline replay and authenticated clinical acceptance: skipped | [workflow job](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644562762/job/132599323951) | Verified, not a pass |
| Report PR #267 | Open, non-draft, not merged; head `3d8eaed38759cddbc6bf737c103e221ab0be5685` | [PR #267](https://github.com/crauch2088-source/roshan-health-hub/pull/267) | Verified |
| Report PR #267 checks | 4/4 success | [report checks](https://github.com/crauch2088-source/roshan-health-hub/commit/3d8eaed38759cddbc6bf737c103e221ab0be5685/checks) | Verified |

**Ancestry correction:** The earlier 38-ahead/0-behind statement was measured against `f8c8b2d...`, the previous base. The live `main` ref is now `79d81f08...`, which is five commits ahead of that old base. Against current main, PR #181 is 38 ahead and 5 behind. This is a genuine stale-base condition, not an API contradiction.

## 4. Work actually performed

1. Re-read `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` from the protocol branch.
2. Resolved the live `main` branch SHA and the payment feature branch SHA independently through GitHub branch endpoints.
3. Compared current main against PR #181's head and separately compared the former base against current main to explain the earlier ancestry discrepancy.
4. Re-fetched PR #181 and PR #267 metadata.
5. Enumerated all 31 check runs on PR #181's exact head and all 4 check runs on the report PR's exact head.
6. Re-read the current PR-head payment route, payment RPC SQL, and Phase 59 receipt-status SQL.
7. Confirmed the UI still omits `_idempotency_key`; the SQL RPC still supports it as an optional parameter and returns the existing payment only when a key is supplied and request details match.
8. Confirmed the UI receipt-status query is enabled with `payments.read`, while the SQL RPC requires both `payments.read` and `billing.read`.
9. Created this separate Round 02 report. No task code, SQL, test, or hosted environment was changed.

## 5. Findings

### F-01 — UI still bypasses the RPC idempotency mechanism

- Severity: **High**
- Status: **Verified — current PR head**
- Affected file/function/SQL object:
  - `src/routes/_authenticated/billing_.$invoiceId.tsx`, payment submit handler.
  - `public.post_invoice_payment(uuid,numeric,text,text,text)` in `db/roshan_invoice_payment_money_precision.sql`.
- Evidence and exact source/commit: At `a49e261b0661239c1e0a18f5734453010499f71c`, the UI sends invoice ID, amount, method and reference, but not `_idempotency_key`. The SQL signature retains `_idempotency_key text DEFAULT NULL`; the advisory lock and replay comparison run only when the key is non-null.
- Reproduction or test: Source contract rechecked. The exact-head PostgreSQL 17 invoice-payment idempotency concurrency workflow passed, but this test validates the SQL contract; it does not prove the UI passes a stable key.
- Impact: A retry after a committed payment with a lost response can be treated as a new payment if the invoice still has outstanding balance.
- Recommended correction: In a separately authorized implementation task, create one stable key per logical attempt, preserve it through retries, rotate it only for a new payment, and pass it to the RPC.
- Required regression test: UI-to-PostgreSQL lost-response retry returns the same payment UUID and exactly one cashbox entry; altered payload with the same key is rejected; concurrent same-key requests create one payment.
- Dependency / owner: Finance implementation owner; explicit authorization to change this review-only window's scope; disposable PostgreSQL 17.

### F-02 — Permission gate mismatch (withdrawn; prior false positive)

- Severity: **No defect established**
- Status: **Withdrawn after full route-boundary reinspection**
- Affected file/function/SQL object: `src/routes/_authenticated/billing_.$invoiceId.tsx`; `get_invoice_payment_receipt_status_v2(uuid[])` in `db/roshan_phase59_receipt_currency_provenance.sql`.
- Evidence and exact source/commit: The invoice route wraps `InvoicePageInner` in `<PermissionGate perm="billing.read">`; the receipt-status query is additionally enabled only when `can("payments.read")` is true. The effective UI gate therefore requires both permissions, matching the RPC's server-side requirement for both `payments.read` and `billing.read`.
- Reproduction or test: Source-boundary reinspection; no authenticated role matrix was run.
- Impact: The earlier claim that a payments-read-only user could reach the RPC without billing-read was incorrect because the parent route gate prevents that path.
- Recommended correction: No code change is indicated by this finding. Preserve both server-side checks and the route-level billing gate.
- Required regression test: Retain a role-matrix test if route or query permission gates are later changed; verify both permissions are required and cross-branch denial remains.
- Dependency / owner: None for the current implementation; permissions owner if the route contract changes.

### F-03 — Current-main integration is not ready

- Severity: **Medium**
- Status: **Verified — repository state**
- Affected file/function/SQL object: PR #181 branch ancestry.
- Evidence and exact source/commit: Current main `79d81f08...` is five commits ahead of old base `f8c8b2d...`; PR #181 is 38 ahead / 5 behind current main.
- Reproduction or test: GitHub compare endpoints using exact SHAs.
- Impact: Existing exact-head CI does not prove compatibility with the current mainline changes.
- Recommended correction: Reconcile/rebase the candidate against current main in an authorized implementation/integration task, resolve conflicts, then rerun one coherent exact-head CI pass.
- Required regression test: Full focused finance/receipt checks plus current-main integration CI.
- Dependency / owner: Repository integration owner.

### Prior Round 01 findings not reimplemented or re-tested

The following remain open from [Round 01 report](https://github.com/crauch2088-source/roshan-health-hub/blob/docs/window-04-financial-receipt-review-round-01/docs/parallel-reports/round-01/window-04.md): receipt identifier not printed (F-02), historical cashier attribution depends on current user state (F-03), payment aggregate reconciliation (F-05), optional Bankak reference policy (F-06), no independent cryptographic receipt verification (F-07), and physical RTL/LTR/printer acceptance not performed (F-08). These were not re-investigated in depth this round and are not represented as newly re-verified.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| Exact PR #181 check runs | Commit `a49e261b0661239c1e0a18f5734453010499f71c` | **30 PASS / 1 SKIPPED** | 31 total; no failed or pending checks |
| PostgreSQL 17 invoice-payment idempotency concurrency | [Job 132599322167](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644562777/job/132599322167) | **PASS** | SQL concurrency contract only; does not cover UI key propagation |
| Canonical PG17 baseline replay and authenticated clinical acceptance | [Job 132599323951](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644562762/job/132599323951) | **SKIPPED** | Must not be counted as a pass |
| Exact report PR #267 check runs | Commit `3d8eaed38759cddbc6bf737c103e221ab0be5685` | **4 PASS** | CodeQL, Vercel preview comments, Python and JS/TS analysis |
| Local UI-to-RPC retry test | Not run | **NOT RUN** | No local checkout/runtime was available in this review session |
| Authenticated role matrix | Not run | **NOT RUN** | No authenticated synthetic sessions run |
| Android/A4/58mm/80mm physical print | Not run | **NOT RUN** | Human device/printer acceptance outstanding |

No SKIPPED or NOT RUN item is counted as a pass. The workflow evidence is from the exact PR #181 head, but that head is five commits behind current main.

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-02/window-04.md` | Current-state revalidation report only | `6fc56800f0334a2f98ec127b7f1d64b787105dc0` (initial report commit) |

- Branch: `docs/window-04-financial-receipt-review-round-02`
- Task branch: `feat/phase53-payment-receipts-qa-20261103` (not modified)
- Task PR: [#181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) (not modified)
- Prior report PR: [#267](https://github.com/crauch2088-source/roshan-health-hub/pull/267) (not modified)
- Report file path: `docs/parallel-reports/round-02/window-04.md`
- Initial report commit: `6fc56800f0334a2f98ec127b7f1d64b787105dc0`.
- Delivery: Separate docs-only PR because this round remained review-only and the original task scope prohibited implementation.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Synthetic financial transaction creation: **No**
- Secret or credential changes: **No**
- PR #181 approval / merge / draft-state change: **No**
- Issue closure / release approval: **No**
- Application code, SQL, or test changes: **No**

## 9. Risks, dependencies, and owner decisions

1. **High:** The UI-to-RPC idempotency key is still missing; the SQL concurrency test passing does not close this gap.
2. **Medium:** PR #181 is five commits behind current main; exact-head CI must be repeated after authorized reconciliation.
3. **Medium:** UI and server permission requirements differ.
4. **Medium:** Round 01 findings on receipt identity, cashier attribution, ledger aggregate reconciliation, Bankak reference policy, verifiability and physical printing remain open.
5. **Release blocker:** Phase 58/59 Production rollout is not established by this review; no live migration state was queried this round.
6. **Scope conflict:** The coordinator handoff lists implementation as Window 04's next action, but the original task was explicitly review-only and the continuation protocol says the original scope remains unchanged. Owner authorization is required before changing application/SQL/tests.

## 10. Next action

**Owner / Window 04:** Explicitly authorize a scope change from review-only to implementation for the payment idempotency integration. Once authorized, rebase/reconcile PR #181 against current main, implement the stable UI key with TDD and a disposable PostgreSQL 17 lost-response retry regression, then update the role-gate contract in a separately scoped decision. Until then, keep PR #181 Draft.

## 11. Session closeout

- Work completed in this session: Rechecked current main and PR branch refs; resolved the five-commit divergence; enumerated exact-head CI; re-inspected payment UI/RPC and receipt-status permissions; revalidated PR #267; prepared this Round 02 report.
- Work not completed: No implementation, local test execution, authenticated role test, physical print acceptance, or live QA/Production schema check.
- Exact current state at close: main `79d81f08...`; PR #181 open Draft at `a49e261b...`, 38 ahead / 5 behind current main, 30 checks passed and one skipped; PR #267 open at `3d8eaed...`, four checks passed.
- Recommended continuation when the owner says **"أكمل"**: If implementation scope is explicitly authorized, follow the Next action above; otherwise continue read-only review and preserve the scope boundary.


## 12. Implementation continuation addendum — 2026-11-16

The owner subsequently authorized the specific scope expansion proposed in chat: implement the UI idempotency-key propagation, prove retry behavior in disposable PostgreSQL 17, and reconcile the feature candidate onto current `main`. This addendum records work after the original review-only snapshot; it does not rewrite the historical findings or authorize deployment/merge.

### Current implementation candidate

- Branch: `fix/window-04-payment-idempotency-20261116`
- PR: [#280](https://github.com/crauch2088-source/roshan-health-hub/pull/280), open and Draft.
- Final verified head at this addendum: `1c7aff22417897660c0ddc69914ca827d9ddebb6`.
- Base: current main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`.
- GitHub compare: **2 commits ahead / 0 behind** current main; merge base is the exact main SHA above.
- PR #181 remains open Draft and was not modified. Its prior candidate branch is not the integration target for this fix.
- The feature files from #181 were transplanted as a patch onto a new branch based on current main; no history rewrite or force push was used.

### Implemented changes

1. Added `src/lib/finance/payment-idempotency.ts`.
   - Creates an opaque SHA-256 fingerprint from invoice ID, amount, method and normalized reference.
   - Stores only the fingerprint-derived key name and UUID value in tab-scoped `sessionStorage`; raw amount/reference are not persisted.
   - Reuses the same key for the same request after network retries and route reloads.
   - Generates a different key when payment details change.
   - Clears the key only after the payment RPC succeeds.
2. Updated `src/routes/_authenticated/billing_.$invoiceId.tsx` to pass `_idempotency_key` to `post_invoice_payment` and clear the matching key in the success callback only.
3. Added `tests/payment-idempotency.test.ts` for same-request retry reuse, changed-request key rotation, success cleanup, and absence of plaintext payment fields in storage keys.
4. Extended `tests/print-receipt-ui.test.ts` to assert the payment UI obtains, submits and success-clears the key, and keeps the amount/method/reference controls disabled while the mutation is pending.
5. Extended `db/tests/finance_payment_idempotency_concurrency.sh` to simulate a lost response after commit, retry the same RPC request and assert the same payment UUID is returned; reusing the key with a changed amount must fail; only one payment row may exist.
6. Added the new unit test to the existing `test:guard` script in `package.json`.

### Test-first evidence

- RED commit: `4416c0bbb85ae9d702da1aab1f37c2ececd1a97c` added the regression test and test command before the implementation module existed.
- RED exact-head workflow: [run 43857866440](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43857866440); the `Role guard unit tests` step failed at the intended pre-implementation state. The dependent typecheck/build steps were skipped. This establishes a failing pre-fix state; it is not counted as a passing run.
- GREEN implementation commit: `7b91edc8e8b8d392be5b9fb0939056493691145d`.
- The first GREEN CI attempt exposed two Prettier-only lint errors in the new test file; both were corrected in `8815d0f1c5f52c7868de69ce65be0b42ae810d24`.
- The pending-state hardening and its UI assertion were committed in `1c7aff22417897660c0ddc69914ca827d9ddebb6`.
- Disposable PostgreSQL 17 invoice-payment idempotency concurrency: **PASS** on the current head, [job 133269455737](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43858673581/job/133269455737).
- PostgreSQL 17 finance RPC-only writes: **PASS** on the current head, [job 133269456155](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43858673581/job/133269456155).
- Exact-head PR #280 final status: **31/31 check runs completed; 30 success, 1 intentionally skipped, 0 failures, 0 pending**. The skipped check is the deferred canonical baseline replay/authenticated clinical acceptance workflow; it is not counted as a pass.
- Main Install/audit/typecheck/lint/build: **PASS**, including role guard tests, typecheck, lint and production build.
- PostgreSQL 17 invoice-payment idempotency concurrency and finance RPC-only write isolation: **PASS** on the final exact head.
- The prior exact-head #181 concurrency pass remains historical evidence; the new expanded retry/mismatch assertions were executed on PR #280's disposable PostgreSQL 17 workflow.

### Reassessment and remaining gates

- The previous F-02 permission mismatch is withdrawn: route-level `billing.read` plus query-level `payments.read` matches the RPC's dual permission check.
- The stale-base condition on PR #181 is mitigated for this implementation candidate: PR #280 is based directly on current main. PR #181 remains Draft and should not be merged independently over the new candidate.
- No hosted QA/Production writes, migrations, payment rows, ledger rows, deployment promotion, approval, or merge were performed.
- Remaining release blockers include full exact-head CI completion, independent finance/security review, QA authenticated cashier/role acceptance, Phase 58/59 Production migration rollout under the release gates, and physical Android/RTL/LTR/A4/thermal-printer acceptance.
- Next action: request independent finance/security review of PR #280, then proceed to authenticated QA cashier/role acceptance and separate release-gate verification. Keep #280 Draft and #181 Draft until those gates are satisfied.


### Final exact-head verification update — 2026-11-16

- Final PR #280 head: `1c7aff22417897660c0ddc69914ca827d9ddebb6`.
- PR #280: open, Draft, mergeable according to GitHub; 16 changed files; based on `main` `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; comparison is 4 commits ahead / 0 behind.
- Exact-head check runs: **31 total; 30 success, 1 skipped, 0 failed, 0 pending**. The skipped canonical PG17 baseline replay/authenticated clinical acceptance is deferred by workflow configuration and is not counted as a pass.
- The full Install/audit/typecheck/lint/build job passed, including role guard tests, typecheck, lint and production build.
- PostgreSQL 17 invoice-payment idempotency concurrency and finance RPC-only write-isolation workflows passed on the final head.
- The TDD RED commit and the initial formatting-only lint failure are retained in history; the formatting correction is included in the final green head.
- Report file update commit: `f145171a2abf761859db7e857dc0c2d0b1cacc98` (the final report metadata commit is recorded in the next delivery verification).
- PR #181 remains open Draft and untouched. PR #280 is the mainline-based successor candidate. Neither was approved or merged.
- No QA/Production writes, migrations, deployment promotions, real financial records, or patient data were used.
