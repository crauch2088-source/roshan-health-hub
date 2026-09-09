-- =====================================================================
-- ROSHAN — Phase 5: Insurance foundation
--
-- Already applied to the live project (jewzonxplxhogqrnhosl) this
-- session, in three steps. Combined here into one file for the repo
-- record. Fully additive, re-runnable (every statement is IF NOT
-- EXISTS / OR REPLACE / ON CONFLICT DO NOTHING / guarded by NOT
-- EXISTS), no existing table/column touched, no legacy data rewritten.
--
-- Reuses Phase 4's fn_ledger_post() for the cashbox side of claim
-- settlements instead of duplicating ledger-posting logic.
-- =====================================================================

begin;

do $$
begin
  if to_regprocedure('public.app_has_perm(text)') is null then
    raise exception 'app_has_perm missing — run earlier migrations first';
  end if;
  if to_regprocedure('public.fn_ledger_post(text,numeric,text,text,text,text,uuid,timestamptz,uuid)') is null then
    raise exception 'fn_ledger_post missing — Phase 4 finance must be applied first';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table if not exists public.insurance_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  active boolean not null default true,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz, deleted_by uuid
);

create table if not exists public.insurance_plans (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.insurance_companies(id),
  name text not null,
  default_coverage_percent numeric(5,2) not null default 0 check (default_coverage_percent between 0 and 100),
  requires_prior_auth boolean not null default false,
  notes text,
  active boolean not null default true,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz, deleted_by uuid
);

create table if not exists public.patient_insurance (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id),
  company_id uuid not null references public.insurance_companies(id),
  plan_id uuid not null references public.insurance_plans(id),
  policy_number text,
  member_number text,
  is_primary boolean not null default true,
  start_date date not null default current_date,
  expiry_date date,
  status text not null default 'active' check (status in ('active','expired','suspended')),
  notes text,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz, deleted_by uuid
);

-- Coverage is matched by GENERIC NAME for medicines (a rule with
-- reference_id/generic_name null is the plan's default for a whole
-- service_type; a more specific row overrides it — see
-- fn_calculate_insurance_coverage below for exact precedence).
create table if not exists public.insurance_coverage_rules (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.insurance_plans(id),
  service_type text not null check (service_type in ('consultation','lab','medicine')),
  reference_id uuid,
  generic_name text,
  coverage_percent numeric(5,2) check (coverage_percent between 0 and 100),
  fixed_amount numeric(14,2),
  requires_prior_auth boolean not null default false,
  excluded boolean not null default false,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint insurance_coverage_rules_amount_ck check (
    excluded = true or coverage_percent is not null or fixed_amount is not null
  )
);

create table if not exists public.insurance_prior_authorizations (
  id uuid primary key default gen_random_uuid(),
  patient_insurance_id uuid not null references public.patient_insurance(id),
  service_type text not null check (service_type in ('consultation','lab','medicine')),
  reference_id uuid,
  description text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','expired')),
  reference_number text,
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  notes text,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create sequence if not exists public.insurance_claim_number_seq;

create table if not exists public.insurance_claims (
  id uuid primary key default gen_random_uuid(),
  claim_number text not null default ('CLM-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.insurance_claim_number_seq')::text, 6, '0')),
  patient_insurance_id uuid not null references public.patient_insurance(id),
  invoice_id uuid references public.invoices(id),
  status text not null default 'draft'
    check (status in ('draft','submitted','under_review','approved','partially_approved','rejected','paid')),
  submitted_amount numeric(14,2) not null default 0,
  approved_amount numeric(14,2),
  paid_amount numeric(14,2) not null default 0,
  submitted_at timestamptz,
  decided_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (claim_number)
);

create table if not exists public.insurance_claim_items (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.insurance_claims(id),
  service_type text not null check (service_type in ('consultation','lab','medicine')),
  reference_id uuid,
  description text not null,
  gross_amount numeric(14,2) not null default 0,
  covered_amount numeric(14,2) not null default 0,
  patient_amount numeric(14,2) not null default 0,
  coverage_rule_id uuid references public.insurance_coverage_rules(id),
  created_at timestamptz not null default now()
);

create table if not exists public.insurance_claim_payments (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.insurance_claims(id),
  amount numeric(14,2) not null,
  payment_method text not null default 'bank',
  reference text,
  received_at timestamptz not null default now(),
  created_by uuid,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists ix_ins_plans_company on public.insurance_plans (company_id);
create index if not exists ix_patient_insurance_patient on public.patient_insurance (patient_id);
create index if not exists ix_patient_insurance_status on public.patient_insurance (status);
create index if not exists ix_coverage_rules_plan on public.insurance_coverage_rules (plan_id, service_type);
create index if not exists ix_coverage_rules_generic on public.insurance_coverage_rules (generic_name) where generic_name is not null;
create index if not exists ix_claims_patient_insurance on public.insurance_claims (patient_insurance_id);
create index if not exists ix_claims_status on public.insurance_claims (status);
create index if not exists ix_claim_items_claim on public.insurance_claim_items (claim_id);
create index if not exists ix_claim_payments_claim on public.insurance_claim_payments (claim_id);
create unique index if not exists uq_claim_payment_source on public.cashbox_transactions (source_type, source_id) where source_type = 'insurance_claim_payment';

-- ---------------------------------------------------------------------
-- Functions — coverage calculation, claim creation, status transitions,
-- and atomic claim-payment reconciliation into the Phase 4 ledger.
-- ---------------------------------------------------------------------

create or replace function public.fn_calculate_insurance_coverage(
  _patient_insurance_id uuid, _service_type text, _reference_id uuid,
  _generic_name text, _gross_amount numeric
) returns table (
  covered_amount numeric, patient_amount numeric, requires_prior_auth boolean,
  excluded boolean, coverage_rule_id uuid
)
language plpgsql stable security definer set search_path = public as $$
declare
  pi public.patient_insurance; plan public.insurance_plans; rule public.insurance_coverage_rules;
  covered numeric := 0; auth_needed boolean := false; is_excluded boolean := false; rule_id uuid := null;
begin
  select * into pi from public.patient_insurance where id = _patient_insurance_id and deleted_at is null;
  if pi.id is null or pi.status <> 'active' or (pi.expiry_date is not null and pi.expiry_date < current_date) then
    covered_amount := 0; patient_amount := coalesce(_gross_amount, 0);
    requires_prior_auth := false; excluded := false; coverage_rule_id := null;
    return next; return;
  end if;

  select * into plan from public.insurance_plans where id = pi.plan_id and deleted_at is null;

  select * into rule from public.insurance_coverage_rules
   where plan_id = pi.plan_id and service_type = _service_type
     and reference_id = _reference_id and deleted_at is null limit 1;

  if rule.id is null and _service_type = 'medicine' and _generic_name is not null then
    select * into rule from public.insurance_coverage_rules
     where plan_id = pi.plan_id and service_type = 'medicine'
       and generic_name is not null and lower(generic_name) = lower(_generic_name)
       and reference_id is null and deleted_at is null limit 1;
  end if;

  if rule.id is null then
    select * into rule from public.insurance_coverage_rules
     where plan_id = pi.plan_id and service_type = _service_type
       and reference_id is null and generic_name is null and deleted_at is null limit 1;
  end if;

  if rule.id is not null then
    rule_id := rule.id; auth_needed := rule.requires_prior_auth;
    if rule.excluded then
      is_excluded := true; covered := 0;
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
  covered_amount := covered; patient_amount := coalesce(_gross_amount, 0) - covered;
  requires_prior_auth := auth_needed; excluded := is_excluded; coverage_rule_id := rule_id;
  return next;
end $$;

create or replace function public.create_insurance_claim(
  _patient_insurance_id uuid, _invoice_id uuid, _items jsonb, _notes text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare claim_id uuid; uid uuid; total numeric := 0; item jsonb;
begin
  if not public.app_has_perm('insurance.create') then
    raise exception 'not authorised to create insurance claims';
  end if;
  if _items is null or jsonb_array_length(_items) = 0 then
    raise exception 'a claim needs at least one item';
  end if;

  uid := public.current_app_user_id();
  select coalesce(sum((i->>'gross_amount')::numeric), 0) into total from jsonb_array_elements(_items) i;

  insert into public.insurance_claims (patient_insurance_id, invoice_id, status, submitted_amount, notes, created_by)
  values (_patient_insurance_id, _invoice_id, 'draft', total, _notes, uid)
  returning id into claim_id;

  for item in select * from jsonb_array_elements(_items) loop
    insert into public.insurance_claim_items (
      claim_id, service_type, reference_id, description, gross_amount, covered_amount, patient_amount, coverage_rule_id
    ) values (
      claim_id, item->>'service_type', nullif(item->>'reference_id', '')::uuid,
      coalesce(item->>'description', ''), coalesce((item->>'gross_amount')::numeric, 0),
      coalesce((item->>'covered_amount')::numeric, 0), coalesce((item->>'patient_amount')::numeric, 0),
      nullif(item->>'coverage_rule_id', '')::uuid
    );
  end loop;

  return claim_id;
end $$;

create or replace function public.update_insurance_claim_status(
  _claim_id uuid, _new_status text, _approved_amount numeric default null, _notes text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare claim public.insurance_claims; uid uuid; allowed boolean := false;
begin
  if not public.app_has_perm('insurance.update') then
    raise exception 'not authorised to update insurance claims';
  end if;

  select * into claim from public.insurance_claims where id = _claim_id and deleted_at is null for update;
  if claim.id is null then
    raise exception 'claim not found';
  end if;

  allowed := (claim.status, _new_status) in (
    ('draft','submitted'), ('submitted','under_review'),
    ('under_review','approved'), ('under_review','partially_approved'), ('under_review','rejected'),
    ('approved','paid'), ('partially_approved','paid')
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
         notes = coalesce(_notes, notes), updated_by = uid, updated_at = now()
   where id = _claim_id;
end $$;

create or replace function public.post_insurance_claim_payment(
  _claim_id uuid, _amount numeric, _method text default 'bank', _reference text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare claim public.insurance_claims; pay_id uuid; uid uuid; outstanding numeric; new_paid numeric;
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
  from public.insurance_claim_payments where claim_id = _claim_id and deleted_at is null;

  update public.insurance_claims
     set paid_amount = new_paid,
         status = case when new_paid >= coalesce(approved_amount, 0) and approved_amount is not null then 'paid' else status end,
         paid_at = case when new_paid >= coalesce(approved_amount, 0) and approved_amount is not null then now() else paid_at end,
         updated_by = uid, updated_at = now()
   where id = _claim_id;

  perform public.fn_ledger_post(
    'income', abs(_amount), coalesce(_method, 'bank'), 'insurance_settlement',
    'Insurance claim payment — ' || claim.claim_number, 'insurance_claim_payment', pay_id, now(), null
  );

  return pay_id;
end $$;

-- ---------------------------------------------------------------------
-- Permissions, grants, RLS, audit
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, module, action)
values
  ('insurance.read',   'View insurance',   'insurance', 'read'),
  ('insurance.create', 'Create insurance records', 'insurance', 'create'),
  ('insurance.update', 'Update insurance records', 'insurance', 'update')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p
where r.code in ('super_admin','admin')
  and p.code in ('insurance.read','insurance.create','insurance.update')
  and not exists (select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_id=p.id);

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p
where r.code = 'receptionist'
  and p.code in ('insurance.read','insurance.create')
  and not exists (select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_id=p.id);

grant select, insert, update on public.insurance_companies to authenticated;
grant select, insert, update on public.insurance_plans to authenticated;
grant select, insert, update on public.patient_insurance to authenticated;
grant select, insert, update on public.insurance_coverage_rules to authenticated;
grant select, insert, update on public.insurance_prior_authorizations to authenticated;
grant select, insert, update on public.insurance_claims to authenticated;
grant select, insert on public.insurance_claim_items to authenticated;
grant select, insert on public.insurance_claim_payments to authenticated;
grant usage on sequence public.insurance_claim_number_seq to authenticated;

grant all on public.insurance_companies, public.insurance_plans, public.patient_insurance,
  public.insurance_coverage_rules, public.insurance_prior_authorizations, public.insurance_claims,
  public.insurance_claim_items, public.insurance_claim_payments to service_role;

grant execute on function public.fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric) to authenticated;
grant execute on function public.create_insurance_claim(uuid,uuid,jsonb,text) to authenticated;
grant execute on function public.update_insurance_claim_status(uuid,text,numeric,text) to authenticated;
grant execute on function public.post_insurance_claim_payment(uuid,numeric,text,text) to authenticated;

alter table public.insurance_companies enable row level security;
alter table public.insurance_plans enable row level security;
alter table public.patient_insurance enable row level security;
alter table public.insurance_coverage_rules enable row level security;
alter table public.insurance_prior_authorizations enable row level security;
alter table public.insurance_claims enable row level security;
alter table public.insurance_claim_items enable row level security;
alter table public.insurance_claim_payments enable row level security;

do $$
declare tbl text;
begin
  foreach tbl in array array[
    'insurance_companies','insurance_plans','patient_insurance',
    'insurance_coverage_rules','insurance_prior_authorizations','insurance_claims'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', tbl || '_sel', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_ins', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_upd', tbl);
    execute format('create policy %I on public.%I for select to authenticated using (public.app_has_perm(%L))', tbl || '_sel', tbl, 'insurance.read');
    execute format('create policy %I on public.%I for insert to authenticated with check (public.app_has_perm(%L))', tbl || '_ins', tbl, 'insurance.create');
    execute format('create policy %I on public.%I for update to authenticated using (public.app_has_perm(%L)) with check (public.app_has_perm(%L))', tbl || '_upd', tbl, 'insurance.update', 'insurance.update');
  end loop;

  foreach tbl in array array['insurance_claim_items','insurance_claim_payments']
  loop
    execute format('drop policy if exists %I on public.%I', tbl || '_sel', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_ins', tbl);
    execute format('create policy %I on public.%I for select to authenticated using (public.app_has_perm(%L))', tbl || '_sel', tbl, 'insurance.read');
    execute format('create policy %I on public.%I for insert to authenticated with check (public.app_has_perm(%L))', tbl || '_ins', tbl, 'insurance.create');
  end loop;
end $$;

do $$
declare tbl text;
begin
  foreach tbl in array array['insurance_companies','insurance_plans','patient_insurance','insurance_claims']
  loop
    execute format('drop trigger if exists trg_finance_audit on public.%I', tbl);
    execute format('create trigger trg_finance_audit after insert or update or delete on public.%I for each row execute function public.fn_finance_audit()', tbl);
  end loop;
end $$;

commit;
