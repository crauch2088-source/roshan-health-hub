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
