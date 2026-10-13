// Per-user "recent searches" and "search history". Both can contain patient names or MRNs
// (what was typed, what was opened), so they must never be shared between staff accounts that
// use the same browser. Storage is injected so this stays pure and unit testable with
// `node --test` (see tests/search-memory.test.ts).
import type { SearchResultItem } from "./search-core";

export type StorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

const RECENT_BASE = "roshan:search:recent-terms";
const HISTORY_BASE = "roshan:search:history";
const MAX_RECENT_TERMS = 8;
const MAX_HISTORY = 10;

function read<T>(storage: StorageLike, key: string): T[] {
  try {
    const raw = storage.getItem(key);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? (parsed as T[]) : [];
  } catch {
    return [];
  }
}

function write(storage: StorageLike, key: string, value: unknown) {
  try {
    storage.setItem(key, JSON.stringify(value));
  } catch {
    // Non-fatal — this is a convenience, not a source of truth.
  }
}

/**
 * Before per-user keys existed, one shared (unscoped) list was kept per browser. Remove it so
 * names typed or opened by an earlier user are not left behind in storage.
 */
export function purgeLegacySearchMemory(storage: StorageLike) {
  try {
    storage.removeItem(RECENT_BASE);
    storage.removeItem(HISTORY_BASE);
  } catch {
    // ignore
  }
}

/**
 * With no signed-in owner (or no storage) every read is empty and every write is a no-op, so
 * nothing is ever stored under a shared key.
 */
export function createSearchMemory(
  storage: StorageLike | null,
  ownerId: string | null | undefined,
) {
  const active = storage !== null && Boolean(ownerId);
  const recentKey = `${RECENT_BASE}:${ownerId ?? ""}`;
  const historyKey = `${HISTORY_BASE}:${ownerId ?? ""}`;
  if (storage && active) purgeLegacySearchMemory(storage);

  const getRecentTerms = (): string[] =>
    storage && active ? read<string>(storage, recentKey) : [];
  const getHistory = (): SearchResultItem[] =>
    storage && active ? read<SearchResultItem>(storage, historyKey) : [];

  return {
    getRecentTerms,
    pushRecentTerm(term: string) {
      const clean = term.trim();
      if (!storage || !active || !clean) return;
      const next = [
        clean,
        ...getRecentTerms().filter((t) => t.toLowerCase() !== clean.toLowerCase()),
      ].slice(0, MAX_RECENT_TERMS);
      write(storage, recentKey, next);
    },
    clearRecentTerms() {
      if (storage && active) write(storage, recentKey, []);
    },
    getHistory,
    pushHistoryItem(item: SearchResultItem) {
      if (!storage || !active) return;
      const next = [item, ...getHistory().filter((h) => h.key !== item.key)].slice(0, MAX_HISTORY);
      write(storage, historyKey, next);
    },
    clearHistory() {
      if (storage && active) write(storage, historyKey, []);
    },
  };
}
