import { useMemo, useRef, useState } from "react";
import { Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { sanitizeTerm, useDebounced } from "@/lib/search";
import { n, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

const CATEGORY_ORDER = [
  "Hematology",
  "Clinical Chemistry",
  "Hormones",
  "Microbiology",
  "Serology",
  "Immunology",
  "Urinalysis",
  "Parasitology",
  "Other",
];
const CATEGORY_AR: Record<string, string> = {
  Hematology: "أمراض الدم",
  "Clinical Chemistry": "الكيمياء السريرية",
  Hormones: "الهرمونات",
  Microbiology: "الأحياء الدقيقة",
  Serology: "السيرولوجي",
  Immunology: "المناعة",
  Urinalysis: "تحليل البول",
  Parasitology: "الطفيليات",
  Other: "أخرى",
};

function normalizeCategory(value: string) {
  const v = value.trim();
  if (!v) return "Other";
  const lower = v.toLowerCase();
  if (lower.includes("hemat") || lower.includes("cbc") || lower.includes("blood"))
    return "Hematology";
  if (
    lower.includes("chem") ||
    lower.includes("liver") ||
    lower.includes("renal") ||
    lower.includes("kidney") ||
    lower.includes("lipid")
  )
    return "Clinical Chemistry";
  if (lower.includes("horm")) return "Hormones";
  if (lower.includes("micro") || lower.includes("culture")) return "Microbiology";
  if (
    lower.includes("sero") ||
    lower.includes("viral") ||
    lower.includes("hepat") ||
    lower.includes("hiv")
  )
    return "Serology";
  if (lower.includes("immun")) return "Immunology";
  if (lower.includes("urine") || lower.includes("urin")) return "Urinalysis";
  if (lower.includes("paras") || lower.includes("malaria")) return "Parasitology";
  return v;
}

export function LaboratoryTab({ visitId }: { visitId: string }) {
  const { lang } = useLang();
  const { can } = useAuth();
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search, 280);
  const safeSearch = sanitizeTerm(debouncedSearch);
  const [category, setCategory] = useState("all");
  const [selected, setSelected] = useState<Row[]>([]);
  const [priority, setPriority] = useState("normal");
  const [notes, setNotes] = useState("");
  const [separateInvoice, setSeparateInvoice] = useState(false);
  const pendingRequestRef = useRef<{ fingerprint: string; id: string } | null>(null);

  const visitQ = useRows<Row[]>(["clinic-visit", visitId], () =>
    supabase
      .from("visits")
      .select("id,patient_id,patients(id,full_name)")
      .eq("id", visitId)
      .limit(1),
  );
  const visit = (visitQ.data ?? [])[0] as Row | undefined;
  const patient = rel(visit, "patients");

  const testsQ = useRows<Row[]>(["clinic-lab-tests", safeSearch], () => {
    let q = supabase
      .from("lab_tests")
      .select("id,name,name_ar,code,price,category")
      .eq("active", true)
      .is("deleted_at", null)
      .order("name")
      .limit(300);
    const term = safeSearch;
    if (term)
      q = q.or(
        `name.ilike.%${term}%,name_ar.ilike.%${term}%,code.ilike.%${term}%,category.ilike.%${term}%`,
      );
    return q;
  });

  const tests = useMemo(() => (testsQ.data ?? []) as Row[], [testsQ.data]);
  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const test of tests) set.add(normalizeCategory(s(test, "category")));
    return [
      "all",
      ...CATEGORY_ORDER.filter((x) => x !== "Other" && set.has(x)),
      ...Array.from(set).filter((x) => !CATEGORY_ORDER.includes(x) && x !== "all"),
    ];
  }, [tests]);
  const visible = useMemo(
    () =>
      tests.filter(
        (test) => category === "all" || normalizeCategory(s(test, "category")) === category,
      ),
    [tests, category],
  );

  const selectedIds = new Set(selected.map((x) => s(x, "id")));
  const profiles = useMemo(() => {
    const by = (words: string[]) =>
      tests.filter((t) =>
        words.some((w) =>
          `${s(t, "name")} ${s(t, "name_ar")} ${s(t, "code")}`.toLowerCase().includes(w),
        ),
      );
    return [
      {
        id: "cbc",
        label: lang === "ar" ? "CBC / صورة الدم" : "CBC profile",
        tests: by(["cbc", "complete blood count"]),
      },
      {
        id: "renal",
        label: lang === "ar" ? "وظائف الكلى" : "Renal profile",
        tests: by(["creatinine", "urea", "renal", "kidney"]),
      },
      {
        id: "liver",
        label: lang === "ar" ? "وظائف الكبد" : "Liver profile",
        tests: by(["lft", "alt", "ast", "bilirubin", "liver"]),
      },
      {
        id: "glucose",
        label: lang === "ar" ? "السكري" : "Glucose profile",
        tests: by(["glucose", "fbs", "rbs", "hba1c"]),
      },
    ].filter((p) => p.tests.length);
  }, [tests, lang]);

  const toggle = (test: Row) =>
    setSelected((current) =>
      selectedIds.has(s(test, "id"))
        ? current.filter((x) => s(x, "id") !== s(test, "id"))
        : [...current, test],
    );
  const addProfile = (profile: { tests: Row[] }) =>
    setSelected((current) => {
      const map = new Map(current.map((x) => [s(x, "id"), x]));
      profile.tests.forEach((x) => map.set(s(x, "id"), x));
      return Array.from(map.values());
    });

  const create = useSave(
    async () => {
      if (!s(patient, "id"))
        throw new Error(lang === "ar" ? "المريض غير موجود" : "Patient not found");
      if (!selected.length)
        throw new Error(lang === "ar" ? "اختر فحصاً واحداً على الأقل" : "Select at least one test");
      const testIds = selected.map((test) => s(test, "id"));
      const fingerprint = JSON.stringify({
        visitId,
        priority,
        notes: notes || null,
        testIds,
        separateInvoice,
      });
      if (pendingRequestRef.current?.fingerprint !== fingerprint) {
        pendingRequestRef.current = { fingerprint, id: crypto.randomUUID() };
      }
      const requestId = pendingRequestRef.current.id;
      const { data: orderId, error } = await supabase.rpc("create_lab_order_with_invoice_atomic", {
        p_visit_id: visitId,
        p_priority: priority,
        p_notes: notes || null,
        p_test_ids: testIds,
        p_separate_invoice: separateInvoice,
        p_request_id: requestId,
      });
      if (error) throw new Error(error.message);
      pendingRequestRef.current = null;
      setSelected([]);
      setNotes("");
      setSeparateInvoice(false);
      return orderId as string;
    },
    {
      invalidate: [
        ["lab-orders"],
        ["lab-orders", visitId],
        ["patient-labs", s(patient, "id")],
        ["invoices"],
      ],
      successMessage: lang === "ar" ? "تم إرسال طلب المختبر" : "Lab order created",
    },
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {lang === "ar" ? "اختيار الفحوصات" : "Select investigations"}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 p-4">
        {visitQ.error ? (
          <div role="alert" className="space-y-2">
            <p>
              {lang === "ar" ? "تعذّر تحميل بيانات الزيارة." : "Could not load visit details."}
            </p>
            <Button variant="outline" size="sm" onClick={() => void visitQ.refetch()}>
              {lang === "ar" ? "إعادة المحاولة" : "Retry visit"}
            </Button>
          </div>
        ) : null}
        <div className="grid gap-2 lg:grid-cols-[1fr_auto]">
          <div className="relative">
            <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              className="ps-9"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={
                lang === "ar"
                  ? "ابحث باسم الفحص أو الرمز أو التصنيف"
                  : "Search test, code or category"
              }
            />
          </div>
          <select
            className="rounded-md border bg-background px-3 py-2 text-sm"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            <option value="all">{lang === "ar" ? "كل التصنيفات" : "All categories"}</option>
            {categories
              .filter((x) => x !== "all")
              .map((x) => (
                <option key={x} value={x}>
                  {lang === "ar" ? (CATEGORY_AR[x] ?? x) : x}
                </option>
              ))}
          </select>
        </div>
        {profiles.length > 0 && (
          <div>
            <div className="mb-2 text-xs font-medium text-muted-foreground">
              {lang === "ar" ? "حزم سريعة" : "Quick profiles"}
            </div>
            <div className="flex flex-wrap gap-2">
              {profiles.map((p) => (
                <Button
                  key={p.id}
                  type="button"
                  size="sm"
                  variant="secondary"
                  onClick={() => addProfile(p)}
                >
                  {p.label} <span className="ms-1 text-xs opacity-70">{p.tests.length}</span>
                </Button>
              ))}
            </div>
          </div>
        )}
        {testsQ.isLoading ? (
          <p
            role="status"
            className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground"
          >
            {lang === "ar" ? "جارٍ تحميل قائمة التحاليل…" : "Loading test catalogue…"}
          </p>
        ) : testsQ.error ? (
          <div
            role="alert"
            className="rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive"
          >
            <p>
              {lang === "ar"
                ? "تعذّر تحميل قائمة التحاليل. لم يتم إرسال أي طلب؛ حاول مجددًا."
                : "Could not load the test catalogue. No order was submitted; please retry."}
            </p>
            <Button variant="outline" size="sm" onClick={() => void testsQ.refetch()}>
              {lang === "ar" ? "إعادة المحاولة" : "Retry test catalogue"}
            </Button>
          </div>
        ) : null}
        <div className="grid gap-4 lg:grid-cols-2">
          {categories
            .filter((x) => x !== "all")
            .map((cat) => {
              const group = visible.filter((t) => normalizeCategory(s(t, "category")) === cat);
              if (!group.length) return null;
              return (
                <div
                  key={cat}
                  className="overflow-hidden rounded-xl border border-border/80 bg-card/75 shadow-sm"
                >
                  <div className="flex items-center justify-between border-b bg-muted/45 px-3 py-2.5">
                    <span className="font-medium">
                      {lang === "ar" ? (CATEGORY_AR[cat] ?? cat) : cat}
                    </span>
                    <span className="text-xs text-muted-foreground">{group.length}</span>
                  </div>
                  <div className="grid gap-2 p-2">
                    {group.map((test) => {
                      const chosen = selectedIds.has(s(test, "id"));
                      return (
                        <button
                          type="button"
                          key={s(test, "id")}
                          onClick={() => toggle(test)}
                          className={`min-h-[4.5rem] rounded-xl border p-3 text-start transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 ${chosen ? "border-primary bg-primary/8 shadow-sm ring-1 ring-primary/15" : "border-border/80 bg-background/75 hover:border-primary/35 hover:bg-muted/50"}`}
                          aria-pressed={chosen}
                        >
                          <div className="flex items-start justify-between gap-2">
                            <div className="font-medium">
                              {lang === "ar"
                                ? s(test, "name_ar") || s(test, "name")
                                : s(test, "name")}
                            </div>
                            {chosen && <span className="text-xs text-primary">✓</span>}
                          </div>
                          <div className="mt-1 text-xs text-muted-foreground" dir="ltr">
                            {s(test, "code") || "—"} · {n(test, "price")}
                          </div>
                        </button>
                      );
                    })}
                  </div>
                </div>
              );
            })}
        </div>
        {!testsQ.isLoading && !testsQ.error && !visible.length && (
          <div className="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
            {lang === "ar" ? "لا توجد فحوصات مطابقة" : "No matching tests"}
          </div>
        )}
        {selected.length > 0 && (
          <div className="roshan-surface space-y-3 p-4 lg:sticky lg:bottom-3">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="font-bold">
                  {lang === "ar"
                    ? `الفحوصات المختارة (${selected.length})`
                    : `Selected tests (${selected.length})`}
                </div>
                <div className="mt-1 text-xs text-muted-foreground">
                  {lang === "ar"
                    ? "المجموع التقديري للفحوصات المحددة"
                    : "Estimated selected-test subtotal"}
                </div>
                <div className="mt-0.5 text-lg font-bold tabular-nums text-primary" dir="ltr">
                  {selected
                    .reduce((sum, item) => sum + n(item, "price"), 0)
                    .toLocaleString(undefined, { maximumFractionDigits: 2 })}
                </div>
              </div>
              <Button type="button" variant="ghost" size="sm" onClick={() => setSelected([])}>
                {lang === "ar" ? "مسح الكل" : "Clear all"}
              </Button>
            </div>
            <div className="flex flex-wrap gap-2">
              {selected.map((t) => (
                <span
                  key={s(t, "id")}
                  className="inline-flex items-center gap-1 rounded-full border bg-background px-2.5 py-1 text-xs"
                >
                  {lang === "ar" ? s(t, "name_ar") || s(t, "name") : s(t, "name")}
                  <button
                    type="button"
                    onClick={() => toggle(t)}
                    aria-label={
                      lang === "ar"
                        ? `إزالة ${s(t, "name_ar") || s(t, "name")}`
                        : `Remove ${s(t, "name")}`
                    }
                    className="rounded-full p-1 text-muted-foreground hover:bg-destructive/10 hover:text-destructive focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    <X className="size-3" />
                  </button>
                </span>
              ))}
            </div>
          </div>
        )}
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="text-sm font-medium">
            {lang === "ar" ? "الأولوية" : "Priority"}
            <select
              className="mt-1 w-full rounded-md border bg-background p-2 font-normal"
              value={priority}
              onChange={(e) => setPriority(e.target.value)}
            >
              <option value="normal">{lang === "ar" ? "عادي" : "Normal"}</option>
              <option value="urgent">{lang === "ar" ? "عاجل" : "Urgent"}</option>
            </select>
            {priority === "urgent" ? (
              <span className="mt-1 block text-xs font-medium text-warning-foreground">
                {lang === "ar"
                  ? "تأكد من وجود مبرر سريري للأولوية العاجلة وفق بروتوكول المركز."
                  : "Use urgent priority only when clinically justified under the center protocol."}
              </span>
            ) : null}
          </label>
          <label className="text-sm font-medium">
            {lang === "ar" ? "ملاحظات الطلب" : "Order notes"}
            <Textarea
              className="mt-1 font-normal"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </label>
        </div>
        <div className="flex flex-wrap justify-end gap-2">
          {can("billing.create") ? (
            <Button
              type="button"
              variant={separateInvoice ? "default" : "outline"}
              onClick={() => setSeparateInvoice((current) => !current)}
              aria-pressed={separateInvoice}
            >
              {lang === "ar" ? "إنشاء فاتورة منفصلة" : "Create separate invoice"}
            </Button>
          ) : null}
          <Button
            disabled={
              create.isPending || !selected.length || !s(patient, "id") || Boolean(testsQ.error)
            }
            onClick={() => create.mutate(undefined as never)}
          >
            {create.isPending
              ? lang === "ar"
                ? "جاري الإنشاء..."
                : "Creating..."
              : lang === "ar"
                ? "طلب الفحوصات وإنشاء الفاتورة"
                : "Order tests & create bill"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
function rel(row: Row | undefined, key: string): Row {
  const x = row?.[key];
  return (Array.isArray(x) ? x[0] : x) || {};
}
