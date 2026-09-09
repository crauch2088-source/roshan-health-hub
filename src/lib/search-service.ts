import { patientEmbeddedFilter, patientPickerQuery, sanitizeTerm } from "./search";
import { supabase } from "./supabase";

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
};

const EMPTY_RESULTS: SearchResults = { patients: [], visits: [], lab: [], medicines: [] };
const RECENT_TERMS_KEY = "roshan:search:recent-terms";
const HISTORY_KEY = "roshan:search:history";
const MAX_RECENT_TERMS = 8;
const MAX_HISTORY = 10;
const PER_CATEGORY_LIMIT = 6;
const CACHE_TTL_MS = 30_000;

// ---------------------------------------------------------------------------
// Short in-memory cache — the same term typed twice in a session (e.g. the
// user reopens Ctrl+K) shouldn't re-hit the database. Not persisted; a page
// refresh clears it, which is fine, this is purely a debounce-adjacent
// optimization, not a data source of truth.
// ---------------------------------------------------------------------------
const cache = new Map<string, { at: number; results: SearchResults }>();

function readCache(term: string): SearchResults | null {
  const hit = cache.get(term);
  if (!hit) return null;
  if (Date.now() - hit.at > CACHE_TTL_MS) {
    cache.delete(term);
    return null;
  }
  return hit.results;
}

// ---------------------------------------------------------------------------
// Per-category search — each is a small, indexed, server-side query, never
// a full-table pull filtered in JS.
// ---------------------------------------------------------------------------

async function searchPatients(term: string): Promise<SearchResultItem[]> {
  const { data } = await patientPickerQuery(term, PER_CATEGORY_LIMIT);
  return ((data ?? []) as Record<string, unknown>[]).map((p) => ({
    key: `patient:${p.id}`,
    title: String(p.full_name ?? ""),
    subtitle: [p.mrn, p.phone].filter(Boolean).join(" · "),
    to: `/patients/${p.id}`,
    category: "patient" as const,
  }));
}

async function searchVisits(term: string): Promise<SearchResultItem[]> {
  const clean = sanitizeTerm(term);
  // Visit search spans its own columns and the joined patient's columns;
  // rather than a brittle single embedded-OR filter, run the two queries
  // that matter (visit id / by patient) and merge+dedupe client-side.
  const byPatient = supabase
    .from("visits")
    .select("id, visit_date, status, patients!visits_patient_id_fkey(full_name, mrn)")
    .is("deleted_at", null)
    .order("visit_date", { ascending: false })
    .limit(PER_CATEGORY_LIMIT);

  const filtered = clean ? patientEmbeddedFilter(byPatient, clean) : byPatient;
  const { data } = await filtered;

  return ((data ?? []) as Record<string, unknown>[]).map((v) => {
    const patient = (v.patients as Record<string, unknown> | null) ?? {};
    return {
      key: `visit:${v.id}`,
      title: String(patient.full_name ?? ""),
      subtitle: `${String(patient.mrn ?? "")} · ${String(v.visit_date ?? "")}`,
      meta: String(v.status ?? ""),
      to: `/clinic/${v.id}`,
      category: "visit" as const,
    };
  });
}

async function searchLab(term: string): Promise<SearchResultItem[]> {
  const clean = sanitizeTerm(term);
  if (!clean) return [];
  const { data } = await supabase
    .from("lab_orders")
    .select(
      "id, status, created_at, patients!lab_orders_patient_id_fkey(full_name, mrn), lab_order_items(lab_tests(name))",
    )
    .is("deleted_at", null)
    .or(`mrn.ilike.%${clean}%,full_name.ilike.%${clean}%`, { referencedTable: "patients" })
    .order("created_at", { ascending: false })
    .limit(PER_CATEGORY_LIMIT);

  return ((data ?? []) as Record<string, unknown>[]).map((o) => {
    const patient = (o.patients as Record<string, unknown> | null) ?? {};
    const items = (o.lab_order_items as { lab_tests: { name: string } | null }[] | null) ?? [];
    const testNames = items.map((i) => i.lab_tests?.name).filter(Boolean);
    return {
      key: `lab:${o.id}`,
      title: String(patient.full_name ?? ""),
      subtitle: testNames.length > 0 ? testNames.join(", ") : String(patient.mrn ?? ""),
      meta: String(o.status ?? ""),
      to: `/lab/${o.id}`,
      category: "lab" as const,
    };
  });
}

async function searchMedicines(term: string): Promise<SearchResultItem[]> {
  const clean = sanitizeTerm(term);
  if (!clean) return [];
  const { data } = await supabase
    .from("medicines")
    .select("id, name, unit, stock_quantity, selling_price, barcode")
    .is("deleted_at", null)
    .or(`name.ilike.%${clean}%,barcode.ilike.%${clean}%`)
    .order("name", { ascending: true })
    .limit(PER_CATEGORY_LIMIT);

  return ((data ?? []) as Record<string, unknown>[]).map((m) => ({
    key: `medicine:${m.id}`,
    title: String(m.name ?? ""),
    subtitle: m.unit ? String(m.unit) : undefined,
    meta: `${String(m.stock_quantity ?? 0)}`,
    to: `/inventory`,
    category: "medicine" as const,
  }));
}

/** Runs every category in parallel and returns as soon as all settle. */
export async function searchAll(rawTerm: string): Promise<SearchResults> {
  const term = rawTerm.trim();
  if (term.length < 2) return EMPTY_RESULTS;

  const cached = readCache(term);
  if (cached) return cached;

  const [patients, visits, lab, medicines] = await Promise.all([
    searchPatients(term).catch(() => []),
    searchVisits(term).catch(() => []),
    searchLab(term).catch(() => []),
    searchMedicines(term).catch(() => []),
  ]);

  const results: SearchResults = { patients, visits, lab, medicines };
  cache.set(term, { at: Date.now(), results });
  return results;
}

// ---------------------------------------------------------------------------
// Recent search terms (what was typed) — separate from history (what was
// opened). Both localStorage-backed, per browser, nothing clinical stored.
// ---------------------------------------------------------------------------

function readList<T>(key: string): T[] {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T[]) : [];
  } catch {
    return [];
  }
}

function writeList<T>(key: string, list: T[]) {
  try {
    window.localStorage.setItem(key, JSON.stringify(list));
  } catch {
    // Non-fatal — recents are a convenience, not a source of truth.
  }
}

export function getRecentSearchTerms(): string[] {
  return readList<string>(RECENT_TERMS_KEY);
}

export function pushRecentSearchTerm(term: string): void {
  const clean = term.trim();
  if (!clean) return;
  const next = [clean, ...getRecentSearchTerms().filter((t) => t.toLowerCase() !== clean.toLowerCase())].slice(
    0,
    MAX_RECENT_TERMS,
  );
  writeList(RECENT_TERMS_KEY, next);
}

export function clearRecentSearchTerms(): void {
  writeList(RECENT_TERMS_KEY, []);
}

export function getSearchHistory(): SearchResultItem[] {
  return readList<SearchResultItem>(HISTORY_KEY);
}

export function pushSearchHistoryItem(item: SearchResultItem): void {
  const next = [item, ...getSearchHistory().filter((h) => h.key !== item.key)].slice(0, MAX_HISTORY);
  writeList(HISTORY_KEY, next);
}

export function clearSearchHistory(): void {
  writeList(HISTORY_KEY, []);
}
