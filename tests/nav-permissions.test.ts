// Guards that the navigation never offers a destination under a weaker permission than the
// route itself enforces. The UI check is only a convenience: the route's PermissionGate and
// Supabase RLS remain the real boundary, and this test fails if the two ever drift apart.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { flatNavItems, HOME_ITEM, navPermissionForRoute } from "../src/config/nav.ts";
import { isNavItemActive } from "../src/lib/nav-active.ts";
import { QUICK_ACTIONS } from "../src/lib/quick-actions.ts";

const ROUTES_DIR = new URL("../src/routes/_authenticated/", import.meta.url);

function routeGatePermission(to: string): string | undefined {
  const source = readFileSync(new URL(`${to.slice(1)}.tsx`, ROUTES_DIR), "utf8");
  return /<PermissionGate\s+perm="([a-z_.]+)"/.exec(source)?.[1];
}

test("each nav item's permission equals the PermissionGate of its route", () => {
  for (const item of [HOME_ITEM, ...flatNavItems()]) {
    assert.equal(
      routeGatePermission(item.to),
      item.perm,
      `${item.to}: nav perm and route gate differ`,
    );
  }
});

test("exactly one nav item is current for a section and for its detail routes", () => {
  const all = [HOME_ITEM, ...flatNavItems()];
  for (const item of all) {
    for (const path of [item.to, `${item.to}/`, `${item.to}/some-id`, `${item.to}?tab=1`]) {
      const matches = all.filter((i) => isNavItemActive(path, i.to)).map((i) => i.to);
      assert.deepEqual(matches, [item.to], `${path} matched ${matches.join(", ")}`);
    }
  }
});

test("every quick action targets an existing nav destination that is permission gated", () => {
  const all = [HOME_ITEM, ...flatNavItems()];
  for (const action of QUICK_ACTIONS) {
    const destination = all.find((i) => i.to === action.to);
    assert.ok(destination, `${action.key} points at ${action.to}, which is not in the nav config`);
    assert.ok(destination.perm, `${action.to} has no permission`);
  }
});

test("shortcut permission lookup includes Home and fails closed for unknown routes", () => {
  assert.equal(navPermissionForRoute("/dashboard"), HOME_ITEM.perm);
  assert.equal(navPermissionForRoute("/patients"), "patients.read");
  assert.equal(navPermissionForRoute("/not-a-route"), undefined);
});
