import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const picker = readFileSync(
  new URL("../src/components/patient-picker.tsx", import.meta.url),
  "utf8",
);

test("patient search errors are distinct from an empty result and can be retried", () => {
  const errorBranch = picker.indexOf("results.error ? (");
  const emptyBranch = picker.indexOf("rows.length === 0 ?");

  assert.ok(errorBranch >= 0, "the picker must render a dedicated query-error state");
  assert.ok(emptyBranch > errorBranch, "query errors must take precedence over empty results");

  const errorState = picker.slice(errorBranch, emptyBranch);
  assert.match(errorState, /ErrorBox error=\{results\.error\}/);
  assert.match(errorState, /onRetry=\{\(\) => void results\.refetch\(\)\}/);
  assert.doesNotMatch(errorState, /to="\/patients"/);
});

test("the add-patient suggestion remains limited to a successful empty search", () => {
  const emptyBranch = picker.indexOf("rows.length === 0 ?");
  const resultsBranch = picker.indexOf("rows.map((p)", emptyBranch);
  assert.ok(emptyBranch >= 0 && resultsBranch > emptyBranch);
  const emptyState = picker.slice(emptyBranch, resultsBranch);
  assert.match(emptyState, /to="\/patients"/);
  assert.match(emptyState, /duplicate_patient_hint/);
});

test("patient picker error regression is included in the guard suite", () => {
  const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
    scripts?: Record<string, string>;
  };
  assert.match(pkg.scripts?.["test:guard"] ?? "", /patient-picker-error-state\.test\.ts/);
});
