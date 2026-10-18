# Supabase Advisor triage — 2026-10-18

Project: `jewzonxplxhogqrnhosl`
Method: read-only catalog queries and current Supabase Security/Performance Advisor output. No production schema, ACL, extension, authentication setting, or index was changed.

## Findings and disposition

### 1. `pg_trgm` in `public` — open, do not move blindly
- Advisor: one `extension_in_public` warning.
- Catalog confirms `pg_trgm` currently belongs to schema `public`.
- Before relocation, inventory extension-owned objects, dependent indexes/operators/functions, and application search behavior; prepare a reversible migration and regression tests for patient-name fuzzy search.
- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public

### 2. SECURITY DEFINER functions callable by authenticated — classify by intended contract
- Advisor: 22 warnings.
- The two clinical RPCs required for the staged Phase 30 are `complete_lab_order_item(uuid)` and `create_medical_certificate(uuid,text,date,date)`. Live catalog confirms both are SECURITY DEFINER, use a fixed empty `search_path`, are executable by `authenticated`, and are not executable by `anon`. That is the intended frontend RPC contract, not by itself evidence that either function is safe; the function bodies and per-role authorization checks still require review.
- A separate read-only catalog query showed several SECURITY DEFINER routines that are not executable by either `authenticated` or `anon` in the current effective privilege check. Advisor counts therefore must not be translated into a blanket ACL migration: inspect each exact signature, grants, schema exposure, callers, and behavior before changing it.
- No blanket revocation performed.
- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

### 3. Leaked/compromised password protection — status not independently verified
- Advisor reports one warning. SQL catalog access does not establish the Auth dashboard's compromised-password protection setting. Verify in Supabase Auth configuration, then record the observed setting; do not claim it enabled or disabled from Advisor alone.

### 4. Unused indexes — open, no drops
- Advisor reports 89 unused-index findings.
- A read-only `pg_stat_user_indexes` sample returned `idx_scan = 0` for six candidates: `medicines_barcode_idx`, `medicines_generic_name_idx`, `stock_movements_medicine_created_idx`, `patients_full_name_trgm_idx`, `patients_phone_idx`, and `patients_national_id_idx`.
- Zero scans in the current statistics window is not proof an index is redundant; counters may have reset and the application has low/early workload. Check statistics reset time, query plans, uniqueness/constraint dependencies, and actual search paths before proposing a drop.
- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index

## Safe next actions
1. Verify compromised-password protection through the supported Auth settings interface.
2. Extract and review each of the 22 exact Advisor function signatures, intended caller roles, and function bodies; add targeted tests before any grant change.
3. Establish `pg_stat_database.stats_reset` and index dependency/query-plan evidence before index recommendations.
4. Evaluate `pg_trgm` relocation in a non-production PostgreSQL 17 regression environment first.
5. Keep Phase 30 blocked until the canonical frontend deployment is current and both synthetic-data UI flows pass.
