// Regression tests for complete (all-pages) reads used by dashboard totals and alerts.
// Run with:  npm run test:guard
import assert from "node:assert/strict";
import { test } from "node:test";

import { fetchAllPages, type PageResult } from "../src/lib/paging.ts";

/** Fake PostgREST: `total` rows, server never returns more than `maxRows` per request. */
function fakeServer(total: number, maxRows: number, opts: { count?: boolean } = {}) {
  const calls: Array<[number, number]> = [];
  const fetchPage = async (from: number, to: number): Promise<PageResult> => {
    calls.push([from, to]);
    const end = Math.min(to, from + maxRows - 1, total - 1);
    const data = [];
    for (let i = from; i <= end; i++) data.push({ id: i, amount: 1 });
    return { data, error: null, count: opts.count === false ? null : total };
  };
  return { fetchPage, calls };
}

test("reads every row across several pages", async () => {
  const srv = fakeServer(2500, 1000);
  const res = await fetchAllPages(srv.fetchPage, { pageSize: 1000 });
  assert.equal(res.rows.length, 2500);
  assert.equal(res.exact, true);
  assert.equal(res.count, 2500);
  assert.equal(new Set(res.rows.map((r) => (r as { id: number }).id)).size, 2500);
});

test("keeps going when the server caps a page below the requested size", async () => {
  const srv = fakeServer(450, 100);
  const res = await fetchAllPages(srv.fetchPage, { pageSize: 1000 });
  assert.equal(res.rows.length, 450);
  assert.equal(res.exact, true);
  assert.deepEqual(srv.calls[1], [100, 1099]);
});

test("an empty result is exact and makes one request", async () => {
  const srv = fakeServer(0, 1000);
  const res = await fetchAllPages(srv.fetchPage, { pageSize: 1000 });
  assert.deepEqual(res.rows, []);
  assert.equal(res.exact, true);
  assert.equal(srv.calls.length, 1);
});

test("a database error is thrown, never turned into partial totals", async () => {
  let n = 0;
  const fetchPage = async (): Promise<PageResult> =>
    n++ === 0
      ? { data: [{ id: 1 }], error: null, count: 3 }
      : { data: null, error: { message: "boom" }, count: null };
  await assert.rejects(fetchAllPages(fetchPage, { pageSize: 1 }), /boom/);
});

test("rows that stop arriving before the exact count are flagged inexact", async () => {
  let n = 0;
  const fetchPage = async (): Promise<PageResult> =>
    n++ === 0
      ? { data: [{ id: 1 }, { id: 2 }], error: null, count: 5 }
      : { data: [], error: null, count: 5 };
  const res = await fetchAllPages(fetchPage, { pageSize: 2 });
  assert.equal(res.rows.length, 2);
  assert.equal(res.exact, false);
});

test("without a server count, a short page ends the read but is not claimed exact", async () => {
  const srv = fakeServer(30, 1000, { count: false });
  const res = await fetchAllPages(srv.fetchPage, { pageSize: 100 });
  assert.equal(res.rows.length, 30);
  assert.equal(res.count, null);
  assert.equal(res.exact, false);
});

test("the page cap stops runaway reads and reports inexact", async () => {
  const srv = fakeServer(10_000, 10);
  const res = await fetchAllPages(srv.fetchPage, { pageSize: 10, maxPages: 3 });
  assert.equal(res.rows.length, 30);
  assert.equal(res.exact, false);
});
