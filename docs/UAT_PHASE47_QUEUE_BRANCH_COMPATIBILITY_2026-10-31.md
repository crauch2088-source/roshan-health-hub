> **Superseding rollout status (2026-10-31):** Phase 47 is now merged and applied to QA and production. Production migration version: `20261031071122`; QA version: `20261031070544`. See [the production rollout record](PRODUCTION_ROLLOUT_2026-10-31.md) for post-apply verification and remaining launch gates.

# UAT follow-up — visit and queue branch attribution (Phase 47)

## Read-only production evidence

- `public.queue_tickets.branch_id` is absent although `src/routes/_authenticated/queue.tsx` selects it. This would make the full Queue screen fail with a missing-column error; the UAT only confirmed the Q1 value on the visit form, not the Queue route.
- Production has one active branch, one visit, and one queue ticket. The visit and ticket are branchless, while the linked patient has a branch assignment. The queue ticket has a valid visit and matching patient. No invoice is linked to the visit.
- The current visit creation route inserts a visit without `branch_id`; this is why the visit was branchless despite the patient having a branch.

## Phase 47 candidate

- Add nullable `queue_tickets.branch_id uuid`, FK to branches, and a branch/date/status index.
- When exactly one active branch exists, backfill branchless visits only from an explicitly assigned patient branch matching that sole active branch. With multiple active branches, leave ambiguous rows untouched; do not guess.
- Backfill linked queue tickets from the now-authoritative visit branch.
- Add invoker trigger guards so future visits inherit the patient's branch when omitted and reject mismatched/inactive branches; new queue tickets inherit patient and branch from the linked active visit.
- Keep legacy unlinked queue tickets mutable for non-identity metadata, but never allow arbitrary branch or identity assignment.

## Verification

The dedicated disposable PostgreSQL 17 suite tests single-branch backfill, no-guess behavior for inactive/unassigned patient branches, new visit/queue inheritance, cross-branch and patient mismatch rejection, deleted/missing visit rejection, and browser-role function ACLs.

This is a candidate only until QA and production read-back. Phase 46 was applied to isolated QA; Phase 47 has not yet been applied to either live project.
