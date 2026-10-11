// Regression: production showed the generic "technical fault" page on every SSR request
// because Vercel built/ran the server function on Node 20, where @supabase/supabase-js
// throws "native WebSocket not found" when the client is created. Nitro takes the function
// runtime from the build's Node version, so package.json must pin Node >= 22.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  engines?: { node?: string };
};

test("package.json pins a Node runtime with native WebSocket (>= 22)", () => {
  const range = pkg.engines?.node;
  assert.ok(range, "package.json must declare engines.node");
  const major = Number(/(\d+)/.exec(range)?.[1]);
  assert.ok(major >= 22, `engines.node must be >= 22 (got "${range}")`);
  assert.ok(
    !/^[<>~^]?=?\s*\d+\s*\|\|/.test(range) && !/\b(18|20)\b/.test(range),
    `engines.node must not allow Node 18/20 (got "${range}")`,
  );
});
