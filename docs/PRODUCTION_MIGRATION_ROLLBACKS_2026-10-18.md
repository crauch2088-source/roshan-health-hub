# Roshan Health Hub — Production Migration Rollback Plan (2026-10-18)

This is the reviewed rollback reference for the applied branch/finite guards and the subsequent monetary-precision candidates in:
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

## 3. Expense two-decimal precision rollback

This restores the already-tested finite-only — but not scale-–2 — function body from `db/roshan_post_expense_finite_amount.sql`. It keeps NULL/NaN/Infinity/non-positive rejection while permitting values with more than two decimals, so use only for a confirmed regression. The exact rollback SQL is the current source body in that file; it must be submitted with migration name `roshan_post_expense_money_precision` if a rollback is required.

## 4. Insurance approval/payment precision rollback

This restores the exact pre-change live function logic captured before migration `roshan_insurance_claim_money_precision`. `CREATE OR REPLACE` preserves the existing ACL and fixed empty search path. It restores the old behavior that could accept over-precision numeric values; use only for a confirmed regression.

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.update_insurance_claim_status(_claim_id uuid, _new_status text, _approved_amount numeric DEFAULT NULL::numeric, _notes text DEFAULT NULL::text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare claim public.insurance_claims; uid uuid;
begin
  if not public.app_has_perm('insurance.update') then raise exception 'not authorised to update insurance claims'; end if;
  select * into claim from public.insurance_claims where id=_claim_id and deleted_at is null for update;
  if claim.id is null then raise exception 'claim not found'; end if;
  if not public.is_super_admin() and not private.app_has_claim_branch(_claim_id) then raise exception 'cross-branch insurance claim access denied'; end if;
  if (claim.status,_new_status) not in (('draft','submitted'),('submitted','under_review'),('under_review','approved'),('under_review','partially_approved'),('under_review','rejected'),('approved','paid'),('partially_approved','paid')) then raise exception 'invalid claim status transition: % -> %',claim.status,_new_status; end if;
  if _new_status in ('approved','partially_approved') and _approved_amount is null then raise exception 'approved_amount is required when approving a claim'; end if;
  if _new_status in ('approved','partially_approved') and (_approved_amount < 0 or _approved_amount > claim.submitted_amount) then raise exception 'approved amount must be between zero and submitted amount'; end if;
  uid:=public.current_app_user_id();
  update public.insurance_claims set status=_new_status,approved_amount=case when _new_status in ('approved','partially_approved') then _approved_amount else approved_amount end,submitted_at=case when _new_status='submitted' then now() else submitted_at end,decided_at=case when _new_status in ('approved','partially_approved','rejected') then now() else decided_at end,notes=coalesce(_notes,notes),updated_by=uid,updated_at=now() where id=_claim_id;
end; $function$;

CREATE OR REPLACE FUNCTION public.post_insurance_claim_payment(_claim_id uuid, _amount numeric, _method text DEFAULT 'bank'::text, _reference text DEFAULT NULL::text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare claim public.insurance_claims; pay_id uuid; uid uuid; outstanding numeric; new_paid numeric; claim_branch uuid;
begin
  if not public.app_has_perm('insurance.update') then raise exception 'not authorised to record insurance payments'; end if;
  if _amount is null or _amount<=0 then raise exception 'amount must be greater than zero'; end if;
  select c.*, i.branch_id into claim from public.insurance_claims c join public.invoices i on i.id=c.invoice_id where c.id=_claim_id and c.deleted_at is null for update;
  if claim.id is null then raise exception 'claim not found'; end if;
  select i.branch_id into claim_branch from public.invoices i where i.id=claim.invoice_id;
  if not public.is_super_admin() and not private.app_has_claim_branch(_claim_id) then raise exception 'cross-branch insurance claim access denied'; end if;
  if claim.status not in ('approved','partially_approved','paid') then raise exception 'claim must be approved before recording a payment (current status: %)',claim.status; end if;
  outstanding:=greatest(coalesce(claim.approved_amount,0)-coalesce(claim.paid_amount,0),0);
  if _amount>outstanding then raise exception 'payment (%) exceeds outstanding approved balance (%)',_amount,outstanding; end if;
  uid:=public.current_app_user_id();
  insert into public.insurance_claim_payments(claim_id,amount,payment_method,reference,created_by) values(_claim_id,_amount,coalesce(_method,'bank'),_reference,uid) returning id into pay_id;
  select coalesce(sum(amount),0) into new_paid from public.insurance_claim_payments where claim_id=_claim_id and deleted_at is null;
  update public.insurance_claims set paid_amount=new_paid,status=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then 'paid' else status end,paid_at=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then now() else paid_at end,updated_by=uid,updated_at=now() where id=_claim_id;
  perform public.fn_ledger_post('income',abs(_amount),coalesce(_method,'bank'),'insurance_settlement','Insurance claim payment — '||claim.claim_number,'insurance_claim_payment',pay_id,now(),claim_branch);
  return pay_id;
end; $function$;

COMMIT;
```

**Pre-change production evidence:** at capture time there were zero non-deleted insurance claims and zero insurance-payment-vs-cashbox amount mismatches. No historical rows need repair based on this read-only check.

## Applied-state ledger note — 2026-10-18

The four reviewed forward migrations are now applied and read back from Supabase project `jewzonxplxhogqrnhosl`:
- `roshan_insurance_prior_authorization_branch_isolation` — `20261017225523`
- `roshan_post_expense_finite_amount` — `20261017225540`
- `roshan_post_expense_money_precision` — `20261017230623`
- `roshan_insurance_claim_money_precision` — `20261017230645`

The live ledger is at 101 entries. The precision migration rollbacks restore the previous finite-only expense guard and the captured prior insurance approval/payment function bodies, respectively. Preflight and postflight found zero claims, payments, expenses, or prior authorizations, and zero existing claim-payment/cashbox mismatches.
