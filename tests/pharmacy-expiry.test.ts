import assert from "node:assert/strict";
import { test } from "node:test";
import { daysUntil, expiryStatus } from "../src/lib/pharmacy-expiry.ts";

function localIsoDate(offsetDays: number): string {
  const date = new Date();
  date.setHours(12, 0, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,"0")}-${String(date.getDate()).padStart(2,"0")}`;
}

test("missing and malformed expiry dates are unknown, never healthy", () => {
  assert.equal(expiryStatus(null,90),"unknown");
  assert.equal(expiryStatus(undefined,90),"unknown");
  assert.equal(expiryStatus("not-a-date",90),"unknown");
  assert.equal(daysUntil(null),null);
  assert.equal(daysUntil("2026-02-31"),null);
});

test("date-only expiry comparison is calendar-correct at day boundaries", () => {
  assert.equal(expiryStatus(localIsoDate(-1),90),"expired");
  assert.equal(expiryStatus(localIsoDate(0),90),"expiring_soon");
  assert.equal(expiryStatus(localIsoDate(90),90),"expiring_soon");
  assert.equal(expiryStatus(localIsoDate(91),90),"healthy");
  assert.equal(daysUntil(localIsoDate(5)),5);
});
