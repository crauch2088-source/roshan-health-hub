import { useMutation, useQuery, useQueryClient, type QueryKey } from "@tanstack/react-query";
import { toast } from "sonner";

import { dbError, supabase } from "./supabase";

type Builder = { then: unknown };

/** Runs a PostgREST builder and throws a readable error. */
export async function run<T>(builder: PromiseLike<{ data: T | null; error: unknown }>): Promise<T> {
  const { data, error } = await builder;
  if (error) throw new Error(dbError(error));
  return (data ?? ([] as unknown as T)) as T;
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
    queryFn: async () => (await run<T>(build() as never)) as T,
    enabled: options?.enabled ?? true,
    refetchInterval: options?.refetchInterval,
    retry: 0,
  });
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
      for (const key of opts?.invalidate ?? []) void qc.invalidateQueries({ queryKey: key });
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
  const query = useRows(["system_settings"], () =>
    supabase.from("system_settings").select("setting_key, setting_value"),
  );
  const map: Record<string, string> = {};
  for (const r of (query.data ?? []) as Row[]) {
    map[String(r.setting_key)] = String(r.setting_value ?? "");
  }
  return { ...query, settings: map, currency: map.currency || "SDG" };
}

export function csvExport(rows: Row[], filename: string) {
  if (!rows.length) {
    toast.error("No records to export");
    return;
  }
  const headers = Object.keys(rows[0]);
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

export type { Builder };
