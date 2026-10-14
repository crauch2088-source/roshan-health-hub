-- Regression test for db/roshan_phase4_cashbox_reversal_concurrency.sql
-- STATUS: written but NOT YET EXECUTED. Run only on a disposable/staging Supabase database.
-- The transaction rolls back all fixture data. A true two-session concurrency test is still
-- required before production rollout; this test checks function guard + unique-index defense.
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
  original_id uuid;
begin
  select * into t from _cashbox_test_fixture;

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
  ) returning id into original_id;

  update _cashbox_test_fixture
     set super_profile = profile_id, original_id = original_id;
end $$;

grant select, insert on _cashbox_test_fixture to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select super_auth from _cashbox_test_fixture),
    'role', 'authenticated'
  )::text,
  true
);

insert into _cashbox_test_fixture (reversal_id)
select public.reverse_cashbox_entry(original_id, 'automated regression test')
from _cashbox_test_fixture;

do $$
declare
  original_id uuid;
  error_message text;
begin
  select f.original_id into original_id from _cashbox_test_fixture f;
  begin
    perform public.reverse_cashbox_entry(original_id, 'second reversal must fail');
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
  original_id uuid;
  error_message text;
begin
  select f.original_id into original_id from _cashbox_test_fixture f;

  begin
    insert into public.cashbox_transactions (
      branch_id, transaction_type, amount, payment_method, category,
      description, source_type, transaction_date, created_by, reversal_of, reversal_reason
    )
    select branch_id, 'reversal', -10.00, 'cash', 'test',
           'duplicate reversal constraint test', 'reversal', now(), super_profile,
           original_id, 'duplicate attempt'
      from _cashbox_test_fixture;
    raise exception 'FAIL: unique reversal index allowed a duplicate';
  exception when unique_violation then
    raise notice 'PASS: unique index prevents a second reversal row';
  end;

  if (select count(*) from public.cashbox_transactions where reversal_of = original_id) <> 1 then
    raise exception 'FAIL: expected exactly one reversal row';
  end if;

  if position('FOR UPDATE' in upper(pg_get_functiondef('public.reverse_cashbox_entry(uuid,text)'::regprocedure))) = 0 then
    raise exception 'FAIL: reverse_cashbox_entry does not lock the original row';
  end if;
  raise notice 'PASS: function definition locks original row';
end $$;

rollback;
