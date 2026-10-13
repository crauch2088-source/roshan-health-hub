// Regression tests for global-search failure handling, partial results, caching and scope.
// Run with:  npm run test:guard   (node --test, no extra dependencies)
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  createSearchAll,
  FULL_SCOPE,
  SearchCategoryError,
  unwrapRows,
  type CategoryQueries,
  type SearchResultItem,
} from "../src/lib/search-core.ts";

function item(category: SearchResultItem["category"], id: string): SearchResultItem {
  return { key: `${category}:${id}`, title: id, to: `/${category}/${id}`, category };
}

/** Fake category queries that count calls; `fail` makes them go through unwrapRows with an error. */
function makeQueries(opts: { fail?: (keyof CategoryQueries)[]; empty?: boolean } = {}) {
  const calls: Record<keyof CategoryQueries, number> = {
    patients: 0,
    visits: 0,
    lab: 0,
    medicines: 0,
  };
  const make =
    (name: keyof CategoryQueries, category: SearchResultItem["category"]) => async () => {
      calls[name] += 1;
      if (opts.fail?.includes(name)) {
        // Exactly what Supabase does: resolves (does not reject) with an error object.
        return unwrapRows(
          { data: null, error: { message: 'relation "secret_table" does not exist' } },
          name,
        ).map(() => item(category, "never"));
      }
      return opts.empty ? [] : [item(category, "1")];
    };
  const queries: CategoryQueries = {
    patients: make("patients", "patient"),
    visits: make("visits", "visit"),
    lab: make("lab", "lab"),
    medicines: make("medicines", "medicine"),
  };
  return { queries, calls };
}

test("unwrapRows throws a category error for a resolved { data, error } response", () => {
  assert.throws(
    () => unwrapRows({ data: null, error: { message: "boom", details: "SELECT * FROM x" } }, "lab"),
    (err: unknown) =>
      err instanceof SearchCategoryError &&
      err.category === "lab" &&
      !/boom|SELECT|x\b/.test(err.message),
  );
  assert.deepEqual(unwrapRows({ data: [{ id: 1 }], error: null }, "lab"), [{ id: 1 }]);
  assert.deepEqual(unwrapRows({ data: null, error: null }, "lab"), []);
});

test("a successful empty result is not a failure and is cached", async () => {
  const { queries, calls } = makeQueries({ empty: true });
  const searchAll = createSearchAll(queries);
  const first = await searchAll("ahmed");
  assert.equal(first.failed, false);
  assert.equal(
    first.patients.length + first.visits.length + first.lab.length + first.medicines.length,
    0,
  );
  await searchAll("ahmed");
  assert.equal(calls.patients, 1, "second identical search should be served from cache");
});

test("a category error flags failed, keeps the other categories, and exposes no details", async () => {
  const { queries } = makeQueries({ fail: ["lab"] });
  const searchAll = createSearchAll(queries);
  const res = await searchAll("ahmed");
  assert.equal(res.failed, true);
  assert.equal(res.lab.length, 0);
  assert.equal(res.patients.length, 1);
  assert.equal(res.visits.length, 1);
  assert.equal(res.medicines.length, 1);
  assert.ok(!JSON.stringify(res).includes("secret_table"));
});

test("failed or partial results are never cached as successful", async () => {
  let failLab = true;
  const { queries, calls } = makeQueries();
  const searchAll = createSearchAll({
    ...queries,
    lab: async () => {
      calls.lab += 1;
      if (failLab)
        return unwrapRows({ data: null, error: { message: "x" } }, "lab").map(() =>
          item("lab", "n"),
        );
      return [item("lab", "ok")];
    },
  });
  const partial = await searchAll("ahmed");
  assert.equal(partial.failed, true);
  failLab = false;
  const retry = await searchAll("ahmed");
  assert.equal(
    retry.failed,
    false,
    "retry must hit the database again, not the failed cache entry",
  );
  assert.equal(retry.lab.length, 1);
  assert.equal(calls.lab, 2);
});

test("a rejected promise is treated like a category failure", async () => {
  const { queries } = makeQueries();
  const searchAll = createSearchAll({
    ...queries,
    visits: async () => {
      throw new Error("network down");
    },
  });
  const res = await searchAll("ahmed");
  assert.equal(res.failed, true);
  assert.equal(res.patients.length, 1);
});

test("categories outside the scope are never queried", async () => {
  const { queries, calls } = makeQueries();
  const searchAll = createSearchAll(queries);
  const res = await searchAll("ahmed", {
    patients: true,
    visits: false,
    lab: false,
    medicines: true,
  });
  assert.equal(calls.visits, 0);
  assert.equal(calls.lab, 0);
  assert.equal(calls.patients, 1);
  assert.equal(calls.medicines, 1);
  assert.equal(res.visits.length + res.lab.length, 0);
  assert.equal(res.failed, false);
});

test("the cache is keyed by scope, so a narrower scope never reuses a wider result", async () => {
  const { queries, calls } = makeQueries();
  const searchAll = createSearchAll(queries);
  await searchAll("ahmed", FULL_SCOPE);
  const narrow = await searchAll("ahmed", {
    patients: true,
    visits: false,
    lab: false,
    medicines: false,
  });
  assert.equal(narrow.lab.length, 0, "lab results from the wide search must not leak");
  assert.equal(calls.patients, 2);
});

test("cache entries expire after the TTL, and short terms run no queries", async () => {
  let clock = 0;
  const { queries, calls } = makeQueries();
  const searchAll = createSearchAll(queries, { ttlMs: 1000, now: () => clock });
  await searchAll("ahmed");
  clock = 500;
  await searchAll("ahmed");
  assert.equal(calls.patients, 1);
  clock = 1501;
  await searchAll("ahmed");
  assert.equal(calls.patients, 2);
  const before = { ...calls };
  const short = await searchAll(" a ");
  assert.deepEqual(calls, before);
  assert.equal(short.patients.length, 0);
});

test("search history is filtered to the categories the current user may search", async () => {
  const { filterByScope } = await import("../src/lib/search-core.ts");
  const history = [
    item("patient", "p"),
    item("visit", "v"),
    item("lab", "l"),
    item("medicine", "m"),
  ];
  const scope = { patients: false, visits: true, lab: false, medicines: true };
  assert.deepEqual(
    filterByScope(history, scope).map((h) => h.category),
    ["visit", "medicine"],
  );
  assert.equal(filterByScope(history, FULL_SCOPE).length, 4);
});
