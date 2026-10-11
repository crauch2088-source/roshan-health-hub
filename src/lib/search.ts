import { useEffect, useState } from "react";

import { supabase } from "./supabase";

/**
 * Centralised search service.
 *
 * Every module (patients, visits, laboratory, pharmacy, certificates) goes
 * through these helpers so that:
 *   - free text is sanitised before it is embedded in a PostgREST filter,
 *   - searches run in the DATABASE (`ilike` + `range`) instead of pulling a
 *     whole table into React and filtering it there,
 *   - patient lookups are MRN-first (a receptionist typing a card number
 *     gets that exact patient at the top, not a fuzzy name match),
 *   - pharmacy can accept a scanned barcode in the same input box.
 */

/** Strips characters that would break a PostgREST `or(...)` filter string. */
export function sanitizeTerm(term: string): string {
  return term.replace(/[,()%*\\"']/g, " ").replace(/\s+/g, " ").trim();
}

/** Debounces a fast-changing value (typing / scanning) for query keys. */
export function useDebounced<T>(value: T, delay = 350): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return debounced;
}

/** A scanned EAN/UPC-style code: 6+ digits and nothing else. */
export function looksLikeBarcode(term: string): boolean {
  return /^\d{6,}$/.test(term.trim());
}

/** MRN-ish input: mostly digits, optionally prefixed (e.g. `MRN-000123`). */
export function looksLikeMrn(term: string): boolean {
  return /^[A-Za-z]{0,5}[-/]?\d{1,}$/.test(term.trim());
}

export const PATIENT_LIST_COLUMNS =
  "id, mrn, full_name, phone, gender, date_of_birth, national_id, created_at";

export const PATIENT_PICKER_COLUMNS = "id, full_name, mrn, phone";

type PagedResponse = { data: unknown; error: unknown; count: number | null };

/**
 * Paged, MRN-first patient search. Shaped for `usePagedRows`.
 *
 * When the term looks like an MRN we first try an MRN prefix match; only if
 * that finds nothing do we fall back to the broad name/phone/national-id
 * search. That keeps the common reception case (typing a card number) to a
 * single indexed lookup.
 */
export async function searchPatientsPaged(opts: {
  term: string;
  from: number;
  to: number;
  columns?: string;
}): Promise<PagedResponse> {
  const columns = opts.columns ?? PATIENT_LIST_COLUMNS;
  const base = () =>
    supabase
      .from("patients")
      .select(columns, { count: "exact" })
      .is("deleted_at", null);

  const term = sanitizeTerm(opts.term);
  if (!term) {
    return base().order("created_at", { ascending: false }).range(opts.from, opts.to);
  }

  if (looksLikeMrn(term)) {
    const byMrn = await base()
      .ilike("mrn", `${term}%`)
      .order("mrn", { ascending: true })
      .range(opts.from, opts.to);
    if (!byMrn.error && (byMrn.count ?? 0) > 0) return byMrn;
  }

  return base()
    .or(
      `mrn.ilike.%${term}%,full_name.ilike.%${term}%,phone.ilike.%${term}%,national_id.ilike.%${term}%`,
    )
    .order("created_at", { ascending: false })
    .range(opts.from, opts.to);
}

/** Short patient list for pickers/combos — never a full-table scan. */
export function patientPickerQuery(term: string, limit = 30) {
  const clean = sanitizeTerm(term);
  let q = supabase
    .from("patients")
    .select(PATIENT_PICKER_COLUMNS)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (clean.length >= 2) {
    q = q.or(
      `mrn.ilike.%${clean}%,full_name.ilike.%${clean}%,phone.ilike.%${clean}%,national_id.ilike.%${clean}%`,
    );
  }
  return q;
}

/**
 * Applies a patient-scoped text filter to a query that embeds
 * `patients!inner(...)` — used by the laboratory and pharmacy worklists so
 * their search happens server-side across the joined patient row.
 */
export function patientEmbeddedFilter<
  T extends { or: (f: string, opts: { referencedTable: string }) => T },
>(query: T, term: string): T {
  const clean = sanitizeTerm(term);
  if (!clean) return query;
  return query.or(
    `mrn.ilike.%${clean}%,full_name.ilike.%${clean}%,phone.ilike.%${clean}%`,
    { referencedTable: "patients" },
  );
}

/** Resolves a scanned barcode (or a code typed by hand) to one medicine. */
export async function findMedicineByBarcode(code: string) {
  const clean = sanitizeTerm(code);
  if (!clean) return null;
  const { data } = await supabase
    .from("medicines")
    .select("id, name, barcode, selling_price, stock_quantity")
    .eq("barcode", clean)
    .is("deleted_at", null)
    .limit(1);
  return (data?.[0] as Record<string, unknown> | undefined) ?? null;
}
