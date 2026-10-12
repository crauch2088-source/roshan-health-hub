// Pure core of the global search: category fan-out, partial-failure handling and the
// short-lived cache. It has no Supabase or React imports so it can be unit tested with
// `node --test` (see tests/search-core.test.ts). The real queries live in search-service.ts.

export type SearchCategory = "patient" | "visit" | "lab" | "medicine";

export type SearchResultItem = {
  key: string;
  title: string;
  subtitle?: string | undefined;
  meta?: string | undefined;
  to: string;
  category: SearchCategory;
};

export type SearchResults = {
  patients: SearchResultItem[];
  visits: SearchResultItem[];
  lab: SearchResultItem[];
  medicines: SearchResultItem[];
  /** true when at least one category failed (the other categories are still returned). */
  failed?: boolean;
};

/** Which categories the signed-in user may search (mirrors route permissions). */
export type SearchScope = Record<"patients" | "visits" | "lab" | "medicines", boolean>;

export const FULL_SCOPE: SearchScope = { patients: true, visits: true, lab: true, medicines: true };

export type CategoryQueries = Record<
  keyof SearchScope,
  (term: string) => Promise<SearchResultItem[]>
>;

/**
 * Thrown when a category query comes back with a database error. It deliberately carries
 * only the category name: never the database message, SQL, hints or identifiers.
 */
export class SearchCategoryError extends Error {
  readonly category: keyof SearchScope;
  constructor(category: keyof SearchScope) {
    super(`search category failed: ${category}`);
    this.name = "SearchCategoryError";
    this.category = category;
  }
}

/**
 * Supabase resolves `{ data, error }` instead of rejecting, so `.catch()` alone never sees
 * a database error. Every category query must pass its response through here.
 */
export function unwrapRows(
  response: { data: unknown; error: unknown },
  category: keyof SearchScope,
): Record<string, unknown>[] {
  if (response.error) throw new SearchCategoryError(category);
  return Array.isArray(response.data) ? (response.data as Record<string, unknown>[]) : [];
}

const CATEGORY_SCOPE: Record<SearchCategory, keyof SearchScope> = {
  patient: "patients",
  visit: "visits",
  lab: "lab",
  medicine: "medicines",
};

/**
 * Search history lives in this browser's storage and may have been written by a different
 * signed-in user. Only entries from categories the current user may search are shown.
 */
export function filterByScope(items: readonly SearchResultItem[], scope: SearchScope) {
  return items.filter((item) => scope[CATEGORY_SCOPE[item.category]]);
}

export const EMPTY_RESULTS: SearchResults = { patients: [], visits: [], lab: [], medicines: [] };

const SCOPE_KEYS = ["patients", "visits", "lab", "medicines"] as const;

export function createSearchAll(
  queries: CategoryQueries,
  options: { ttlMs?: number; now?: () => number } = {},
) {
  const ttlMs = options.ttlMs ?? 30_000;
  const now = options.now ?? Date.now;
  const cache = new Map<string, { at: number; results: SearchResults }>();

  return async function searchAll(
    rawTerm: string,
    scope: SearchScope = FULL_SCOPE,
  ): Promise<SearchResults> {
    const term = rawTerm.trim();
    if (term.length < 2) return EMPTY_RESULTS;

    const cacheKey = `${term}|${SCOPE_KEYS.map((k) => Number(scope[k])).join("")}`;
    const hit = cache.get(cacheKey);
    if (hit) {
      if (now() - hit.at <= ttlMs) return hit.results;
      cache.delete(cacheKey);
    }

    let failed = false;
    const run = async (enabled: boolean, query: (t: string) => Promise<SearchResultItem[]>) => {
      // A category outside the user's scope is never queried at all.
      if (!enabled) return [] as SearchResultItem[];
      try {
        return await query(term);
      } catch {
        failed = true;
        return [] as SearchResultItem[];
      }
    };

    const [patients, visits, lab, medicines] = await Promise.all([
      run(scope.patients, queries.patients),
      run(scope.visits, queries.visits),
      run(scope.lab, queries.lab),
      run(scope.medicines, queries.medicines),
    ]);

    const results: SearchResults = { patients, visits, lab, medicines, failed };
    // Failed or partial results must never be served later as if they were complete.
    if (!failed) cache.set(cacheKey, { at: now(), results });
    return results;
  };
}
