---
name: roshan-database
description: Use for every Roshan PostgreSQL/Supabase schema, SQL, migration, RPC, trigger, index, grant, RLS change, or database contract investigation.
---

# Roshan Database

## Inspect first
- Verify intended Supabase project/ref and environment; distinguish Production from isolated QA.
- Inspect migration ledger/order, live catalog evidence, callers, grants, policies, triggers, and tests.
- Read docs/DB_MIGRATION_RECONCILIATION.md and relevant baseline/manifest docs.
- Never assume a migration is applied because a file exists or a prior report says so.

## Invariants
- Use disposable PostgreSQL 17 integration tests where specified.
- Enforce branch boundaries in authoritative database policies and RPCs; client filters are not security.
- Preserve immutable accounting/inventory ledgers, atomic operations, idempotency, exact decimal precision, and audit triggers.
- Preserve RPC-only write contracts for protected tables.
- SECURITY DEFINER functions require fixed safe search_path; verify owner, grants, caller authorization, and delegated helpers.
- Never weaken FORCE RLS, remove policies, widen grants, or add bypass paths as shortcuts.
- Keep migrations ordered/tracked and pair behavior changes with assertions and source-parity updates.

## Migration protocol
1. State the invariant and why current schema cannot satisfy it.
2. Prefer one comprehensive migration per logical phase; use Expand/Contract only for proven compatibility needs.
3. Add disposable PG17 fixtures for behavior, authorization, idempotency, and rollback.
4. Inspect SQL and all callers before execution.
5. Never use Production as a test database or seed synthetic business rows there.
6. Never apply candidate SQL, mutate grants/RLS, or write live data without documented owner authorization and release gates.
7. After authorized apply, verify ledger and resulting catalog with a batched read-only diagnostic.

Report source presence, CI replay, QA application, Production application, and read-back as separate facts.
