# Roshan Health Hub — 48-Hour Accelerated Execution Charter

**Status:** Owner-approved execution charter; documentation baseline  
**Target:** A verified, reviewable Release Candidate (RC), not an automatic clinical launch  
**Planning window:** 48 elapsed working hours from the explicit sprint start  
**Repository baseline:** `6f4e8c4c92c7fcd6612ea137063ca34d711bbd69`  
**Currency policy:** SDG is the sole project currency; no alternate-currency roadmap or conversion layer is in scope.

## 1. Mandate

Concentrate engineering effort into a short, coordinated execution sprint. Remove avoidable waiting, parallelize independent work, reuse existing infrastructure, and close verified blockers in dependency order. The objective is to produce the strongest safe Release Candidate that the evidence permits within 48 hours.

The 48-hour target is a time-box, not a promise that every external dependency will be satisfied. A green CI run, a merged PR, or a deployed build is not proof of clinical readiness. If a mandatory safety, data-integrity, migration, backup, device, or staff-acceptance gate remains open at hour 48, the correct result is a documented blocked RC—not a waived gate.

## 2. Definition of success

The sprint may be declared **Engineering RC complete** only when all applicable conditions below are evidenced on the exact candidate commit:

1. All in-scope P0/P1 engineering defects are fixed or explicitly documented as blockers with owner and evidence; no unresolved known critical defect is hidden in a completion percentage.
2. Pharmacy dispensing, medicine identity/pack verification, receipt/transaction currency provenance, and dependent UI workflows have coherent source, tests, and reviewed database contracts.
3. Production/QA migration histories and migration sources are reconciled sufficiently to define a safe, forward-only rollout. No ledger row is manually edited and no QA migration is replayed into Production as a shortcut.
4. Critical authorization, RLS, branch isolation, RPC grants, auditability, and SECURITY DEFINER functions receive focused, evidence-based review. Generic advisor warnings are triaged individually; blanket revocation is prohibited.
5. PostgreSQL 17 disposable integration tests, focused regression tests, typecheck/lint/build as relevant, and exact-head CI are green. Intentional skips and unavailable acceptance tests remain visible.
6. Core user journeys have test evidence for reception → clinician → laboratory → pharmacy → billing, including failure, retry, duplicate-submit, and partial-failure behavior where applicable.
7. Phone-sized layouts, Arabic RTL, English LTR, keyboard/accessibility basics, receipt rendering, and printer workflow have been checked to the extent that the required runtime/device is available.
8. Backup evidence is current and includes a successful restore rehearsal and verified owner-readable encrypted artifact. Storage files and Vault/secret exclusions are explicitly accounted for; a database-only backup is not represented as a complete system backup.
9. Documentation, evidence links, unresolved risks, release sequence, and rollback/recovery notes are updated in the same logical delivery.
10. The owner receives a clear go/no-go recommendation separating Engineering RC, authenticated QA acceptance, staff/device acceptance, and Production release approval.

**Operational acceptance is a separate milestone.** It requires real authorized staff to accept the workflows, a clinician to validate clinical behavior, a pharmacist to validate dispensing, finance to validate SDG receipts and reconciliation, and actual target-device/printer checks. It cannot be fabricated by automation or inferred from code completion.

## 3. Execution model: parallel streams with dependency control

Run the following streams concurrently only where their inputs are stable. A stream may not bypass another stream's contract or release gate.

### Stream A — Orchestration, evidence, and scope control
- Establish the sprint baseline from current `main`, open PRs, exact CI heads, release reports, and current live read-only evidence.
- Build a deduplicated, weighted task ledger with P0/P1/P2 priority, dependency, owner, evidence required, and status.
- Freeze scope to launch-critical work. Defer cosmetic polish, speculative features, broad refactors, new integrations, and post-launch experiments.
- Maintain one authoritative status record in `docs/MASTER_PLAN.md`; this charter defines execution rules and does not create a competing roadmap.

### Stream B — Pharmacy and medicine catalogue
- Resolve the Phase 57 dispensing contract, including explicit NULL-quantity rejection, no silent quantity fallback, FEFO/stock integrity, idempotency, invoice atomicity, branch scope, and audit evidence.
- Correct the medicine identity editor so any identity-field change invalidates prior physical-pack acknowledgement, or bind acknowledgement cryptographically/structurally to the exact normalized identity payload.
- Settle shared-catalogue permissions and durable pack-verification audit semantics.
- Prove behavior with regression tests and disposable PostgreSQL 17; then perform synthetic authenticated pharmacist acceptance in QA.

### Stream C — SDG finance, receipts, and accounting integrity
- Keep SDG as the single canonical currency across settings, invoices, receipts, reports, and accounting.
- Persist transaction/invoice currency provenance at transaction creation; never derive historical receipt currency from mutable settings.
- Define explicit handling for legacy NULL/mismatched currency records. Do not silently relabel, convert, print, or reconcile ambiguous historical transactions.
- Review the receipt UI only after the provenance contract is accepted; validate totals, rounding, duplicate submission, idempotency, and audit trail.

### Stream D — Database provenance, security, and release safety
- Reconcile the canonical migration source, manifest, Production ledger, and QA ledger using read-only evidence first.
- Explain every divergence and identify a safe forward-only migration sequence. Never edit migration history to make environments appear equal.
- Review SECURITY DEFINER functions individually for fixed search_path, actor binding, permission checks, branch checks, input validation, and intended grants.
- Preserve intended authenticated RPC access. No bulk grants/revokes, RLS changes, Auth changes, Storage changes, extension moves, or live DDL/DML without the relevant explicit release approval.
- Confirm current backup/restore evidence and document excluded Storage/Vault components and recovery dependencies.

### Stream E — User journeys, mobile UX, bilingual support, and printing
- Prioritize complete, reliable workflows over isolated screen polish.
- Validate the 320–430 px phone range, Arabic RTL and English LTR, navigation, validation, loading/error/retry states, and role-specific visibility.
- Validate receipt content and actual A4/thermal printing on available hardware. A browser preview is not physical printer acceptance.
- Keep the interface clinically conservative: no invented dose, diagnosis, result, amount, signature, or missing value.

### Stream F — Independent QA and release decision
- Build a risk-based test matrix mapped to the task ledger and acceptance criteria.
- Run each focused test once after the relevant change, then the smallest justified integrated suite and one exact-head CI run per coherent stage.
- Distinguish unit, integration, disposable-database, authenticated QA, browser, physical-device, staff, and Production evidence.
- Produce a final evidence index, unresolved-risk register, release checklist, and explicit go/no-go recommendation.

## 4. 48-hour sequence

The schedule is an execution envelope. Reorder only when a verified dependency requires it; record the reason.

| Window | Required outcome |
|---|---|
| H0–H2 | Freeze baseline; inspect main and all relevant PR heads; confirm CI; create weighted P0/P1/P2 ledger; identify external dependencies and blockers. |
| H2–H10 | Parallel source review and targeted fixes for pharmacy, catalogue acknowledgement, SDG provenance, and migration/security evidence. Write regression tests before behavior changes. |
| H10–H18 | Complete coherent implementation bundles; run focused tests and disposable PG17 tests; resolve cross-stream contract conflicts. |
| H18–H26 | Integrate compatible changes; review SQL and authorization independently; complete source/migration reconciliation and backup evidence assessment. |
| H26–H34 | Run critical end-to-end journeys in isolated QA with synthetic identities/data; verify failure paths, branch isolation, idempotency, and financial integrity. |
| H34–H40 | Browser/mobile/RTL/LTR checks; receipt and printer validation where hardware is available; staff/clinical/pharmacy/finance acceptance sessions where people are available. |
| H40–H46 | Independent final review; exact-head CI; close only evidence-backed tasks; document blockers, rollback/recovery, and residual risks. |
| H46–H48 | Freeze candidate; publish evidence and decision record; classify result as Engineering RC, blocked RC, or no-go. No last-minute scope expansion. |

If a dependency is unavailable, continue independent work and mark the dependent task blocked. Do not spend the sprint repeatedly waiting on the same unavailable human, device, secret, quota, or external service.

## 5. Priority and stop rules

- **P0 — Stop-ship:** patient safety, incorrect medication/dispense behavior, unauthorized access, cross-branch leakage, lost/duplicated financial or stock transactions, false clinical/financial documents, destructive migration risk, or unverifiable recovery. Stop the affected release path immediately.
- **P1 — Required for RC:** broken critical workflow, incorrect SDG provenance/receipt, unresolved migration-source ambiguity, material audit gap, missing critical regression coverage, or failure of an essential supported device/viewport.
- **P2 — Defer:** cosmetic issues, non-critical convenience, speculative analytics, broad refactors, optional integrations, and post-launch experiments.

No task is complete because a PR exists, code compiles, a screenshot looks correct, a migration file exists, or a checklist is ticked. Completion requires the stated evidence.

## 6. Non-negotiable execution laws

1. **Evidence before assertion:** every status claim links to an exact commit, test, CI run, read-only query, review, or signed acceptance record.
2. **No invented parallelism:** work may run in parallel only when dependencies and ownership are independent; conflicting writes to the same file, branch, database, or PR are serialized.
3. **One atomic delivery per logical task:** source, regression tests, migration/fixtures when applicable, and documentation are prepared together in one coherent commit. Use a single Git tree/commit and expected-SHA ref update; do not rewrite published history.
4. **CI and quota discipline:** one CI run per completed coherent stage; fix actual failures and rerun only necessary validation. Documentation-, SQL-, migration-, and script-only changes must avoid frontend builds. No paid upgrades or quota bypasses.
5. **Production is not a test environment:** no synthetic patient, clinical, pharmacy, lab, inventory, or financial transactions in Production.
6. **Production changes follow the Constitution's delegated authorization:** this charter does not independently grant authority, but the standing owner authorization in `.specify/memory/constitution.md` permits qualifying engineering changes after all preflight, validation, recovery, and post-change evidence gates pass. No per-change conversational approval is needed inside that delegated envelope. Destructive or irreversible business-data changes, clinical-policy decisions, unresolved critical risks, and actions with uncertain scope/cost/recovery remain owner-gated.
7. **No unsafe shortcuts:** never weaken RLS, branch isolation, authorization, auditability, atomicity, clinical confirmation, or financial integrity to meet the clock.
8. **No false completion:** skipped, deferred, blocked, flaky, untested, and unavailable checks remain separately labeled. An intentional skip is not a pass.
9. **No silent scope change:** SDG remains the only currency. Do not add multi-currency, new paid services, new agent runtimes, or speculative tooling in this sprint.
10. **Owner authority is preserved:** the owner retains clinical-policy decisions, acceptance of residual risk outside the delegated envelope, and real-world operational launch. The engineering agent may execute qualifying Production engineering changes under the standing authorization in the Constitution; it may not waive release gates, self-approve clinical policy, or declare staff/clinical acceptance.

## 7. Measurement and reporting

At H0, calculate a baseline from a deduplicated weighted ledger rather than counting historical checkboxes or PRs. Report two separate measures:

- **Engineering completion:** weighted completion of scoped implementation, tests, reviews, and documentation.
- **Operational readiness:** weighted completion of authenticated role acceptance, staff UAT, device/printer checks, backup/restore, and release gates.

Never combine these into one percentage. Every update must state the evidence date, exact candidate commit, completed/blocked work, remaining critical dependencies, and a realistic remaining-time estimate. If the denominator changes, explain it; do not inflate the percentage by deleting difficult tasks.

## 8. End-of-sprint outcomes

- **Engineering RC complete:** all engineering exit criteria met; operational acceptance may still be pending.
- **Blocked RC:** a coherent candidate exists, but one or more mandatory gates are unavailable or unresolved. State exactly what is blocked and what evidence would unblock it.
- **No-go:** a P0 defect, unsafe migration/data ambiguity, security failure, or inadequate recovery evidence prevents a responsible candidate.

Production changes are covered by the standing owner delegation in Constitution section X, but only after all applicable release gates pass. None of these labels automatically authorizes clinic launch or substitutes for clinical/staff acceptance.

## 9. Ratification and change control

This charter is binding for the accelerated Roshan execution sprint once accepted by the owner. It supplements the Roshan Constitution and AGENTS.md; it does not supersede them, docs/MASTER_PLAN.md, feature specifications, or explicit release approvals. If a conflict arises, the stricter clinical-safety, privacy, data-integrity, or Production-protection rule prevails.

Any relaxation of a stop rule requires an explicit owner decision, a written rationale, an impact analysis, and recorded acceptance. A schedule target alone is never sufficient justification.

**Owner decision:** charter approved in conversation on 2026-11-10; standing delegated Production engineering authority explicitly granted in conversation on 2026-11-12 and recorded in Constitution section X.  
**Baseline:** main `6f4e8c4c92c7fcd6612ea137063ca34d711bbd69`.  
**Currency:** SDG only.
