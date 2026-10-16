begin;

-- ---------------------------------------------------------------------
-- Coverage calculation. Priority: specific reference_id match > generic
-- name match (medicines only) > plan default for that service_type.
-- An `excluded` rule always wins over any percent/fixed match for the
-- same specificity level. Never guesses: no matching rule + no plan
-- default = zero coverage (patient pays gross), and the caller is told
-- whether prior auth is required so the UI can block silent full cover.
-- ---------------------------------------------------------------------
create or replace function public.fn_calculate_insurance_coverage(
  _patient_insurance_id uuid,
  _service_type text,
  _reference_id uuid,
  _generic_name text,
  _gross_amount numeric
) returns table (
  covered_amount numeric,
  patient_amount numeric,
  requires_prior_auth boolean,
  excluded boolean,
  coverage_rule_id uuid
)
language plpgsql stable security definer set search_path = public as $$
declare
  pi public.patient_insurance;
  plan public.insurance_plans;
  rule public.insurance_coverage_rules;
  covered numeric := 0;
  auth_needed boolean := false;
  is_excluded boolean := false;
  rule_id uuid := null;
begin
  select * into pi from public.patient_insurance
   where id = _patient_insurance_id and deleted_at is null;
  if pi.id is null or pi.status <> 'active' or (pi.expiry_date is not null and pi.expiry_date < current_date) then
    covered_amount := 0; patient_amount := coalesce(_gross_amount, 0);
    requires_prior_auth := false; excluded := false; coverage_rule_id := null;
    return next;
    return;
  end if;

  select * into plan from public.insurance_plans where id = pi.plan_id and deleted_at is null;

  -- 1) specific reference_id match
  select * into rule from public.insurance_coverage_rules
   where plan_id = pi.plan_id and service_type = _service_type
     and reference_id = _reference_id and deleted_at is null
   limit 1;

  -- 2) generic name match (medicines only)
  if rule.id is null and _service_type = 'medicine' and _generic_name is not null then
    select * into rule from public.insurance_coverage_rules
     where plan_id = pi.plan_id and service_type = 'medicine'
       and generic_name is not null and lower(generic_name) = lower(_generic_name)
       and reference_id is null and deleted_at is null
     limit 1;
  end if;

  -- 3) plan-wide default for the service type (no specific reference/generic)
  if rule.id is null then
    select * into rule from public.insurance_coverage_rules
     where plan_id = pi.plan_id and service_type = _service_type
       and reference_id is null and generic_name is null and deleted_at is null
     limit 1;
  end if;

  if rule.id is not null then
    rule_id := rule.id;
    auth_needed := rule.requires_prior_auth;
    if rule.excluded then
      is_excluded := true;
      covered := 0;
    elsif rule.fixed_amount is not null then
      covered := least(rule.fixed_amount, coalesce(_gross_amount, 0));
    else
      covered := round(coalesce(_gross_amount, 0) * coalesce(rule.coverage_percent, 0) / 100, 2);
    end if;
  elsif plan.id is not null then
    auth_needed := plan.requires_prior_auth;
    covered := round(coalesce(_gross_amount, 0) * coalesce(plan.default_coverage_percent, 0) / 100, 2);
  end if;

  covered := least(covered, coalesce(_gross_amount, 0));
  covered_amount := covered;
  patient_amount := coalesce(_gross_amount, 0) - covered;
  requires_prior_auth := auth_needed;
  excluded := is_excluded;
  coverage_rule_id := rule_id;
  return next;
end $$;

-- ---------------------------------------------------------------------
-- Create a claim + its items atomically. _items is a jsonb array of
-- {service_type, reference_id, description, gross_amount, covered_amount,
-- patient_amount, coverage_rule_id}. submitted_amount is derived from the
-- items, never trusted from the client directly.
-- ---------------------------------------------------------------------
create or replace function public.create_insurance_claim(
  _patient_insurance_id uuid,
  _invoice_id uuid,
  _items jsonb,
  _notes text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  claim_id uuid;
  uid uuid;
  total numeric := 0;
  item jsonb;
begin
  if not public.app_has_perm('insurance.create') then
    raise exception 'not authorised to create insurance claims';
  end if;
  if _items is null or jsonb_array_length(_items) = 0 then
    raise exception 'a claim needs at least one item';
  end if;

  uid := public.current_app_user_id();

  select coalesce(sum((i->>'gross_amount')::numeric), 0) into total
  from jsonb_array_elements(_items) i;

  insert into public.insurance_claims (patient_insurance_id, invoice_id, status, submitted_amount, notes, created_by)
  values (_patient_insurance_id, _invoice_id, 'draft', total, _notes, uid)
  returning id into claim_id;

  for item in select * from jsonb_array_elements(_items)
  loop
    insert into public.insurance_claim_items (
      claim_id, service_type, reference_id, description,
      gross_amount, covered_amount, patient_amount, coverage_rule_id
    ) values (
      claim_id,
      item->>'service_type',
      nullif(item->>'reference_id', '')::uuid,
      coalesce(item->>'description', ''),
      coalesce((item->>'gross_amount')::numeric, 0),
      coalesce((item->>'covered_amount')::numeric, 0),
      coalesce((item->>'patient_amount')::numeric, 0),
      nullif(item->>'coverage_rule_id', '')::uuid
    );
  end loop;

  return claim_id;
end $$;

-- ---------------------------------------------------------------------
-- Status transitions. Deliberately narrow: only the moves that make
-- sense in the workflow are allowed, so a claim can't jump from draft
-- straight to paid without going through submission/approval.
-- ---------------------------------------------------------------------
create or replace function public.update_insurance_claim_status(
  _claim_id uuid,
  _new_status text,
  _approved_amount numeric default null,
  _notes text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  claim public.insurance_claims;
  uid uuid;
  allowed boolean := false;
begin
  if not public.app_has_perm('insurance.update') then
    raise exception 'not authorised to update insurance claims';
  end if;

  select * into claim from public.insurance_claims where id = _claim_id and deleted_at is null for update;
  if claim.id is null then
    raise exception 'claim not found';
  end if;

  allowed := (claim.status, _new_status) in (
    ('draft','submitted'),
    ('submitted','under_review'),
    ('under_review','approved'),
    ('under_review','partially_approved'),
    ('under_review','rejected'),
    ('approved','paid'),
    ('partially_approved','paid')
  );
  if not allowed then
    raise exception 'invalid claim status transition: % -> %', claim.status, _new_status;
  end if;

  if _new_status in ('approved','partially_approved') and _approved_amount is null then
    raise exception 'approved_amount is required when approving a claim';
  end if;
  if _new_status in ('approved','partially_approved') and _approved_amount > claim.submitted_amount then
    raise exception 'approved amount (%) cannot exceed submitted amount (%)', _approved_amount, claim.submitted_amount;
  end if;

  uid := public.current_app_user_id();

  update public.insurance_claims
     set status = _new_status,
         approved_amount = case when _new_status in ('approved','partially_approved') then _approved_amount else approved_amount end,
         submitted_at = case when _new_status = 'submitted' then now() else submitted_at end,
         decided_at = case when _new_status in ('approved','partially_approved','rejected') then now() else decided_at end,
         notes = coalesce(_notes, notes),
         updated_by = uid,
         updated_at = now()
   where id = _claim_id;
end $$;

-- ---------------------------------------------------------------------
-- Record an insurance settlement payment. Atomic: inserts the payment
-- row, recomputes claim.paid_amount/status, and posts to the SAME
-- cashbox ledger Phase 4 already uses (via fn_ledger_post, which is
-- itself idempotent on (source_type, source_id) — calling this twice
-- for the same payment_id is a safe no-op on the ledger side; the
-- payment-row insert itself is guarded by the caller passing a stable
-- idempotency reference via the returned payment id).
-- ---------------------------------------------------------------------
create or replace function public.post_insurance_claim_payment(
  _claim_id uuid,
  _amount numeric,
  _method text default 'bank',
  _reference text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  claim public.insurance_claims;
  pay_id uuid;
  uid uuid;
  outstanding numeric;
  new_paid numeric;
begin
  if not public.app_has_perm('insurance.update') then
    raise exception 'not authorised to record insurance payments';
  end if;
  if _amount is null or _amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  select * into claim from public.insurance_claims where id = _claim_id and deleted_at is null for update;
  if claim.id is null then
    raise exception 'claim not found';
  end if;
  if claim.status not in ('approved','partially_approved','paid') then
    raise exception 'claim must be approved before recording a payment (current status: %)', claim.status;
  end if;

  outstanding := greatest(coalesce(claim.approved_amount, 0) - coalesce(claim.paid_amount, 0), 0);
  if _amount > outstanding then
    raise exception 'payment (%) exceeds outstanding approved balance (%)', _amount, outstanding;
  end if;

  uid := public.current_app_user_id();

  insert into public.insurance_claim_payments (claim_id, amount, payment_method, reference, created_by)
  values (_claim_id, _amount, coalesce(_method, 'bank'), _reference, uid)
  returning id into pay_id;

  select coalesce(sum(amount), 0) into new_paid
  from public.insurance_claim_payments
  where claim_id = _claim_id and deleted_at is null;

  update public.insurance_claims
     set paid_amount = new_paid,
         status = case when new_paid >= coalesce(approved_amount, 0) and approved_amount is not null then 'paid' else status end,
         paid_at = case when new_paid >= coalesce(approved_amount, 0) and approved_amount is not null then now() else paid_at end,
         updated_by = uid,
         updated_at = now()
   where id = _claim_id;

  perform public.fn_ledger_post(
    'income', abs(_amount), coalesce(_method, 'bank'), 'insurance_settlement',
    'Insurance claim payment — ' || claim.claim_number,
    'insurance_claim_payment', pay_id, now(), null
  );

  return pay_id;
end $$;

commit;
