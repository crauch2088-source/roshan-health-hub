import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2, FlaskConical } from "lucide-react";
import { useEffect, useState } from "react";

import {
  Empty,
  ErrorBox,
  Loading,
  PageHeader,
  PrintButton,
  SectionTitle,
  StatusBadge,
  PermissionGate,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge } from "@/lib/medical";
import { hasLabItemResultInput, mapLabResult, selectLabReferenceRange } from "@/lib/lab-workflow";
import { supabase } from "@/lib/supabase";

function firstFiniteBound(row: Row | undefined, ...keys: string[]): number | null {
  for (const key of keys) {
    const raw = row?.[key];
    if (raw == null || String(raw).trim() === "") continue;
    const value = Number(raw);
    if (Number.isFinite(value)) return value;
  }
  return null;
}

export const Route = createFileRoute("/_authenticated/lab_/$orderId")({
  head: () => ({
    meta: [{ title: "Lab order — ROSHAN Medical Center" }],
  }),
  component: LabOrderPage,
});

function LabOrderPage() {
  return (
    <PermissionGate perm="lab.read">
      <LabOrderPageInner />
    </PermissionGate>
  );
}

function LabOrderPageInner() {
  const { orderId } = useParams({
    from: "/_authenticated/lab_/$orderId",
  });

  const { t, lang } = useLang();
  const { can, user } = useAuth();

  const [values, setValues] = useState<Record<string, string>>({});
  const [comments, setComments] = useState<Record<string, string>>({});

  const orderQ = useRows<Row[]>(["lab-order", orderId], () =>
    supabase
      .from("lab_orders")
      .select(
        "id,status,created_at,ordered_at,patient_id,patients(id,full_name,mrn,gender,date_of_birth),users!lab_orders_ordered_by_fkey(full_name)",
      )
      .eq("id", orderId)
      .limit(1),
  );

  const itemsQ = useRows<Row[]>(["lab-items", orderId], () =>
    supabase
      .from("lab_order_items")
      .select("id,status,test_id,price,lab_tests(id,name,name_ar)")
      .eq("order_id", orderId)
      .is("deleted_at", null)
      .order("created_at"),
  );

  const order = (orderQ.data ?? [])[0] as Row | undefined;
  const patient = rel(order, "patients");
  const items = (itemsQ.data ?? []) as Row[];

  const testIds = items.map((i) => s(i, "test_id")).filter(Boolean);

  const parametersQ = useRows<Row[]>(["lab-parameters", ...testIds], () =>
    testIds.length
      ? supabase
          .from("lab_parameters")
          .select("id,test_id,name,code,unit,data_type,display_order,reference_text")
          .in("test_id", testIds)
          .eq("active", true)
          .is("deleted_at", null)
          .order("display_order")
      : supabase
          .from("lab_parameters")
          .select("id,test_id,name,code,unit,data_type,display_order,reference_text")
          .eq("test_id", "00000000-0000-0000-0000-000000000000"),
  );

  const rangeQ = useRows<Row[]>(
    ["lab-ranges", s(patient, "gender"), s(patient, "date_of_birth")],
    () =>
      supabase
        .from("lab_reference_ranges")
        .select(
          "id,parameter_id,gender,min_age,max_age,lower_limit,upper_limit,text_reference,min_value,max_value,age_min,age_max,text_value,unit",
        )
        .is("deleted_at", null),
  );

  const actualResultsQ = useRows<Row[]>(
    ["lab-order-results", orderId, ...items.map((i) => s(i, "id"))],
    () => {
      const itemIds = items.map((i) => s(i, "id")).filter(Boolean);

      return itemIds.length
        ? supabase.from("lab_results").select("*").in("order_item_id", itemIds)
        : supabase
            .from("lab_results")
            .select("*")
            .eq("order_item_id", "00000000-0000-0000-0000-000000000000");
    },
  );

  useEffect(() => {
    const v: Record<string, string> = {};
    const c: Record<string, string> = {};

    for (const r of (actualResultsQ.data ?? []) as Row[]) {
      const key = `${s(r, "order_item_id")}:${s(r, "parameter_id")}`;

      v[key] = s(r, "result_value");
      c[key] = s(r, "comment");
    }

    setValues(v);
    setComments(c);
  }, [actualResultsQ.data]);

  const age = calcAge(s(patient, "date_of_birth")) ?? undefined;
  const parameters = (parametersQ.data ?? []) as Row[];
  const ranges = (rangeQ.data ?? []) as Row[];

  function rangeFor(parameterId: string) {
    return selectLabReferenceRange(ranges, parameterId, s(patient, "gender"), age);
  }

  const resultRows = (actualResultsQ.data ?? []) as Row[];
  const hasUnsavedResultEdits = items.some((item) =>
    parameters
      .filter((parameter) => s(parameter, "test_id") === s(item, "test_id"))
      .some((parameter) => {
        const key = s(item, "id") + ":" + s(parameter, "id");
        const saved = resultRows.find(
          (row) =>
            s(row, "order_item_id") === s(item, "id") &&
            s(row, "parameter_id") === s(parameter, "id"),
        );
        return (
          (values[key] ?? "").trim() !== s(saved, "result_value").trim() ||
          (comments[key] ?? "") !== s(saved, "comment")
        );
      }),
  );
  const abnormalResultCount = items.reduce((count, item) => {
    const itemParameters = parameters.filter(
      (parameter) => s(parameter, "test_id") === s(item, "test_id"),
    );
    return (
      count +
      itemParameters.filter((parameter) => {
        const value = (values[s(item, "id") + ":" + s(parameter, "id")] ?? "").trim();
        if (!value) return false;
        const range = rangeFor(s(parameter, "id"));
        const mapped = mapLabResult({
          value,
          dataType: s(parameter, "data_type"),
          lower: firstFiniteBound(range, "lower_limit", "min_value"),
          upper: firstFiniteBound(range, "upper_limit", "max_value"),
          flag: s(
            resultRows.find(
              (row) =>
                s(row, "order_item_id") === s(item, "id") &&
                s(row, "parameter_id") === s(parameter, "id"),
            ),
            "flag",
          ),
        });
        return mapped.kind === "numeric" && mapped.abnormal;
      }).length
    );
  }, 0);
  const save = useSave(
    async () => {
      let allItemsCompleted = true;
      for (let i = 0; i < items.length; i++) {
        const item = items[i];

        const params = parameters.filter((p) => s(p, "test_id") === s(item, "test_id"));
        const parameterIds = params.map((parameter) => s(parameter, "id"));
        if (!hasLabItemResultInput(s(item, "id"), parameterIds, values)) {
          allItemsCompleted = false;
          continue;
        }

        for (const p of params) {
          const key = `${s(item, "id")}:${s(p, "id")}`;
          const value = (values[key] ?? "").trim();

          if (!value) continue;

          const numeric = Number(value);
          const range = rangeFor(s(p, "id"));

          const lower = firstFiniteBound(range, "lower_limit", "min_value");
          const upper = firstFiniteBound(range, "upper_limit", "max_value");
          const mapped = mapLabResult({
            value,
            dataType: s(p, "data_type"),
            lower,
            upper,
          });
          const abnormal = mapped.kind === "numeric" && mapped.abnormal;
          const flag = mapped.kind === "numeric" ? mapped.flag : null;

          const payload = {
            order_item_id: s(item, "id"),
            parameter_id: s(p, "id"),
            result_value: value,
            numeric_value: mapped.kind === "numeric" ? mapped.value : null,
            flag,
            is_abnormal: abnormal,
            comment: comments[key] || null,
            entered_by: user?.id ?? null,
          };

          const existing = ((actualResultsQ.data ?? []) as Row[]).find(
            (r) => s(r, "order_item_id") === s(item, "id") && s(r, "parameter_id") === s(p, "id"),
          );

          const result = existing
            ? await supabase.from("lab_results").update(payload).eq("id", s(existing, "id"))
            : await supabase.from("lab_results").insert(payload);

          if (result.error) {
            throw new Error(result.error.message);
          }
        }

        const completion = await supabase.rpc("complete_lab_order_item", {
          p_order_item_id: s(item, "id"),
        });
        if (completion.error) {
          throw new Error(completion.error.message);
        }
      }

      // Keep a multi-test order open while any item has no entered result.
      if (allItemsCompleted) {
        const orderCompletion = await supabase
          .from("lab_orders")
          .update({
            status: "completed",
            completed_at: new Date().toISOString(),
            updated_by: user?.id ?? null,
          })
          .eq("id", orderId);
        if (orderCompletion.error) {
          throw new Error(orderCompletion.error.message);
        }
      }

      return null;
    },
    {
      invalidate: [
        ["lab-order", orderId],
        ["lab-items", orderId],
        ["lab-order-results", orderId],
        ["lab-orders"],
      ],
      successMessage: t("saved"),
    },
  );

  const verify = useSave(
    async () => {
      const { error } = await supabase
        .from("lab_results")
        .update({
          verified_by: user?.id ?? null,
          verified_at: new Date().toISOString(),
        })
        .in(
          "order_item_id",
          items.map((i) => s(i, "id")),
        );

      if (error) throw new Error(error.message);

      const { error: e } = await supabase
        .from("lab_orders")
        .update({ status: "verified" })
        .eq("id", orderId);

      if (e) throw new Error(e.message);

      return null;
    },
    {
      invalidate: [["lab-order", orderId], ["lab-order-results", orderId], ["lab-orders"]],
      successMessage: t("saved"),
    },
  );

  if (orderQ.isLoading || itemsQ.isLoading) {
    return <Loading />;
  }

  if (!order) {
    return <Empty label={t("no_data")} />;
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={lang === "ar" ? "طلب المختبر" : "Laboratory order"}
        subtitle={`${s(patient, "full_name")} · ${t("mrn")}: ${s(patient, "mrn")} · ${t("age")}: ${age ?? "—"}`}
      >
        <StatusBadge status={s(order, "status")} />

        <PrintButton />

        <Button asChild variant="outline" size="sm">
          <Link to="/lab">
            <ArrowLeft className="size-4" />
            {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox
        error={
          orderQ.error ?? itemsQ.error ?? actualResultsQ.error ?? parametersQ.error ?? rangeQ.error
        }
      />

      {abnormalResultCount > 0 ? (
        <div
          role="alert"
          className="rounded-xl border border-destructive/35 bg-destructive/5 p-4 text-sm"
        >
          <p className="font-semibold text-destructive">
            {lang === "ar"
              ? "توجد " + abnormalResultCount + " نتيجة خارج المدى المرجعي."
              : abnormalResultCount + " result(s) are outside the configured reference range."}
          </p>
          <p className="mt-1 text-muted-foreground">
            {lang === "ar"
              ? "راجع القيم وسياق المريض قبل اعتماد النتائج. التنبيه لا يحدد القيم الحرجة؛ اتبع بروتوكول المركز للتصعيد."
              : "Review the values and clinical context before verification. This is not a critical-value classifier; follow the center protocol."}
          </p>
        </div>
      ) : null}

      <Card>
        <CardContent className="p-4">
          <SectionTitle>{lang === "ar" ? "النتائج" : "Results"}</SectionTitle>

          <div className="mt-4 space-y-6">
            {items.map((item) => {
              const test = rel(item, "lab_tests");

              const params = parameters.filter((p) => s(p, "test_id") === s(item, "test_id"));

              return (
                <div key={s(item, "id")} className="rounded-lg border p-3">
                  <div className="mb-3 flex items-center gap-2 font-semibold">
                    <FlaskConical className="size-4" />

                    {lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")}

                    <span className="ms-auto text-xs text-muted-foreground">
                      {s(item, "status")}
                    </span>
                  </div>

                  {params.length === 0 ? (
                    <div className="text-sm text-muted-foreground">
                      {lang === "ar"
                        ? "لا توجد معاملات لهذا الفحص"
                        : "No parameters configured for this test."}
                    </div>
                  ) : (
                    <Table density="compact">
                      <TableHeader>
                        <TableRow>
                          <TableHead>{lang === "ar" ? "المعامل" : "Parameter"}</TableHead>

                          <TableHead>{t("result")}</TableHead>

                          <TableHead>{t("unit")}</TableHead>

                          <TableHead>{lang === "ar" ? "المرجع" : "Reference"}</TableHead>

                          <TableHead>{t("notes")}</TableHead>
                        </TableRow>
                      </TableHeader>

                      <TableBody>
                        {params.map((p) => {
                          const key = `${s(item, "id")}:${s(p, "id")}`;

                          const value = values[key] ?? "";

                          const range = rangeFor(s(p, "id"));

                          const lower = firstFiniteBound(range, "lower_limit", "min_value");
                          const upper = firstFiniteBound(range, "upper_limit", "max_value");
                          const savedResult = resultRows.find(
                            (row) =>
                              s(row, "order_item_id") === s(item, "id") &&
                              s(row, "parameter_id") === s(p, "id"),
                          );
                          const mapped = mapLabResult({
                            value,
                            dataType: s(p, "data_type"),
                            status: !value && s(item, "status") === "pending" ? "pending" : null,
                            lower,
                            upper,
                            flag: s(savedResult, "flag"),
                          });
                          const abnormal = mapped.kind === "numeric" && mapped.abnormal;

                          return (
                            <TableRow key={key}>
                              <TableCell className="font-medium">
                                {s(p, "name")}{" "}
                                {s(p, "code") && (
                                  <span className="text-xs text-muted-foreground">
                                    ({s(p, "code")})
                                  </span>
                                )}
                              </TableCell>

                              <TableCell className="w-40">
                                <Input
                                  dir="ltr"
                                  disabled={!can("lab.update")}
                                  value={value}
                                  onChange={(e) =>
                                    setValues({
                                      ...values,
                                      [key]: e.target.value,
                                    })
                                  }
                                />

                                {mapped.kind === "pending" && (
                                  <div className="mt-1 text-xs text-muted-foreground">
                                    {lang === "ar" ? "قيد الانتظار" : "Pending"}
                                  </div>
                                )}
                                {mapped.kind === "numeric" && mapped.critical && (
                                  <div
                                    role="alert"
                                    className="mt-1 text-xs font-semibold text-destructive"
                                  >
                                    {lang === "ar"
                                      ? "قيمة حرجة — اتبع بروتوكول التصعيد"
                                      : "Critical value — follow escalation protocol"}
                                  </div>
                                )}
                                {abnormal && !mapped.critical && (
                                  <div className="mt-1 text-xs font-medium text-destructive">
                                    {lang === "ar" ? "خارج المدى" : "Out of range"}
                                  </div>
                                )}
                              </TableCell>

                              <TableCell dir="ltr">
                                {s(p, "unit") || s(range, "unit") || "—"}
                              </TableCell>

                              <TableCell dir="ltr">
                                {range
                                  ? s(range, "text_reference") ||
                                    `${lower ?? "—"} – ${upper ?? "—"}`
                                  : s(p, "reference_text") || "—"}
                              </TableCell>

                              <TableCell>
                                <Input
                                  value={comments[key] ?? ""}
                                  disabled={!can("lab.update")}
                                  onChange={(e) =>
                                    setComments({
                                      ...comments,
                                      [key]: e.target.value,
                                    })
                                  }
                                />
                              </TableCell>
                            </TableRow>
                          );
                        })}
                      </TableBody>
                    </Table>
                  )}
                </div>
              );
            })}
          </div>

          <div className="no-print mt-5 flex flex-wrap gap-2">
            {can("lab.update") && (
              <Button disabled={save.isPending} onClick={() => save.mutate(undefined as never)}>
                {save.isPending ? t("saving") : t("save_results")}
              </Button>
            )}

            {can("lab.verify") && (
              <Button
                variant="secondary"
                disabled={
                  verify.isPending ||
                  actualResultsQ.isLoading ||
                  parametersQ.isLoading ||
                  rangeQ.isLoading
                }
                onClick={() => {
                  if (hasUnsavedResultEdits) {
                    window.alert(
                      lang === "ar"
                        ? "احفظ تعديلات النتائج أولاً قبل اعتمادها."
                        : "Save result changes before verification.",
                    );
                    return;
                  }
                  if (abnormalResultCount > 0) {
                    const confirmed = window.confirm(
                      lang === "ar"
                        ? "توجد نتائج خارج المدى المرجعي. هل راجعتها مع سياق المريض قبل الاعتماد؟"
                        : "Some results are outside the reference range. Have you reviewed the clinical context?",
                    );
                    if (!confirmed) return;
                  }
                  verify.mutate(undefined as never);
                }}
              >
                <CheckCircle2 className="size-4" />
                {t("verify")}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
