import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";

import {
  DataPanel,
  Empty,
  ErrorBox,
  ExportButtons,
  InitialAvatar,
  NoResults,
  PageHeader,
  PageSkeleton,
  PermissionGate,
  SearchField,
  SectionTitle,
  StatusBadge,
  Toolbar,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
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
import { dispensePrescriptionFefo, type DispenseResultRow } from "@/lib/pharmacy";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/pharmacy")({
  head: () => ({
    meta: [
      { title: "Pharmacy — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Dispense prescriptions using FEFO batch stock and bill medicines.",
      },
      { property: "og:title", content: "Pharmacy — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Dispense prescriptions using FEFO batch stock and bill medicines.",
      },
    ],
  }),
  component: PharmacyPage,
});

const STATUSES = ["pending", "dispensed", "external", "all"];

function PharmacyPage() {
  return (
    <PermissionGate perm="pharmacy.read">
      <PharmacyPageInner />
    </PermissionGate>
  );
}

function PharmacyPageInner() {
  const { t, lang } = useLang();
  // pharmacy.manage/pharmacy.dispense were never real permission codes (see
  // Phase 3 write-up) — the actual DB-level RLS on pharmacy_inventory,
  // medicines and stock_movements already keys off pharmacy.create/update,
  // so the UI now checks the same codes instead of two dangling ones.
  const { can } = useAuth();
  const { currency } = useSettings();
  const [status, setStatus] = useState("pending");
  const [search, setSearch] = useState("");
  const [dispenseDetail, setDispenseDetail] = useState<Record<string, DispenseResultRow[]>>({});

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
    { refetchInterval: 20000, keepPrevious: true },
  );

  const dispense = useSave<{ prescriptionId: string }>(
    async ({ prescriptionId }) => {
      const result = await dispensePrescriptionFefo(prescriptionId);
      setDispenseDetail((prev) => ({ ...prev, [prescriptionId]: result }));
      return result;
    },
    {
      invalidate: [["pharmacy-queue"], ["medicines"], ["inventory"], ["pharmacy-batches"]],
      successMessage: t("dispensed"),
    },
  );

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return ((list.data ?? []) as Row[]).filter((p) => {
      if (!q) return true;
      const patient = rel(p, "patients");
      const items = (p["prescription_items"] as Row[]) ?? [];
      const meds = items.map((i) => s(rel(i, "medicines"), "name")).join(" ");
      return `${s(patient, "full_name")} ${s(patient, "mrn")} ${meds}`.toLowerCase().includes(q);
    });
  }, [list.data, search]);
  if (list.isLoading) return <PageSkeleton />;
  const filtered = search.trim() !== "" || status !== "pending";

  return (
    <div>
      <PageHeader title={t("pharmacy")} subtitle={t("dispense_queue")}>
        <ExportButtons rows={rows} filename="roshan-prescriptions" />
      </PageHeader>

      <Toolbar className="mb-4">
        <SearchField
          value={search}
          onChange={setSearch}
          placeholder={t("search")}
          label={t("search")}
        />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="h-11 w-full sm:w-44" aria-label={t("status")}>
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
      </Toolbar>

      <ErrorBox error={list.error} />

      {rows.length === 0 && filtered ? (
        <NoResults
          onClear={() => {
            setSearch("");
            setStatus("pending");
          }}
        />
      ) : rows.length === 0 ? (
        <Empty
          title={t("no_data")}
          description={lang === "ar" ? "لا وصفات مطابقة." : "No matching prescriptions."}
        />
      ) : (
        <div className="grid gap-4">
          {rows.map((p) => {
            const items = (p["prescription_items"] as Row[]) ?? [];
            const total = items.reduce(
              (sum, i) => sum + (n(i, "quantity") || 1) * n(rel(i, "medicines"), "selling_price"),
              0,
            );
            const usedBatches = dispenseDetail[s(p, "id")];
            return (
              <DataPanel key={s(p, "id")}>
                <div className="p-4">
                  <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <InitialAvatar name={s(rel(p, "patients"), "full_name")} />
                      <div className="min-w-0">
                        <p className="truncate font-semibold">
                          {s(rel(p, "patients"), "full_name")}
                        </p>
                        <p className="truncate text-xs text-muted-foreground" dir="ltr">
                          {s(rel(p, "patients"), "mrn")} · {formatDateTime(s(p, "created_at"))} ·{" "}
                          {s(rel(p, "users"), "full_name")}
                        </p>
                      </div>
                    </div>
                    <div className="flex w-full items-center justify-between gap-2 sm:w-auto sm:justify-end">
                      <StatusBadge status={s(p, "status")} />
                      {can("pharmacy.update") && s(p, "status") === "pending" ? (
                        <Button
                          disabled={dispense.isPending}
                          onClick={() => dispense.mutate({ prescriptionId: s(p, "id") })}
                        >
                          {t("dispense")}
                        </Button>
                      ) : null}
                    </div>
                  </div>
                  <SectionTitle>{t("medicines")}</SectionTitle>
                  <ul className="divide-y rounded-md border md:hidden">
                    {items.map((i) => (
                      <li
                        key={s(i, "id")}
                        className="flex items-start justify-between gap-3 p-2.5 text-sm"
                      >
                        <div className="min-w-0 space-y-0.5">
                          <p className="font-medium">{s(rel(i, "medicines"), "name")}</p>
                          <p className="text-xs text-muted-foreground">
                            {[s(i, "dosage"), s(i, "frequency"), s(i, "duration")]
                              .filter(Boolean)
                              .join(" · ") || "—"}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            {t("quantity")} <span dir="ltr">{n(i, "quantity") || 1}</span> ·{" "}
                            {t("stock")}{" "}
                            <span dir="ltr">{n(rel(i, "medicines"), "stock_quantity")}</span>
                          </p>
                        </div>
                        <span className="shrink-0 font-semibold">
                          {money(
                            (n(i, "quantity") || 1) * n(rel(i, "medicines"), "selling_price"),
                            currency,
                          )}
                        </span>
                      </li>
                    ))}
                  </ul>
                  <div className="hidden md:block">
                    <Table density="compact">
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
                            <TableCell className="font-medium">
                              {s(rel(i, "medicines"), "name")}
                            </TableCell>
                            <TableCell>
                              {[s(i, "dosage"), s(i, "frequency"), s(i, "duration")]
                                .filter(Boolean)
                                .join(" · ") || "—"}
                            </TableCell>
                            <TableCell dir="ltr">{n(i, "quantity") || 1}</TableCell>
                            <TableCell dir="ltr">
                              {n(rel(i, "medicines"), "stock_quantity")}
                            </TableCell>
                            <TableCell>
                              {money(
                                (n(i, "quantity") || 1) * n(rel(i, "medicines"), "selling_price"),
                                currency,
                              )}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                  <p className="mt-2 text-end text-sm font-semibold">
                    {t("total")}: {money(total, currency)}
                  </p>

                  {usedBatches && usedBatches.length > 0 ? (
                    <div className="mt-4 rounded-lg border bg-accent/30 p-3">
                      <SectionTitle>{t("batches_used")}</SectionTitle>
                      <Table density="compact">
                        <TableHeader>
                          <TableRow>
                            <TableHead>{t("medicines")}</TableHead>
                            <TableHead>{t("batch_number")}</TableHead>
                            <TableHead>{t("expiry_date")}</TableHead>
                            <TableHead>{t("quantity_dispensed")}</TableHead>
                            <TableHead>{t("remaining_quantity")}</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {usedBatches.map((row, idx) => (
                            <TableRow key={`${row.item_id}-${row.batch_id ?? "legacy"}-${idx}`}>
                              <TableCell className="font-medium">{row.medicine_name}</TableCell>
                              <TableCell dir="ltr">
                                {row.batch_number ?? t("legacy_stock")}
                              </TableCell>
                              <TableCell dir="ltr">{row.expiry_date ?? "—"}</TableCell>
                              <TableCell dir="ltr">{row.quantity_dispensed}</TableCell>
                              <TableCell dir="ltr">{row.batch_quantity_remaining ?? "—"}</TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </div>
                  ) : null}
                </div>
              </DataPanel>
            );
          })}
        </div>
      )}
    </div>
  );
}
