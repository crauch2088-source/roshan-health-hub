import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { getAvailableQuickActions, QUICK_ACTIONS } from "../src/lib/quick-actions.ts";

const ROUTE_FILES: Record<string, string> = {
  new_patient: "patients.tsx",
  new_visit: "visits.tsx",
  new_invoice: "billing.tsx",
};

test("quick actions require both route-read and action-create permissions", () => {
  const allowed = new Set([
    "patients.read",
    "patients.create",
    "visits.read",
    "visits.create",
    "billing.read",
  ]);
  assert.deepEqual(
    getAvailableQuickActions((permission) => Boolean(permission && allowed.has(permission))).map(
      (action) => action.key,
    ),
    ["new_patient", "new_visit"],
  );
});

test("every advertised quick action has a route consumer for its one-shot flag", () => {
  for (const action of QUICK_ACTIONS) {
    const filename = ROUTE_FILES[action.key];
    assert.ok(filename, `${action.key} must have an explicit destination handler`);
    const source = readFileSync(
      new URL(`../src/routes/_authenticated/${filename}`, import.meta.url),
      "utf8",
    );
    assert.match(
      source,
      new RegExp(`consumeQuickAction\\(["']${action.key}["']\\)`),
      `${action.key} must open its create flow after navigation`,
    );
  }
});

test("quick-action destinations are still valid navigation routes", () => {
  for (const action of QUICK_ACTIONS) {
    assert.ok(action.permission.endsWith(".create"), `${action.key} needs a create permission`);
    assert.ok(action.to.startsWith("/"), `${action.key} needs an absolute route`);
  }
});
