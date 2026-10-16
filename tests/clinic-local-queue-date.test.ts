import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const ui = readFileSync(
  new URL("../src/routes/_authenticated/visits.tsx", import.meta.url),
  "utf8",
);
const migration = readFileSync(
  new URL("../db/roshan_phase22_clinic_local_queue_date.sql", import.meta.url),
  "utf8",
);
const pkg = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as { scripts?: Record<string, string> };

test("visit creation persists the intended clinic-local date", () => {
  assert.match(ui, /queue_date:\s*date/);
});

test("queue trigger derives fallback dates in the clinic timezone for both visit and ticket", () => {
  assert.equal((migration.match(/AT TIME ZONE 'Africa\/Khartoum'/g) ?? []).length, 2);
  assert.doesNotMatch(migration, /AT TIME ZONE 'UTC'/);
  assert.match(migration, /new\.queue_date/);
});

test("clinic-local queue-date regression test is part of the guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /clinic-local-queue-date\.test\.ts/);
});
