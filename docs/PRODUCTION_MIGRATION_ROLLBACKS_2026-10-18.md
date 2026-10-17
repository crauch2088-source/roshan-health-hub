# Roshan Health Hub — Production Migration Rollback Plan (2026-10-18)

This is the reviewed rollback reference for the two narrowly scoped forward candidates in:
- `db/roshan_insurance_prior_authorization_branch_isolation.sql`
- `db/roshan_post_expense_finite_amount.sql`

**Scope and safety:** the live Supabase project is `jewzonxplxhogqrnhosl`. Before the proposed changes, read-only queries confirmed zero rows in `public.insurance_prior_authorizations` and `public.patient_insurance`; the new helper `private.app_has_prior_authorization_branch_access(uuid)` did not exist. The production `post_expense` body was captured before modification. Do not use a rollback to conceal a failed test; first capture the exact error and confirm whether any writes occurred.

## 1. Prior-authorization RLS rollback

This restores the three policy expressions observed before the forward migration and removes only the helper introduced by that migration. Run as the database migration owner in one transaction:

```sql
BEGIN;

DROP POLICY IF EXISTS insurance_prior_authorizations_upd
  ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_upd
  ON public.insurance_prior_authorizations
  FOR UPDATE TO authenticated
  USING (app_has_perm('insurance.update'::text))
  WITH CHECK (app_has_perm('insurance.update'::text));

DROP POLICY IF EXISTS insurance_prior_authorizations_ins
  ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_ins
  ON public.insurance_prior_authorizations
  FOR INSERT TO authenticated
  WITH CHECK (app_has_perm('insurance.create'::text));

DROP POLICY IF EXISTS insurance_prior_authorizations_sel
  ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_sel
  ON public.insurance_prior_authorizations
  FOR SELECT TO authenticated
  USING (app_has_perm('insurance.read'::text));

REVOKE ALL ON FUNCTION private.app_has_prior_authorization_branch_access(uuid)
  FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS private.app_has_prior_authorization_branch_access(uuid);

COMMIT;
```

**Security consequence:** this rollback reopens the pre-existing cross-branch authorization exposure. It is a break-glass recovery only; if used, keep the system prelaunch and immediately create a replacement fix.

## 2. Expense finite-amount guard rollback

This restores the pre-change function body captured from the live catalog. It intentionally restores the old validation behavior, so use only if the new function causes a confirmed production regression.

```sql
CREATE OR REPLACE FUNCTION public.post_expense(
  _category text,
  _amount numeric,
  _description text DEFAULT NULL::text,
  _expense_date date DEFAULT CURRENT_DATE,
  _method text DEFAULT 'cash'::text,
  _paid_to text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  exp_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record expenses';
  END IF;

  IF _amount IS NULL OR _amount <= 0 THEN
    RAISE EXCEPTION 'expense amount must be greater than zero';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;

  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured';
  END IF;

  INSERT INTO public.expenses (
    branch_id, category, amount, description, expense_date,
    payment_method, paid_to, created_by
  )
  VALUES (
    bid, COALESCE(_category, 'other'), _amount, _description,
    COALESCE(_expense_date, CURRENT_DATE), COALESCE(_method, 'cash'),
    _paid_to, uid
  )
  RETURNING id INTO exp_id;

  RETURN exp_id;
END;
$function$;
```

## 3. Post-change verification checklist

After each forward migration, verify:
1. Supabase migration history contains exactly one new entry for the migration name; do not retry blindly if the tool times out.
2. Prior-authorization policies include both the existing permission check and `private.app_has_prior_authorization_branch_access(patient_insurance_id)`; the helper has `search_path = ''`, is not executable by `anon`, and is executable by `authenticated`.
3. `public.post_expense` contains the NULL/NaN/Infinity/positive-value guard and retains its original permission, user, and branch-attribution behavior.
4. Recheck the table row counts, policy catalog, function definition, and exact ledger tail using read-only queries.
5. Run the corresponding PostgreSQL 17 regression workflow and the main CI checks. Keep the production domain in prelaunch/test-only status until the broader migration replay and clinical workflow gates are resolved.

The historical migration replay is still incomplete: no reviewed initial schema baseline exists and one environment-specific identity-link migration is intentionally redacted. These forward fixes do not prove that full historical replay is clean.
