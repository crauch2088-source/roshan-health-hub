import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, Plus, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
  SectionTitle,
  StatusBadge,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import {
  calcAge,
  calcBmi,
  calcEdd,
  calcGestationalDays,
  formatDate,
  formatDateTime,
  formatGestationalAge,
} from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/clinic_/$visitId")({
  head: () => ({
    meta: [
      {
        title: "Consultation — ROSHAN Medical Center",
      },
      {
        name: "description",
        content:
          "Record vitals, clinical notes, diagnoses, lab orders and prescriptions.",
      },
      {
        property: "og:title",
        content: "Consultation — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Record vitals, clinical notes, diagnoses, lab orders and prescriptions.",
      },
    ],
  }),
  component: Consultation,
});

type RxItem = {
  medicine_id: string;
  dosage: string;
  frequency: string;
  duration: string;
  quantity: string;
};

function Consultation() {
  const { visitId } = useParams({
    from: "/_authenticated/clinic_/$visitId",
  });

  const { t, lang } = useLang();
  const { can, user } = useAuth();

  const visitQ = useRows(["visit", visitId], () =>
    supabase
      .from("visits")
      .select(
        "id, visit_number, visit_date, status, patient_id, doctor_id, patients(id, full_name, mrn, gender, date_of_birth, blood_group), departments(name, name_ar)",
      )
      .eq("id", visitId)
      .limit(1),
  );

  const visit = ((visitQ.data ?? []) as Row[])[0];
  const patient = rel(visit, "patients");
  const patientId = s(patient, "id");
  const isFemale = s(patient, "gender") === "female";

  const [vitals, setVitals] = useState<Row>({});
  const [clinicalNote, setClinicalNote] = useState<Row>({});
  const [labSel, setLabSel] = useState<string[]>([]);
  const [rx, setRx] = useState<RxItem[]>([]);
  const [rxExternal, setRxExternal] = useState(false);

  /*
   * VITALS
   */
  const vitalsQ = useRows(["vitals", visitId], () =>
    supabase
      .from("vitals")
      .select("*")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .limit(1),
  );

  /*
   * CLINICAL NOTES
   *
   * The actual database table is clinical_notes,
   * not medical_records.
   */
  const clinicalNoteQ = useRows(["clinical-note", visitId], () =>
    supabase
      .from("clinical_notes")
      .select("*")
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .limit(1),
  );

  /*
   * LAB TESTS
   */
  const testsQ = useRows(["lab-tests"], () =>
    supabase
      .from("lab_tests")
      .select("id, name, name_ar, price, category, active")
      .eq("active", true)
      .is("deleted_at", null),
  );

  /*
   * MEDICINES
   *
   * Only use columns that actually exist in medicines.
   */
  const medsQ = useRows(["medicines"], () =>
    supabase
      .from("medicines")
      .select(
        "id, name, generic_name, brand_name, strength, dosage_form, unit",
      )
      .eq("active", true)
      .is("deleted_at", null),
  );

  /*
   * LAB ORDERS
   *
   * Actual relationship:
   * lab_order_items.order_id -> lab_orders.id
   * lab_order_items.test_id  -> lab_tests.id
   */
  const ordersQ = useRows(["visit-labs", visitId], () =>
    supabase
      .from("lab_orders")
      .select(
        "id, status, created_at, lab_order_items(id, status, price, lab_tests(name, name_ar))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  /*
   * PRESCRIPTIONS
   */
  const rxQ = useRows(["visit-rx", visitId], () =>
    supabase
      .from("prescriptions")
      .select(
        "id, status, is_external, created_at, prescription_items(id, dosage, dose, frequency, duration, quantity, medicines(name, generic_name, brand_name))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );

  /*
   * CLINICAL HISTORY
   *
   * clinical_notes does not have patient_id.
   * The patient is reached through visits.
   */
  const historyQ = useRows(
    ["clinical-history", patientId],
    () =>
      supabase
        .from("clinical_notes")
        .select(
          "id, created_at, chief_complaint, assessment, visit_id, visits!inner(patient_id)",
        )
        .eq("visits.patient_id", patientId)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(20),
    {
      enabled: Boolean(patientId),
    },
  );

  /*
   * LOAD VITALS
   */
  useEffect(() => {
    const v = ((vitalsQ.data ?? []) as Row[])[0];

    if (v) {
      setVitals(v);
    }
  }, [vitalsQ.data]);

  /*
   * LOAD CLINICAL NOTE
   */
  useEffect(() => {
    const note = ((clinicalNoteQ.data ?? []) as Row[])[0];

    if (note) {
      setClinicalNote(note);
    }
  }, [clinicalNoteQ.data]);

  /*
   * SAVE VITALS
   */
  const saveVitals = useSave(
    async () => {
      const weight = Number(s(vitals, "weight")) || null;
      const height = Number(s(vitals, "height")) || null;

      const bmi = calcBmi(
        Number(s(vitals, "weight")),
        Number(s(vitals, "height")),
      );

      const bpValue = s(vitals, "blood_pressure");

      let systolicBp: number | null = null;
      let diastolicBp: number | null = null;

      if (bpValue.includes("/")) {
        const [sys, dia] = bpValue.split("/");

        systolicBp = Number(sys) || null;
        diastolicBp = Number(dia) || null;
      }

      const payload = {
        visit_id: visitId,
        patient_id: patientId,
        temperature:
          Number(s(vitals, "temperature")) || null,
        pulse: Number(s(vitals, "pulse")) || null,
        respiratory_rate:
          Number(s(vitals, "respiratory_rate")) || null,
        systolic_bp: systolicBp,
        diastolic_bp: diastolicBp,
        bp_systolic: systolicBp,
        bp_diastolic: diastolicBp,
        weight,
        height,
        bmi: bmi ?? null,
        spo2: Number(s(vitals, "spo2")) || null,
        lmp: s(vitals, "lmp") || null,
        edd: s(vitals, "edd") || null,
        gestational_age_days:
          Number(s(vitals, "gestational_age_days")) || null,
        recorded_by: user?.id ?? null,
      };

      const existing = ((vitalsQ.data ?? []) as Row[])[0];

      const q = existing
        ? supabase
            .from("vitals")
            .update(payload)
            .eq("id", s(existing, "id"))
        : supabase.from("vitals").insert(payload);

      const { error } = await q;

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["vitals", visitId]],
      successMessage: t("saved"),
    },
  );

  /*
   * SAVE CLINICAL NOTE
   */
  const saveClinicalNote = useSave(
    async () => {
      const lmp = s(clinicalNote, "lmp");

      const gestationalDays = calcGestationalDays(lmp);

      const edd = calcEdd(lmp);

      const payload = {
        visit_id: visitId,
        doctor_id: user?.id ?? null,
        created_by: user?.id ?? null,
        updated_by: user?.id ?? null,

        chief_complaint:
          s(clinicalNote, "chief_complaint") || null,

        history_present_illness:
          s(clinicalNote, "history_present_illness") ||
          s(clinicalNote, "hpi") ||
          null,

        hpi:
          s(clinicalNote, "hpi") ||
          s(clinicalNote, "history_present_illness") ||
          null,

        examination:
          s(clinicalNote, "examination") || null,

        assessment:
          s(clinicalNote, "assessment") ||
          null,

        plan:
          s(clinicalNote, "plan") ||
          null,

        allergy_history:
          s(clinicalNote, "allergy_history") ||
          null,

        past_medical_history:
          s(clinicalNote, "past_medical_history") ||
          null,

        lmp: lmp || null,
        edd: edd || null,
        gestational_age_days:
          gestationalDays ?? null,
      };

      const existing =
        ((clinicalNoteQ.data ?? []) as Row[])[0];

      const q = existing
        ? supabase
            .from("clinical_notes")
            .update(payload)
            .eq("id", s(existing, "id"))
        : supabase
            .from("clinical_notes")
            .insert(payload);

      const { error } = await q;

      if (error) {
        throw new Error(error.message);
      }

      const { error: visitError } = await supabase
        .from("visits")
        .update({
          status: "completed",
          completed_at: new Date().toISOString(),
          updated_by: user?.id ?? null,
        })
        .eq("id", visitId);

      if (visitError) {
        throw new Error(visitError.message);
      }

      return null;
    },
    {
      invalidate: [
        ["clinical-note", visitId],
        ["visit", visitId],
        ["clinical-history", patientId],
      ],
      successMessage: t("saved"),
    },
  );

  /*
   * ORDER LAB TESTS
   */
  const orderLabs = useSave(
    async () => {
      const { data: order, error } = await supabase
        .from("lab_orders")
        .insert({
          visit_id: visitId,
          patient_id: patientId,
          ordered_by: user?.id ?? null,
          created_by: user?.id ?? null,
          status: "ordered",
          priority: "normal",
        })
        .select("id")
        .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!order) {
        throw new Error(
          "Failed to create laboratory order.",
        );
      }

      const items = labSel.map((testId) => {
        const test = (
          (testsQ.data ?? []) as Row[]
        ).find((x) => s(x, "id") === testId);

        return {
          order_id: order.id,
          test_id: testId,
          price: n(test, "price"),
          status: "pending",
          created_by: user?.id ?? null,
        };
      });

      if (items.length > 0) {
        const { error: itemError } = await supabase
          .from("lab_order_items")
          .insert(items);

        if (itemError) {
          throw new Error(itemError.message);
        }
      }

      return null;
    },
    {
      invalidate: [
        ["visit-labs", visitId],
        ["lab-orders"],
      ],
      successMessage: t("saved"),
      onDone: () => setLabSel([]),
    },
  );

  /*
   * SAVE PRESCRIPTION
   */
  const saveRx = useSave(
    async () => {
      const { data: pres, error } = await supabase
        .from("prescriptions")
        .insert({
          visit_id: visitId,
          patient_id: patientId,
          prescribed_by: user?.id ?? null,
          doctor_id: user?.id ?? null,
          prescription_type: rxExternal
            ? "external"
            : "internal",
          is_external: rxExternal,
          status: rxExternal
            ? "external"
            : "pending",
          created_by: user?.id ?? null,
        })
        .select("id")
        .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!pres) {
        throw new Error(
          "Failed to create prescription.",
        );
      }

      const items = rx
        .filter((r) => r.medicine_id)
        .map((r) => ({
          prescription_id: pres.id,
          medicine_id: r.medicine_id,
          medication_name:
            (
              (
                (medsQ.data ?? []) as Row[]
              ).find(
                (m) =>
                  s(m, "id") === r.medicine_id,
              )
            )?.name ?? null,
          dose: r.dosage || null,
          dosage: r.dosage || null,
          frequency: r.frequency || null,
          duration: r.duration || null,
          quantity:
            Number(r.quantity) || 1,
          created_by: user?.id ?? null,
        }));

      if (items.length > 0) {
        const { error: itemError } = await supabase
          .from("prescription_items")
          .insert(items);

        if (itemError) {
          throw new Error(itemError.message);
        }
      }

      return null;
    },
    {
      invalidate: [
        ["visit-rx", visitId],
        ["pharmacy-queue"],
      ],
      successMessage: t("saved"),
      onDone: () => {
        setRx([]);
        setRxExternal(false);
      },
    },
  );

  /*
   * LOADING / EMPTY
   */
  if (visitQ.isLoading) {
    return <Loading />;
  }

  if (!visit) {
    return <Empty label={t("no_data")} />;
  }

  /*
   * CALCULATIONS
   */
  const bmi = calcBmi(
    Number(s(vitals, "weight")),
    Number(s(vitals, "height")),
  );

  const gestDays = calcGestationalDays(
    s(clinicalNote, "lmp"),
  );

  /*
   * RENDER
   */
  return (
    <div>
      <PageHeader
        title={s(patient, "full_name")}
        subtitle={`${t("mrn")}: ${s(
          patient,
          "mrn",
        )} · ${t("age")}: ${
          calcAge(s(patient, "date_of_birth")) ?? "—"
        } · ${t(
          s(patient, "gender"),
        )} · ${formatDate(
          s(visit, "visit_date"),
        )}`}
      >
        <StatusBadge status={s(visit, "status")} />

        <Button
          asChild
          variant="outline"
          size="sm"
        >
          <Link to="/clinic">
            <ArrowLeft className="size-4" />
            {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox
        error={
          visitQ.error ??
          vitalsQ.error ??
          clinicalNoteQ.error ??
          testsQ.error ??
          medsQ.error ??
          ordersQ.error ??
          rxQ.error ??
          historyQ.error
        }
      />

      <Tabs defaultValue="emr">
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="emr">
            {t("clinical_notes")}
          </TabsTrigger>

          <TabsTrigger value="vitals">
            {t("vitals")}
          </TabsTrigger>

          <TabsTrigger value="labs">
            {t("laboratory")}
          </TabsTrigger>

          <TabsTrigger value="rx">
            {t("prescription")}
          </TabsTrigger>

          <TabsTrigger value="history">
            {t("history")}
          </TabsTrigger>
        </TabsList>

        {/* ==================== CLINICAL NOTES ==================== */}

        <TabsContent value="emr">
          <Card>
            <CardContent className="grid gap-4 p-4">
              <Field
                label={t("chief_complaint")}
              >
                <Textarea
                  rows={2}
                  value={s(
                    clinicalNote,
                    "chief_complaint",
                  )}
                  onChange={(e) =>
                    setClinicalNote({
                      ...clinicalNote,
                      chief_complaint:
                        e.target.value,
                    })
                  }
                />
              </Field>

              <Field label={t("history")}>
                <Textarea
                  rows={3}
                  value={
                    s(
                      clinicalNote,
                      "history_present_illness",
                    ) ||
                    s(
                      clinicalNote,
                      "hpi",
                    )
                  }
                  onChange={(e) =>
                    setClinicalNote({
                      ...clinicalNote,
                      history_present_illness:
                        e.target.value,
                      hpi: e.target.value,
                    })
                  }
                />
              </Field>

              <Field
                label={t("examination")}
              >
                <Textarea
                  rows={3}
                  value={s(
                    clinicalNote,
                    "examination",
                  )}
                  onChange={(e) =>
                    setClinicalNote({
                      ...clinicalNote,
                      examination:
                        e.target.value,
                    })
                  }
                />
              </Field>

              <div className="grid gap-4 sm:grid-cols-2">
                <Field
                  label={t("diagnosis")}
                >
                  <Textarea
                    rows={2}
                    value={s(
                      clinicalNote,
                      "assessment",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        assessment:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("treatment_plan")}
                >
                  <Textarea
                    rows={2}
                    value={s(
                      clinicalNote,
                      "plan",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        plan: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("allergies")}
                >
                  <Input
                    value={s(
                      clinicalNote,
                      "allergy_history",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        allergy_history:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t(
                    "chronic_conditions",
                  )}
                >
                  <Input
                    value={s(
                      clinicalNote,
                      "past_medical_history",
                    )}
                    onChange={(e) =>
                      setClinicalNote({
                        ...clinicalNote,
                        past_medical_history:
                          e.target.value,
                      })
                    }
                  />
                </Field>
              </div>

              {isFemale ? (
                <div>
                  <SectionTitle>
                    {t("obstetrics")}
                  </SectionTitle>

                  <div className="grid gap-4 sm:grid-cols-3">
                    <Field
                      label={t("lmp")}
                    >
                      <Input
                        type="date"
                        dir="ltr"
                        value={s(
                          clinicalNote,
                          "lmp",
                        ).slice(0, 10)}
                        onChange={(e) =>
                          setClinicalNote({
                            ...clinicalNote,
                            lmp: e.target.value,
                          })
                        }
                      />
                    </Field>

                    <Field
                      label={t("edd")}
                    >
                      <Input
                        dir="ltr"
                        readOnly
                        value={
                          calcEdd(
                            s(
                              clinicalNote,
                              "lmp",
                            ),
                          ) ?? ""
                        }
                      />
                    </Field>

                    <Field
                      label={t(
                        "gestational_age",
                      )}
                    >
                      <Input
                        readOnly
                        value={formatGestationalAge(
                          gestDays,
                          lang,
                        )}
                      />
                    </Field>
                  </div>
                </div>
              ) : null}

              {can("emr.create") ? (
                <div>
                  <Button
                    disabled={
                      saveClinicalNote.isPending
                    }
                    onClick={() =>
                      saveClinicalNote.mutate(
                        undefined as never,
                      )
                    }
                  >
                    {saveClinicalNote.isPending
                      ? t("saving")
                      : t("save")}
                  </Button>
                </div>
              ) : null}
            </CardContent>
          </Card>
        </TabsContent>

        {/* ==================== VITALS ==================== */}

        <TabsContent value="vitals">
          <Card>
            <CardContent className="grid gap-4 p-4">
              <div className="grid gap-4 sm:grid-cols-3 lg:grid-cols-4">
                <Field
                  label={t("temperature")}
                >
                  <Input
                    type="number"
                    dir="ltr"
                    step="0.1"
                    value={s(
                      vitals,
                      "temperature",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        temperature:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("pulse")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={s(vitals, "pulse")}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        pulse:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("blood_pressure")}
                >
                  <Input
                    dir="ltr"
                    placeholder="120/80"
                    value={
                      s(
                        vitals,
                        "systolic_bp",
                      ) ||
                      s(
                        vitals,
                        "bp_systolic",
                      )
                        ? `${s(
                            vitals,
                            "systolic_bp",
                          ) || s(
                            vitals,
                            "bp_systolic",
                          )}/${s(
                            vitals,
                            "diastolic_bp",
                          ) || s(
                            vitals,
                            "bp_diastolic",
                          )}`
                        : ""
                    }
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        blood_pressure:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t(
                    "respiratory_rate",
                  )}
                >
                  <Input
                    type="number"
                    dir="ltr"
                    value={s(
                      vitals,
                      "respiratory_rate",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        respiratory_rate:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("spo2")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={s(vitals, "spo2")}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        spo2:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("weight")}
                >
                  <Input
                    type="number"
                    dir="ltr"
                    step="0.1"
                    value={s(
                      vitals,
                      "weight",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        weight:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("height")}
                >
                  <Input
                    type="number"
                    dir="ltr"
                    step="0.1"
                    value={s(
                      vitals,
                      "height",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        height:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("bmi")}>
                  <Input
                    readOnly
                    dir="ltr"
                    value={bmi ?? ""}
                  />
                </Field>
              </div>

              {can("vitals.create") ? (
                <div>
                  <Button
                    disabled={
                      saveVitals.isPending
                    }
                    onClick={() =>
                      saveVitals.mutate(
                        undefined as never,
                      )
                    }
                  >
                    {saveVitals.isPending
                      ? t("saving")
                      : t("save")}
                  </Button>
                </div>
              ) : null}
            </CardContent>
          </Card>
        </TabsContent>

        {/* ==================== LABORATORY ==================== */}

        <TabsContent value="labs">
          <div className="grid gap-4 lg:grid-cols-2">
            <Card>
              <CardContent className="p-4">
                <SectionTitle>
                  {t("order_tests")}
                </SectionTitle>

                <div className="max-h-80 space-y-2 overflow-y-auto">
                  {(
                    (testsQ.data ?? []) as Row[]
                  ).map((test) => {
                    const id = s(
                      test,
                      "id",
                    );

                    return (
                      <label
                        key={id}
                        className="flex items-center gap-2 text-sm"
                      >
                        <Checkbox
                          checked={labSel.includes(
                            id,
                          )}
                          onCheckedChange={(
                            value,
                          ) =>
                            setLabSel(
                              value
                                ? [
                                    ...labSel,
                                    id,
                                  ]
                                : labSel.filter(
                                    (x) =>
                                      x !== id,
                                  ),
                            )
                          }
                        />

                        <span>
                          {lang === "ar"
                            ? s(
                                test,
                                "name_ar",
                              ) ||
                              s(
                                test,
                                "name",
                              )
                            : s(
                                test,
                                "name",
                              )}
                        </span>
                      </label>
                    );
                  })}
                </div>

                {can("lab.create") ? (
                  <Button
                    className="mt-4"
                    disabled={
                      labSel.length === 0 ||
                      orderLabs.isPending
                    }
                    onClick={() =>
                      orderLabs.mutate(
                        undefined as never,
                      )
                    }
                  >
                    {orderLabs.isPending
                      ? t("saving")
                      : t("order_tests")}
                  </Button>
                ) : null}
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <SectionTitle>
                  {t("laboratory")}
                </SectionTitle>

                {(
                  (ordersQ.data ?? []) as Row[]
                ).length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="space-y-2 text-sm">
                    {(
                      (ordersQ.data ??
                        []) as Row[]
                    ).map((order) => (
                      <li
                        key={s(
                          order,
                          "id",
                        )}
                        className="flex items-center justify-between gap-2 rounded-md border p-2"
                      >
                        <span>
                          {(
                            (order[
                              "lab_order_items"
                            ] as Row[]) ??
                            []
                          )
                            .map((item) => {
                              const test =
                                rel(
                                  item,
                                  "lab_tests",
                                );

                              return lang ===
                                "ar"
                                ? s(
                                    test,
                                    "name_ar",
                                  ) ||
                                    s(
                                      test,
                                      "name",
                                    )
                                : s(
                                    test,
                                    "name",
                                  );
                            })
                            .join(", ")}
                        </span>

                        <div className="flex items-center gap-2">
                          <StatusBadge
                            status={s(
                              order,
                              "status",
                            )}
                          />

                          <Button
                            asChild
                            variant="ghost"
                            size="sm"
                          >
                            <Link
                              to="/lab/$orderId"
                              params={{
                                orderId:
                                  s(
                                    order,
                                    "id",
                                  ),
                              }}
                            >
                              {t("open")}
                            </Link>
                          </Button>
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ==================== PRESCRIPTION ==================== */}

        <TabsContent value="rx">
          <Card>
            <CardContent className="p-4">
              <SectionTitle>
                {t("prescription")}
              </SectionTitle>

              <div className="space-y-3">
                {rx.map((item, index) => (
                  <div
                    key={index}
                    className="grid gap-2 rounded-md border p-3 sm:grid-cols-6"
                  >
                    <div className="sm:col-span-2">
                      <Select
                        value={
                          item.medicine_id
                        }
                        onValueChange={(value) =>
                          setRx(
                            rx.map(
                              (
                                current,
                                i,
                              ) =>
                                i === index
                                  ? {
                                      ...current,
                                      medicine_id:
                                        value,
                                    }
                                  : current,
                            ),
                          )
                        }
                      >
                        <SelectTrigger>
                          <SelectValue
                            placeholder={t(
                              "medicines",
                            )}
                          />
                        </SelectTrigger>

                        <SelectContent className="max-h-72">
                          {(
                            (medsQ.data ??
                              []) as Row[]
                          ).map((medicine) => (
                            <SelectItem
                              key={s(
                                medicine,
                                "id",
                              )}
                              value={s(
                                medicine,
                                "id",
                              )}
                            >
                              {s(
                                medicine,
                                "name",
                              ) ||
                                s(
                                  medicine,
                                  "generic_name",
                                ) ||
                                s(
                                  medicine,
                                  "brand_name",
                                )}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>

                    <Input
                      placeholder={t(
                        "dosage",
                      )}
                      value={item.dosage}
                      onChange={(e) =>
                        setRx(
                          rx.map(
                            (
                              current,
                              i,
                            ) =>
                              i === index
                                ? {
                                    ...current,
                                    dosage:
                                      e.target
                                        .value,
                                  }
                                : current,
                          ),
                        )
                      }
                    />

                    <Input
                      placeholder={t(
                        "frequency",
                      )}
                      value={item.frequency}
                      onChange={(e) =>
                        setRx(
                          rx.map(
                            (
                              current,
                              i,
                            ) =>
                              i === index
                                ? {
                                    ...current,
                                    frequency:
                                      e.target
                                        .value,
                                  }
                                : current,
                          ),
                        )
                      }
                    />

                    <Input
                      placeholder={t(
                        "duration",
                      )}
                      value={item.duration}
                      onChange={(e) =>
                        setRx(
                          rx.map(
                            (
                              current,
                              i,
                            ) =>
                              i === index
                                ? {
                                    ...current,
                                    duration:
                                      e.target
                                        .value,
                                  }
                                : current,
                          ),
                        )
                      }
                    />

                    <div className="flex gap-2">
                      <Input
                        type="number"
                        dir="ltr"
                        min={1}
                        placeholder={t(
                          "quantity",
                        )}
                        value={
                          item.quantity
                        }
                        onChange={(e) =>
                          setRx(
                            rx.map(
                              (
                                current,
                                i,
                              ) =>
                                i === index
                                  ? {
                                      ...current,
                                      quantity:
                                        e.target
                                          .value,
                                    }
                                  : current,
                            ),
                          )
                        }
                      />

                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() =>
                          setRx(
                            rx.filter(
                              (_, i) =>
                                i !== index,
                            ),
                          )
                        }
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-4 flex flex-wrap items-center gap-3">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    setRx([
                      ...rx,
                      {
                        medicine_id: "",
                        dosage: "",
                        frequency: "",
                        duration: "",
                        quantity: "1",
                      },
                    ])
                  }
                >
                  <Plus className="size-4" />
                  {t("add")}
                </Button>

                <label className="flex items-center gap-2 text-sm">
                  <Checkbox
                    checked={rxExternal}
                    onCheckedChange={(value) =>
                      setRxExternal(
                        Boolean(value),
                      )
                    }
                  />

                  {t(
                    "external_prescription",
                  )}
                </label>

                {can(
                  "prescriptions.create",
                ) ? (
                  <Button
                    disabled={
                      rx.length === 0 ||
                      saveRx.isPending
                    }
                    onClick={() =>
                      saveRx.mutate(
                        undefined as never,
                      )
                    }
                  >
                    {saveRx.isPending
                      ? t("saving")
                      : t("save")}
                  </Button>
                ) : null}
              </div>

              <div className="mt-6">
                <SectionTitle>
                  {t("history")}
                </SectionTitle>

                {(
                  (rxQ.data ?? []) as Row[]
                ).length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="space-y-2 text-sm">
                    {(
                      (rxQ.data ??
                        []) as Row[]
                    ).map((prescription) => (
                      <li
                        key={s(
                          prescription,
                          "id",
                        )}
                        className="flex items-center justify-between rounded-md border p-2"
                      >
                        <span>
                          {(
                            (prescription[
                              "prescription_items"
                            ] as Row[]) ??
                            []
                          )
                            .map((item) => {
                              const medicine =
                                rel(
                                  item,
                                  "medicines",
                                );

                              return `${s(
                                medicine,
                                "name",
                              )} ${s(
                                item,
                                "dosage",
                              )}`;
                            })
                            .join(" · ")}
                        </span>

                        <StatusBadge
                          status={s(
                            prescription,
                            "status",
                          )}
                        />
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ==================== HISTORY ==================== */}

        <TabsContent value="history">
          <Card>
            <CardContent className="p-0">
              {(
                (historyQ.data ??
                  []) as Row[]
              ).length === 0 ? (
                <Empty />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>
                        {t("date")}
                      </TableHead>

                      <TableHead>
                        {t(
                          "chief_complaint",
                        )}
                      </TableHead>

                      <TableHead>
                        {t("diagnosis")}
                      </TableHead>
                    </TableRow>
                  </TableHeader>

                  <TableBody>
                    {(
                      (historyQ.data ??
                        []) as Row[]
                    ).map((history) => (
                      <TableRow
                        key={s(
                          history,
                          "id",
                        )}
                      >
                        <TableCell dir="ltr">
                          {formatDateTime(
                            s(
                              history,
                              "created_at",
                            ),
                          )}
                        </TableCell>

                        <TableCell>
                          {s(
                            history,
                            "chief_complaint",
                          ) || "—"}
                        </TableCell>

                        <TableCell>
                          {s(
                            history,
                            "assessment",
                          ) || "—"}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}