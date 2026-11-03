# Feature specifications

Feature-specific requirements, plans and task lists live here. The master roadmap remains `docs/MASTER_PLAN.md`; specs must not duplicate it.

| Spec | Feature | Status |
|---|---|---|
| [001 — Clinical Document Printing](001-clinical-document-printing/spec.md) | Receipt, invoice, prescription and medical certificate printing | Draft; clarification and code-contract review pending |
| [002 — Source-aware Financial Reversal](002-source-aware-financial-reversal/spec.md) | Atomic invoice-payment reversal and receipt-status read model | Implemented in QA; production backup gate pending |
| [003 — Clinical Parent-link and ACL Reconciliation](003-clinical-parent-link-acl-reconciliation/spec.md) | Immutable lab item parent link and private helper ACL hardening | Applied to QA; exact-head CI passed; PR #172 awaiting merge; Production backup gate pending |
