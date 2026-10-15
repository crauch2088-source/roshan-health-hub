create or replace function public.next_mrn()
returns text
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare next_no bigint;
begin
  perform pg_advisory_xact_lock(hashtext('roshan:mrn'));
  select coalesce(max(nullif(regexp_replace(mrn,'[^0-9]','','g'),'')::bigint),0) + 1
    into next_no
  from public.patients
  where mrn ~ '^RMC[0-9]+$';
  return 'RMC' || lpad(next_no::text, 6, '0');
end;
$$;

create or replace function public.next_invoice_number()
returns text
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  month_key text := to_char(now(),'YYYYMM');
  next_no bigint;
begin
  perform pg_advisory_xact_lock(hashtext('roshan:invoice:' || month_key));
  select coalesce(max((regexp_match(invoice_number, '^INV-[0-9]{6}-([0-9]+)$'))[1]::bigint),0) + 1
    into next_no
  from public.invoices
  where invoice_number like 'INV-' || month_key || '-%';
  return 'INV-' || month_key || '-' || lpad(next_no::text, 5, '0');
end;
$$;
