# Recovered applied migration SQL — quarantine only

Recovered on 2026-10-15 from a read-only query against the live Supabase migration ledger for project `jewzonxplxhogqrnhosl`.

- These files reconstruct SQL statement strings stored in each ledger row, joined with blank lines. They are recovered artifacts, not original migration files byte-for-byte.
- The manifest preserves each ledger version/name and original ledger checksum/byte count.
- Migration `20260818191254_fix_patients_rls_and_admin_link.sql` contains an environment-specific admin email and user UUID in a one-time `users.auth_user_id` update. Its public file is **redacted**; the original identity literals are not reproduced in this public repository. Its ledger checksum and byte count refer to the original ledger row, while the public file intentionally differs.
- A basic scan found no common private-key or token patterns. This is not a complete secret/privacy audit.
- **Do not execute or move these files into `supabase/migrations` yet.** They have not been semantically reviewed against the current schema or replayed in a clean PostgreSQL/Supabase environment.
- This is a quarantine/recovery artifact only. Production was queried read-only; no SQL was applied and no data was changed.

Next gates: review migration bodies in order; compare to current `db/*.sql` artifacts; inspect environment-specific data and destructive assumptions; test full replay in disposable PostgreSQL 17; then test Supabase-specific auth/RLS/grants in an isolated Supabase environment before deciding on a canonical migration directory.
