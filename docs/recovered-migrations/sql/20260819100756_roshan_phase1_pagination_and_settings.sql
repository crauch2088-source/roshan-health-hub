alter table public.system_settings add column if not exists is_public boolean not null default false;

update public.system_settings
set is_public = true
where setting_key in (
  'center_name','center_name_ar','currency','phone','address','invoice_footer','receipt_footer','tax_percent'
);

drop policy if exists system_settings_sel on public.system_settings;
create policy system_settings_sel
on public.system_settings
for select
to authenticated
using (
  is_public = true
  or public.app_has_perm('settings.read')
);

create index if not exists patients_created_at_idx
  on public.patients (created_at desc)
  where deleted_at is null;

create extension if not exists pg_trgm;

create index if not exists patients_full_name_trgm_idx
  on public.patients using gin (full_name gin_trgm_ops);

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);

create index if not exists patients_mrn_idx
  on public.patients (mrn);
create index if not exists patients_phone_idx
  on public.patients (phone);
create index if not exists patients_national_id_idx
  on public.patients (national_id);
