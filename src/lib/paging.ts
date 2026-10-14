/**
 * Complete reads of a PostgREST table.
 *
 * A plain `.select()` is silently truncated at the project's `max-rows` limit
 * (1000 by default on Supabase), so sums or "any row matches" checks computed
 * from it can be wrong without any error. `fetchAllPages` walks `.range()`
 * pages until the exact server count is reached and reports whether it got
 * there (`exact`), so callers can refuse to present an unproven total.
 */
export type PageResult = {
  data: unknown[] | null;
  error: unknown;
  count: number | null;
};

export type AllPagesResult<T> = {
  rows: T[];
  /** Exact row count reported by the server for the first page, if any. */
  count: number | null;
  /** True only when the server count is known and every row was received. */
  exact: boolean;
};

const DEFAULT_PAGE_SIZE = 1000;
const DEFAULT_MAX_PAGES = 200;

function defaultToError(error: unknown): Error {
  if (error instanceof Error) return error;
  const message = (error as { message?: unknown } | null)?.message;
  return new Error(typeof message === "string" ? message : String(error));
}

export async function fetchAllPages<T = Record<string, unknown>>(
  fetchPage: (from: number, to: number) => PromiseLike<PageResult>,
  options: { pageSize?: number; maxPages?: number; toError?: (error: unknown) => Error } = {},
): Promise<AllPagesResult<T>> {
  const pageSize = Math.max(1, options.pageSize ?? DEFAULT_PAGE_SIZE);
  const maxPages = Math.max(1, options.maxPages ?? DEFAULT_MAX_PAGES);
  const toError = options.toError ?? defaultToError;

  const rows: T[] = [];
  let count: number | null = null;
  let from = 0;

  for (let page = 0; page < maxPages; page++) {
    const result = await fetchPage(from, from + pageSize - 1);
    if (result.error) throw toError(result.error);
    if (page === 0) count = result.count;

    const data = (result.data ?? []) as T[];
    if (data.length === 0) break;
    rows.push(...data);
    from += data.length;

    if (count != null) {
      if (rows.length >= count) break;
    } else if (data.length < pageSize) {
      break;
    }
  }

  return { rows, count, exact: count != null && rows.length === count };
}
