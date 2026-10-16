import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const auth = read("../src/lib/auth.tsx");
const migration = read("../db/roshan_phase25_current_app_profile.sql");
const integration = read("../db/tests/current_app_profile_integration.sql");

test("auth bootstrap uses the self-profile RPC instead of RLS-blocked table reads", () => {
  assert.match(auth, /supabase\.rpc\("get_my_app_profile"\)/);
  assert.doesNotMatch(auth, /\.from\("users"\)/);
  assert.doesNotMatch(auth, /\.from\("role_permissions"\)/);
  assert.match(migration, /WHERE u\.auth_user_id = auth\.uid\(\)/);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.get_my_app_profile\(\) FROM PUBLIC, anon/,
  );
  assert.match(integration, /authenticated receptionist must be able to load their own profile/);
  assert.match(integration, /anon must not execute the profile RPC/);
});
