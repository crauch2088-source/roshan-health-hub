import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../db/roshan_security_privileged_role_guard.sql", import.meta.url),
  "utf8",
);

test("privileged-role guard protects users, roles, and role permissions", () => {
  assert.match(migration, /CREATE TRIGGER trg_guard_super_admin_users[\s\S]*ON public\.users/i);
  assert.match(migration, /CREATE TRIGGER trg_guard_super_admin_roles[\s\S]*ON public\.roles/i);
  assert.match(
    migration,
    /CREATE TRIGGER trg_guard_super_admin_role_permissions[\s\S]*ON public\.role_permissions/i,
  );
  assert.equal((migration.match(/USING errcode = '42501'/gi) ?? []).length >= 6, true);
  assert.match(migration, /SET search_path = ''/i);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION private\.guard_super_admin_users\(\) FROM public, anon, authenticated/i,
  );
  assert.match(migration, /bootstrap_super_admin\(text, text, text\)/i);
  assert.match(migration, /bootstrap_super_admin\(uuid, text, text\)/i);
});
