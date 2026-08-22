import { useMemo, useState } from "react";
import { Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rpc, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

const CATEGORY_ORDER = ["Hematology", "Clinical Chemistry", "Hormones", "Microbiology", "Serology", "Immunology", "Urinalysis", "Parasitology", "Other"];
const CATEGORY_AR: Record<string, string> = {
  Hematology: "أمراض الدم", "Clinical Chemistry": "الكيمياء السريرية", Hormones: "الهرمونات", Microbiology: "الأحياء الدقيقة", Serology: "السيرولوجي", Immunology: "المناعة", Urinalysis: "تحليل البول", Parasitology: "الطفيليات", Other: "أخرى",
};

function normalizeCategory(value: string) {
  const v = value.trim();
  if (!v) return "Other";
  const lower = v.toLowerCase();
  if (lower.includes("hemat") || lower.includes("cbc") || lower.includes("blood")) return "Hematology";
  if (lower.includes("chem") || lower.includes("liver") || lower.includes("renal") || lower.includes("kidney") || lower.includes("lipid")) return "Clinical Chemistry";
  if (lower.includes("horm")) return "Hormones";
  if (lower.includes("micro") || lower.includes("culture")) return "Microbiology";
  if (lower.includes("sero") || lower.includes("viral") || lower.includes("hepat") || lower.includes("hiv")) return "Serology";
  if (lower.includes("immun")) return "Immunology";
  if (lower.includes("urine") || lower.includes("urin")) return "Urinalysis";
  if (lower.includes("paras") || lower.includes("malaria")) return "Parasitology";
  return v;
}

export function LaboratoryTab({ visitId }: { visitId: string }) {
  const { user } = useAuth();
  const { lang } = useLang();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("all");
  const [selected, setSelected] = useState<Row[]>([]);
  const [priority, setPriority] = useState("normal");
  const [notes, setNotes] = useState("");

  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () => supabase.from("visits").select("id,patient_id,patients(id,full_name)").eq("id", visitId).limit(1));
  const visit = (visitQ.data ?? [])[0] as Row | undefined;
  const patient = rel(visit, "patients");

  const testsQ = useRows<Row[]>(["clinic-lab-tests", search], () => {
    let q = supabase.from("lab_tests").select("id,name,name_ar,code,price,category").eq("active", true).is("deleted_at", null).order("name").limit(300);
    const term = search.replace(/[,()%]/g, "").trim();
    if (term) q = q.or(`name.ilike.%${term}%,name_ar.ilike.%${term}%,code.ilike.%${term}%,category.ilike.%${term}%`);
    return q;
  });

  const tests = (testsQ.data ?? []) as Row[];
  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const test of tests) set.add(normalizeCategory(s(test, "category")));
    return ["all", ...CATEGORY_ORDER.filter((x) => x !== "Other" && set.has(x)), ...Array.from(set).filter((x) => !CATEGORY_ORDER.includes(x) && x !== "all")];
  }, [tests]);
  const visible = useMemo(() => tests.filter((test) => category === "all" || normalizeCategory(s(test, "category")) === category), [tests, category]);

  const selectedIds = new Set(selected.map((x) => s(x, "id")));
  const profiles = useMemo(() => {
    const by = (words: string[]) => tests.filter((t) => words.some((w) => `${s(t, "name")} ${s(t, "name_ar")} ${s(t, "code")}`.toLowerCase().includes(w)));
    return [
      { id: "cbc", label: lang === "ar" ? "CBC / صورة الدم" : "CBC profile", tests: by(["cbc", "complete blood count"]) },
      { id: "renal", label: lang === "ar" ? "وظائف الكلى" : "Renal profile", tests: by(["creatinine", "urea", "renal", "kidney"]) },
      { id: "liver", label: lang === "ar" ? "وظائف الكبد" : "Liver profile", tests: by(["lft", "alt", "ast", "bilirubin", "liver"]) },
      { id: "glucose", label: lang === "ar" ? "السكري" : "Glucose profile", tests: by(["glucose", "fbs", "rbs", "hba1c"]) },
    ].filter((p) => p.tests.length);
  }, [tests, lang]);

  const toggle = (test: Row) => setSelected((current) => selectedIds.has(s(test, "id")) ? current.filter((x) => s(x, "id") !== s(test, "id")) : [...current, test]);
  const addProfile = (profile: { tests: Row[] }) => setSelected((current) => {
    const map = new Map(current.map((x) => [s(x, "id"), x]));
    profile.tests.forEach((x) => map.set(s(x, "id"), x));
    return Array.from(map.values());
  });

  const create = useSave(async () => {
    if (!s(patient, "id")) throw new Error(lang === "ar" ? "المريض غير موجود" : "Patient not found");
    if (!selected.length) throw new Error(lang === "ar" ? "اختر فحصاً واحداً على الأقل" : "Select at least one test");
    const { data: order, error } = await supabase.from("lab_orders").insert({ patient_id: s(patient, "id"), visit_id: visitId, ordered_by: user?.id ?? null, status: "ordered", priority, notes: notes || null, created_by: user?.id ?? null }).select("id").single();
    if (error) throw new Error(error.message);
    const items = selected.map((t) => ({ order_id: order.id, test_id: s(t, "id"), price: n(t, "price"), created_by: user?.id ?? null }));
    const { error: itemError } = await supabase.from("lab_order_items").insert(items);
    if (itemError) throw new Error(itemError.message);
    const total = selected.reduce((sum, t) => sum + n(t, "price"), 0);
    if (total > 0) {
      const invoiceNumber = await rpc<string>("next_invoice_number");
      const { data: inv, error: invError } = await supabase.from("invoices").insert({ invoice_number: invoiceNumber, patient_id: s(patient, "id"), visit_id: visitId, invoice_date: new Date().toISOString().slice(0, 10), total_amount: total, subtotal: total, discount_amount: 0, net_amount: total, paid_amount: 0, status: "unpaid", payment_status: "unpaid", created_by: user?.id ?? null }).select("id").single();
      if (invError) throw new Error(invError.message);
      const rows = selected.map((t) => ({ invoice_id: inv.id, item_type: "laboratory", item_name: s(t, "name"), quantity: 1, unit_price: n(t, "price"), total_price: n(t, "price"), item_id: s(t, "id"), created_by: user?.id ?? null }));
      const { error: invoiceItemsError } = await supabase.from("invoice_items").insert(rows);
      if (invoiceItemsError) throw new Error(invoiceItemsError.message);
    }
    setSelected([]); setNotes("");
    return order.id;
  }, { invalidate: [["lab-orders"], ["lab-orders", visitId], ["patient-labs", s(patient, "id")], ["invoices"]], successMessage: lang === "ar" ? "تم إرسال طلب المختبر وإنشاء الفاتورة" : "Lab order created and invoice generated" });

  return (
    <Card>
      <CardHeader><CardTitle className="text-base">{lang === "ar" ? "اختيار الفحوصات" : "Select investigations"}</CardTitle></CardHeader>
      <CardContent className="space-y-4 p-4">
        <div className="grid gap-2 lg:grid-cols-[1fr_auto]">
          <div className="relative"><Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" /><Input className="ps-9" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={lang === "ar" ? "ابحث باسم الفحص أو الرمز أو التصنيف" : "Search test, code or category"} /></div>
          <select className="rounded-md border bg-background px-3 py-2 text-sm" value={category} onChange={(e) => setCategory(e.target.value)}><option value="all">{lang === "ar" ? "كل التصنيفات" : "All categories"}</option>{categories.filter((x) => x !== "all").map((x) => <option key={x} value={x}>{lang === "ar" ? CATEGORY_AR[x] ?? x : x}</option>)}</select>
        </div>
        {profiles.length > 0 && <div><div className="mb-2 text-xs font-medium text-muted-foreground">{lang === "ar" ? "حزم سريعة" : "Quick profiles"}</div><div className="flex flex-wrap gap-2">{profiles.map((p) => <Button key={p.id} type="button" size="sm" variant="secondary" onClick={() => addProfile(p)}>{p.label} <span className="ms-1 text-xs opacity-70">{p.tests.length}</span></Button>)}</div></div>}
        <div className="grid gap-4 lg:grid-cols-2">
          {categories.filter((x) => x !== "all").map((cat) => {
            const group = visible.filter((t) => normalizeCategory(s(t, "category")) === cat);
            if (!group.length) return null;
            return <div key={cat} className="rounded-xl border"><div className="flex items-center justify-between border-b bg-muted/30 px-3 py-2"><span className="font-medium">{lang === "ar" ? CATEGORY_AR[cat] ?? cat : cat}</span><span className="text-xs text-muted-foreground">{group.length}</span></div><div className="grid gap-2 p-2">{group.map((test) => { const chosen = selectedIds.has(s(test, "id")); return <button type="button" key={s(test, "id")} onClick={() => toggle(test)} className={`rounded-lg border p-3 text-start transition ${chosen ? "border-primary bg-primary/5" : "hover:bg-muted/50"}`}><div className="flex items-start justify-between gap-2"><div className="font-medium">{lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")}</div>{chosen && <span className="text-xs text-primary">✓</span>}</div><div className="mt-1 text-xs text-muted-foreground" dir="ltr">{s(test, "code") || "—"} · {n(test, "price")}</div></button>; })}</div></div>;
          })}
        </div>
        {!visible.length && <div className="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">{lang === "ar" ? "لا توجد فحوصات مطابقة" : "No matching tests"}</div>}
        {selected.length > 0 && <div className="rounded-xl border bg-muted/20 p-3"><div className="mb-2 flex items-center justify-between"><span className="font-medium">{lang === "ar" ? `الفحوصات المختارة (${selected.length})` : `Selected tests (${selected.length})`}</span><Button type="button" variant="ghost" size="sm" onClick={() => setSelected([])}>{lang === "ar" ? "مسح الكل" : "Clear all"}</Button></div><div className="flex flex-wrap gap-2">{selected.map((t) => <span key={s(t, "id")} className="inline-flex items-center gap-1 rounded-full border bg-background px-2.5 py-1 text-xs">{lang === "ar" ? s(t, "name_ar") || s(t, "name") : s(t, "name")}<button type="button" onClick={() => toggle(t)} aria-label="remove"><X className="size-3" /></button></span>)}</div></div>}
        <div className="grid gap-3 sm:grid-cols-2"><label className="text-sm font-medium">{lang === "ar" ? "الأولوية" : "Priority"}<select className="mt-1 w-full rounded-md border bg-background p-2 font-normal" value={priority} onChange={(e) => setPriority(e.target.value)}><option value="normal">{lang === "ar" ? "عادي" : "Normal"}</option><option value="urgent">{lang === "ar" ? "عاجل" : "Urgent"}</option></select></label><label className="text-sm font-medium">{lang === "ar" ? "ملاحظات الطلب" : "Order notes"}<Textarea className="mt-1 font-normal" value={notes} onChange={(e) => setNotes(e.target.value)} /></label></div>
        <div className="flex justify-end"><Button disabled={create.isPending || !selected.length} onClick={() => create.mutate(undefined as never)}>{create.isPending ? (lang === "ar" ? "جاري الإنشاء..." : "Creating...") : (lang === "ar" ? "طلب الفحوصات وإنشاء الفاتورة" : "Order tests & create bill")}</Button></div>
      </CardContent>
    </Card>
  );
}
function rel(row: Row | undefined, key: string): Row { const x = row?.[key]; return (Array.isArray(x) ? x[0] : x) || {}; }
