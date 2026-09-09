import { useEffect, useState } from "react";

import { searchAll, type SearchResults } from "@/lib/search-service";
import { useDebounced } from "@/lib/search";

const EMPTY: SearchResults = { patients: [], visits: [], lab: [], medicines: [] };

/** Debounces the query, then fans it out to every category via SearchService. */
export function useGlobalSearch(query: string) {
  const debounced = useDebounced(query, 300);
  const [results, setResults] = useState<SearchResults>(EMPTY);
  const [isSearching, setIsSearching] = useState(false);

  useEffect(() => {
    const term = debounced.trim();
    if (term.length < 2) {
      setResults(EMPTY);
      setIsSearching(false);
      return;
    }

    let cancelled = false;
    setIsSearching(true);
    searchAll(term)
      .then((next) => {
        if (!cancelled) setResults(next);
      })
      .finally(() => {
        if (!cancelled) setIsSearching(false);
      });

    return () => {
      cancelled = true;
    };
  }, [debounced]);

  return { results, isSearching };
}
