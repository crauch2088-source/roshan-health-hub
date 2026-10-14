// Regression tests for RTL/LTR tooltip placement and the permission-driven bottom-bar layout.
import assert from "node:assert/strict";
import { test } from "node:test";

import { bottomBarColumns, railTooltipSide } from "../src/lib/nav-layout.ts";

test("rail tooltips open towards the content in both directions", () => {
  assert.equal(railTooltipSide("ar"), "left"); // rail is on the right in RTL
  assert.equal(railTooltipSide("en"), "right"); // rail is on the left in LTR
});

test("bottom bar has one equal column per permitted destination plus More", () => {
  assert.equal(bottomBarColumns(4), "repeat(5, minmax(0, 1fr))");
  assert.equal(bottomBarColumns(2), "repeat(3, minmax(0, 1fr))");
  assert.equal(bottomBarColumns(0), "repeat(1, minmax(0, 1fr))");
  assert.equal(bottomBarColumns(-3), "repeat(1, minmax(0, 1fr))");
});

import { navTrail, pickPrimaryRoutes } from "../src/lib/nav-layout.ts";

const PRIORITY = ["/dashboard", "/patients", "/visits", "/pharmacy", "/lab", "/queue"];

test("primary bar takes the first four permitted destinations in priority order", () => {
  assert.deepEqual(
    pickPrimaryRoutes(PRIORITY, () => true),
    ["/dashboard", "/patients", "/visits", "/pharmacy"],
  );
});

test("a lab-only user gets the laboratory on the bar, not empty slots", () => {
  const allowed = new Set(["/dashboard", "/lab"]);
  assert.deepEqual(
    pickPrimaryRoutes(PRIORITY, (to) => allowed.has(to)),
    ["/dashboard", "/lab"],
  );
});

test("primary bar never exceeds max, never duplicates, never invents routes", () => {
  assert.deepEqual(
    pickPrimaryRoutes(["/a", "/a", "/b"], () => true, 2),
    ["/a", "/b"],
  );
  assert.deepEqual(
    pickPrimaryRoutes(PRIORITY, () => false),
    [],
  );
  assert.deepEqual(
    pickPrimaryRoutes(PRIORITY, () => true, 0),
    [],
  );
});

test("breadcrumb trail: detail step only on nested routes, home only when permitted", () => {
  assert.deepEqual(
    navTrail({
      hasHome: true,
      moduleKey: "clinical",
      sectionTo: "/patients",
      onSection: false,
    }).map((s) => s.kind),
    ["home", "module", "section", "detail"],
  );
  assert.deepEqual(
    navTrail({ hasHome: false, moduleKey: undefined, sectionTo: "/lab", onSection: true }).map(
      (s) => s.kind,
    ),
    ["section"],
  );
});


// Supabase environment compatibility: current and legacy Vercel key names.
import { resolveSupabaseKey } from "../src/lib/supabase-key.ts";

test("prefers the publishable key when both key names are configured", () => {
  assert.equal(
    resolveSupabaseKey({
      VITE_SUPABASE_PUBLISHABLE_KEY: "publishable-key",
      VITE_SUPABASE_ANON_KEY: "legacy-anon-key",
    }),
    "publishable-key",
  );
});

test("falls back to the configured legacy anon key", () => {
  assert.equal(
    resolveSupabaseKey({ VITE_SUPABASE_ANON_KEY: "legacy-anon-key" }),
    "legacy-anon-key",
  );
});

test("returns undefined when neither supported key is configured", () => {
  assert.equal(resolveSupabaseKey({}), undefined);
});

test("falls back when the publishable key is an empty string", () => {
  assert.equal(
    resolveSupabaseKey({
      VITE_SUPABASE_PUBLISHABLE_KEY: "",
      VITE_SUPABASE_ANON_KEY: "legacy-anon-key",
    }),
    "legacy-anon-key",
  );
});
