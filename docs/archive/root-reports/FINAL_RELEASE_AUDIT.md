# Roshan Health Hub — Final Release Candidate Audit

Date: 2026-08-23  
Scope: delivered source archive and database migrations

## Verification performed

- `npx tsc --noEmit`: **PASS**
- `npm run build`: **PASS**
- Build no longer reports the non-route `users.server.ts` warning.
- Static inspection covered authentication, permission checks, RLS migrations,
  clinical calculations, search query construction, persistence, printing
  entry points, and audit triggers.

An authenticated browser and a live Supabase project were not available in this
workspace. Therefore, the reception/doctor/pharmacy/billing and lab workflows,
Arabic rendering, PDF output, mobile layout, query timings, and live RLS
behavior remain pilot-environment acceptance tests rather than claims of
completed execution.

## Changes applied

### High priority

1. Fixed two remaining TypeScript blockers:
   - Lab results now passes `SectionTitle` content as children.
   - Visit creation selects the created visit id before creating its invoice.
2. Added a settings-page permission gate so users cannot view the admin
   settings UI by navigating directly to `/settings`.
3. Filtered the application navigation by the authenticated user's
   permission, and made queue mutations fail closed when `visits.update` is
   absent.
4. Renamed the server-only user helper to `-users.server.ts`, so TanStack
   Router does not treat it as a route.
5. Corrected obstetric date handling:
   - LMP/EDD are calculated in UTC date-only arithmetic.
   - Invalid date-only input is rejected.
   - Future LMP values no longer produce a positive gestational age.

### Remaining high/medium risks

- The live end-to-end chains still require execution against a seeded
  Supabase environment.
- Pediatric growth values are explicitly approximate medians/SDs, not the full
  WHO LMS reference tables. This must be clinically validated before using the
  percentile display for decisions.
- Queue buttons for `called` and `in_progress` should be visually hidden for
  users without `visits.update`; the mutation itself is now fail-closed and
  database RLS remains the authoritative control.
- The generic migration must be applied in the documented order. Client-side
  permission checks are not a substitute for applying the RLS migrations.
- `npm run lint` is not a release gate for this archive: it reports 1,197
  existing Prettier-format errors across the delivered tree. No broad
  formatting rewrite was applied because it would create a noisy,
  non-functional change.

## Critical blockers

None found in the static audit after the fixes above.

## GO / NO-GO

**CONDITIONAL GO for a controlled pilot**, not a claim of production readiness.
Proceed only after applying all migrations and completing the live acceptance
checklist in `DEPLOYMENT_CHECKLIST.md`, including role-by-role RLS tests and
Arabic print/PDF checks. Do not use the pediatric percentile output for
clinical decisions until the reference data is validated by the clinic.

## Exact modified files

- `src/routes/_authenticated/lab_.$orderId.tsx`
- `src/routes/_authenticated/visits.tsx`
- `src/components/app-shell.tsx`
- `src/routes/_authenticated/queue.tsx`
- `src/routes/_authenticated/settings.tsx`
- `src/lib/medical.ts`
- `src/routes/_authenticated/users.tsx`
- `src/routes/_authenticated/-users.server.ts` (renamed from `users.server.ts`)
- `package-lock.json` (synchronized with `package.json` during verification)