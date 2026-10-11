// Regression tests for privilege escalation via role assignment.
// Run with:  npm run test:guard   (node --test, no extra dependencies)
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  canAssignRole,
  isPrivilegedRole,
  SUPER_ADMIN_ROLE_CODE,
} from "../src/lib/role-guard.ts";

const ordinaryUserManager = { isSuperAdmin: false };
const superAdmin = { isSuperAdmin: true };

test("a user manager (users.create) cannot assign super_admin", () => {
  assert.equal(
    canAssignRole(ordinaryUserManager, { code: SUPER_ADMIN_ROLE_CODE }),
    false,
  );
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

test("unknown role is treated as privileged", () => {
  assert.equal(isPrivilegedRole(null), true);
  assert.equal(isPrivilegedRole(undefined), true);
});
