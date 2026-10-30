// Regression tests for privilege escalation via role assignment.
// Run with:  npm run test:guard   (node --test, no extra dependencies)
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { canAssignRole, isPrivilegedRole, SUPER_ADMIN_ROLE_CODE } from "../src/lib/role-guard.ts";

const staffUserHandler = readFileSync(
  new URL("../src/routes/_authenticated/-users.server.ts", import.meta.url),
  "utf8",
);

const ordinaryUserManager = { isSuperAdmin: false };
const superAdmin = { isSuperAdmin: true };

test("a user manager (users.create) cannot assign super_admin", () => {
  assert.equal(canAssignRole(ordinaryUserManager, { code: SUPER_ADMIN_ROLE_CODE }), false);
});

test("a user manager can still assign ordinary roles", () => {
  for (const code of ["admin", "doctor", "lab_tech", "pharmacist", "receptionist", "staff"]) {
    assert.equal(canAssignRole(ordinaryUserManager, { code }), true, code);
  }
});

test("a super admin can assign super_admin and ordinary roles", () => {
  assert.equal(canAssignRole(superAdmin, { code: SUPER_ADMIN_ROLE_CODE }), true);
  assert.equal(canAssignRole(superAdmin, { code: "doctor" }), true);
});

test("fails closed: missing caller or missing role is denied", () => {
  assert.equal(canAssignRole(null, { code: "doctor" }), false);
  assert.equal(canAssignRole(undefined, { code: "doctor" }), false);
  assert.equal(canAssignRole(superAdmin, null), false);
  assert.equal(canAssignRole(ordinaryUserManager, undefined), false);
});

test("role code matching is exact (no case/whitespace tricks)", () => {
  assert.equal(isPrivilegedRole({ code: "Super_Admin" }), false);
  assert.equal(isPrivilegedRole({ code: " super_admin" }), false);
  assert.equal(isPrivilegedRole({ code: "super_admin" }), true);
  // Documented limitation: matching is by exact code. The database trigger
  // additionally blocks changing the code of the super_admin role itself.
});

test("staff user creation rejects soft-deleted callers before provisioning", () => {
  const queryStart = staffUserHandler.indexOf("const { data: callerRow, error: callerRowError }");
  const authorizationStart = staffUserHandler.indexOf("const callerIsSuperAdmin", queryStart);
  assert.ok(queryStart >= 0 && authorizationStart > queryStart);

  const callerLookup = staffUserHandler.slice(queryStart, authorizationStart);
  assert.match(callerLookup, /\.is\(\s*["']deleted_at["']\s*,\s*null\s*\)/);
  assert.ok(
    callerLookup.indexOf('.is("deleted_at", null)') < callerLookup.indexOf(".maybeSingle()"),
  );

  const callerRejected = staffUserHandler.indexOf(
    "if (callerRowError || !callerRow || !callerRow.active)",
    queryStart,
  );
  const createAuthUser = staffUserHandler.indexOf(
    "admin.auth.admin.createUser",
    authorizationStart,
  );
  const insertProfile = staffUserHandler.indexOf('.from("users").insert', authorizationStart);
  assert.ok(callerRejected > queryStart);
  assert.ok(callerRejected < authorizationStart);
  assert.ok(createAuthUser > callerRejected);
  assert.ok(insertProfile > createAuthUser);
});

test("unknown role is treated as privileged", () => {
  assert.equal(isPrivilegedRole(null), true);
  assert.equal(isPrivilegedRole(undefined), true);
});
