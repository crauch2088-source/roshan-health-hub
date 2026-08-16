import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useEffect, useState } from "react";

import { Empty, ErrorBox, Loading, PageHeader, PrintButton, SectionTitle, StatusBadge } from "@/components/kit";
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
import { n, rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, flagResult, formatDateTime } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/lab/$orderId")({
  head: () => ({
    meta: [
      { title: "Lab order — ROSHAN Medical Center" },
      { name: "description", content: "Enter, flag and verify laboratory results with reference ranges." },
      { property: "og:title", content: "Lab order — ROSHAN Medical Center" },
      { property: "og:description", content: "Enter, flag and verify laboratory results with reference ranges." },
    ],
  }),
  component: LabOrderPage,
});

function LabOrderPage() {
  const { orderId } = useParams({ from: "/_authenticated/lab/$orderId" });
  const { t, lang } = useLang();
  const { can, user } = useAuth();
  const [values, setValues] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});

  const orderQ = useRows(["lab-order", orderId], () =>
    supabase
      .from("lab_orders")
      .select(
        "id, status, created_at, patient_id, patients(id, full_name, mrn, gender, date_of_birth), users(full_name)",
      )
      .eq("id", orderId)
      .limit(1),
  );
  const order = ((orderQ.data ?? []) as Row[])[0];
  const patient = rel(order, "patients");

  const itemsQ = useRows(["lab-order-items", orderId], () =>
    supabase
      .from("lab_order_items")
      .select(
        "id, status, lab_test_id, lab_tests(name, name_ar, unit, normal_min, normal_max, reference_range)",
      )
      .eq("lab_order_id", orderId),
  );

  const resultsQ = useRows(["lab-results", orderId], () =>
    supabase.from("lab_results").select("*").eq("lab_order_id", orderId),
  );

  useEffect(() => {
    const map: Record<string, string> = {};
    const noteMap: Record<string, string> = {};
    for (const r of (resultsQ.data ?? []) as Row[]) {
      map[s(r, "lab_order_item_id")] = s(r, "result_value");
      noteMap[s(r, "lab_order_item_id")] = s(r, "notes");
    }
    setValues((prev) => ({ ...map, ...prev }));
    setNotes((prev) => ({ ...noteMap, ...prev }));
  }, [resultsQ.data]);

  const setStatus = useSave<{ status: string }>(
    async ({ status }) => {
      const patch: Row = { status };
      if (status === "verified") {
        patch["verified_by"] = user?.id ?? null;
        patch["verified_at"] = new Date().toISOString();
      }
      const { error } = await supabase.from("lab_orders").update(patch).eq("id", orderId);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["lab-order", orderId], ["lab-orders"]], successMessage: t("saved") },
  );

  const saveResults = useSave(
    async () => {
      const items = (itemsQ.data ?? []) as Row[];
      const existing = (resultsQ.data ?? []) as Row[];
      for (const item of items) {
        const itemId = s(item, "id");
        const value = values[itemId] ?? "";
        if (!value) continue;
        const test = rel(item, "lab_tests");
        const payload = {
          lab_order_id: orderId,
          lab_order_item_id: itemId,
          patient_id: s(patient, "id"),
          lab_test_id: s(item, "lab_test_id"),
          result_value: value,
          unit: s(test, "unit") || null,
          reference_range: s(test, "reference_range") || null,
          flag: flagResult(value, n(test, "normal_min"), n(test, "normal_max")),
          notes: notes[itemId] || null,
          performed_by: user?.id ?? null,
        };
        const prev = existing.find((r) => s(r, "lab_order_item_id") === itemId);
        const q = prev
          ? supabase.from("lab_results").update(payload).eq("id", s(prev, "id"))
          : supabase.from("lab_results").insert(payload);
        const { error } = await q;
        if (error) throw new Error(error.message);
        await supabase.from("lab_order_items").update({ status: "completed" }).eq("id", itemId);
      }
      await supabase.from("lab_orders").update({ status: "completed" }).eq("id", orderId);
      return null;
    },
    {
      invalidate: [["lab-results", orderId], ["lab-order", orderId], ["lab-order-items", orderId], ["lab-orders"]],
      successMessage: t("saved"),
    },
  );

  if (orderQ.isLoading) return <Loading />;
  if (!order) return <Empty label={t("no_data")} />;

  const items = (itemsQ.data ?? []) as Row[];

  return (
    <div>
      <PageHeader
        title={`${t("laboratory")} — ${s(patient, "full_name")}`}
        subtitle={`${t("mrn")}: ${s(patient, "mrn")} · ${t("age")}: ${calcAge(s(patient, "date_of_birth")) ?? "—"} · ${formatDateTime(
          s(order, "created_at"),
        )}`}
      >
        <StatusBadge status={s(order, "status")} />
        <PrintButton />
        <Button asChild variant="outline" size="sm">
          <Link to="/lab">
            <ArrowLeft className="size-4" /> {t("back")}
          </Link>
        </Button>
      </PageHeader>

      <ErrorBox error={orderQ.error} />

      <Card>
        <CardContent className="p-4">
          <SectionTitle>{t("results")}</SectionTitle>
          {items.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("test")}</TableHead>
                  <TableHead>{t("result")}</TableHead>
                  <TableHead>{t("unit")}</TableHead>
                  <TableHead>{t("reference_range")}</TableHead>
                  <TableHead>{t("flag")}</TableHead>
                  <TableHead>{t("notes")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((item) => {
                  const test = rel(item, "lab_tests");
                  const id = s(item, "id");
                  const flag = flagResult(values[id] ?? "", n(test, "normal_min"), n(test, "normal_max"));
                  return (
                    <TableRow key={id}>
                      <TableCell className="font-medium">
                        {lang === "ar" ? s(test, "name_ar") || s(test, "name") : s(test, "name")}
                      </TableCell>
                      <TableCell className="w-40">
                        <Input
                          dir="ltr"
                          value={values[id] ?? ""}
                          disabled={!can("lab.update")}
                          onChange={(e) => setValues({ ...values, [id]: e.target.value })}
                        />
                      </TableCell>
                      <TableCell dir="ltr">{s(test, "unit") || "—"}</TableCell>
                      <TableCell dir="ltr">{s(test, "reference_range") || "—"}</TableCell>
                      <TableCell>
                        {flag ? <StatusBadge status={flag} /> : <span className="text-muted-foreground">—</span>}
                      </TableCell>
                      <TableCell className="w-56">
                        <Input
                          value={notes[id] ?? ""}
                          disabled={!can("lab.update")}
                          onChange={(e) => setNotes({ ...notes, [id]: e.target.value })}
                        />
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}

          <div className="no-print mt-4 flex flex-wrap gap-2">
            {can("lab.update") ? (
              <>
                <Button variant="outline" onClick={() => setStatus.mutate({ status: "sample_collected" })}>
                  {t("collect_sample")}
                </Button>
                <Button disabled={saveResults.isPending} onClick={() => saveResults.mutate(undefined as never)}>
                  {saveResults.isPending ? t("saving") : t("save_results")}
                </Button>
              </>
            ) : null}
            {can("lab.verify") ? (
              <Button variant="secondary" onClick={() => setStatus.mutate({ status: "verified" })}>
                {t("verify")}
              </Button>
            ) : null}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
