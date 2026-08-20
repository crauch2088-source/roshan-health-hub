import { useMemo } from "react";
import { useMutation, useQuery, useQueryClient, type QueryKey } from "@tanstack/react-query";
import { toast } from "sonner";
import { dbError, supabase } from "./supabase";

/** Runs a PostgREST builder and throws a readable error. */
export async function run<T>(builder: PromiseLike<{ data: T | null; error: unknown }>): Promise<T> {
  const { data, error } = await builder;
  if (error) throw new Error(dbError(error));
  return (data ?? []) as T;
}

export type Row = Record<string, unknown>;

/** Read helper: any table, any filter chain. */
export function useRows<T = Row[]>(
  key: QueryKey,
  build: () => PromiseLike<{ data: unknown; error: unknown }>,
  options?: { enabled?: boolean; refetchInterval?: number },
) {
  return useQuery({
    queryKey: key,
    queryFn: async () => (await run<T>(build() as never)),
    enabled: options?.enabled ?? true,
    refetchInterval: options?.refetchInterval ?? false,
    retry: false,
  });
}

/**
 * Read helper for large/growing tables: pages results at the database
 * level using PostgREST's `.range()` + an exact count, instead of
 * fetching an entire table and slicing/searching it in React.
 */
export function usePagedRows<T = Row[]>(
  key: QueryKey,
  build: (range: { from: number; to: number }) => PromiseLike<{
    data: unknown;
    error: unknown;
    count: number | null;
  }>,
  page: number,
  pageSize: number,
  options?: { enabled?: boolean },
) {
  const safePage = Math.max(1, page);
  const from = (safePage - 1) * pageSize;
  const to = from + pageSize - 1;

  const query = useQuery({
    queryKey: [...key, "page", safePage, pageSize],
    queryFn: async () => {
      const { data, error, count } = await build({ from, to });
      if (error) throw new Error(dbError(error));
      return { rows: (data ?? []) as T, count: count ?? null };
    },
    enabled: options?.enabled ?? true,
    retry: false,
    placeholderData: (prev) => prev,
  });

  const count = query.data?.count ?? null;
  const rows = (query.data?.rows ?? []) as T;
  const rowCount = Array.isArray(rows) ? (rows as unknown[]).length : 0;
  const pageCount = count != null ? Math.max(1, Math.ceil(count / pageSize)) : null;

  return {
    ...query,
    rows,
    count,
    page: safePage,
    pageSize,
    pageCount,
    hasPrev: safePage > 1,
    hasNext: pageCount != null ? safePage < pageCount : rowCount === pageSize,
  };
}

/** Write helper with toast + cache invalidation. */
export function useSave<TVars>(
  fn: (vars: TVars) => Promise<unknown>,
  opts?: { invalidate?: QueryKey[]; successMessage?: string; onDone?: (result: unknown) => void },
) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (vars: TVars) => fn(vars),
    onSuccess: (result) => {
      if (opts?.invalidate) {
        for (const key of opts.invalidate) void qc.invalidateQueries({ queryKey: key });
      }
      if (opts?.successMessage) toast.success(opts.successMessage);
      opts?.onDone?.(result);
    },
    onError: (e: Error) => toast.error(e.message),
  });
}

export async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(name, args ?? {});
  if (error) throw new Error(dbError(error));
  return data as T;
}

/** System settings as a flat map. */
export function useSettings() {
  const query = useRows<Row[]>(["system_settings"], () =>
    supabase.from("system_settings").select("setting_key, setting_value"),
  );

  const settings = useMemo(() => {
    const map: Record<string, string> = {};
    const dataList = Array.isArray(query.data) ? (query.data as Row[]) : [];
    for (const r of dataList) {
      map[String(r["setting_key"])] = String(r["setting_value"] ?? "");
    }
    return map;
  }, [query.data]);

  return { ...query, settings, currency: settings["currency"] || "SDG" };
}

export function csvExport(rows: Row[], filename: string) {
  const first = rows[0];
  if (!first) {
    toast.error("No records to export");
    return;
  }
  const headers = Object.keys(first);
  const escape = (v: unknown) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const csv = [
    headers.join(","),
    ...rows.map((r) => headers.map((h) => escape(r[h])).join(",")),
  ].join("\n");
  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

export function s(row: Row | undefined | null, key: string): string {
  const v = row?.[key];
  return v == null ? "" : String(v);
}
export function n(row: Row | undefined | null, key: string): number {
  const v = Number(row?.[key]);
  return Number.isFinite(v) ? v : 0;
}
export function b(row: Row | undefined | null, key: string): boolean {
  return Boolean(row?.[key]);
}
export function rel(row: Row | undefined | null, key: string): Row | null {
  const v = row?.[key];
  return Array.isArray(v) ? ((v[0] as Row) ?? null) : (v as Row) ?? null;
}
