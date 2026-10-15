-- Widen the public-settings allowlist to include the new pharmacy expiry
-- threshold, same rationale as tax_percent/currency: UI configuration,
-- not a secret, and needs to be readable by pharmacy roles who don't
-- necessarily hold settings.read.
create or replace function public.enforce_public_system_setting_keys()
returns trigger
language plpgsql
as $function$
begin
  if new.is_public is null then
    new.is_public := false;
  end if;

  if new.is_public = true
     and new.setting_key not in (
       'center_name',
       'center_name_ar',
       'currency',
       'phone',
       'address',
       'invoice_footer',
       'receipt_footer',
       'tax_percent',
       'pharmacy_expiry_threshold_days'
     ) then
    raise exception 'Security violation: Setting key "%" is not allowed to be public.', new.setting_key
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

insert into public.system_settings (setting_key, setting_value, description, is_public)
values (
  'pharmacy_expiry_threshold_days',
  '90',
  'Days before expiry a batch is flagged "Expiring soon" on pharmacy screens and dashboards.',
  true
)
on conflict (setting_key) do nothing;
