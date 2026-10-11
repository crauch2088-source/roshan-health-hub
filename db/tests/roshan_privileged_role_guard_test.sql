-- Regression test for db/roshan_security_privileged_role_guard.sql
-- STATUS: written but NOT YET EXECUTED. Run on a Supabase branch/staging DB
-- (or in production only after the guard migration is approved and applied).
-- Everything happens inside a transaction that is ROLLED BACK at the end.
-- Run as postgres (SQL editor). Expected output: NOTICE lines "PASS: ..."
-- and no exception.
begin;

-- Fixtures (inserted as postgres: auth.uid() is null, so the guard is bypassed).
create temp table _t as
select gen_random_uuid() as admin_auth, gen_random_uuid() as doc_auth,
       gen_random_uuid() as super_auth, gen_random_uuid() as victim_auth,
       (select id from public.branches limit 1) as branch_id,
       (select id from public.roles where code = 'admin') as admin_role,
       (select id from public.roles where code = 'doctor') as doctor_role,
       (select id from public.roles where code = 'super_admin') as super_role;
grant select on _t to authenticated;

insert into auth.users (id, aud, role, email)
select admin_auth, 'authenticated', 'authenticated', 'guard-admin@test.invalid' from _t
union all select doc_auth, 'authenticated', 'authenticated', 'guard-doc@test.invalid' from _t
union all select super_auth, 'authenticated', 'authenticated', 'guard-super@test.invalid' from _t
union all select victim_auth, 'authenticated', 'authenticated', 'guard-victim@test.invalid' from _t;

insert into public.users (auth_user_id, full_name, email, role_id, branch_id, active)
select admin_auth, 'Guard Admin', 'guard-admin@test.invalid', admin_role, branch_id, true from _t
union all select doc_auth, 'Guard Doctor', 'guard-doc@test.invalid', doctor_role, branch_id, true from _t
union all select super_auth, 'Guard Super', 'guard-super@test.invalid', super_role, branch_id, true from _t
union all select victim_auth, 'Guard Victim', 'guard-victim@test.invalid', doctor_role, branch_id, true from _t;

-- Act as the NON-super admin (holds users.update / users.create / admin.full).
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', (select admin_auth from _t), 'role', 'authenticated')::text, true);

do $$
declare n int; t record;
begin
  select * into t from _t;

  -- 1. cannot promote someone to super_admin via UPDATE
  begin
    update public.users set role_id = t.super_role where auth_user_id = t.doc_auth;
    raise exception 'FAIL 1: admin promoted a user to super_admin';
  exception when insufficient_privilege then raise notice 'PASS 1: promote via UPDATE denied'; end;

  -- 2. cannot self-promote
  begin
    update public.users set role_id = t.super_role where auth_user_id = t.admin_auth;
    raise exception 'FAIL 2: admin self-promoted';
  exception when insufficient_privilege then raise notice 'PASS 2: self-promotion denied'; end;

  -- 3. cannot INSERT a super_admin profile
  begin
    insert into public.users (auth_user_id, full_name, email, role_id, branch_id, active)
    values (gen_random_uuid(), 'x', 'x@test.invalid', t.super_role, t.branch_id, true);
    raise exception 'FAIL 3: admin inserted a super_admin';
  exception when insufficient_privilege or foreign_key_violation then
    if sqlstate = '23503' then raise notice 'NOTE 3: blocked by FK before guard (acceptable)';
    else raise notice 'PASS 3: insert super_admin denied'; end if; end;

  -- 4. cannot modify or delete an existing super admin
  begin
    update public.users set active = false where auth_user_id = t.super_auth;
    raise exception 'FAIL 4a: admin modified a super admin';
  exception when insufficient_privilege then raise notice 'PASS 4a: modify super admin denied'; end;
  begin
    delete from public.users where auth_user_id = t.super_auth;
    raise exception 'FAIL 4b: admin deleted a super admin';
  exception when insufficient_privilege then raise notice 'PASS 4b: delete super admin denied'; end;

  -- 5. cannot rename / re-permission the super_admin role
  begin
    update public.roles set code = 'super_admin_old' where id = t.super_role;
    raise exception 'FAIL 5a: admin renamed super_admin role';
  exception when insufficient_privilege then raise notice 'PASS 5a: rename super_admin role denied'; end;
  begin
    delete from public.role_permissions where role_id = t.super_role;
    raise exception 'FAIL 5b: admin changed super_admin permissions';
  exception when insufficient_privilege then raise notice 'PASS 5b: super_admin permissions protected'; end;

  -- 6. legitimate management still works: change an ordinary user's role
  update public.users set role_id = t.doctor_role where auth_user_id = t.victim_auth;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 6: ordinary role change blocked (rows=%)', n; end if;
  raise notice 'PASS 6: ordinary user management still allowed';
end $$;

-- Act as the REAL super admin: allowed.
select set_config('request.jwt.claims',
  json_build_object('sub', (select super_auth from _t), 'role', 'authenticated')::text, true);
do $$
declare n int; t record;
begin
  select * into t from _t;
  update public.users set role_id = t.super_role where auth_user_id = t.doc_auth;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 7: super admin could not assign super_admin (rows=%)', n; end if;
  raise notice 'PASS 7: super admin may assign super_admin';
end $$;

reset role;
rollback;
