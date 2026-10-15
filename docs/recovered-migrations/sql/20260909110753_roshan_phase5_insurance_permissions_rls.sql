begin;

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
