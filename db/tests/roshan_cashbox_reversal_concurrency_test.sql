-- Regression test for db/roshan_phase4_cashbox_reversal_concurrency.sql
-- STATUS: written but NOT YET EXECUTED. Run only on a disposable/staging Supabase database.
-- The transaction rolls back all fixture data. A true two-session concurrency test is still
-- required before production rollout; this test checks the function guard + unique-index defense.
begin;

create temp table _cashbox_test_fixture (
  super_auth uuid,
  super_profile uuid,
  branch_id uuid,
  original_id uuid,
  reversal_id uuid
);

insert into _cashbox_test_fixture (super_auth, branch_id)
select gen_random_uuid(), (select id from public.branches limit 1);

do $$
declare
  t record;
  profile_id uuid;
  v_original_id uuid;
begin
  select * into t from _cashbox_test_fixture limit 1;

  if t.branch_id is null then
    raise exception 'Test requires at least one branch';
  end if;

  if not exists (select 1 from public.roles where code = 'super_admin') then
    raise exception 'Test requires the super_admin role';
  end if;

  insert into auth.users (id, aud, role, email)
  values (t.super_auth, 'authenticated', 'authenticated', 'cashbox-reversal-test@test.invalid');

  insert into public.users (auth_user_id, full_name, email, role_id, branch_id, active)
  select t.super_auth, 'Cashbox Reversal Test', 'cashbox-reversal-test@test.invalid',
         r.id, t.branch_id, true
    from public.roles r
   where r.code = 'super_admin'
  returning id into profile_id;

  insert into public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category,
    description, source_type, transaction_date, created_by
  ) values (
    t.branch_id, 'deposit', 10.00, 'cash', 'test',
    'cashbox reversal regression fixture', 'manual', now(), profile_id
  ) returning id into v_original_id;

  update _cashbox_test_fixture f
     set super_profile = profile_id, original_id = v_original_id
   where f.super_auth = t.super_auth;
end $$;

grant select, insert, update on _cashbox_test_fixture to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select super_auth from _cashbox_test_fixture limit 1),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  v_original_id uuid;
  v_reversal_id uuid;
begin
  select f.original_id into v_original_id
    from _cashbox_test_fixture f
   where f.original_id is not null
   limit 1;

  v_reversal_id := public.reverse_cashbox_entry(v_original_id, 'automated regression test');

  update _cashbox_test_fixture f
     set reversal_id = v_reversal_id
   where f.original_id = v_original_id;
end $$;

do $$
declare
  v_original_id uuid;
  error_message text;
begin
  select f.original_id into v_original_id
    from _cashbox_test_fixture f
   where f.original_id is not null
   limit 1;

  begin
    perform public.reverse_cashbox_entry(v_original_id, 'second reversal must fail');
    raise exception 'FAIL: second reversal call unexpectedly succeeded';
  exception when others then
    get stacked diagnostics error_message = message_text;
    if error_message not like '%transaction already reversed%' then
      raise exception 'FAIL: unexpected second-reversal error: %', error_message;
    end if;
    raise notice 'PASS: function rejects a second reversal';
  end;
end $$;

reset role;

do $$
declare
  v_original_id uuid;
  v_function_definition text;
  v_function_config text[];
begin
  select f.original_id into v_original_id
    from _cashbox_test_fixture f
   where f.original_id is not null
   limit 1;

  begin
    insert into public.cashbox_transactions (
      branch_id, transaction_type, amount, payment_method, category,
      description, source_type, transaction_date, created_by, reversal_of, reversal_reason
    )
    select f.branch_id, 'reversal', -10.00, 'cash', 'test',
           'duplicate reversal constraint test', 'reversal', now(), f.super_profile,
           v_original_id, 'duplicate attempt'
      from _cashbox_test_fixture f
     where f.original_id = v_original_id;
    raise exception 'FAIL: unique reversal index allowed a duplicate';
  exception when unique_violation then
    raise notice 'PASS: unique index prevents a second reversal row';
  end;

  if (select count(*) from public.cashbox_transactions where reversal_of = v_original_id) <> 1 then
    raise exception 'FAIL: expected exactly one reversal row';
  end if;

  if (select count(*) from public.cashbox_transactions
       where reversal_of = v_original_id
         and transaction_type = 'adjustment'
         and amount = -10.00) <> 1 then
    raise exception 'FAIL: reversal must preserve the established adjustment type and negate the original amount';
  end if;

  select pg_get_functiondef(p.oid), p.proconfig
    into v_function_definition, v_function_config
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'reverse_cashbox_entry'
     and pg_get_function_identity_arguments(p.oid) = '_transaction_id uuid, _reason text';

  if position('FOR UPDATE' in upper(v_function_definition)) = 0 then
    raise exception 'FAIL: reverse_cashbox_entry does not lock the original row';
  end if;
  if position('cross-branch cashbox access denied' in v_function_definition) = 0 then
    raise exception 'FAIL: reverse_cashbox_entry is missing its branch-isolation guard';
  end if;
  if not coalesce(v_function_config, array[]::text[]) @> array['search_path=""'] then
    raise exception 'FAIL: reverse_cashbox_entry must use an empty search_path';
  end if;
  raise notice 'PASS: row lock, branch isolation, and empty search_path are present';
end $$;

rollback;
