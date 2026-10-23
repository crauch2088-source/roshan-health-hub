# Isolated QA environment — 2026-10-23

## Purpose

This branch exists only to prepare the single comprehensive Roshan Health Hub acceptance session. It must not be promoted to production.

- Git branch: `qa/isolated-acceptance-20261023`
- Supabase QA project: `roshan-health-hub-qa`
- Supabase project ref: `hopfohcnrtbiqjkgeukz`
- Region: `eu-west-1`
- Vercel environment: Preview only, branch-scoped to this branch.
- QA browser variables: `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`; both are scoped to this branch's Preview deployment.
- Production Supabase project `jewzonxplxhogqrnhosl` and production environment variables are not modified.

## Current limitations

The QA project is newly provisioned and its application schema is empty. Do not run clinical acceptance writes until a safe, Supabase-compatible schema bootstrap is validated.

The tracked `db/baseline/0000_roshan_pg17_baseline_v112.sql` is explicitly a disposable PostgreSQL CI baseline. It creates minimal Auth compatibility shims and roles, and is not a replacement for Supabase-managed Auth, Storage, Realtime, or other platform services. Do not apply it unchanged to a real Supabase project. The repository's migration reconciliation also documents that the historical migration chain is incomplete and one environment-specific identity mapping is intentionally redacted.

## Required safe next steps

1. Run the existing PostgreSQL 17 clean-room replay and test suite using the CI disposable database, including migrations 113–115 and the Phase 45 candidate migration.
2. Establish a reviewed, Supabase-compatible QA schema bootstrap that preserves platform-managed schemas and services; do not invent missing historical SQL.
3. Create synthetic QA-only auth users and role profiles after schema bootstrap and verify branch-scoped Preview connectivity.
4. Run automated smoke checks first. Keep staff usability/clinical workflow acceptance for the single final session with the user.
5. Keep Issue #95 open until that final acceptance session passes and results are recorded.

## Data and release safety

- No patient, visit, laboratory, prescription, inventory, or financial fixtures are allowed in production.
- Do not apply Phase 45 to production without a separate explicit release gate after QA evidence.
- Do not use paid database branches, paid services, or unnecessary Vercel builds.
