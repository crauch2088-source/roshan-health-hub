# Roshan Health Hub — Execution Batch 2
**Date:** 2026-10-16  
**Scope:** 20 additional implementation, database-verification, regression-test, and deployment-check items. Production database writes were not performed.

## 20 items completed

1. Re-read the canonical `docs/MASTER_PLAN.md` from `main` before starting this batch.
2. Recounted the plan's explicit checkbox items: 156 total.
3. Recounted completed checkboxes: 63.
4. Recalculated checklist completion as 63/156 = **40.4%**; audit-only work is not counted as implementation completion.
5. Queried the connected Supabase migration ledger; it reports 79 applied migrations.
6. Queried the live public schema table inventory; it reports 56 public tables.
7. Verified that all 56 listed public tables currently have RLS enabled.
8. Counted 33 public SECURITY DEFINER functions.
9. Verified that all 33 public SECURITY DEFINER functions have a function-level `search_path` configuration. This is a configuration check, not a substitute for reviewing each function's actual value and logic.
10. Verified that the `anon` role cannot directly INSERT into `public.patients`.
11. Found that `authenticated` can currently INSERT directly into `public.patients`; the proposed PR #39 revocation has not been applied to production.
12. Found that `authenticated` can currently EXECUTE `public.next_mrn()`; the proposed PR #39 revocation has not been applied to production.
13. Confirmed that `public.create_patient_atomic(text,text,date,text,text)` does not yet exist in production.
14. Read the current production `public.next_mrn()` definition without modifying it.
15. Confirmed that the live allocator uses the transaction advisory-lock key `hashtext('roshan:mrn')`.
16. Compared PR #39's candidate atomic allocator and confirmed it uses the same advisory-lock key, so the two code paths coordinate on the same lock if deployed.
17. Reviewed the candidate SQL fixture and found invalid dollar-quote syntax around its stub `next_mrn()` function.
18. Corrected the fixture to use valid `$$ ... $$` dollar quoting.
19. Added an integration regression test asserting that a blank gender is rejected by the atomic patient-registration RPC.
20. Committed those two test corrections to PR #39 as [90bc780](https://github.com/crauch2088-source/roshan-health-hub/commit/90bc780cc38d66227ae6b8a8a2cab268c6ca8f0e) and verified its Vercel preview reached READY: [preview deployment](https://vercel.com/roshan45/roshan-health-hub/HmemGD1Zy5DYKRZZ8AGFJR31otW3).

## Important status and safety boundary

- PR #39 remains draft/open. The preview's READY state is a frontend build/deployment signal, not proof that the PostgreSQL integration workflow passed.
- The live database still has direct authenticated patient INSERT and authenticated execution of `next_mrn()`. This is a verified least-privilege gap to close through a reviewed, reconciled migration—not by an ad hoc production SQL command.
- The production database still does not contain the atomic patient-registration RPC. No SQL, grants, patient data, or other database state was changed in this batch.
- Migration-history parity remains unresolved. Do not merge or apply the candidate migration until the repository migration sequence, isolated PostgreSQL/Supabase integration tests, rollback, and branch authorization behavior are reviewed.
- The master-plan checklist percentage remains **40.4%** (63/156). This batch contains substantial audit and test-preparation work, but those tasks are deliberately not reclassified as completed production features.
