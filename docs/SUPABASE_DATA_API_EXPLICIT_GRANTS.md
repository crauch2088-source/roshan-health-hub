# Supabase Data API explicit grants (effective 2026-10-30)

## Roshan status checked 2026-10-20

The live project jewzonxplxhogqrnhosl has 56 public tables; all 56 have RLS enabled and authenticated SELECT. One existing table lacks service_role SELECT and one existing view lacks authenticated SELECT. These existing ACLs were not changed.

The postgres owner's default privileges for new public tables do not automatically grant access to anon, authenticated, or service_role. This is consistent with least privilege. Do not add broad default grants to silence the notification.

## Rule for every new public table

1. Enable RLS in the same migration.
2. Grant only the permissions required by the table's actual clients.
3. Add and test narrowly scoped RLS policies. GRANT alone does not authorize access to rows.
4. Add a PostgreSQL 17 migration test/CI contract.

Example only; adapt to the real access model:

    create table public.example_table (...);
    alter table public.example_table enable row level security;
    grant select on table public.example_table to authenticated;
    grant select, insert, update, delete on table public.example_table to service_role;
    -- Add narrowly scoped RLS policies separately.

Do not grant anon unless unauthenticated access is explicitly required and reviewed. Do not apply broad CRUD grants to clinical or financial tables: Roshan deliberately routes sensitive writes through validated RPCs in several workflows.

## CI enforcement

scripts/verify-supabase-data-api-grants.py checks timestamped SQL migrations dated 2026-10-30 onward for explicit authenticated/service_role SELECT grants and RLS enablement. This is a guardrail, not a complete SQL parser; review each table's full least-privilege grants and policies.

## Verification evidence

Read-only catalog query on 2026-10-20: 56 public tables; 0 tables without RLS; 0 tables without authenticated SELECT; 1 table without service_role SELECT; 1 view without authenticated SELECT. No production DDL/DML was performed.
