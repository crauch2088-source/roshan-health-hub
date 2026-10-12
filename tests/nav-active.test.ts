// Regression tests for the shared active-route matcher and the nav config.
// Run with:  npm run test:guard   (node --test, no extra dependencies)
import assert from "node:assert/strict";
import { test } from "node:test";

import { flatNavItems, HOME_ITEM } from "../src/config/nav.ts";
import { isNavItemActive, matchNavItem, normalizePath } from "../src/lib/nav-active.ts";

test("exact and nested routes are active", () => {
  assert.equal(isNavItemActive("/patients", "/patients"), true);
  assert.equal(isNavItemActive("/patients/abc-123", "/patients"), true);
  assert.equal(isNavItemActive("/clinic/xyz/", "/clinic"), true);
});

test("sibling routes sharing a prefix do not match", () => {
  assert.equal(isNavItemActive("/lab-catalog", "/lab"), false);
  assert.equal(isNavItemActive("/lab/order-1", "/lab-catalog"), false);
  assert.equal(isNavItemActive("/patientsx", "/patients"), false);
  assert.equal(isNavItemActive("/labs", "/lab"), false);
});

test("trailing slash, query string and hash are ignored", () => {
  assert.equal(normalizePath("/billing/"), "/billing");
  assert.equal(normalizePath("/billing?tab=unpaid#top"), "/billing");
  assert.equal(normalizePath(""), "/");
  assert.equal(isNavItemActive("/billing/?tab=unpaid", "/billing"), true);
});

test("matchNavItem picks the most specific item", () => {
  const items = [{ to: "/lab" }, { to: "/lab-catalog" }, { to: "/lab/templates" }];
  assert.equal(matchNavItem("/lab-catalog", items)?.to, "/lab-catalog");
  assert.equal(matchNavItem("/lab/templates/1", items)?.to, "/lab/templates");
  assert.equal(matchNavItem("/lab/order-9", items)?.to, "/lab");
  assert.equal(matchNavItem("/nowhere", items), undefined);
});

test("every real nav item resolves to itself and only itself", () => {
  const all = [HOME_ITEM, ...flatNavItems()];
  const paths = all.map((i) => i.to);
  assert.equal(new Set(paths).size, paths.length, "duplicate nav paths");
  for (const item of all) {
    assert.equal(matchNavItem(item.to, all)?.to, item.to);
    assert.equal(matchNavItem(`${item.to}/some-id`, all)?.to, item.to);
  }
});

test("every nav item declares a permission, so none is shown ungated", () => {
  for (const item of [HOME_ITEM, ...flatNavItems()]) {
    assert.ok(item.perm, `${item.to} has no perm`);
  }
});
