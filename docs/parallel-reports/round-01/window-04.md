# Window 04 — Round 01 Report

## 1. Identity and scope

- Window: **04 — Financial Receipt Integrity Review**
- Original task / Issue / PR: Review saved invoice-payment receipt persistence and printing; PR **#181**
- Round: **01**
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (resolved by the GitHub compare endpoint for `main`; see repository-state qualification below)
- Current task branch / PR: `feat/phase53-payment-receipts-qa-20261103` / [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181)
- PR head checked: `a49e261b0661239c1e0a18f5734453010499f71c`
- Scope: Read-only source, SQL, tests, PR metadata/review, CI status and release-gate review of invoice payment receipt integrity.
- Explicit exclusions: No application/SQL/test code changes; no hosted QA/Production writes, migrations, ACL/RLS changes, payment creation, deployment promotion, PR approval, or merge.

## 2. Executive verdict

- Status: **CHANGES REQUIRED**
- What is actually complete: Read-only review of PR #181's receipt model, invoice route, payment RPC contract, Phase 59 receipt-status SQL, relevant existing tests, print CSS, PR metadata and available status/review evidence.
- What remains incomplete: UI-to-RPC idempotency integration, reconciliation of payment aggregates, role-matrix acceptance, stable printed receipt identity/policy, cashier historical attribution policy, physical printing acceptance, and Production dependency rollout.
- Work type: **Review-only**. No code change was appropriate because the original task explicitly prohibited code modifications.
- Recommendation: Keep PR #181 Draft; do not approve or merge until the High finding and release gates below are resolved.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Requested round baseline | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [Commit](https://github.com/crauch2088-source/roshan-health-hub/commit/79d81f08f6567f5145f7143e3bf5afdd6e93bf59) | Verified |
| PR #181 state | Open, Draft, not merged; 13 files, +983/−57 | [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Verified |
| PR branch/head | `feat/phase53-payment-receipts-qa-20261103` / `a49e261b0661239c1e0a18f5734453010499f71c` | PR metadata | Verified |
| PR base metadata | `main`, base SHA `f8c8b2d1767643561599764405b4cdbfd4db2c79` | PR metadata | Verified |
| Baseline comparison | 38 ahead / 5 behind; merge base `f8c8b2d1767643561599764405b4cdbfd4db2c79` | [Compare](https://github.com/crauch2088-source/roshan-health-hub/compare/79d81f08f6567f5145f7143e3bf5afdd6e93bf59...a49e261b0661239c1e0a18f5734453010499f71c) | Verified |
| Exact-head combined status | Vercel status success; no other contexts returned by this status endpoint | [Head commit](https://github.com/crauch2088-source/roshan-health-hub/commit/a49e261b0661239c1e0a18f5734453010499f71c) | Verified, limited |
| PR workflow evidence | PR body records 8/8 successful PR-triggered workflows; this review did not independently retrieve every run | [PR #181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Reported, not rechecked individually |
| Review submissions | Two COMMENTED reviews by repository owner; no independent approval established | [PR #181 reviews](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Verified |
| Inline review threads | Zero | PR review-thread API result | Verified |
| Phase 58/59 QA | PR history/release reconciliation records QA migrations and RPC present | [Release reconciliation](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md) | Reported in repo; not live-requeried this session |
| Phase 58/59 Production | Not confirmed/applied per latest release reconciliation | Same release reconciliation | Reported in repo; not live-requeried this session |

**Comparison qualification:** The requested baseline comparison is 38 ahead / 5 behind with merge base `f8c8b2d...`. PR metadata separately names `main` and base SHA `f8c8b2d...`. Do not describe the five commits as definitely behind current main without a fresh, unambiguous branch-ref comparison; the connector's compare response for symbolic `main` and its resolved base metadata were internally inconsistent during this check. Reconcile branch refs before integration.

## 4. Work actually performed

1. Read `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` from the continuation-protocol branch.
2. Re-fetched PR #181 metadata, changed-file list, current head, review submissions and review threads.
3. Inspected `src/routes/_authenticated/billing_.$invoiceId.tsx`, including payment RPC submission, receipt status query, cashier mapping and print document.
4. Inspected `src/lib/print/receipt.ts` and `tests/print-receipt-model.test.ts`.
5. Inspected `db/roshan_invoice_payment_money_precision.sql` and `db/roshan_phase59_receipt_currency_provenance.sql` at the requested baseline.
6. Confirmed that the SQL payment RPC has an optional `_idempotency_key` argument, advisory transaction lock and replay validation, while the receipt route currently omits that argument.
7. Confirmed the Phase 59 status RPC checks both `payments.read` and `billing.read`, while the route enables the query based on `payments.read`.
8. Checked the exact PR-head combined status endpoint. It returned Vercel success; the PR narrative records broader workflow success, but individual workflow runs were not independently enumerated here.
9. Created a dedicated documentation-only branch for this review. No application code or SQL was modified.

## 5. Findings

### F-01 — Payment UI omits the available idempotency key

- Severity: **High**
- Status: **Verified — candidate branch**
- Affected file/function/SQL object:
  - `src/routes/_authenticated/billing_.$invoiceId.tsx`, lines 137–155 at PR head.
  - `public.post_invoice_payment(uuid,numeric,text,text,text)` in `db/roshan_invoice_payment_money_precision.sql`, baseline.
- Evidence and exact source/commit:
  - UI calls `rpc("post_invoice_payment", { _invoice_id, _amount, _method, _reference })` and supplies no `_idempotency_key`.
  - SQL defines `_idempotency_key text DEFAULT NULL`; when non-null, it obtains `pg_advisory_xact_lock(hashtextextended(...))`, looks up the existing payment, validates actor/invoice/amount/method/reference equality, and returns the original payment ID.
  - When the key is null, this replay-identification path is skipped. Invoice locking/overpayment protection does not prove that a retry after a lost response is the same request.
- Reproduction or test: Source-level contract mismatch verified. No payment RPC was executed in this review. Existing `db/tests/finance_payment_idempotency_concurrency.sh` exercises the database concurrency contract, but does not establish that this UI sends a stable key.
- Impact: A cashier retry after an ambiguous network response can create a second payment if the invoice still has sufficient outstanding balance.
- Recommended correction: Generate one stable key per logical payment attempt, preserve it across retries/reloads as appropriate, and rotate it only for a genuinely new payment. Do not derive a fresh key on each retry.
- Required regression test: Simulate successful commit followed by lost response; retry the same key and assert the same payment UUID and one cashbox entry. Reuse the same key with altered amount/method/reference and assert rejection. Concurrent same-key submissions must produce one transaction.
- Dependency / owner: Window 04 / finance implementation owner; disposable PostgreSQL 17 and UI integration test.

### F-02 — Payment UUID is not exposed on the printed receipt

- Severity: **Medium**
- Status: **Verified — candidate branch**
- Affected file/function/SQL object: `src/lib/print/receipt.ts`, lines 65–73 and 157–174; `src/routes/_authenticated/billing_.$invoiceId.tsx`, print document around lines 496–600.
- Evidence and exact source/commit: The model contains `paymentId`, but the printed markup displays invoice number, date, patient, method, cashier, reference, amount and current balance; it does not render paymentId or a distinct receipt number.
- Reproduction or test: Source inspection; no browser print execution.
- Impact: Two payments against one invoice can be harder to distinguish during audit or when a paper copy is presented later.
- Recommended correction: Decide whether payment UUID is the canonical receipt identifier or whether a separate immutable sequential receipt number is required; print that identifier. Add a reprint/copy marker if policy requires it.
- Required regression test: Two payments on one invoice produce distinguishable receipt identifiers; reprinting preserves the identifier and does not create another payment.
- Dependency / owner: Finance/product owner decision; no need to add a receipt table unless the approved policy requires one.

### F-03 — Historical cashier name depends on current user state

- Severity: **Medium**
- Status: **Verified — candidate branch**
- Affected file/function/SQL object: `src/routes/_authenticated/billing_.$invoiceId.tsx`, lines 190–202.
- Evidence and exact source/commit: For another cashier, the route displays the joined user name only when the viewer has `users.read`, the user remains active, and the user is not deleted. The current user's own name follows a separate path.
- Reproduction or test: Source inspection; no user records were changed.
- Impact: Deactivation/deletion or loss of `users.read` can remove the cashier name from an otherwise valid historical receipt.
- Recommended correction: Preserve immutable actor display attribution on the financial record or provide a protected historical identity lookup that does not require the cashier to remain active.
- Required regression test: Deactivate/delete a synthetic cashier after payment posting and verify authorized historical receipt attribution remains stable.
- Dependency / owner: Finance/security owner; agree retention and privacy policy.

### F-04 — Receipt verification permission contract is stricter than UI enablement

- Severity: **Medium**
- Status: **Verified — candidate branch**
- Affected file/function/SQL object:
  - `src/routes/_authenticated/billing_.$invoiceId.tsx`, lines 116–131 and 447–477.
  - `db/roshan_phase59_receipt_currency_provenance.sql`, `get_invoice_payment_receipt_status_v2(uuid[])`.
- Evidence and exact source/commit: UI enables the receipt-status query with `can("payments.read")`; SQL requires both `payments.read` and `billing.read`.
- Reproduction or test: Contract comparison verified from source. No authenticated role-switch test was run.
- Impact: A user with payment-read but without billing-read sees receipt verification fail closed and printing unavailable. This is safe against disclosure but may break intended cashier/finance roles.
- Recommended correction: Align UI gating and the intended role matrix with the server contract; do not weaken server authorization merely to make the button work.
- Required regression test: Authenticated role matrix covering Reception, Admin, GP, accounting and least-privilege custom roles; prove both allowed receipt reads and denied cross-branch/unauthorized reads.
- Dependency / owner: Role/permission owner and security reviewer.

### F-05 — Receipt model does not independently reconcile invoice paid_amount to active payments

- Severity: **Medium**
- Status: **Verified — candidate branch**
- Affected file/function/SQL object: `src/lib/print/receipt.ts`, lines 127–138.
- Evidence and exact source/commit: The model derives current balance as invoice `net_amount - paid_amount` and checks non-negative/finite inputs, but does not compare invoice `paid_amount` with the aggregate of active payment rows.
- Reproduction or test: Source inspection; no financial data or DB rows were created.
- Impact: A drift between invoice aggregate and underlying payment records may remain undetected while a receipt displays a plausible current balance.
- Recommended correction: Add an authoritative aggregate consistency result to the server-side receipt verification contract, or a separate read-only reconciliation assertion. Keep the displayed label explicitly “current invoice balance”.
- Required regression test: Synthetic fixture where active payment sum differs from invoice paid_amount must be flagged; correct partial/full/reversed histories must reconcile exactly.
- Dependency / owner: Finance/database owner.

### F-06 — Bankak reference is optional in the payment submission path

- Severity: **Low–Medium**
- Status: **Verified — candidate branch; policy-dependent**
- Affected file/function/SQL object: `src/routes/_authenticated/billing_.$invoiceId.tsx`, lines 149–154; `src/lib/print/receipt.ts`, lines 117–125 and 164–166.
- Evidence and exact source/commit: Empty reference is submitted as null; receipt completeness does not require a reference for any payment method.
- Reproduction or test: Source inspection only.
- Impact: Electronic transfer traceability is weaker if Bankak payments are recorded without an external transaction reference.
- Recommended correction: Approve method-specific reference requirements; do not impose a Bankak reference requirement on cash.
- Required regression test: Bankak without reference follows approved validation policy; cash remains valid without an external reference.
- Dependency / owner: Finance operations policy owner.

### F-07 — Printed receipt is a client-rendered document, not a cryptographically verifiable artifact

- Severity: **Medium**
- Status: **Verified — design limitation**
- Affected file/function/SQL object: `src/routes/_authenticated/billing_.$invoiceId.tsx`, receipt DOM and `handlePrintPayment`; `src/lib/print/receipt.ts`.
- Evidence and exact source/commit: The browser builds the printable DOM from fetched rows and an authoritative status RPC. The inspected implementation does not expose a signed receipt payload, server-generated verification code, or QR verification route. The browser can be modified by a user controlling the client.
- Reproduction or test: Architecture inspection only; no attempt was made to forge a live receipt.
- Impact: Ledger validation protects normal UI output, but a paper printout is not independently verifiable by a third party solely from its appearance.
- Recommended correction: Decide whether this is an internal convenience receipt or an official externally verifiable receipt. If the latter, add a server-verifiable receipt reference/QR and an authenticated or privacy-preserving verification endpoint.
- Required regression test: Alter client-side displayed amount/identity and prove the verification endpoint reports the persisted transaction values, not client-supplied values.
- Dependency / owner: Finance/legal/product policy; avoid overengineering if internal-only receipts are sufficient.

### F-08 — Physical RTL/LTR and thermal printer behavior remain unverified

- Severity: **Medium**
- Status: **Not tested**
- Affected file/function/SQL object: `src/routes/_authenticated/billing_.$invoiceId.tsx`, print markup; `src/styles.css`, lines 320–352.
- Evidence and exact source/commit: The document sets `dir` from the language, marks numeric/date identifiers LTR, and isolates the print target. This is source evidence, not physical printer acceptance.
- Reproduction or test: No Android/browser/printer execution was performed.
- Impact: Mixed Arabic/English names, Bankak references, page breaks and thermal widths may render incorrectly despite the source-level direction settings.
- Recommended correction: Perform authenticated browser acceptance on Android and physical A4/58mm/80mm printers.
- Required regression test: Arabic and English receipts, mixed-script names/reference, long text, cancellation/reprint and page-size cases.
- Dependency / owner: QA/cashier staff; human physical acceptance required.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result: PASS / FAIL / SKIP / NOT RUN / BLOCKED | Notes |
|---|---|---|---|
| Receipt model unit tests | `tests/print-receipt-model.test.ts` | NOT RUN | Existing tests cover saved values, ledger/currency mismatch, reversal and malformed inputs; no execution in this review. |
| Receipt UI tests | `tests/print-receipt-ui.test.ts` | NOT RUN | Existing source tests not executed here. |
| Finance idempotency concurrency | `db/tests/finance_payment_idempotency_concurrency.sh` | NOT RUN | Existing PG17 database test; it does not prove the UI passes a stable key. |
| Phase 59 receipt currency integration | `db/tests/phase59_receipt_currency_integration.sql` | NOT RUN | No disposable PostgreSQL instance was run in this review. |
| Exact PR-head combined status | Commit `a49e261b0661239c1e0a18f5734453010499f71c` | PASS, limited | Combined status endpoint returned Vercel success only. |
| PR-reported workflow set | PR body states 8/8 PR-triggered workflows succeeded | NOT RECHECKED INDIVIDUALLY | Do not treat narrative alone as an independently enumerated current run set. |
| Authenticated role matrix | Not run | NOT RUN | Requires synthetic authenticated QA sessions. |
| Android/A4/thermal printer | Not run | NOT RUN | Physical acceptance outstanding. |

No SKIP, NOT RUN or BLOCKED item is counted as a pass.

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-01/window-04.md` | This review report only | To be filled after commit |

- Branch: `docs/window-04-financial-receipt-review-round-01`
- Task code branch: `feat/phase53-payment-receipts-qa-20261103` (not modified)
- Task PR: [#181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) (not modified)
- Report file path: `docs/parallel-reports/round-01/window-04.md`
- Report creation commit SHA: `5bbb9d4e2fe5d9bff874443bea81b459b459cc1b`.
- Report PR: [#267](https://github.com/crauch2088-source/roshan-health-hub/pull/267).
- Delivery method: Separate docs-only PR because the task was review-only and the original PR must not be modified by this review window.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Synthetic financial transaction creation: **No**
- Secret or credential changes: **No**
- PR #181 merge / approval / draft-state change: **No**
- Issue closure / release approval: **No**
- Application code or SQL modifications: **No**

## 9. Risks, dependencies, and owner decisions

1. **High:** UI must pass a stable idempotency key to the already idempotent-capable payment RPC and prove retry semantics.
2. **Medium:** Decide whether payment UUID is the canonical receipt identity or a dedicated immutable receipt number is required.
3. **Medium:** Preserve cashier attribution for historical records after user deactivation/deletion.
4. **Medium:** Align UI query gating and Phase 59's `payments.read + billing.read` authorization contract with the role matrix.
5. **Medium:** Add authoritative reconciliation between invoice paid_amount and active payment aggregates.
6. **Policy decision:** Define Bankak reference requirement and whether receipts require third-party authenticity verification.
7. **Release blocker:** Phase 58/59 receipt-status and currency-provenance contracts are not confirmed in Production by the latest repository release evidence. Do not deploy receipt UI to an environment lacking the required RPC/schema.
8. **Acceptance blocker:** Authenticated cashier role/branch acceptance and real Android/A4/thermal printing remain outstanding.
9. **Integration hygiene:** Reconcile the task branch against the current main ref using an unambiguous branch-SHA comparison before any integration decision; preserve the requested round baseline and do not infer branch ancestry from conflicting compare metadata.

## 10. Next action

**Window 04 / finance implementation owner:** In the next implementation-authorized task, wire a stable per-attempt idempotency key through the payment UI, add a lost-response/retry UI-to-PostgreSQL 17 regression, and prove one payment plus one cashbox source row under concurrent same-key retries. Keep PR #181 Draft until this and the independent finance/security and printer acceptance gates are satisfied.

## 11. Session closeout

- Work completed in this session: Re-read continuation protocol and report template; rechecked PR #181 metadata/head/files/reviews/status; inspected receipt UI/model, payment RPC and Phase 59 permission contract; prepared this isolated report.
- Work not completed: No code/test changes; no disposable PostgreSQL execution; no authenticated role testing; no physical printer testing; no live database recheck.
- Exact current state at close: PR #181 remains open and Draft at head `a49e261b0661239c1e0a18f5734453010499f71c`; report is being delivered through a separate docs-only PR.
- Recommended continuation when the owner says **"أكمل"**: Recheck this report PR and PR #181 current refs, then continue only with the next owner-authorized action; do not modify payment code unless the task scope explicitly permits implementation.
