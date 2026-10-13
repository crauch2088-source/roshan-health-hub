import { patientEmbeddedFilter, patientPickerQuery, sanitizeTerm } from "./search";
import { createSearchAll, unwrapRows, type SearchResultItem } from "./search-core";
import { createSearchMemory, type StorageLike } from "./search-memory";
import { supabase } from "./supabase";

export type { SearchCategory, SearchResultItem, SearchResults, SearchScope } from "./search-core";
export { FULL_SCOPE, filterByScope } from "./search-core";

const PER_CATEGORY_LIMIT = 6;

// ---------------------------------------------------------------------------
// Per-category search — each is a small, indexed, server-side query, never
// a full-table pull filtered in JS.
// ---------------------------------------------------------------------------

async function searchPatients(term: string): Promise<SearchResultItem[]> {
  const rows = unwrapRows(await patientPickerQuery(term, PER_CATEGORY_LIMIT), "patients");
  return rows.map((p) => ({
    key: `patient:${p["id"]}`,
    title: String(p["full_name"] ?? ""),
    subtitle: [p["mrn"], p["phone"]].filter(Boolean).join(" · "),
    to: `/patients/${p["id"]}`,
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
  const rows = unwrapRows(await filtered, "visits");

  return rows.map((v) => {
    const patient = (v["patients"] as Record<string, unknown> | null) ?? {};
    return {
      key: `visit:${v["id"]}`,
      title: String(patient["full_name"] ?? ""),
      subtitle: `${String(patient["mrn"] ?? "")} · ${String(v["visit_date"] ?? "")}`,
      meta: String(v["status"] ?? ""),
      to: `/clinic/${v["id"]}`,
      category: "visit" as const,
    };
  });
}

async function searchLab(term: string): Promise<SearchResultItem[]> {
  const clean = sanitizeTerm(term);
  if (!clean) return [];
  const response = await supabase
    .from("lab_orders")
    .select(
      "id, status, created_at, patients!lab_orders_patient_id_fkey(full_name, mrn), lab_order_items(lab_tests(name))",
    )
    .is("deleted_at", null)
    .or(`mrn.ilike.%${clean}%,full_name.ilike.%${clean}%`, { referencedTable: "patients" })
    .order("created_at", { ascending: false })
    .limit(PER_CATEGORY_LIMIT);

  return unwrapRows(response, "lab").map((o) => {
    const patient = (o["patients"] as Record<string, unknown> | null) ?? {};
    const items = (o["lab_order_items"] as { lab_tests: { name: string } | null }[] | null) ?? [];
    const testNames = items.map((i) => i.lab_tests?.name).filter(Boolean);
    return {
      key: `lab:${o["id"]}`,
      title: String(patient["full_name"] ?? ""),
      subtitle: testNames.length > 0 ? testNames.join(", ") : String(patient["mrn"] ?? ""),
      meta: String(o["status"] ?? ""),
      to: `/lab/${o["id"]}`,
      category: "lab" as const,
    };
  });
}

async function searchMedicines(term: string): Promise<SearchResultItem[]> {
  const clean = sanitizeTerm(term);
  if (!clean) return [];
  const response = await supabase
    .from("medicines")
    .select("id, name, unit, stock_quantity, selling_price, barcode")
    .is("deleted_at", null)
    .or(`name.ilike.%${clean}%,barcode.ilike.%${clean}%`)
    .order("name", { ascending: true })
    .limit(PER_CATEGORY_LIMIT);

  return unwrapRows(response, "medicines").map((m) => ({
    key: `medicine:${m["id"]}`,
    title: String(m["name"] ?? ""),
    subtitle: m["unit"] ? String(m["unit"]) : undefined,
    meta: `${String(m["stock_quantity"] ?? 0)}`,
    to: `/inventory`,
    category: "medicine" as const,
  }));
}

/**
 * Runs every permitted category in parallel (see search-core.ts for the failure and
 * caching rules). Categories outside `scope` are never queried.
 */
export const searchAll = createSearchAll({
  patients: searchPatients,
  visits: searchVisits,
  lab: searchLab,
  medicines: searchMedicines,
});

// ---------------------------------------------------------------------------
// Recent search terms and history are per signed-in user (see search-memory.ts).
// ---------------------------------------------------------------------------

function browserStorage(): StorageLike | null {
  try {
    return typeof window === "undefined" ? null : window.localStorage;
  } catch {
    return null;
  }
}

export function getSearchMemory(ownerId: string | null | undefined) {
  return createSearchMemory(browserStorage(), ownerId);
}
