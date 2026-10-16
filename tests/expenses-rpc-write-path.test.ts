import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import testRunner from "node:test";

const source = readFileSync(
  new URL("../src/routes/_authenticated/expenses.tsx", import.meta.url),
  "utf8",
);

testRunner("expense creation uses the guarded post_expense RPC", () => {
  assert.match(source, /rpc\(["']post_expense["']/);
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']expenses["']\)\s*\.insert\s*\(/,
    "expense creation must not bypass the server-side finance RPC",
  );
});

testRunner("expense form rejects invalid amounts before submission", () => {
  assert.match(source, /Number\.isFinite\(amount\)/);
  assert.match(source, /amount\s*<=\s*0/);
});
