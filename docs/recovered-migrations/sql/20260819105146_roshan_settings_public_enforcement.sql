create or replace function public.enforce_public_system_setting_keys()
returns trigger
language plpgsql
as $$
begin
  -- Keep the safe default even if a caller explicitly supplies NULL.
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
       'tax_percent'
     ) then
    raise exception 'Security violation: Setting key "%" is not allowed to be public.', new.setting_key
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists tr_enforce_public_system_setting_keys on public.system_settings;

create trigger tr_enforce_public_system_setting_keys
before insert or update on public.system_settings
for each row
execute function public.enforce_public_system_setting_keys();
