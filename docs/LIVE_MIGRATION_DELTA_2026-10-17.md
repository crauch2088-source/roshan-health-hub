# Live migration and security verification delta — 2026-10-17

**Project:** `jewzonxplxhogqrnhosl` (Roshan Production)  
**Verification window:** 2026-10-17 12:59–13:32 UTC  
**Result:** four tracked forward migrations applied and read back successfully. The historical 93-entry chain was not replayed.

## Applied migrations and exact source matching

| Version | Applied name | Tracked source | Stored statement chars | Exact match |
|---|---|---|---:|---|
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | `db/roshan_security_candidate_bundle_20261017.sql` | 29,974 | Yes |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | `db/roshan_phase5_insurance_claim_amount_integrity.sql` | 7,357 | Yes |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | `db/roshan_phase5_insurance_coverage_validity.sql` | 7,334 | Yes |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | `db/roshan_phase27_revoke_legacy_invoice_number.sql` | 256 | Yes |

A follow-up read-only RPC audit found that `public.next_invoice_number()` was still directly executable by `authenticated` despite no client callsite and no branch filter. The function is used internally by the SECURITY DEFINER `create_invoice_atomic`; its owner retains execution. A test-first PostgreSQL 17 regression failed before the revocation and passed afterward. The exact live transaction dry-run passed, the tracked migration was applied, and read-back confirmed authenticated/anon EXECUTE=false while owner EXECUTE=true. The Security Advisor's authenticated SECURITY DEFINER callable count dropped from 21 to 20.

For each entry, the stored `supabase_migrations.schema_migrations.statements[1]` was compared directly against the full tracked source string in PostgreSQL; all four comparisons returned `exact_source_match=true`. The migration ledger now has **97 rows**, latest version `20261017133157`. Combined with the previous verified 92 source matches and one intentionally redacted identity-link exception, the current mapping is **96/97 exact source matches, one documented redaction, zero unmapped versions**. The old `source-parity-report.json` remains a frozen 93-row historical snapshot and is not the live delta record.

## Production read-back

- All 11 targeted child tables have exactly four policies each (44 total); each policy includes its expected parent/branch helper. The per-table read-back reported zero missing expected helpers.
- Direct INSERT/UPDATE/DELETE grants are now false for `authenticated` and `anon` on the five finance tables (`cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, `supplier_payments`) and the three insurance ledger tables (`insurance_claims`, `insurance_claim_items`, `insurance_claim_payments`). Authenticated SELECT remains true on all eight.
- The legacy `add_cashbox_entry` RPC is no longer executable by `authenticated` or `anon`; the validated finance RPCs remain executable by `authenticated`, not `anon`, and retain an empty fixed `search_path`.
- `create_insurance_claim(uuid,uuid,jsonb,text)` is SECURITY DEFINER with empty `search_path`; authenticated EXECUTE=true, anon EXECUTE=false. The live definition contains invoice/visit patient and branch consistency guards and the claim item amount-split invariant.
- `fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric)` is SECURITY DEFINER with empty `search_path`; authenticated EXECUTE=true, anon EXECUTE=false. The live definition rejects unsupported service types and gross amounts with more than two decimal places, and validates policy/plan/company activity and validity windows.
- Current live security Advisor snapshot reports 20 SECURITY DEFINER callable warnings (intended authenticated RPCs requiring per-function authorization review), one `pg_trgm`-in-`public` extension warning, and one leaked-password-protection warning. Supabase confirms leaked-password protection requires Pro; no paid upgrade was attempted. These warnings need triage; intended RPC exposure is not automatically a vulnerability, but each function must retain explicit authorization checks.
- Runtime-error aggregation returned no events in the preceding 24 hours at the time checked. Vercel's production deployment remains behind current source and the latest current-main build check is blocked by the Hobby build-rate limit; no paid upgrade, forced deploy, or bypass was attempted.

## Test evidence

- Security bundle: all six PostgreSQL 17 isolated/combined workflow jobs passed.
- Insurance claim integrity: the test-first invoice/visit mismatch cases failed before the guard and passed after; the PostgreSQL 17 integration workflow passed.
- Insurance coverage validity: unsupported service type and fractional-cent regression cases failed before the guard and passed after; the PostgreSQL 17 integration workflow passed.
- General CI on the tested PR heads passed install/audit/typecheck/lint/build, source-parity, migration replay-safe policy portion, invoice, patient registration, prescription/pharmacy, visit/queue, finance trigger and concurrency tests.
- Before applying, the exact security bundle plus both insurance SQL files were executed in one explicit transaction against the live schema with catalog assertions, then rolled back. It succeeded; a subsequent read confirmed the ledger was still at 93 before the tracked migrations were applied.

## Safety and remaining gates

- The three migrations were applied through Supabase's migration tool. No patient/financial rows were updated or deleted by the migration content; changes were policies, grants, and function definitions.
- This did **not** replay the historical chain. The missing trustworthy pre-migration baseline and redacted historical identity-link migration remain documented bootstrap limitations; they are not silently reconstructed.
- No live app login or patient-facing write smoke test was performed because the production deployment is behind current source and build capacity is rate-limited. Database catalog/function read-back and synthetic PostgreSQL 17 integration tests are complete, but this is not a declaration of clinical readiness.
- Issue #16 was closed after live read-back evidence was attached. Issue #25 remains open for alert/security-control follow-up.
