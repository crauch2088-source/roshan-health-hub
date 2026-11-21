import { useEffect, useMemo, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useLang } from "@/lib/i18n";
import {
  canFinalizeClinicianOrder,
  convertMgToMl,
  evaluateMedicationDecisionSupport,
  isRouteConsistentWithFormulation,
  validatePatientWeight,
} from "@/lib/medication-engine/pediatric-safety";

export interface PediatricSafetyPanelProps {
  patientAgeYears: number;
  weightKg: number | null;
  weightRecordedAt: string | null;
  dosageForm: string;
  route: string;
  clinicianEnteredDose: string;
  onConfirmationChange: (confirmed: boolean) => void;
}

type DoseBasisLabel = "mg_per_kg_per_dose" | "mg_per_kg_per_day";

export function PediatricSafetyPanel({
  patientAgeYears,
  weightKg,
  weightRecordedAt,
  dosageForm,
  route,
  clinicianEnteredDose,
  onConfirmationChange,
}: PediatricSafetyPanelProps) {
  const { lang } = useLang();
  const [basisLabel, setBasisLabel] = useState<DoseBasisLabel>("mg_per_kg_per_dose");
  const [doseMgText, setDoseMgText] = useState("");
  const [concMgText, setConcMgText] = useState("");
  const [concPerMlText, setConcPerMlText] = useState("5");
  const [clinicianConfirmed, setClinicianConfirmed] = useState(false);
  const [overrideReason, setOverrideReason] = useState("");

  const referenceTimeIso = useMemo(() => new Date().toISOString(), []);

  const weightCheck = useMemo(
    () => validatePatientWeight(weightKg, weightRecordedAt, referenceTimeIso),
    [weightKg, weightRecordedAt, referenceTimeIso],
  );

  const routeCompatible = useMemo(() => {
    if (!dosageForm || !route) return true;
    return isRouteConsistentWithFormulation(dosageForm, route);
  }, [dosageForm, route]);

  // Protocol remains explicitly null until qualified clinical sign-off activates a protocol.
  const recommendation = useMemo(
    () =>
      evaluateMedicationDecisionSupport({
        patientAgeYears,
        weightKg,
        weightRecordedAt,
        referenceTimeIso,
        dosageForm: dosageForm || "tablet",
        route: route || "oral",
        protocol: null,
        basis: null,
      }),
    [patientAgeYears, weightKg, weightRecordedAt, referenceTimeIso, dosageForm, route],
  );

  const conversion = useMemo(() => {
    const doseMg = Number(doseMgText);
    const mg = Number(concMgText);
    const perMl = Number(concPerMlText);
    if (!doseMgText || !concMgText || !concPerMlText) return null;
    return convertMgToMl(doseMg, mg, perMl);
  }, [doseMgText, concMgText, concPerMlText]);

  const canFinalize = useMemo(
    () =>
      canFinalizeClinicianOrder({
        recommendation,
        clinicianEnteredDose: clinicianEnteredDose || "manual-review",
        clinicianConfirmed,
        overrideReason: overrideReason.trim() || undefined,
      }),
    [recommendation, clinicianEnteredDose, clinicianConfirmed, overrideReason],
  );

  useEffect(() => {
    onConfirmationChange(canFinalize && weightCheck.valid && routeCompatible);
  }, [canFinalize, weightCheck.valid, routeCompatible, onConfirmationChange]);

  return (
    <div className="space-y-3 rounded-lg border border-amber-300 bg-amber-50/70 p-3 text-xs">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="font-semibold text-amber-950">
          {lang === "ar"
            ? "فحص سلامة وصفات الأطفال (غير مفعل للبروتوكولات التلقائية)"
            : "Pediatric Prescribing Safety Check (Manual Clinician Decision)"}
        </span>
        <Badge variant="outline" className="border-amber-500 text-amber-900">
          {lang === "ar"
            ? "البروتوكول غير معتمد للتفعيل"
            : "Protocol Activation Gated (Manual Only)"}
        </Badge>
      </div>

      <div className="grid gap-2 sm:grid-cols-2">
        <div>
          <span className="font-medium">{lang === "ar" ? "الوزن المسجل:" : "Recorded Weight:"}</span>{" "}
          {weightCheck.valid ? (
            <span className="text-emerald-800">
              {weightKg} kg ({lang === "ar" ? "صالح" : "Valid"})
            </span>
          ) : (
            <span className="font-semibold text-destructive">
              {lang === "ar"
                ? `الوزن غير صالح أو مفقود (${weightCheck.reason ?? "missing"}) — لا يمكن استبدال جرعة البالغين`
                : `Weight invalid/missing (${weightCheck.reason ?? "missing"}) — adult dose must not be substituted`}
            </span>
          )}
        </div>
        <div>
          <span className="font-medium">
            {lang === "ar" ? "توافق الشكل الدوائي وطريقة الإعطاء:" : "Formulation / Route Match:"}
          </span>{" "}
          {routeCompatible ? (
            <span className="text-emerald-800">{lang === "ar" ? "متوافق" : "Compatible"}</span>
          ) : (
            <span className="font-semibold text-destructive">
              {lang === "ar"
                ? `عدم توافق بين ${dosageForm} و ${route}`
                : `Mismatch between ${dosageForm} and ${route}`}
            </span>
          )}
        </div>
      </div>

      <div className="grid gap-2 sm:grid-cols-4">
        <Select value={basisLabel} onValueChange={(v) => setBasisLabel(v as DoseBasisLabel)}>
          <SelectTrigger className="h-8 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="mg_per_kg_per_dose">
              {lang === "ar" ? "ملغ/كغ/جرعة (mg/kg/dose)" : "mg/kg/dose (per single dose)"}
            </SelectItem>
            <SelectItem value="mg_per_kg_per_day">
              {lang === "ar" ? "ملغ/كغ/يوم (mg/kg/day)" : "mg/kg/day (total daily divided)"}
            </SelectItem>
          </SelectContent>
        </Select>
        <Input
          type="number"
          min={0}
          step="0.1"
          className="h-8 text-xs"
          placeholder={
            basisLabel === "mg_per_kg_per_dose"
              ? lang === "ar"
                ? "الجرعة الواحدة (mg)"
                : "Single dose (mg)"
              : lang === "ar"
                ? "إجمالي اليوم (mg/day)"
                : "Total daily (mg/day)"
          }
          value={doseMgText}
          onChange={(e) => setDoseMgText(e.target.value)}
        />
        <Input
          type="number"
          min={0}
          step="0.1"
          className="h-8 text-xs"
          placeholder={lang === "ar" ? "التركيز (mg)" : "Conc (mg)"}
          value={concMgText}
          onChange={(e) => setConcMgText(e.target.value)}
        />
        <Input
          type="number"
          min={0.1}
          step="0.1"
          className="h-8 text-xs"
          placeholder={lang === "ar" ? "لكل (mL)" : "Per (mL)"}
          value={concPerMlText}
          onChange={(e) => setConcPerMlText(e.target.value)}
        />
      </div>

      {conversion ? (
        <div className="text-xs">
          {conversion.valid ? (
            <span className="font-medium text-emerald-900">
              {lang === "ar"
                ? `التحويل المحسوب: ${conversion.volumeMl} mL (${basisLabel === "mg_per_kg_per_dose" ? "لكل جرعة" : "لليوم الكامل"})`
                : `Calculated volume: ${conversion.volumeMl} mL (${basisLabel === "mg_per_kg_per_dose" ? "per dose" : "per day"})`}
            </span>
          ) : (
            <span className="text-destructive">
              {lang === "ar"
                ? `خطأ في التحويل: ${conversion.reason}`
                : `Conversion invalid: ${conversion.reason}`}
            </span>
          )}
        </div>
      ) : null}

      <div className="grid gap-2 sm:grid-cols-2">
        <label className="flex items-center gap-2 font-medium text-amber-950">
          <input
            type="checkbox"
            checked={clinicianConfirmed}
            onChange={(e) => setClinicianConfirmed(e.target.checked)}
          />
          {lang === "ar"
            ? "أؤكد مراجعة وزن الطفل والجرعة يدوياً (لا يوجد صرف تلقائي)"
            : "I confirm manual clinician review of pediatric weight and dose"}
        </label>
        <Input
          className="h-8 text-xs"
          placeholder={
            lang === "ar" ? "ملاحظة/مبرر الطبيب (اختياري)" : "Clinician decision note (optional)"
          }
          value={overrideReason}
          onChange={(e) => setOverrideReason(e.target.value)}
        />
      </div>
    </div>
  );
}
