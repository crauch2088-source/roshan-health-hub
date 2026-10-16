-- =====================================================================
-- Roshan Health Hub — privileged-role guard
--
-- STATUS: PREPARED, NOT APPLIED. Do not run against production until the
-- owner has reviewed it. Idempotent (safe to run twice).
--
-- Problem (verified against the live database 2026-10-10):
--   * RLS on public.users only requires the generic `users.create` /
--     `users.update` permission and puts NO limit on role_id, so anyone
--     holding those permissions (the `admin` role today; 0 members) can
--     write role_id = <super_admin> directly through PostgREST.
--   * RLS on public.roles / public.role_permissions only requires
--     `admin.full`, so an admin could rename or re-permission the
--     super_admin role. (private.is_super_admin() is keyed on roles.code.)
--
-- Fix: BEFORE-row triggers that deny non-super-admins any assignment,
-- demotion, deletion or editing of the super_admin role. Enforced in the
-- database, independent of the UI and of the server function.
--
-- Trusted contexts that are NOT restricted (no end-user JWT subject, so
-- auth.uid() IS NULL): migrations and the service_role server client.
-- Server code using service_role must enforce the same rule itself —
-- src/lib/role-guard.ts + createStaffUser do.
--
-- Rollback (see bottom): drop the three triggers.
-- =====================================================================

begin;

-- Distinguish trusted service/migration execution from anonymous JWTs.
-- auth.uid() is NULL for both anon and trusted contexts, so it is not a trust signal.
create or replace function private.is_trusted_role_guard_context()
returns boolean
language sql
stable
security definer
set search_path = ''
as $
  select coalesce(auth.role() = 'service_role', false)
      or (auth.role() is null and session_user in ('postgres', 'supabase_admin'))
$;

revoke all on function private.is_trusted_role_guard_context() from public, anon, authenticated;

-- 1. Helper: is this role id the super_admin role?
create or replace function private.is_super_admin_role(_role_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select r.code = 'super_admin' from public.roles r where r.id = _role_id),
    false
  )
$$;

revoke all on function private.is_super_admin_role(uuid) from public, anon, authenticated;

-- 2. public.users: assigning / holding / deleting the super_admin role.
create or replace function private.guard_super_admin_users()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Trusted, non-end-user context (migrations, service_role).
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  -- A real super admin may do anything.
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can assign the super_admin role'
        using errcode = '42501';
    end if;
    return new;

  elsif tg_op = 'UPDATE' then
    -- Cannot touch an existing super admin's row at all ...
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can modify a super admin account'
        using errcode = '42501';
    end if;
    -- ... and cannot move anyone INTO the super_admin role.
    if new.role_id is distinct from old.role_id
       and private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can assign the super_admin role'
        using errcode = '42501';
    end if;
    return new;

  else -- DELETE
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can delete a super admin account'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$$;

revoke all on function private.guard_super_admin_users() from public, anon, authenticated;

drop trigger if exists trg_guard_super_admin_users on public.users;
create trigger trg_guard_super_admin_users
  before insert or update or delete on public.users
  for each row execute function private.guard_super_admin_users();

-- 3. public.roles: the super_admin role row itself (code is the authority
--    key used by private.is_super_admin()).
create or replace function private.guard_super_admin_roles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.code = 'super_admin' then
      raise exception 'Only a super admin can create the super_admin role'
        using errcode = '42501';
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if old.code = 'super_admin' or new.code = 'super_admin' then
      raise exception 'Only a super admin can modify the super_admin role'
        using errcode = '42501';
    end if;
    return new;
  else
    if old.code = 'super_admin' then
      raise exception 'Only a super admin can delete the super_admin role'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$$;

revoke all on function private.guard_super_admin_roles() from public, anon, authenticated;

drop trigger if exists trg_guard_super_admin_roles on public.roles;
create trigger trg_guard_super_admin_roles
  before insert or update or delete on public.roles
  for each row execute function private.guard_super_admin_roles();

-- 4. public.role_permissions: permissions attached to the super_admin role.
create or replace function private.guard_super_admin_role_permissions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if private.is_super_admin_role(old.role_id)
       or private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return new;
  else
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$$;

revoke all on function private.guard_super_admin_role_permissions() from public, anon, authenticated;

drop trigger if exists trg_guard_super_admin_role_permissions on public.role_permissions;
create trigger trg_guard_super_admin_role_permissions
  before insert or update or delete on public.role_permissions
  for each row execute function private.guard_super_admin_role_permissions();

-- 5. First-run bootstrap: not callable by end users.
--    VERIFIED LIVE (2026-10-10): neither overload is executable by anon or
--    authenticated, and setup is complete (profiles and super admins exist),
--    so these REVOKEs match production and are no-ops there. They exist so
--    that re-running db/roshan_phase1_migration.sql can never re-open it.
--    To bootstrap a brand-new empty install, run as postgres in the SQL
--    editor (never from the browser):
--      select public.bootstrap_super_admin('<auth_user_uuid>'::uuid,
--                                           'Full Name', 'email@example.com');
revoke execute on function public.bootstrap_super_admin(text, text, text)
  from public, anon, authenticated;
revoke execute on function public.bootstrap_super_admin(uuid, text, text)
  from public, anon, authenticated;

commit;

-- ---------------------------------------------------------------------
-- ROLLBACK (only if this migration must be undone):
--   drop trigger if exists trg_guard_super_admin_users on public.users;
--   drop trigger if exists trg_guard_super_admin_roles on public.roles;
--   drop trigger if exists trg_guard_super_admin_role_permissions on public.role_permissions;
--   drop function if exists private.guard_super_admin_users();
--   drop function if exists private.guard_super_admin_roles();
--   drop function if exists private.guard_super_admin_role_permissions();
--   drop function if exists private.is_super_admin_role(uuid);
-- ---------------------------------------------------------------------
