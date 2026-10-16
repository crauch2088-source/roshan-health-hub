import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const ui = readFileSync(
  new URL("../src/routes/_authenticated/patients.tsx", import.meta.url),
  "utf8",
);

test("patient registration uses one atomic server-side RPC", () => {
  const start = ui.indexOf("const create = useSave(");
  const end = ui.indexOf("\n\n  const rows", start);
  assert.ok(start >= 0 && end > start, "patient create handler must exist");
  const handler = ui.slice(start, end);
  assert.match(handler, /rpc(?:<[^>]+>)?\(["']create_patient_atomic["']/);
  assert.doesNotMatch(handler, /rpc(?:<[^>]+>)?\(["']next_mrn["']/);
  assert.doesNotMatch(handler, /\.from\(["']patients["']\)\.insert/);
});

test("patient registration regression test is part of the guard suite", () => {
  const pkg = JSON.parse(
    readFileSync(new URL("../package.json", import.meta.url), "utf8"),
  ) as { scripts?: Record<string, string> };
  assert.match(pkg.scripts?.["test:guard"] ?? "", /patient-registration-atomicity\.test\.ts/);
});
