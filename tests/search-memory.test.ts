// Regression tests: recent searches and history must never leak between staff accounts that
// share one browser (they can contain patient names and MRNs).
import assert from "node:assert/strict";
import { test } from "node:test";

import type { SearchResultItem } from "../src/lib/search-core.ts";
import { createSearchMemory, type StorageLike } from "../src/lib/search-memory.ts";

function fakeStorage(initial: Record<string, string> = {}) {
  const data = new Map(Object.entries(initial));
  const storage: StorageLike = {
    getItem: (k) => data.get(k) ?? null,
    setItem: (k, v) => void data.set(k, v),
    removeItem: (k) => void data.delete(k),
  };
  return { storage, data };
}

const patient = (id: string): SearchResultItem => ({
  key: `patient:${id}`,
  title: `Name ${id}`,
  to: `/patients/${id}`,
  category: "patient",
});

test("one user's terms and history are invisible to another user on the same browser", () => {
  const { storage } = fakeStorage();
  const a = createSearchMemory(storage, "user-a");
  a.pushRecentTerm("Fatima Ali");
  a.pushHistoryItem(patient("1"));

  const b = createSearchMemory(storage, "user-b");
  assert.deepEqual(b.getRecentTerms(), []);
  assert.deepEqual(b.getHistory(), []);
  assert.deepEqual(createSearchMemory(storage, "user-a").getRecentTerms(), ["Fatima Ali"]);
});

test("clearing affects only the current user", () => {
  const { storage } = fakeStorage();
  const a = createSearchMemory(storage, "user-a");
  const b = createSearchMemory(storage, "user-b");
  a.pushRecentTerm("one");
  b.pushRecentTerm("two");
  a.clearRecentTerms();
  assert.deepEqual(a.getRecentTerms(), []);
  assert.deepEqual(b.getRecentTerms(), ["two"]);
});

test("legacy shared keys are purged so earlier names do not linger", () => {
  const { storage, data } = fakeStorage({
    "roshan:search:recent-terms": JSON.stringify(["Old Patient"]),
    "roshan:search:history": JSON.stringify([patient("9")]),
  });
  const a = createSearchMemory(storage, "user-a");
  assert.equal(data.has("roshan:search:recent-terms"), false);
  assert.equal(data.has("roshan:search:history"), false);
  assert.deepEqual(a.getRecentTerms(), []);
});

test("without a signed-in owner nothing is read or written", () => {
  const { storage, data } = fakeStorage();
  for (const owner of [null, undefined, ""]) {
    const m = createSearchMemory(storage, owner);
    m.pushRecentTerm("secret name");
    m.pushHistoryItem(patient("1"));
    assert.deepEqual(m.getRecentTerms(), []);
    assert.deepEqual(m.getHistory(), []);
  }
  assert.equal(data.size, 0);
  const none = createSearchMemory(null, "user-a");
  none.pushRecentTerm("x");
  assert.deepEqual(none.getRecentTerms(), []);
});

test("terms are de-duplicated case-insensitively, newest first, and capped", () => {
  const { storage } = fakeStorage();
  const m = createSearchMemory(storage, "u");
  m.pushRecentTerm("Ahmed");
  m.pushRecentTerm("ahmed");
  assert.deepEqual(m.getRecentTerms(), ["ahmed"]);
  for (let i = 0; i < 12; i++) m.pushRecentTerm(`t${i}`);
  assert.equal(m.getRecentTerms().length, 8);
  assert.equal(m.getRecentTerms()[0], "t11");
  for (let i = 0; i < 15; i++) m.pushHistoryItem(patient(String(i)));
  assert.equal(m.getHistory().length, 10);
});

test("corrupt stored data is treated as empty, not as an error", () => {
  const { storage } = fakeStorage({
    "roshan:search:recent-terms:u": "{not json",
    "roshan:search:history:u": '{"a":1}',
  });
  const m = createSearchMemory(storage, "u");
  assert.deepEqual(m.getRecentTerms(), []);
  assert.deepEqual(m.getHistory(), []);
});
