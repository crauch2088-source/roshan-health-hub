import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/lib/auth";
import { s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

type Fields = Record<string, string>;

/** Clinical danger ranges for adult vitals — drives the red highlight. */
const DANGER: Record<string, (v: number) => boolean> = {
  bp_systolic: (v) => v < 90 || v >= 180,
  bp_diastolic: (v) => v < 60 || v >= 110,
  pulse: (v) => v < 50 || v > 120,
  respiratory_rate: (v) => v < 10 || v > 24,
  temperature: (v) => v < 35 || v >= 38.5,
  spo2: (v) => v < 92,
};

function isDanger(key: string, raw: string): boolean {
  const rule = DANGER[key];
  if (!rule || !raw.trim()) return false;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 && rule(value);
}

export function VitalsTab({ visitId }: { visitId: string }) {
  const { user } = useAuth();
  const { lang } = useLang();
  const [f, setF] = useState<Fields>({});

  const q = useRows<Row[]>(["vitals", visitId], () =>
    supabase
      .from("vitals")
      .select("*")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(1),
  );

  // Existing saved vitals are loaded into the form. Nothing is pre-filled
  // with "normal" values — placeholders only, so a normal reading is never
  // stored unless the clinician actually typed it.
  useEffect(() => {
    const row = ((q.data ?? []) as Row[])[0];
    if (!row) return;
    const next: Fields = {};
    for (const [key, value] of Object.entries(row)) next[key] = value == null ? "" : String(value);
    setF(next);
  }, [q.data]);

  const set = (key: string, value: string) => setF((prev) => ({ ...prev, [key]: value }));
  const get = (key: string) => f[key] ?? "";

  const bmi = useMemo(() => {
    const w = Number(get("weight"));
    const h = Number(get("height"));
    return w > 0 && h > 0 ? (w / (h / 100) ** 2).toFixed(1) : "";
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [f["weight"], f["height"]]);

  const lmp = get("lmp");
  const edd = lmp
    ? (() => {
        const d = new Date(`${lmp}T00:00:00`);
        d.setDate(d.getDate() + 280);
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
      })()
    : "";
  const ga = lmp
    ? Math.max(0, Math.floor((Date.now() - new Date(`${lmp}T00:00:00`).getTime()) / 86400000))
    : 0;

  const num = (key: string) => {
    const v = Number(get(key));
    return Number.isFinite(v) && get(key).trim() !== "" ? v : null;
  };

  const save = useSave(
    async () => {
      const existing = ((q.data ?? []) as Row[])[0];
      const payload = {
        visit_id: visitId,
        patient_id: get("patient_id") || null,
        bp_systolic: num("bp_systolic"),
        bp_diastolic: num("bp_diastolic"),
        systolic_bp: num("bp_systolic"),
        diastolic_bp: num("bp_diastolic"),
        pulse: num("pulse"),
        respiratory_rate: num("respiratory_rate"),
        temperature: num("temperature"),
        spo2: num("spo2"),
        weight: num("weight"),
        height: num("height"),
        bmi: bmi ? Number(bmi) : null,
        lmp: lmp || null,
        edd: edd || null,
        gestational_age_days: lmp ? ga : null,
        recorded_by: user?.id ?? null,
        updated_by: user?.id ?? null,
      };
      const builder = existing
        ? supabase.from("vitals").update(payload).eq("id", s(existing, "id"))
        : supabase.from("vitals").insert({ ...payload, created_by: user?.id ?? null });
      const { error } = await builder;
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["vitals", visitId]],
      successMessage: lang === "ar" ? "تم حفظ العلامات الحيوية" : "Vitals saved",
    },
  );

  const fields: { key: string; label: string; unit: string; placeholder: string; step?: string }[] = [
    { key: "bp_systolic", label: lang === "ar" ? "الضغط الانقباضي" : "BP systolic", unit: "mmHg", placeholder: "120" },
    { key: "bp_diastolic", label: lang === "ar" ? "الضغط الانبساطي" : "BP diastolic", unit: "mmHg", placeholder: "80" },
    { key: "pulse", label: lang === "ar" ? "النبض" : "Pulse", unit: "bpm", placeholder: "78" },
    { key: "respiratory_rate", label: lang === "ar" ? "معدل التنفس" : "Respiratory rate", unit: "/min", placeholder: "16" },
    { key: "temperature", label: lang === "ar" ? "الحرارة" : "Temperature", unit: "°C", placeholder: "36.8", step: "0.1" },
    { key: "spo2", label: "SpO₂", unit: "%", placeholder: "98" },
    { key: "weight", label: lang === "ar" ? "الوزن" : "Weight", unit: "kg", placeholder: "70", step: "0.1" },
    { key: "height", label: lang === "ar" ? "الطول" : "Height", unit: "cm", placeholder: "170" },
  ];

  const anyDanger = fields.some((x) => isDanger(x.key, get(x.key)));

  return (
    <Card>
      <CardContent className="space-y-4 p-4">
        {anyDanger ? (
          <div className="rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-sm font-medium text-destructive">
            {lang === "ar"
              ? "تحذير: توجد قيم حيوية خارج النطاق الآمن — راجع القيم المظللة بالأحمر."
              : "Warning: one or more vitals are outside the safe range — review the values highlighted in red."}
          </div>
        ) : null}

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {fields.map((x) => {
            const danger = isDanger(x.key, get(x.key));
            return (
              <label key={x.key} className="space-y-1 text-sm">
                <span className="font-medium">
                  {x.label} <span className="text-xs text-muted-foreground">({x.unit})</span>
                </span>
                <Input
                  dir="ltr"
                  type="number"
                  step={x.step ?? "1"}
                  placeholder={x.placeholder}
                  aria-invalid={danger}
                  value={get(x.key)}
                  onChange={(e) => set(x.key, e.target.value)}
                  className={
                    danger ? "border-destructive bg-destructive/10 focus-visible:ring-destructive" : undefined
                  }
                />
              </label>
            );
          })}

          <div className="rounded-lg border p-2 text-sm">
            BMI
            <div className="text-lg font-semibold">{bmi || "—"}</div>
          </div>

          <div className="rounded-lg border p-3 sm:col-span-2 lg:col-span-3">
            <div className="mb-2 font-medium">
              {lang === "ar" ? "حسابات الحمل" : "Obstetric calculation"}
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              <label className="space-y-1 text-sm">
                <span className="font-medium">LMP</span>
                <Input dir="ltr" type="date" value={lmp} onChange={(e) => set("lmp", e.target.value)} />
              </label>
              <div className="text-sm">
                EDD
                <div dir="ltr" className="font-semibold">
                  {edd || "—"}
                </div>
              </div>
              <div className="text-sm">
                GA
                <div className="font-semibold">{lmp ? `${Math.floor(ga / 7)}w ${ga % 7}d` : "—"}</div>
              </div>
            </div>
          </div>
        </div>

        <div className="flex justify-end">
          <Button disabled={save.isPending} onClick={() => save.mutate(undefined as never)}>
            {save.isPending
              ? lang === "ar"
                ? "جاري الحفظ..."
                : "Saving..."
              : lang === "ar"
                ? "حفظ العلامات الحيوية"
                : "Save vitals"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
