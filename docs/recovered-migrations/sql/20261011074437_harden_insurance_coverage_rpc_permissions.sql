
create or replace function public.fn_calculate_insurance_coverage(
  _patient_insurance_id uuid,
  _service_type text,
  _reference_id uuid,
  _generic_name text,
  _gross_amount numeric
)
returns table(
  covered_amount numeric,
  patient_amount numeric,
  requires_prior_auth boolean,
  excluded boolean,
  coverage_rule_id uuid
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  pi public.patient_insurance;
  plan public.insurance_plans;
  rule public.insurance_coverage_rules;
  covered numeric := 0;
  auth_needed boolean := false;
  is_excluded boolean := false;
  rule_id uuid := null;
  patient_branch uuid;
  user_branch uuid;
begin
  if not private.app_has_perm('insurance.read') then
    raise exception 'Permission denied' using errcode = '42501';
  end if;

  select * into pi
  from public.patient_insurance
  where id = _patient_insurance_id and deleted_at is null;

  if pi.id is null then
    covered_amount := 0;
    patient_amount := coalesce(_gross_amount, 0);
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := null;
    return next;
    return;
  end if;

  if not private.is_super_admin() then
    select branch_id into patient_branch
    from public.patients
    where id = pi.patient_id and deleted_at is null;

    select branch_id into user_branch
    from public.users
    where auth_user_id = auth.uid() and coalesce(active, true) = true
    limit 1;

    if patient_branch is null or user_branch is null or patient_branch is distinct from user_branch then
      raise exception 'cross-branch insurance coverage access denied' using errcode = '42501';
    end if;
  end if;

  if pi.status <> 'active' or (pi.expiry_date is not null and pi.expiry_date < current_date) then
    covered_amount := 0;
    patient_amount := coalesce(_gross_amount, 0);
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := null;
    return next;
    return;
  end if;

  select * into plan
  from public.insurance_plans
  where id = pi.plan_id and deleted_at is null;

  select * into rule
  from public.insurance_coverage_rules
  where plan_id = pi.plan_id
    and service_type = _service_type
    and reference_id = _reference_id
    and deleted_at is null
  limit 1;

  if rule.id is null and _service_type = 'medicine' and _generic_name is not null then
    select * into rule
    from public.insurance_coverage_rules
    where plan_id = pi.plan_id
      and service_type = 'medicine'
      and generic_name is not null
      and lower(generic_name) = lower(_generic_name)
      and reference_id is null
      and deleted_at is null
    limit 1;
  end if;

  if rule.id is null then
    select * into rule
    from public.insurance_coverage_rules
    where plan_id = pi.plan_id
      and service_type = _service_type
      and reference_id is null
      and generic_name is null
      and deleted_at is null
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

  covered := least(greatest(covered, 0), coalesce(_gross_amount, 0));
  covered_amount := covered;
  patient_amount := greatest(coalesce(_gross_amount, 0) - covered, 0);
  requires_prior_auth := auth_needed;
  excluded := is_excluded;
  coverage_rule_id := rule_id;
  return next;
end;
$function$;
