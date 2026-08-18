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
  const isFemale = s(patient, "gender") === "female";

  const [vitals, setVitals] = useState<Row>({});
  const [emr, setEmr] = useState<Row>({});
  const [labSel, setLabSel] = useState<string[]>([]);
  const [rx, setRx] = useState<RxItem[]>([]);
  const [rxExternal, setRxExternal] = useState(false);

  const vitalsQ = useRows(["vitals", visitId], () =>
    supabase
      .from("vitals")
      .select("")
      .eq("visit_id", visitId)
      .limit(1),
  );

  const emrQ = useRows(["emr", visitId], () =>
    supabase
      .from("medical_records")
      .select("")
      .eq("visit_id", visitId)
      .limit(1),
  );

  const testsQ = useRows(["lab-tests"], () =>
    supabase
      .from("lab_tests")
      .select("id, name, name_ar, price, category")
      .eq("active", true)
      .is("deleted_at", null),
  );

  const medsQ = useRows(["medicines"], () =>
    supabase
      .from("medicines")
      .select("id, name, unit, selling_price, stock_quantity")
      .is("deleted_at", null),
  );

  const ordersQ = useRows(["visit-labs", visitId], () =>
    supabase
      .from("lab_orders")
      .select(
        "id, status, created_at, lab_order_items(id, lab_tests(name, name_ar))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null),
  );

  const rxQ = useRows(["visit-rx", visitId], () =>
    supabase
      .from("prescriptions")
      .select(
        "id, status, is_external, created_at, prescription_items(id, dosage, frequency, duration, medicines(name))",
      )
      .eq("visit_id", visitId)
      .is("deleted_at", null),
  );

  const historyQ = useRows(
    ["emr-history", s(patient, "id")],
    () =>
      supabase
        .from("medical_records")
        .select("id, created_at, chief_complaint, diagnosis, visit_id")
        .eq("patient_id", s(patient, "id"))
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(20),
    {
      enabled: Boolean(s(patient, "id")),
    },
  );

  useEffect(() => {
    const v = ((vitalsQ.data ?? []) as Row[])[0];

    if (v) {
      setVitals(v);
    }
  }, [vitalsQ.data]);

  useEffect(() => {
    const e = ((emrQ.data ?? []) as Row[])[0];

    if (e) {
      setEmr(e);
    }
  }, [emrQ.data]);

  const saveVitals = useSave(
    async () => {
      const payload = {
        visit_id: visitId,
        patient_id: s(patient, "id"),
        temperature:
          Number(s(vitals, "temperature")) || null,
        pulse:
          Number(s(vitals, "pulse")) || null,
        respiratory_rate:
          Number(s(vitals, "respiratory_rate")) || null,
        blood_pressure:
          s(vitals, "blood_pressure") || null,
        weight:
          Number(s(vitals, "weight")) || null,
        height:
          Number(s(vitals, "height")) || null,
        spo2:
          Number(s(vitals, "spo2")) || null,
        blood_sugar:
          Number(s(vitals, "blood_sugar")) || null,
        notes:
          s(vitals, "notes") || null,
      };

      const existing =
        ((vitalsQ.data ?? []) as Row[])[0];

      const q = existing
        ? supabase
            .from("vitals")
            .update(payload)
            .eq("id", s(existing, "id"))
        : supabase
            .from("vitals")
            .insert(payload);

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

  const saveEmr = useSave(
    async () => {
      const payload = {
        visit_id: visitId,
        patient_id: s(patient, "id"),
        doctor_id: user?.id ?? null,
        chief_complaint:
          s(emr, "chief_complaint") || null,
        history:
          s(emr, "history") || null,
        examination:
          s(emr, "examination") || null,
        diagnosis:
          s(emr, "diagnosis") || null,
        treatment_plan:
          s(emr, "treatment_plan") || null,
        allergies:
          s(emr, "allergies") || null,
        chronic_conditions:
          s(emr, "chronic_conditions") || null,
        lmp:
          s(emr, "lmp") || null,
        gravida:
          Number(s(emr, "gravida")) || null,
        para:
          Number(s(emr, "para")) || null,
        follow_up_date:
          s(emr, "follow_up_date") || null,
      };

      const existing =
        ((emrQ.data ?? []) as Row[])[0];

      const q = existing
        ? supabase
            .from("medical_records")
            .update(payload)
            .eq("id", s(existing, "id"))
        : supabase
            .from("medical_records")
            .insert(payload);

      const { error } = await q;

      if (error) {
        throw new Error(error.message);
      }

      await supabase
        .from("visits")
        .update({ status: "completed" })
        .eq("id", visitId);

      return null;
    },
    {
      invalidate: [
        ["emr", visitId],
        ["visit", visitId],
        ["emr-history", s(patient, "id")],
      ],
      successMessage: t("saved"),
    },
  );

  const orderLabs = useSave(
    async () => {
      const { data: order, error } = await supabase
        .from("lab_orders")
        .insert({
          visit_id: visitId,
          patient_id: s(patient, "id"),
          doctor_id: user?.id ?? null,
          status: "ordered",
        })
        .select("id")
        .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!order) {
        throw new Error("Failed to create laboratory order.");
      }

      const items = labSel.map((testId) => {
        const test = (
          (testsQ.data ?? []) as Row[]
        ).find((x) => s(x, "id") === testId);

        return {
          lab_order_id: order.id,
          lab_test_id: testId,
          price: n(test, "price"),
          status: "pending",
        };
      });

      if (items.length > 0) {
        const { error: iErr } = await supabase
          .from("lab_order_items")
          .insert(items);

        if (iErr) {
          throw new Error(iErr.message);
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

  const saveRx = useSave(
    async () => {
      const { data: pres, error } = await supabase
        .from("prescriptions")
        .insert({
          visit_id: visitId,
          patient_id: s(patient, "id"),
          doctor_id: user?.id ?? null,
          is_external: rxExternal,
          status: rxExternal ? "external" : "pending",
        })
        .select("id")
        .single();

      if (error) {
        throw new Error(error.message);
      }

      if (!pres) {
        throw new Error("Failed to create prescription.");
      }

      const items = rx
        .filter((r) => r.medicine_id)
        .map((r) => ({
          prescription_id: pres.id,
          medicine_id: r.medicine_id,
          dosage: r.dosage || null,
          frequency: r.frequency || null,
          duration: r.duration || null,
          quantity:
            Number(r.quantity) || 1,
        }));

      if (items.length > 0) {
        const { error: iErr } = await supabase
          .from("prescription_items")
          .insert(items);

        if (iErr) {
          throw new Error(iErr.message);
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
      onDone: () => setRx([]),
    },
  );

  if (visitQ.isLoading) {
    return <Loading />;
  }

  if (!visit) {
    return <Empty label={t("no_data")} />;
  }

  const bmi = calcBmi(
    Number(s(vitals, "weight")),
    Number(s(vitals, "height")),
  );

  const gestDays = calcGestationalDays(
    s(emr, "lmp"),
  );

  return (
    <div>
      <PageHeader
        title={s(patient, "full_name")}
        subtitle={`${t("mrn")}: ${s(patient, "mrn")} · ${t(
          "age",
        )}: ${
          calcAge(s(patient, "date_of_birth")) ?? "—"
        } · ${t(s(patient, "gender"))} · ${formatDate(
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
          emrQ.error ??
          testsQ.error ??
          medsQ.error
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

        <TabsContent value="emr">
          <Card>
            <CardContent className="grid gap-4 p-4">
              <Field label={t("chief_complaint")}>
                <Textarea
                  rows={2}
                  value={s(
                    emr,
                    "chief_complaint",
                  )}
                  onChange={(e) =>
                    setEmr({
                      ...emr,
                      chief_complaint:
                        e.target.value,
                    })
                  }
                />
              </Field>

              <Field label={t("history")}>
                <Textarea
                  rows={3}
                  value={s(emr, "history")}
                  onChange={(e) =>
                    setEmr({
                      ...emr,
                      history: e.target.value,
                    })
                  }
                />
              </Field>

              <Field label={t("examination")}>
                <Textarea
                  rows={3}
                  value={s(emr, "examination")}
                  onChange={(e) =>
                    setEmr({
                      ...emr,
                      examination:
                        e.target.value,
                    })
                  }
                />
              </Field>

              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={t("diagnosis")}>
                  <Textarea
                    rows={2}
                    value={s(emr, "diagnosis")}
                    onChange={(e) =>
                      setEmr({
                        ...emr,
                        diagnosis:
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
                      emr,
                      "treatment_plan",
                    )}
                    onChange={(e) =>
                      setEmr({
                        ...emr,
                        treatment_plan:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("allergies")}>
                  <Input
                    value={s(emr, "allergies")}
                    onChange={(e) =>
                      setEmr({
                        ...emr,
                        allergies:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("chronic_conditions")}
                >
                  <Input
                    value={s(
                      emr,
                      "chronic_conditions",
                    )}
                    onChange={(e) =>
                      setEmr({
                        ...emr,
                        chronic_conditions:
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

                  <div className="grid gap-4 sm:grid-cols-4">
                    <Field label={t("lmp")}>
                      <Input
                        type="date"
                        dir="ltr"
                        value={s(
                          emr,
                          "lmp",
                        ).slice(0, 10)}
                        onChange={(e) =>
                          setEmr({
                            ...emr,
                            lmp: e.target.value,
                          })
                        }
                      />
                    </Field>

                    <Field label={t("edd")}>
                      <Input
                        dir="ltr"
                        readOnly
                        value={
                          calcEdd(
                            s(emr, "lmp"),
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

                    <div className="grid grid-cols-2 gap-2">
                      <Field label={t("gravida")}>
                        <Input
                          type="number"
                          dir="ltr"
                          value={s(
                            emr,
                            "gravida",
                          )}
                          onChange={(e) =>
                            setEmr({
                              ...emr,
                              gravida:
                                e.target.value,
                            })
                          }
                        />
                      </Field>

                      <Field label={t("para")}>
                        <Input
                          type="number"
                          dir="ltr"
                          value={s(
                            emr,
                            "para",
                          )}
                          onChange={(e) =>
                            setEmr({
                              ...emr,
                              para:
                                e.target.value,
                            })
                          }
                        />
                      </Field>
                    </div>
                  </div>
                </div>
              ) : null}

              <Field
                label={t("follow_up_date")}
                className="max-w-xs"
              >
                <Input
                  type="date"
                  dir="ltr"
                  value={s(
                    emr,
                    "follow_up_date",
                  ).slice(0, 10)}
                  onChange={(e) =>
                    setEmr({
                      ...emr,
                      follow_up_date:
                        e.target.value,
                    })
                  }
                />
              </Field>

              {can("emr.create") ? (
                <div>
                  <Button
                    disabled={saveEmr.isPending}
                    onClick={() =>
                      saveEmr.mutate(
                        undefined as never,
                      )
                    }
                  >
                    {saveEmr.isPending
                      ? t("saving")
                      : t("save")}
                  </Button>
                </div>
              ) : null}
            </CardContent>
          </Card>
        </TabsContent>

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
                        pulse: e.target.value,
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
                    value={s(
                      vitals,
                      "blood_pressure",
                    )}
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
                        spo2: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("blood_sugar")}
                >
                  <Input
                    type="number"
                    dir="ltr"
                    value={s(
                      vitals,
                      "blood_sugar",
                    )}
                    onChange={(e) =>
                      setVitals({
                        ...vitals,
                        blood_sugar:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("weight")}>
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

                <Field label={t("height")}>
                  <Input
                    type="number"
                    dir="ltr"
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

              <Field label={t("notes")}>
                <Textarea
                  rows={2}
                  value={s(vitals, "notes")}
                  onChange={(e) =>
                    setVitals({
                      ...vitals,
                      notes: e.target.value,
                    })
                  }
                />
              </Field>

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
                    const id = s(test, "id");

                    return (
                      <label
                        key={id}
                        className="flex items-center gap-2 text-sm"
                      >
                        <Checkbox
                          checked={labSel.includes(
                            id,
                          )}
                          onCheckedChange={(v) =>
                            setLabSel(
                              v
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
                    ).map((o) => (
                      <li
                        key={s(o, "id")}
                        className="flex items-center justify-between gap-2 rounded-md border p-2"
                      >
                        <span>
                          {(
                            (o[
                              "lab_order_items"
                            ] as Row[]) ??
                            []
                          )
                            .map((i) =>
                              lang === "ar"
                                ? s(
                                    rel(
                                      i,
                                      "lab_tests",
                                    ),
                                    "name_ar",
                                  ) ||
                                  s(
                                    rel(
                                      i,
                                      "lab_tests",
                                    ),
                                    "name",
                                  )
                                : s(
                                    rel(
                                      i,
                                      "lab_tests",
                                    ),
                                    "name",
                                  ),
                            )
                            .join(", ")}
                        </span>

                        <div className="flex items-center gap-2">
                          <StatusBadge
                            status={s(
                              o,
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
                                orderId: s(
                                  o,
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

        <TabsContent value="rx">
          <Card>
            <CardContent className="p-4">
              <SectionTitle>
                {t("prescription")}
              </SectionTitle>

              <div className="space-y-3">
                {rx.map((item, idx) => (
                  <div
                    key={idx}
                    className="grid gap-2 rounded-md border p-3 sm:grid-cols-6"
                  >
                    <div className="sm:col-span-2">
                      <Select
                        value={
                          item.medicine_id
                        }
                        onValueChange={(v) =>
                          setRx(
                            rx.map(
                              (r, i) =>
                                i === idx
                                  ? {
                                      ...r,
                                      medicine_id:
                                        v,
                                    }
                                  : r,
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
                          ).map((m) => (
                            <SelectItem
                              key={s(
                                m,
                                "id",
                              )}
                              value={s(
                                m,
                                "id",
                              )}
                            >
                              {s(m, "name")}
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
                            (r, i) =>
                              i === idx
                                ? {
                                    ...r,
                                    dosage:
                                      e.target
                                        .value,
                                  }
                                : r,
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
                            (r, i) =>
                              i === idx
                                ? {
                                    ...r,
                                    frequency:
                                      e.target
                                        .value,
                                  }
                                : r,
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
                            (r, i) =>
                              i === idx
                                ? {
                                    ...r,
                                    duration:
                                      e.target
                                        .value,
                                  }
                                : r,
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
                        value={item.quantity}
                        onChange={(e) =>
                          setRx(
                            rx.map(
                              (r, i) =>
                                i === idx
                                  ? {
                                      ...r,
                                      quantity:
                                        e.target
                                          .value,
                                    }
                                  : r,
                            ),
                          )
                        }
                      />

                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() =>
                          setRx(
                            rx.filter(
                              (_, i) =>
                                i !== idx,
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
                    onCheckedChange={(v) =>
                      setRxExternal(
                        Boolean(v),
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
                    ).map((p) => (
                      <li
                        key={s(p, "id")}
                        className="flex items-center justify-between rounded-md border p-2"
                      >
                        <span>
                          {(
                            (p[
                              "prescription_items"
                            ] as Row[]) ??
                            []
                          )
                            .map(
                              (i) =>
                                `${s(
                                  rel(
                                    i,
                                    "medicines",
                                  ),
                                  "name",
                                )} ${s(
                                  i,
                                  "dosage",
                                )}`,
                            )
                            .join(" · ")}
                        </span>

                        <StatusBadge
                          status={s(
                            p,
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
                    ).map((h) => (
                      <TableRow
                        key={s(h, "id")}
                      >
                        <TableCell dir="ltr">
                          {formatDateTime(
                            s(
                              h,
                              "created_at",
                            ),
                          )}
                        </TableCell>

                        <TableCell>
                          {s(
                            h,
                            "chief_complaint",
                          ) || "—"}
                        </TableCell>

                        <TableCell>
                          {s(
                            h,
                            "diagnosis",
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