import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { isGenericCashboxReversalAllowed } from "../src/lib/cashbox-reversal.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const finance = read("../src/routes/_authenticated/finance.tsx");
const pkg = JSON.parse(read("../package.json")) as { scripts?: Record<string, string> };

test("generic cashbox reversal excludes all source-linked payment ledger entries", () => {
  assert.equal(isGenericCashboxReversalAllowed("payment"), false);
  assert.equal(isGenericCashboxReversalAllowed("supplier_payment"), false);
  assert.equal(isGenericCashboxReversalAllowed("insurance_claim_payment"), false);
  assert.equal(isGenericCashboxReversalAllowed("expense"), true);
  assert.equal(isGenericCashboxReversalAllowed("manual"), true);
  assert.equal(isGenericCashboxReversalAllowed(null), true);
});

test("cashbox UI loads source type and guards both mobile and desktop reversal actions", () => {
  assert.match(finance, /source_type/);
  assert.ok(
    (finance.match(/isGenericCashboxReversalAllowed\(/g) ?? []).length >= 2,
    "both mobile and desktop actions must apply the source-aware guard",
  );
  assert.match(finance, /source_specific_reversal_required/);
});

test("source-aware reversal UI guard is included in the standard guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /cashbox-reversal-eligibility\.test\.ts/);
});
