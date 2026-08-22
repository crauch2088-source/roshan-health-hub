import { useMemo, useState } from "react";
import { Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rel, rpc, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

const FALLBACK_CATEGORIES = ["Haematology", "Chemistry", "Parasitology", "Serology", "Microscopy", "Microbiology", "Other"];

export function LaboratoryTab({ visitId }: { visitId: string }) {
  const { user } = useAuth();
  const { lang } = useLang();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("all");
  const [selected, setSelected] = useState<Row[]>([]);
  const [priority, setPriority] = useState("normal");
  const [notes, setNotes] = useState("");

  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () =>
    supabase.from("visits").select("id,patient_id,patients(id,full_name)").eq("id", visitId).limit(1),
  );
  const patient = rel((visitQ.data ?? [])[0] as Row | undefined, "patients");

  const testsQ = useRows<Row[]>(["clinic-lab-tests"], () =>
    supabase.from("lab_tests").select("id,name,name_ar,code,price,category").eq("active", true).is("deleted_at", null).order("category").order("name").limit(300),
  );

  const tests = (testsQ.data ?? []) as Row[];
  const categories = useMemo(() => {
    const found = tests.map((t) => s(t, "category").trim()).filter(Boolean);
    return ["all", ...Array.from(new Set([...found, ...FALLBACK_CATEGORIES]))];
  }, [tests]);
  const visibleTests = useMemo(() => {
    const term = search.trim().toLowerCase();
    return tests.filter((test) => {
      if (category !== "all" && s(test, "category") !== category) return false;
      if (!term) return true;
      return `${s(test, "name")} ${s(test, "name_ar")} ${s(test, "code")} ${s(test, "category")}`.toLowerCase().includes(term);
    });
  }, [tests, search, category]);

  const toggle = (test: Row) => {
    const id = s(test, "id");
    setSelected((current) => current.some((x) => s(x, "id") === id) ? current.filter((x) => s(x, "id") !== id) : [...current, test]);
  };

  const create = useSave(async () => {
    if (!s(patient, "id")) throw new Error("Patient not found");
    if (!selected.length) throw new Error(lang === "ar" ? "اختر فحصاً واحداً على الأقل" : "Select at least one test");
    const { data: order, error } = await supabase.from("lab_orders").insert({ patient_id: s(patient, "id"), visit_id: visitId, ordered_by: user?.id ?? null, status: "ordered", priority, notes: notes.trim() || null, created_by: user?.id ?? null }).select("id").single();
    if (error) throw new Error(error.message);
    const items = selected.map((t) => ({ order_id: order.id, test_id: s(t, "id"), price: n(t, "price"), created_by: user?.id ?? null }));
    const { error: itemError } = await supabase.from("lab_order_items").insert(items);
    if (itemError) throw new Error(itemError.message);
    const total = selected.reduce((a, t) => a + n(t, "price"), 0);
    if (total > 0) {
      const invoiceNumber = await rpc<string>("next_invoice_number");
      const { data: inv, error: invError } = await supabase.from("invoices").insert({ invoice_number: invoiceNumber, patient_id: s(patient, "id"), visit_id: visitId, invoice_date: new Date().toISOString().slice(0, 10), total_amount: total, subtotal: total, discount_amount: 0, net_amount: total, paid_amount: 0, status: "unpaid", payment_status: "unpaid", created_by: user?.id ?? null }).select("id").single();
      if (invError) throw new Error(invError.message);
      const rows = selected.map((t) => ({ invoice_id: inv.id, item_type: "laboratory", item_name: s(t, "name"), quantity: 1, unit_price: n(t, "price"), total_price: n(t, "price"), item_id: s(t, "id"), created_by: user?.id ?? null }));
      const { error: e } = await supabase.from("invoice_items").insert(rows);
      if (e) throw new Error(e.message);
    }
    setSelected([]); setNotes(""); setSearch("");
    return order.id;
  }, { invalidate: [["lab-orders"], ["lab-orders", visitId], ["patient-labs", s(patient, "id")], ["invoices"]], successMessage: lang === "ar" ? "تم إرسال طلب المختبر وإنشاء الفاتورة" : "Lab order created and invoice generated" });

  return <Card><CardContent className="space-y-4 p-4">
    <div className="flex flex-wrap items-center justify-between gap-2"><div className="font-semibold">{lang === "ar" ? "اختيار الفحوصات" : "Laboratory tests"}</div><span className="rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold">{selected.length} {lang === "ar" ? "مختار" : "selected"}</span></div>
    <div className="relative"><Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"/><Input className="ps-9" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={lang === "ar" ? "ابحث باسم الفحص أو الكود أو التصنيف" : "Search test, code or category"}/></div>
    <div className="flex gap-2 overflow-x-auto pb-1">{categories.map((c) => <button type="button" key={c} onClick={() => setCategory(c)} className={`whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium ${category === c ? "border-primary bg-primary text-primary-foreground" : "bg-background hover:bg-muted"}`}>{c === "all" ? (lang === "ar" ? "كل الفحوصات" : "All tests") : c}</button>)}</div>
    <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">{visibleTests.map((test) => { const chosen = selected.some((x) => s(x, "id") === s(test, "id")); return <button type="button" key={s(test, "id")} onClick={() => toggle(test)} className={`rounded-xl border p-3 text-start transition ${chosen ? "border-primary bg-primary/10 ring-1 ring-primary/30" : "hover:border-primary/40 hover:bg-muted/40"}`}><div className="flex items-start justify-between gap-2"><div><div className="font-medium">{lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")}</div><div className="mt-1 text-xs text-muted-foreground">{s(test, "category") || "Other"} · {s(test, "code") || "—"}</div></div><span className="text-sm font-semibold">{n(test, "price")}</span></div></button> })}</div>
    {selected.length > 0 && <div className="rounded-xl border bg-muted/20 p-3"><div className="mb-2 font-medium">{lang === "ar" ? "الفحوصات المختارة" : "Selected tests"}</div><div className="flex flex-wrap gap-2">{selected.map((test) => <span key={s(test, "id")} className="inline-flex items-center gap-1 rounded-full bg-background px-2.5 py-1 text-xs shadow-sm">{lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")}<button type="button" onClick={() => toggle(test)} aria-label="remove"><X className="size-3"/></button></span>)}</div></div>}
    <div className="grid gap-3 sm:grid-cols-2"><label className="text-sm font-medium">{lang === "ar" ? "الأولوية" : "Priority"}<select className="mt-1 w-full rounded-md border bg-background p-2" value={priority} onChange={(e) => setPriority(e.target.value)}><option value="normal">{lang === "ar" ? "عادي" : "Normal"}</option><option value="urgent">{lang === "ar" ? "عاجل" : "Urgent"}</option></select></label><label className="text-sm font-medium">{lang === "ar" ? "ملاحظات الطلب" : "Order notes"}<Textarea className="mt-1" value={notes} onChange={(e) => setNotes(e.target.value)} /></label></div>
    <div className="flex justify-end"><Button disabled={create.isPending || !selected.length} onClick={() => create.mutate(undefined as never)}>{create.isPending ? "Saving..." : lang === "ar" ? "طلب الفحوصات وإنشاء الفاتورة" : "Order tests & create invoice"}</Button></div>
  </CardContent></Card>;
}
