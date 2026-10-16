# Progress batch C — Roshan Health Hub

**Date:** 2026-10-16 (UTC)
**Canonical branch:** `main`
**Master-plan checklist:** 63/156 = **40.4%** (unchanged)

## Merged
- [PR #26 — migration recovery archive](https://github.com/crauch2088-source/roshan-health-hub/pull/26): 79 applied migration statements archived under `docs/recovered-migrations/`; kept non-executable.
- [PR #41 — expense RPC path](https://github.com/crauch2088-source/roshan-health-hub/pull/41): use `post_expense`, reject invalid amounts; fresh CI passed.
- [PR #43 — finance audit deduplication](https://github.com/crauch2088-source/roshan-health-hub/pull/43): tracked migration/tests; fresh CI passed.

## Supabase migrations applied and verified
1. `roshan_phase18_dedupe_finance_audit_triggers_20261016` — version `20261016161923`; removed five duplicate generic audit triggers and confirmed canonical finance triggers remained. No data rows changed.
2. `roshan_phase21_patient_registration_atomicity_20261016` — version `20261016162410`; installed `public.create_patient_atomic` with `SECURITY DEFINER` and empty `search_path`. Direct INSERT and legacy `next_mrn()` permissions remain enabled so the currently deployed app keeps working.

## Pending rollout
- [PR #44 — staged atomic patient registration](https://github.com/crauch2088-source/roshan-health-hub/pull/44) separates Phase 21A function creation from Phase 21B permission revocation. The dedicated PostgreSQL 17 integration job passed, but a full CI run was cancelled during PR refresh; a rerun was requested. Phase 21B must wait until the updated UI is deployed and smoke-tested.
- Production deployment remains on `9f6b2c881247b570cc75e1f61ed13a2337183b86`; PR #41 and #43 are merged but not yet deployed. Vercel returned HTTP 402 because the team's 100/day deployment API quota is exhausted; reset is approximately 2026-10-17 16:24 UTC.
- Supabase migration history count: 81. Full historical migration parity/replay remains open; archived SQL has not been replayed.

## Next actions
1. Finish fresh CI for PR #44; merge when all checks pass.
2. When Vercel quota resets, deploy current `main` and verify patient registration/expense creation.
3. Apply Phase 21B only after the new patient-registration RPC path is live and smoke-tested; then verify the direct INSERT and legacy allocator grants are revoked.
4. Continue migration parity audit and resume remaining ready PRs after refreshing their bases/checks.
