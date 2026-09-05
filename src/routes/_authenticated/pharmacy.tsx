import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, SectionTitle, StatusBadge } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
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
import { useAuth } from "@/lib/auth";
import { n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDateTime, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/pharmacy")({
  head: () => ({
    meta: [
      { title: "Pharmacy — ROSHAN Medical Center" },
      { name: "description", content: "Dispense prescriptions, deduct stock and bill medicines." },
      { property: "og:title", content: "Pharmacy — ROSHAN Medical Center" },
      { property: "og:description", content: "Dispense prescriptions, deduct stock and bill medicines." },
    ],
  }),
  component: PharmacyPage,
});

const STATUSES = ["pending", "dispensed", "external", "all"];

function PharmacyPage() {
  const { t } = useLang();
  const { can, user } = useAuth();
  const { currency } = useSettings();
  const [status, setStatus] = useState("pending");
  const [search, setSearch] = useState("");

  const list = useRows(
    ["pharmacy-queue", status],
    () => {
      let q = supabase
        .from("prescriptions")
        .select(
          "id, status, created_at, is_external, patients(full_name, mrn), users(full_name), prescription_items(id, quantity, dosage, frequency, duration, medicine_id, medicines(name, selling_price, stock_quantity))",
        )
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(200);
      if (status !== "all") q = q.eq("status", status);
      return q;
    },
    { refetchInterval: 20000 },
  );

  const dispense = useSave<{ prescription: Row }>(
    async ({ prescription }) => {
      const items = (prescription["prescription_items"] as Row[]) ?? [];
      for (const item of items) {
        const med = rel(item, "medicines");
        const qty = n(item, "quantity") || 1;
        const stock = n(med, "stock_quantity");
        if (stock < qty) throw new Error(`${t("insufficient_stock")}: ${s(med, "name")}`);
        const { error } = await supabase
          .from("medicines")
          .update({ stock_quantity: stock - qty })
          .eq("id", s(item, "medicine_id"));
        if (error) throw new Error(error.message);
        await supabase.from("stock_movements").insert({
          medicine_id: s(item, "medicine_id"),
          movement_type: "dispense",
          quantity: -qty,
          reference_id: s(prescription, "id"),
          created_by: user?.id ?? null,
        });
      }
      const { error: pErr } = await supabase
        .from("prescriptions")
        .update({ status: "dispensed", dispensed_by: user?.id ?? null, dispensed_at: new Date().toISOString() })
        .eq("id", s(prescription, "id"));
      if (pErr) throw new Error(pErr.message);
      return null;
    },
    { invalidate: [["pharmacy-queue"], ["medicines"], ["inventory"]], successMessage: t("dispensed") },
  );

  const rows = useMemo(() => { const q = search.trim().toLowerCase(); return ((list.data ?? []) as Row[]).filter((p) => { if (!q) return true; const patient = rel(p, "patients"); const items = (p["prescription_items"] as Row[]) ?? []; const meds = items.map((i) => s(rel(i, "medicines"), "name")).join(" "); return `${s(patient,"full_name")} ${s(patient,"mrn")} ${meds}`.toLowerCase().includes(q); }); }, [list.data, search]);
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("pharmacy")} subtitle={t("dispense_queue")}>
        <Input placeholder={t("search")} value={search} onChange={(e) => setSearch(e.target.value)} className="w-56" />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUSES.map((x) => (
              <SelectItem key={x} value={x}>
                {t(x)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <ExportButtons rows={rows} filename="roshan-prescriptions" />
      </PageHeader>

      <ErrorBox error={list.error} />

      {rows.length === 0 ? (
        <Empty />
      ) : (
        <div className="grid gap-4">
          {rows.map((p) => {
            const items = (p["prescription_items"] as Row[]) ?? [];
            const total = items.reduce(
              (sum, i) => sum + (n(i, "quantity") || 1) * n(rel(i, "medicines"), "selling_price"),
              0,
            );
            return (
              <Card key={s(p, "id")}>
                <CardContent className="p-4">
                  <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <p className="font-semibold">{s(rel(p, "patients"), "full_name")}</p>
                      <p className="text-xs text-muted-foreground" dir="ltr">
                        {s(rel(p, "patients"), "mrn")} · {formatDateTime(s(p, "created_at"))} ·{" "}
                        {s(rel(p, "users"), "full_name")}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <StatusBadge status={s(p, "status")} />
                      {can("pharmacy.dispense") && s(p, "status") === "pending" ? (
                        <Button
                          size="sm"
                          disabled={dispense.isPending}
                          onClick={() => dispense.mutate({ prescription: p })}
                        >
                          {t("dispense")}
                        </Button>
                      ) : null}
                    </div>
                  </div>
                  <SectionTitle>{t("medicines")}</SectionTitle>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>{t("medicines")}</TableHead>
                        <TableHead>{t("dosage")}</TableHead>
                        <TableHead>{t("quantity")}</TableHead>
                        <TableHead>{t("stock")}</TableHead>
                        <TableHead>{t("total")}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {items.map((i) => (
                        <TableRow key={s(i, "id")}>
                          <TableCell className="font-medium">{s(rel(i, "medicines"), "name")}</TableCell>
                          <TableCell>
                            {[s(i, "dosage"), s(i, "frequency"), s(i, "duration")].filter(Boolean).join(" · ") || "—"}
                          </TableCell>
                          <TableCell dir="ltr">{n(i, "quantity") || 1}</TableCell>
                          <TableCell dir="ltr">{n(rel(i, "medicines"), "stock_quantity")}</TableCell>
                          <TableCell>
                            {money((n(i, "quantity") || 1) * n(rel(i, "medicines"), "selling_price"), currency)}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                  <p className="mt-2 text-end text-sm font-semibold">
                    {t("total")}: {money(total, currency)}
                  </p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
