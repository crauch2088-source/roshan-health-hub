import { useEffect, useState } from "react";

import { FULL_SCOPE, searchAll, type SearchResults, type SearchScope } from "@/lib/search-service";
import { useDebounced } from "@/lib/search";

const EMPTY: SearchResults = { patients: [], visits: [], lab: [], medicines: [] };

/**
 * Debounces the query, then fans it out to every permitted category via
 * SearchService. `isSearching` is also true while the debounce is pending, so
 * the dialog never flashes "no results" for a term that has not been run yet.
 */
export function useGlobalSearch(query: string, scope: SearchScope = FULL_SCOPE) {
  const debounced = useDebounced(query, 300);
  const [results, setResults] = useState<SearchResults>(EMPTY);
  const [isRunning, setIsRunning] = useState(false);
  const { patients, visits, lab, medicines } = scope;

  useEffect(() => {
    const term = debounced.trim();
    if (term.length < 2) {
      setResults(EMPTY);
      setIsRunning(false);
      return;
    }

    let cancelled = false;
    setIsRunning(true);
    searchAll(term, { patients, visits, lab, medicines })
      .then((next) => {
        if (!cancelled) setResults(next);
      })
      .catch(() => {
        if (!cancelled) setResults({ ...EMPTY, failed: true });
      })
      .finally(() => {
        if (!cancelled) setIsRunning(false);
      });

    return () => {
      cancelled = true;
    };
  }, [debounced, patients, visits, lab, medicines]);

  const pending = query.trim() !== debounced.trim() && query.trim().length >= 2;
  return { results, isSearching: isRunning || pending };
}
