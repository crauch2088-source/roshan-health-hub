import { createFileRoute } from "@tanstack/react-router";
import { Package, Plus, Truck } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";

import { Badge } from "@/components/ui/badge";
import {
  Empty,
  ErrorBox,
  ExportButtons,
  Field,
  Loading,
  PageHeader,
  Pager,
  StatCard,
  PermissionGate,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth";
import { n, rel, s, usePagedRows, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money } from "@/lib/medical";
import {
  DEFAULT_EXPIRY_THRESHOLD_DAYS,
  EXPIRY_TONE,
  expiryStatus,
  type ExpiryStatus,
} from "@/lib/pharmacy";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_authenticated/inventory")({
  head: () => ({
    meta: [
      { title: "Inventory — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Medicine stock levels, batch tracking, expiry and suppliers.",
      },
      { property: "og:title", content: "Inventory — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Medicine stock levels, batch tracking, expiry and suppliers.",
      },
    ],
  }),
  component: InventoryPage,
});

const PAGE_SIZE = 25;

/** Keeps free-text search safe to embed in a PostgREST `.ilike()` filter. */
function sanitizeSearch(term: string): string {
  return term.replace(/[,()%]/g, "").trim();
}

function ExpiryBadge({ status }: { status: ExpiryStatus }) {
  const { t } = useLang();
  return (
    <Badge variant="outline" className={cn("font-medium", EXPIRY_TONE[status])}>
      {t(status)}
    </Badge>
  );
}

function InventoryPage() {
  return (
    <PermissionGate perm="pharmacy.read">
      <InventoryPageInner />
    </PermissionGate>
  );
}

function InventoryPageInner() {
  const { t } = useLang();
  const { currency, settings } = useSettings();
  const [activeTab, setActiveTab] = useState("medicines");
  const [pendingReceiveMedicineId, setPendingReceiveMedicineId] = useState<string | null>(null);
  const thresholdDays =
    Number(settings["pharmacy_expiry_threshold_days"]) || DEFAULT_EXPIRY_THRESHOLD_DAYS;

  const openReceiveForMedicine = useCallback((medicineId: string) => {
    setPendingReceiveMedicineId(medicineId);
    setActiveTab("batches");
  }, []);
  const clearPendingReceiveMedicineId = useCallback(() => setPendingReceiveMedicineId(null), []);

  return (
    <div>
      <PageHeader title={t("inventory")} subtitle={t("stock_overview")} />
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="mb-4 flex-wrap">
          <TabsTrigger value="medicines">{t("medicines")}</TabsTrigger>
          <TabsTrigger value="batches">{t("batches")}</TabsTrigger>
          <TabsTrigger value="suppliers">{t("suppliers")}</TabsTrigger>
        </TabsList>
        <TabsContent value="medicines">
          <MedicinesTab onReceiveStock={openReceiveForMedicine} />
        </TabsContent>
        <TabsContent value="batches">
          <BatchesTab
            thresholdDays={thresholdDays}
            currency={currency}
            initialMedicineId={pendingReceiveMedicineId}
            onInitialMedicineHandled={clearPendingReceiveMedicineId}
          />
        </TabsContent>
        <TabsContent value="suppliers">
          <SuppliersTab currency={currency} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// =============================================================================
// Medicines tab — UNCHANGED from the pre-Phase-3 inventory page other than
// the permission check fix noted inline (pharmacy.manage -> pharmacy.create;
// pharmacy.manage was never a real permission code in the permissions
// table, so this button and the one in the old dispense queue were
// invisible to every non-super-admin role, including the pharmacist role).
// =============================================================================

function MedicinesTab({ onReceiveStock }: { onReceiveStock: (medicineId: string) => void }) {
  const { t } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    name: "",
    unit: "",
    cost_price: "0",
    selling_price: "0",
    reorder_level: "10",
  });

  const list = usePagedRows<Row[]>(
    ["inventory", search],
    ({ from, to }) => {
      let q = supabase
        .from("medicines")
        .select(
          "id, name, unit, stock_quantity, reorder_level, selling_price, cost_price, expiry_date",
          { count: "exact" },
        )
        .is("deleted_at", null);

      const term = sanitizeSearch(search);
      if (term) q = q.ilike("name", `%${term}%`);

      return q.order("name", { ascending: true }).range(from, to);
    },
    page,
    PAGE_SIZE,
  );

  const stats = useRows<Row[]>(["inventory-stats"], () =>
    supabase
      .from("medicines")
      .select("stock_quantity, reorder_level, cost_price")
      .is("deleted_at", null),
  );
  const statRows = (stats.data ?? []) as Row[];
  const lowStock = statRows.filter((m) => n(m, "stock_quantity") <= n(m, "reorder_level")).length;
  const stockValue = statRows.reduce(
    (sum, m) => sum + n(m, "stock_quantity") * n(m, "cost_price"),
    0,
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("medicines").insert({
        name: form.name,
        unit: form.unit || null,
        cost_price: Number(form.cost_price) || 0,
        selling_price: Number(form.selling_price) || 0,
        stock_quantity: 0,
        reorder_level: Number(form.reorder_level) || 0,
        expiry_date: null,
        batch_number: null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["inventory"], ["inventory-stats"], ["medicines"]],
      successMessage: t("saved"),
      onDone: () => setOpen(false),
    },
  );

  const rows = list.rows;

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-end gap-2">
        <Input
          placeholder={t("search")}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          className="w-full sm:w-48"
        />
        <ExportButtons rows={rows} filename="roshan-inventory" />
        {can("pharmacy.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>{t("medicines")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={`${t("name")} *`} className="sm:col-span-2">
                  <Input
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                  />
                </Field>
                <Field label={t("unit")}>
                  <Input
                    value={form.unit}
                    onChange={(e) => setForm({ ...form, unit: e.target.value })}
                  />
                </Field>
                <Field label={t("cost_price")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.cost_price}
                    onChange={(e) => setForm({ ...form, cost_price: e.target.value })}
                  />
                </Field>
                <Field label={t("selling_price")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.selling_price}
                    onChange={(e) => setForm({ ...form, selling_price: e.target.value })}
                  />
                </Field>
                <Field label={t("reorder_level")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.reorder_level}
                    onChange={(e) => setForm({ ...form, reorder_level: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button
                  disabled={!form.name || create.isPending}
                  onClick={() => create.mutate(undefined as never)}
                >
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </div>

      <ErrorBox error={list.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <StatCard label={t("medicines")} value={String(list.count ?? rows.length)} />
        <StatCard label={t("low_stock")} value={String(lowStock)} />
        <StatCard label={t("stock_value")} value={money(stockValue, currency)} />
      </div>

      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <>
              <ul className="divide-y md:hidden" aria-label={t("medicines")}>
                {rows.map((m) => {
                  const low = n(m, "stock_quantity") <= n(m, "reorder_level");
                  return (
                    <li
                      key={s(m, "id")}
                      className={cn("space-y-1.5 p-3", low && "bg-destructive/5")}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="font-medium">{s(m, "name")}</p>
                          <p className="text-xs text-muted-foreground">{s(m, "unit") || "—"}</p>
                        </div>
                        <span
                          dir="ltr"
                          className={cn("shrink-0 font-semibold", low && "text-destructive")}
                        >
                          {n(m, "stock_quantity")}
                        </span>
                      </div>
                      <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
                        <span>{money(n(m, "selling_price"), currency)}</span>
                        <span dir="ltr">
                          {s(m, "expiry_date") ? formatDate(s(m, "expiry_date")) : "—"}
                        </span>
                      </div>
                      {can("pharmacy.create") ? (
                        <Button
                          variant="outline"
                          size="sm"
                          className="w-full"
                          onClick={() => onReceiveStock(s(m, "id"))}
                        >
                          {t("receive_stock")}
                        </Button>
                      ) : null}
                    </li>
                  );
                })}
              </ul>
              <div className="hidden md:block">
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("name")}</TableHead>
                      <TableHead>{t("unit")}</TableHead>
                      <TableHead>{t("stock")}</TableHead>
                      <TableHead>{t("selling_price")}</TableHead>
                      <TableHead>{t("expiry_date")}</TableHead>
                      <TableHead className="no-print" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {rows.map((m) => {
                      const low = n(m, "stock_quantity") <= n(m, "reorder_level");
                      return (
                        <TableRow key={s(m, "id")} className={low ? "bg-destructive/5" : undefined}>
                          <TableCell className="font-medium">{s(m, "name")}</TableCell>
                          <TableCell>{s(m, "unit") || "—"}</TableCell>
                          <TableCell
                            dir="ltr"
                            className={low ? "font-semibold text-destructive" : undefined}
                          >
                            {n(m, "stock_quantity")}
                          </TableCell>
                          <TableCell>{money(n(m, "selling_price"), currency)}</TableCell>
                          <TableCell dir="ltr">
                            {s(m, "expiry_date") ? formatDate(s(m, "expiry_date")) : "—"}
                          </TableCell>
                          <TableCell className="no-print text-end">
                            {can("pharmacy.create") ? (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => onReceiveStock(s(m, "id"))}
                              >
                                {t("receive_stock")}
                              </Button>
                            ) : null}
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </>
          )}
          <Pager
            page={list.page}
            pageCount={list.pageCount}
            count={list.count}
            pageSize={PAGE_SIZE}
            hasPrev={list.hasPrev}
            hasNext={list.hasNext}
            isFetching={list.isFetching}
            onPrev={() => setPage((p) => Math.max(1, p - 1))}
            onNext={() => setPage((p) => p + 1)}
          />
        </CardContent>
      </Card>
    </div>
  );
}

// =============================================================================
// Batches tab — Part 1 (batch fields), Part 3 (expiry status), Part 4
// (low-stock at batch level), Part 6 (batch table, detail dialog, receive
// stock dialog, expiry badges).
// =============================================================================

type BatchFormState = {
  medicine_id: string;
  supplier_id: string;
  batch_number: string;
  quantity_received: string;
  purchase_price: string;
  selling_price: string;
  manufacture_date: string;
  expiry_date: string;
  invoice_reference: string;
};

const EMPTY_BATCH_FORM: BatchFormState = {
  medicine_id: "",
  supplier_id: "",
  batch_number: "",
  quantity_received: "0",
  purchase_price: "0",
  selling_price: "",
  manufacture_date: "",
  expiry_date: "",
  invoice_reference: "",
};

function BatchesTab({
  thresholdDays,
  currency,
  initialMedicineId,
  onInitialMedicineHandled,
}: {
  thresholdDays: number;
  currency: string;
  initialMedicineId: string | null;
  onInitialMedicineHandled: () => void;
}) {
  const { t } = useLang();
  const { can } = useAuth();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | ExpiryStatus>("all");
  const [receiveOpen, setReceiveOpen] = useState(false);
  const [form, setForm] = useState<BatchFormState>(EMPTY_BATCH_FORM);
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [detail, setDetail] = useState<Row | null>(null);

  const updateForm = (patch: Partial<BatchFormState>) => {
    setForm((current) => ({ ...current, ...patch }));
    setIdempotencyKey(crypto.randomUUID());
  };

  useEffect(() => {
    if (!initialMedicineId) return;
    setForm({ ...EMPTY_BATCH_FORM, medicine_id: initialMedicineId, selling_price: "" });
    setIdempotencyKey(crypto.randomUUID());
    setReceiveOpen(true);
    onInitialMedicineHandled();
  }, [initialMedicineId, onInitialMedicineHandled]);

  const batches = useRows<Row[]>(["pharmacy-batches"], () =>
    supabase
      .from("pharmacy_inventory")
      .select(
        "id, medicine_id, batch_number, supplier_id, purchase_price, selling_price, quantity_received, quantity_remaining, manufacture_date, expiry_date, invoice_reference, created_at, updated_at, medicines(id, name, unit), suppliers(id, name, phone)",
      )
      .is("deleted_at", null)
      .order("expiry_date", { ascending: true, nullsFirst: false })
      .limit(500),
  );

  const medicines = useRows<Row[]>(["medicines-picker"], () =>
    supabase
      .from("medicines")
      .select("id, name, unit")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const suppliers = useRows<Row[]>(["suppliers-picker"], () =>
    supabase
      .from("suppliers")
      .select("id, name")
      .is("deleted_at", null)
      .eq("active", true)
      .order("name", { ascending: true }),
  );

  const movements = useRows<Row[]>(
    ["batch-movements", s(detail, "id")],
    () =>
      supabase
        .from("stock_movements")
        .select("id, movement_type, quantity, created_at, reference_table")
        .eq("batch_id", s(detail, "id"))
        .order("created_at", { ascending: false }),
    { enabled: Boolean(detail) },
  );

  const rows = useMemo(() => {
    const term = search.trim().toLowerCase();
    return ((batches.data ?? []) as Row[]).filter((b) => {
      const status = expiryStatus(s(b, "expiry_date") || null, thresholdDays);
      if (statusFilter !== "all" && status !== statusFilter) return false;
      if (!term) return true;
      const hay =
        `${s(b, "batch_number")} ${s(rel(b, "medicines"), "name")} ${s(rel(b, "suppliers"), "name")} ${s(b, "invoice_reference")}`.toLowerCase();
      return hay.includes(term);
    });
  }, [batches.data, search, statusFilter, thresholdDays]);

  const expiringCount = ((batches.data ?? []) as Row[]).filter(
    (b) => expiryStatus(s(b, "expiry_date") || null, thresholdDays) === "expiring_soon",
  ).length;
  const expiredCount = ((batches.data ?? []) as Row[]).filter(
    (b) => expiryStatus(s(b, "expiry_date") || null, thresholdDays) === "expired",
  ).length;
  const lowStockBatches = ((batches.data ?? []) as Row[]).filter(
    (b) => n(b, "quantity_remaining") > 0 && n(b, "quantity_remaining") <= 10,
  ).length;

  const receive = useSave(
    async () => {
      if (!form.medicine_id) throw new Error(t("select_medicine"));
      if (!form.expiry_date) throw new Error(t("expiry_required"));

      const qty = Number(form.quantity_received);
      if (!Number.isFinite(qty) || !Number.isInteger(qty) || qty <= 0) {
        throw new Error(t("invalid_quantity"));
      }

      const moneyPattern = /^\d+(?:\.\d{1,2})?$/;
      const purchaseText = form.purchase_price.trim();
      const sellingText = form.selling_price.trim();
      if (
        (purchaseText && !moneyPattern.test(purchaseText)) ||
        (sellingText && !moneyPattern.test(sellingText))
      ) {
        throw new Error(t("invalid_amount"));
      }

      const purchasePrice = purchaseText ? Number(purchaseText) : 0;
      const sellingPrice = sellingText ? Number(sellingText) : null;
      if (
        !Number.isFinite(purchasePrice) ||
        purchasePrice < 0 ||
        (sellingPrice !== null && (!Number.isFinite(sellingPrice) || sellingPrice < 0))
      ) {
        throw new Error(t("invalid_amount"));
      }

      const { error } = await supabase.rpc("fn_receive_pharmacy_batch_atomic", {
        p_medicine_id: form.medicine_id,
        p_quantity: qty,
        p_batch_number: form.batch_number.trim() || null,
        p_expiry_date: form.expiry_date,
        p_manufacture_date: form.manufacture_date || null,
        p_purchase_price: purchasePrice,
        p_selling_price: sellingPrice,
        p_supplier_id: form.supplier_id || null,
        p_invoice_reference: form.invoice_reference.trim() || null,
        p_idempotency_key: idempotencyKey,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["pharmacy-batches"], ["inventory"], ["inventory-stats"], ["medicines"]],
      successMessage: t("saved"),
      onDone: () => {
        setReceiveOpen(false);
        setForm(EMPTY_BATCH_FORM);
        setIdempotencyKey(crypto.randomUUID());
      },
    },
  );

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-end gap-2">
        <Input
          placeholder={t("search")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full sm:w-52"
        />
        <Select
          value={statusFilter}
          onValueChange={(v) => setStatusFilter(v as "all" | ExpiryStatus)}
        >
          <SelectTrigger className="w-full sm:w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("all")}</SelectItem>
            <SelectItem value="healthy">{t("healthy")}</SelectItem>
            <SelectItem value="expiring_soon">{t("expiring_soon")}</SelectItem>
            <SelectItem value="expired">{t("expired")}</SelectItem>
            <SelectItem value="unknown">{t("unknown")}</SelectItem>
          </SelectContent>
        </Select>
        <ExportButtons rows={rows} filename="roshan-batches" />
        {can("pharmacy.create") ? (
          <Button size="sm" onClick={() => setReceiveOpen(true)}>
            <Plus className="size-4" /> {t("receive_stock")}
          </Button>
        ) : null}
      </div>

      <ErrorBox error={batches.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <StatCard label={t("expiring_medicines")} value={String(expiringCount)} tone="warning" />
        <StatCard label={t("expired_medicines")} value={String(expiredCount)} tone="destructive" />
        <StatCard label={t("low_stock_batches")} value={String(lowStockBatches)} tone="warning" />
      </div>

      <Card>
        <CardContent className="p-0">
          {batches.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <>
              <ul className="divide-y md:hidden" aria-label={t("batches")}>
                {rows.map((b) => {
                  const status = expiryStatus(s(b, "expiry_date") || null, thresholdDays);
                  return (
                    <li key={s(b, "id")}>
                      <button
                        type="button"
                        className="block w-full space-y-1 px-4 py-3 text-start hover:bg-accent/40"
                        onClick={() => setDetail(b)}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <span className="min-w-0 break-words font-medium">
                            {s(rel(b, "medicines"), "name") || "—"}
                          </span>
                          <ExpiryBadge status={status} />
                        </div>
                        <div className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
                          <span dir="ltr">{s(b, "batch_number") || "—"}</span>
                          <span>{s(rel(b, "suppliers"), "name") || "—"}</span>
                          <span dir="ltr">
                            {s(b, "expiry_date") ? formatDate(s(b, "expiry_date")) : "—"}
                          </span>
                        </div>
                        <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
                          <span>
                            {t("purchase_price")}: {money(n(b, "purchase_price"), currency)}
                          </span>
                          <span>
                            {t("selling_price")}: {money(n(b, "selling_price"), currency)}
                          </span>
                        </div>
                        <div
                          className={cn(
                            "text-sm",
                            n(b, "quantity_remaining") <= 10 && "font-semibold text-destructive",
                          )}
                        >
                          {t("remaining_quantity")}:{" "}
                          <span dir="ltr">{n(b, "quantity_remaining")}</span>
                        </div>
                      </button>
                    </li>
                  );
                })}
              </ul>
              <div className="hidden md:block">
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("medicines")}</TableHead>
                      <TableHead>{t("batch_number")}</TableHead>
                      <TableHead>{t("supplier")}</TableHead>
                      <TableHead>{t("expiry_date")}</TableHead>
                      <TableHead>{t("purchase_price")}</TableHead>
                      <TableHead>{t("selling_price")}</TableHead>
                      <TableHead>{t("remaining_quantity")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {rows.map((b) => {
                      const status = expiryStatus(s(b, "expiry_date") || null, thresholdDays);
                      return (
                        <TableRow
                          key={s(b, "id")}
                          className="cursor-pointer hover:bg-accent/40"
                          onClick={() => setDetail(b)}
                        >
                          <TableCell className="font-medium">
                            {s(rel(b, "medicines"), "name") || "—"}
                          </TableCell>
                          <TableCell dir="ltr">{s(b, "batch_number") || "—"}</TableCell>
                          <TableCell>{s(rel(b, "suppliers"), "name") || "—"}</TableCell>
                          <TableCell dir="ltr">
                            {s(b, "expiry_date") ? formatDate(s(b, "expiry_date")) : "—"}
                          </TableCell>
                          <TableCell>{money(n(b, "purchase_price"), currency)}</TableCell>
                          <TableCell>{money(n(b, "selling_price"), currency)}</TableCell>
                          <TableCell
                            dir="ltr"
                            className={
                              n(b, "quantity_remaining") <= 10
                                ? "font-semibold text-destructive"
                                : undefined
                            }
                          >
                            {n(b, "quantity_remaining")}
                          </TableCell>
                          <TableCell>
                            <ExpiryBadge status={status} />
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Receive Stock dialog */}
      <Dialog open={receiveOpen} onOpenChange={setReceiveOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t("receive_stock")}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={`${t("medicines")} *`} className="sm:col-span-2">
              <Select
                {...(form.medicine_id ? { value: form.medicine_id } : {})}
                onValueChange={(v) => updateForm({ medicine_id: v })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t("select_medicine")} />
                </SelectTrigger>
                <SelectContent>
                  {((medicines.data ?? []) as Row[]).map((m) => (
                    <SelectItem key={s(m, "id")} value={s(m, "id")}>
                      {s(m, "name")}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
            <Field label={t("supplier")}>
              <Select
                {...(form.supplier_id ? { value: form.supplier_id } : {})}
                onValueChange={(v) => updateForm({ supplier_id: v })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t("none")} />
                </SelectTrigger>
                <SelectContent>
                  {((suppliers.data ?? []) as Row[]).map((sp) => (
                    <SelectItem key={s(sp, "id")} value={s(sp, "id")}>
                      {s(sp, "name")}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
            <Field label={t("batch_number")}>
              <Input
                dir="ltr"
                value={form.batch_number}
                onChange={(e) => updateForm({ batch_number: e.target.value })}
              />
            </Field>
            <Field label={`${t("quantity_received")} *`}>
              <Input
                type="number"
                min="1"
                step="1"
                dir="ltr"
                value={form.quantity_received}
                onChange={(e) => updateForm({ quantity_received: e.target.value })}
              />
            </Field>
            <Field label={t("purchase_price")}>
              <Input
                type="number"
                min="0"
                step="0.01"
                dir="ltr"
                value={form.purchase_price}
                onChange={(e) => updateForm({ purchase_price: e.target.value })}
              />
            </Field>
            <Field label={t("selling_price")}>
              <Input
                type="number"
                min="0"
                step="0.01"
                dir="ltr"
                value={form.selling_price}
                onChange={(e) => updateForm({ selling_price: e.target.value })}
              />
            </Field>
            <Field label={t("manufacture_date")}>
              <Input
                type="date"
                dir="ltr"
                value={form.manufacture_date}
                onChange={(e) => updateForm({ manufacture_date: e.target.value })}
              />
            </Field>
            <Field label={t("expiry_date")}>
              <Input
                type="date"
                dir="ltr"
                value={form.expiry_date}
                onChange={(e) => updateForm({ expiry_date: e.target.value })}
              />
            </Field>
            <Field label={t("invoice_reference")} className="sm:col-span-2">
              <Input
                dir="ltr"
                value={form.invoice_reference}
                onChange={(e) => updateForm({ invoice_reference: e.target.value })}
              />
            </Field>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setReceiveOpen(false)}>
              {t("cancel")}
            </Button>
            <Button
              disabled={
                !form.medicine_id ||
                !form.quantity_received ||
                !form.expiry_date ||
                receive.isPending
              }
              onClick={() => receive.mutate(undefined as never)}
            >
              {receive.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Batch detail dialog */}
      <Dialog open={Boolean(detail)} onOpenChange={(o) => (o ? null : setDetail(null))}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {s(rel(detail, "medicines"), "name")} · {s(detail, "batch_number") || "—"}
            </DialogTitle>
          </DialogHeader>
          {detail ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <p className="text-xs text-muted-foreground">{t("supplier")}</p>
                  <p className="font-medium">{s(rel(detail, "suppliers"), "name") || "—"}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("status")}</p>
                  <ExpiryBadge
                    status={expiryStatus(s(detail, "expiry_date") || null, thresholdDays)}
                  />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("manufacture_date")}</p>
                  <p dir="ltr">
                    {s(detail, "manufacture_date")
                      ? formatDate(s(detail, "manufacture_date"))
                      : "—"}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("expiry_date")}</p>
                  <p dir="ltr">
                    {s(detail, "expiry_date") ? formatDate(s(detail, "expiry_date")) : "—"}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("quantity_received")}</p>
                  <p dir="ltr">{n(detail, "quantity_received")}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("remaining_quantity")}</p>
                  <p dir="ltr">{n(detail, "quantity_remaining")}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("purchase_price")}</p>
                  <p dir="ltr">{money(n(detail, "purchase_price"), currency)}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t("selling_price")}</p>
                  <p dir="ltr">{money(n(detail, "selling_price"), currency)}</p>
                </div>
                <div className="col-span-2">
                  <p className="text-xs text-muted-foreground">{t("invoice_reference")}</p>
                  <p dir="ltr">{s(detail, "invoice_reference") || "—"}</p>
                </div>
              </div>

              <div>
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {t("movement_history")}
                </p>
                {movements.isLoading ? (
                  <Loading />
                ) : ((movements.data ?? []) as Row[]).length === 0 ? (
                  <Empty />
                ) : (
                  <Table density="compact">
                    <TableHeader>
                      <TableRow>
                        <TableHead>{t("date")}</TableHead>
                        <TableHead>{t("type")}</TableHead>
                        <TableHead>{t("quantity")}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {((movements.data ?? []) as Row[]).map((mv) => (
                        <TableRow key={s(mv, "id")}>
                          <TableCell dir="ltr">{formatDate(s(mv, "created_at"))}</TableCell>
                          <TableCell>{t(s(mv, "movement_type"))}</TableCell>
                          <TableCell
                            dir="ltr"
                            className={n(mv, "quantity") < 0 ? "text-destructive" : "text-success"}
                          >
                            {n(mv, "quantity") > 0 ? `+${n(mv, "quantity")}` : n(mv, "quantity")}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                )}
              </div>
            </div>
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}

// =============================================================================
// Suppliers tab — Part 5. Batch history IS purchase history here: every
// batch received from a supplier is itself a purchase event, so one table
// covers "supplier purchase history" and "supplier batch history" without
// inventing a second ledger that would just duplicate pharmacy_inventory.
// =============================================================================

function SuppliersTab({ currency }: { currency: string }) {
  const { t } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", phone: "", address: "" });
  const [history, setHistory] = useState<Row | null>(null);

  const suppliers = useRows<Row[]>(["suppliers"], () =>
    supabase
      .from("suppliers")
      .select("id, name, phone, address, active")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const supplierBatches = useRows<Row[]>(
    ["supplier-batches", s(history, "id")],
    () =>
      supabase
        .from("pharmacy_inventory")
        .select(
          "id, batch_number, expiry_date, quantity_received, purchase_price, invoice_reference, created_at, medicines(name)",
        )
        .eq("supplier_id", s(history, "id"))
        .is("deleted_at", null)
        .order("created_at", { ascending: false }),
    { enabled: Boolean(history) },
  );

  const create = useSave(
    async () => {
      if (!form.name.trim()) throw new Error(t("name_required"));
      const { error } = await supabase.from("suppliers").insert({
        name: form.name.trim(),
        phone: form.phone || null,
        address: form.address || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["suppliers"], ["suppliers-picker"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm({ name: "", phone: "", address: "" });
      },
    },
  );

  const rows = (suppliers.data ?? []) as Row[];

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-end gap-2">
        <ExportButtons rows={rows} filename="roshan-suppliers" />
        {can("pharmacy.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add_supplier")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("add_supplier")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("name")} *`}>
                  <Input
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                  />
                </Field>
                <Field label={t("phone")}>
                  <Input
                    dir="ltr"
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  />
                </Field>
                <Field label={t("address")}>
                  <Input
                    value={form.address}
                    onChange={(e) => setForm({ ...form, address: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button
                  disabled={!form.name || create.isPending}
                  onClick={() => create.mutate(undefined as never)}
                >
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </div>

      <ErrorBox error={suppliers.error} />

      <Card>
        <CardContent className="p-0">
          {suppliers.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <>
              <ul className="divide-y md:hidden" aria-label={t("suppliers")}>
                {rows.map((sp) => (
                  <li key={s(sp, "id")} className="space-y-1 px-4 py-3">
                    <div className="inline-flex items-center gap-1.5 font-medium">
                      <Truck className="size-3.5 text-muted-foreground" /> {s(sp, "name")}
                    </div>
                    <div className="text-sm text-muted-foreground" dir="ltr">
                      {s(sp, "phone") || "—"}
                    </div>
                    <div className="break-words text-sm text-muted-foreground">
                      {s(sp, "address") || "—"}
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      className="no-print w-full"
                      onClick={() => setHistory(sp)}
                    >
                      <Package className="size-3.5" /> {t("purchase_history")}
                    </Button>
                  </li>
                ))}
              </ul>
              <div className="hidden md:block">
                <Table density="compact">
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("name")}</TableHead>
                      <TableHead>{t("phone")}</TableHead>
                      <TableHead>{t("address")}</TableHead>
                      <TableHead className="no-print" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {rows.map((sp) => (
                      <TableRow key={s(sp, "id")}>
                        <TableCell className="font-medium">
                          <span className="inline-flex items-center gap-1.5">
                            <Truck className="size-3.5 text-muted-foreground" /> {s(sp, "name")}
                          </span>
                        </TableCell>
                        <TableCell dir="ltr">{s(sp, "phone") || "—"}</TableCell>
                        <TableCell>{s(sp, "address") || "—"}</TableCell>
                        <TableCell className="no-print text-end">
                          <Button variant="outline" size="sm" onClick={() => setHistory(sp)}>
                            <Package className="size-3.5" /> {t("purchase_history")}
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      <Dialog open={Boolean(history)} onOpenChange={(o) => (o ? null : setHistory(null))}>
        <DialogContent className="max-h-[90vh] max-w-2xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {t("purchase_history")} — {s(history, "name")}
            </DialogTitle>
          </DialogHeader>
          {supplierBatches.isLoading ? (
            <Loading />
          ) : ((supplierBatches.data ?? []) as Row[]).length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("medicines")}</TableHead>
                  <TableHead>{t("batch_number")}</TableHead>
                  <TableHead>{t("quantity_received")}</TableHead>
                  <TableHead>{t("purchase_price")}</TableHead>
                  <TableHead>{t("expiry_date")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {((supplierBatches.data ?? []) as Row[]).map((b) => (
                  <TableRow key={s(b, "id")}>
                    <TableCell dir="ltr">{formatDate(s(b, "created_at"))}</TableCell>
                    <TableCell className="font-medium">
                      {s(rel(b, "medicines"), "name") || "—"}
                    </TableCell>
                    <TableCell dir="ltr">{s(b, "batch_number") || "—"}</TableCell>
                    <TableCell dir="ltr">{n(b, "quantity_received")}</TableCell>
                    <TableCell>{money(n(b, "purchase_price"), currency)}</TableCell>
                    <TableCell dir="ltr">
                      {s(b, "expiry_date") ? formatDate(s(b, "expiry_date")) : "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
