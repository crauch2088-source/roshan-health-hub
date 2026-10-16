-- =====================================================================
-- ROSHAN — Phase 5: Insurance foundation
-- Additive, re-runnable, non-destructive. No existing table touched
-- except granting 3 new permission codes to existing roles.
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

-- One coverage rule per plan + service_type (+ optional specific item /
-- generic name). A row with reference_id/generic_name null is the plan's
-- default for that whole service type (e.g. "70% of all lab tests");
-- a row with a specific reference_id or generic_name overrides it.
-- Medicine coverage is matched by GENERIC NAME on purpose, per the brief
-- ("Amoxicillin 500mg and brand X recognized as the same coverage group")
-- — reference_id on a medicine row is an extra, more specific override,
-- not the primary matching key.
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

commit;
