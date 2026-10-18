# Roshan Health Hub — Production Migration Rollback Plan (2026-10-18)

This is the reviewed rollback reference for the applied branch/finite guards and the subsequent monetary-precision candidates in:
- `db/roshan_insurance_prior_authorization_branch_isolation.sql`
- `db/roshan_post_expense_finite_amount.sql`
- `db/roshan_post_expense_money_precision.sql`
- `db/roshan_insurance_claim_money_precision.sql`
- `db/roshan_invoice_payment_money_precision.sql`
- `db/roshan_pharmacy_batch_money_precision.sql`

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

## 5. Invoice-payment precision rollback

Restores the exact live function body captured before `roshan_invoice_payment_money_precision`. It retains the existing finite/positive guard, branch enforcement, idempotency lock, and payment trigger behavior, but again permits amounts with more than two decimals that will be silently rounded by `payments.amount numeric(14,2)`. Use only for a confirmed regression.

```sql
CREATE OR REPLACE FUNCTION public.post_invoice_payment(_invoice_id uuid, _amount numeric, _method text DEFAULT 'cash'::text, _reference text DEFAULT NULL::text, _idempotency_key text DEFAULT NULL::text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE net numeric; already numeric; outstanding numeric; pay_id uuid; uid uuid; invoice_branch uuid; user_branch uuid; existing_actor uuid; existing_invoice_id uuid; existing_amount numeric; existing_method text; existing_reference text;
BEGIN
  IF NOT public.app_has_perm('payments.create') AND NOT public.app_has_perm('billing.create') AND NOT public.app_has_perm('accounting.create') THEN RAISE EXCEPTION 'not authorised to record payments' USING ERRCODE='42501'; END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity') OR _amount<=0 THEN RAISE EXCEPTION 'payment amount must be finite and greater than zero' USING ERRCODE='22023'; END IF;
  IF _invoice_id IS NULL THEN RAISE EXCEPTION 'invoice is required' USING ERRCODE='22023'; END IF;
  uid:=public.current_app_user_id();
  SELECT branch_id INTO user_branch FROM public.users WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND user_branch IS NULL THEN RAISE EXCEPTION 'user branch is not configured' USING ERRCODE='42501'; END IF;
  IF _idempotency_key IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('roshan.payment.idempotency:'||_idempotency_key,0));
    SELECT p.id,p.created_by,p.invoice_id,p.amount,COALESCE(p.payment_method,p.method,'cash'),NULLIF(BTRIM(COALESCE(p.reference_no,p.reference,'')),'')
      INTO pay_id,existing_actor,existing_invoice_id,existing_amount,existing_method,existing_reference FROM public.payments p WHERE p.idempotency_key=_idempotency_key;
    IF pay_id IS NOT NULL THEN
      IF existing_actor IS DISTINCT FROM uid OR existing_invoice_id IS DISTINCT FROM _invoice_id OR existing_amount IS DISTINCT FROM _amount OR existing_method IS DISTINCT FROM COALESCE(_method,'cash') OR existing_reference IS DISTINCT FROM NULLIF(BTRIM(COALESCE(_reference,'')),'') THEN RAISE EXCEPTION 'idempotency key reused with different payment request' USING ERRCODE='22023'; END IF;
      RETURN pay_id;
    END IF;
  END IF;
  SELECT COALESCE(i.net_amount,i.total_amount,0),COALESCE(i.paid_amount,0),i.branch_id INTO net,already,invoice_branch FROM public.invoices i WHERE i.id=_invoice_id AND i.deleted_at IS NULL FOR UPDATE;
  IF net IS NULL THEN RAISE EXCEPTION 'invoice not found' USING ERRCODE='22023'; END IF;
  IF NOT public.is_super_admin() AND invoice_branch IS DISTINCT FROM user_branch THEN RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE='42501'; END IF;
  outstanding:=GREATEST(net-already,0);
  IF _amount>outstanding THEN RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)',_amount,outstanding USING ERRCODE='22023'; END IF;
  INSERT INTO public.payments(invoice_id,amount,payment_method,method,reference_no,reference,payment_date,received_at,received_by,created_by,branch_id,idempotency_key)
  VALUES(_invoice_id,_amount,COALESCE(_method,'cash'),COALESCE(_method,'cash'),NULLIF(BTRIM(COALESCE(_reference,'')),''),NULLIF(BTRIM(COALESCE(_reference,'')),''),CURRENT_DATE,now(),uid,uid,invoice_branch,_idempotency_key) RETURNING id INTO pay_id;
  RETURN pay_id;
END; $function$;
```

## 6. Pharmacy batch precision rollback

Restores the live function body captured before `roshan_pharmacy_batch_money_precision`. This restores the old behavior that accepted fractional/non-finite purchase prices and an over-precision effective selling price; the inventory numeric(14,2) columns can silently round those values while the medicine master stores them at higher precision. Use only for a confirmed regression.

```sql
CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch(p_medicine_id uuid,p_quantity numeric,p_batch_number text DEFAULT NULL::text,p_expiry_date date DEFAULT NULL::date,p_manufacture_date date DEFAULT NULL::date,p_purchase_price numeric DEFAULT 0,p_selling_price numeric DEFAULT NULL::numeric,p_supplier_id uuid DEFAULT NULL::uuid,p_invoice_reference text DEFAULT NULL::text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_uid uuid:=public.current_app_user_id(); v_branch uuid; v_batch_id uuid; v_sell numeric;
BEGIN
 IF NOT public.app_has_perm('pharmacy.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE='42501'; END IF;
 IF p_quantity IS NULL OR p_quantity<>pg_catalog.trunc(p_quantity) OR p_quantity<=0 THEN RAISE EXCEPTION 'invalid_quantity'; END IF;
 IF p_purchase_price IS NULL OR p_purchase_price<0 THEN RAISE EXCEPTION 'invalid_purchase_price'; END IF;
 IF p_expiry_date IS NOT NULL AND p_manufacture_date IS NOT NULL AND p_manufacture_date>p_expiry_date THEN RAISE EXCEPTION 'manufacture_after_expiry'; END IF;
 SELECT u.branch_id INTO v_branch FROM public.users u WHERE u.id=v_uid AND u.deleted_at IS NULL;
 IF NOT public.is_super_admin() AND v_branch IS NULL THEN RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(p_selling_price,m.selling_price,0) INTO v_sell FROM public.medicines m WHERE m.id=p_medicine_id AND m.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'medicine_not_found'; END IF;
 INSERT INTO public.pharmacy_inventory(medicine_id,batch_number,batch_no,expiry_date,manufacture_date,quantity,quantity_received,quantity_remaining,purchase_price,selling_price,supplier_id,invoice_reference,branch_id,created_by,updated_by)
 VALUES(p_medicine_id,NULLIF(pg_catalog.btrim(p_batch_number),''),NULLIF(pg_catalog.btrim(p_batch_number),''),p_expiry_date,p_manufacture_date,p_quantity,p_quantity,p_quantity,p_purchase_price,v_sell,p_supplier_id,NULLIF(pg_catalog.btrim(p_invoice_reference),''),v_branch,v_uid,v_uid) RETURNING id INTO v_batch_id;
 UPDATE public.medicines SET stock_quantity=COALESCE(stock_quantity,0)+p_quantity::integer,cost_price=p_purchase_price,selling_price=v_sell,updated_at=pg_catalog.now(),updated_by=v_uid WHERE id=p_medicine_id;
 INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) VALUES(p_medicine_id,v_batch_id,'purchase',p_quantity,v_batch_id,'pharmacy_inventory',v_branch,v_uid);
 RETURN v_batch_id;
END; $function$;
```

**Preflight evidence:** `payments`, `pharmacy_inventory`, and `stock_movements` were empty; all existing non-deleted medicine master purchase/selling prices had at most two decimal places.

## Final applied-state update — 2026-10-18 (103-entry ledger)

The two final precision migrations are now applied and verified in `jewzonxplxhogqrnhosl`:
- `roshan_invoice_payment_money_precision` — `20261017231612`
- `roshan_pharmacy_batch_money_precision` — `20261017231629`

The ledger now contains 103 entries. Preflight/postflight confirmed zero payments, pharmacy inventory batches, stock movements, claims, claim payments, expenses, and prior authorizations; all current medicine master prices have at most two decimal places. No business rows were modified by these migrations.


## Pharmacy receipt idempotency migration — 2026-10-18

Applied production migration: `roshan_pharmacy_batch_receipt_idempotency`, ledger version `20261018061746`. It adds `pharmacy_inventory.idempotency_key`, a partial unique index, and the atomic RPC `fn_receive_pharmacy_batch_atomic(..., p_idempotency_key)`. The application PR was merged only after the live migration and its grants were read-back verified.

**Preferred response to a regression:** roll the application back to a build that does not call the new RPC, then repair forward. Do not remove the idempotency column/index as a routine rollback: once any receipt has been recorded with a key, deleting that history weakens retry safety. Preserve the additive column/index unless a deliberate, reviewed cleanup is required.

If a rollback is absolutely necessary, first verify the deployed app no longer calls this function and record the current ledger/data state. The narrow RPC rollback is:

```sql
DROP FUNCTION IF EXISTS public.fn_receive_pharmacy_batch_atomic(
  uuid, numeric, text, date, date, numeric, numeric, uuid, text, text
);
```

This intentionally leaves the `idempotency_key` column and its partial unique index in place. Do not drop them if any row has a non-null key. If a later cleanup is explicitly approved, first prove `SELECT count(*) FROM public.pharmacy_inventory WHERE idempotency_key IS NOT NULL` returns zero, verify no deployed client calls the RPC, and separately review the data-retention impact before dropping the index/column. Do not revert the existing `fn_receive_pharmacy_batch` implementation as part of this rollback.


## Pharmacy receipt guard migration — 2026-10-18

Applied migration: `roshan_pharmacy_batch_receipt_guards`, ledger version `20261018062939`. It replaces the existing atomic idempotent RPC with stricter eligibility, branch, date, and overflow checks; revokes authenticated execution of the legacy non-idempotent receive RPC; and removes direct authenticated INSERT permission/policy for `stock_movements`.

**Preferred recovery is a forward fix.** Keep the `idempotency_key` column/index, the direct stock-movement INSERT revocation, and the legacy-RPC revocation. Do not roll back to client-side ledger writes.

If a severe regression requires reverting only the new eligibility function body, reapply the reviewed `db/roshan_pharmacy_batch_receipt_idempotency.sql` function definition after verifying the current app still calls the atomic RPC. Do **not** restore `stock_movements` INSERT to `authenticated`, do not recreate `stock_movements_insert`, and do not re-grant `fn_receive_pharmacy_batch` to `authenticated`. This emergency fallback loses the newer medicine/supplier/date/branch/overflow guards, so it should be temporary and followed by a forward fix. Preserve idempotency history and do not drop the column/index.

The global super-admin branch fallback intentionally uses the sole active branch only. If multiple branches are active and a global super-admin has no assigned branch, the RPC fails closed; assign a branch or implement an explicit target-branch selection rather than weakening isolation.


## Invoice RPC-only write migration — 2026-10-18

Applied migration: `roshan_phase19_invoice_rpc_only_writes`, ledger version `20261018063549`. It revokes authenticated direct DML on invoice headers and lines, keeps the reviewed atomic billing/visit/lab RPCs available to `authenticated`, removes anonymous/public execution, and scopes invoice-line reads through the parent invoice's branch.

Pre/post counts were **0 rows in `invoices` and 0 in `invoice_items`**. The migration is privilege/policy-only and does not rewrite or delete invoice data.

**Preferred recovery is a forward fix.** If a wrapper RPC regression appears, repair the wrapper and test it in PostgreSQL 17; do not restore direct client INSERT/UPDATE/DELETE on either invoice table. If the SELECT policy itself must be reverted, restore the prior parent-invoice branch helper predicate while retaining the direct-DML revocations and RPC grants. Do not grant invoice-table DML to `authenticated` as a rollback shortcut.


## Clinical child-row branch-isolation migration — 2026-10-18

Applied migration: `roshan_phase20_clinical_child_branch_isolation`, ledger version `20261018064139`. It strengthens parent/child branch predicates and same-patient/visit linkage checks across prescriptions, prescription items, lab orders/items, medical certificates, patient discounts, and insurance prior authorizations. It also restricts execution of private branch helpers to the authenticated role required by RLS.

The affected tables had zero rows before and after application. The migration changes function/policy definitions only; it does not alter clinical or financial records.

**Preferred recovery is a forward fix.** Do not broadly revert branch policies to the older permission-only predicates. If a specific policy causes a regression, repair that policy in a forward migration and preserve the parent-branch and same-patient/visit checks. Before any emergency rollback, capture the current `pg_policies` definitions and helper function definitions; no blanket rollback script should be run against these interdependent policies.


## Clinical child RPC rollout — Phase 28 applied; Phase 29/30 split

Applied migration: `roshan_clinical_child_write_rpcs`, ledger version `20261018064638`. It creates `public.complete_lab_order_item(uuid)` and `public.create_medical_certificate(uuid,text,date,date)` with fixed empty `search_path`, permission checks, caller-derived author IDs, and parent-branch validation. Both functions are executable by `authenticated`, not by `anon` or `PUBLIC`. Direct table grants remain unchanged by Phase 28.

**Phase 29 — safe subset, ready for application:** revokes direct DML only on `prescriptions`, `prescription_items`, `patient_discounts`, and `insurance_prior_authorizations`. Current-main source search found no direct frontend write calls for these four tables; all have branch-aware RLS enabled and SELECT remains available. Rollback, if required, is to restore DML privileges only to `authenticated` (never `anon` or `PUBLIC`):

```sql
GRANT INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.prescriptions, public.prescription_items, public.patient_discounts, public.insurance_prior_authorizations
  TO authenticated;
```

**Phase 30 — deployment-gated:** revokes direct DML on `lab_order_items` and `medical_certificates` and removes client access to the certificate ID sequence. Do not apply Phase 30 until the production alias serves a READY deployment that contains the RPC call sites and smoke verification succeeds. If Phase 30 must be rolled back, first roll the app back to a build that uses direct writes, then restore only authenticated grants:

```sql
GRANT INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.lab_order_items, public.medical_certificates TO authenticated;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE public.medical_certificates_id_seq TO authenticated;
```

The Vercel API returned HTTP 402 `api-deployments-free-per-day` (100 deployments/day, remaining 0, reset 2026-10-19 08:52 Africa/Khartoum). No paid upgrade or preview-to-production alias workaround will be used because preview builds may contain preview environment variables. A one-time continuation task is scheduled for 2026-10-19 09:00 Africa/Khartoum; it must recheck quota, current main, production alias, and all checks before applying Phase 30.
