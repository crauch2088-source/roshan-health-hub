import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, Pager, StatCard } from "@/components/kit";
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { n, s, usePagedRows, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/inventory")({
  head: () => ({
    meta: [
      { title: "Inventory — ROSHAN Medical Center" },
      { name: "description", content: "Medicine stock levels, expiry tracking and stock receipts." },
      { property: "og:title", content: "Inventory — ROSHAN Medical Center" },
      { property: "og:description", content: "Medicine stock levels, expiry tracking and stock receipts." },
    ],
  }),
  component: InventoryPage,
});

const PAGE_SIZE = 25;

/** Keeps free-text search safe to embed in a PostgREST `.ilike()` filter. */
function sanitizeSearch(term: string): string {
  return term.replace(/[,()%]/g, "").trim();
}

function InventoryPage() {
  const { t } = useLang();
  const { can, user } = useAuth();
  const { currency } = useSettings();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    name: "",
    unit: "",
    cost_price: "0",
    selling_price: "0",
    stock_quantity: "0",
    reorder_level: "10",
    expiry_date: "",
    batch_number: "",
  });
  const [receive, setReceive] = useState<{ id: string; qty: string } | null>(null);

  // Paginated table data: only the current page's columns/rows travel over
  // the network, and PostgREST's exact count gives us the true total.
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

  // Low-stock count and stock value are totals across the WHOLE catalogue,
  // not just the visible page, so they can't come from the paged query.
  // PostgREST can't compare stock_quantity <= reorder_level as a filter
  // (it only compares a column to a literal), so this fetches just the
  // three numeric columns needed for that math — much lighter than the old
  // `select("*")` over every medicine, though still O(catalogue size). If
  // the medicine catalogue grows very large, move this to a small SQL
  // view/RPC in a later phase.
  const stats = useRows<Row[]>(["inventory-stats"], () =>
    supabase.from("medicines").select("stock_quantity, reorder_level, cost_price").is("deleted_at", null),
  );
  const statRows = (stats.data ?? []) as Row[];
  const lowStock = statRows.filter((m) => n(m, "stock_quantity") <= n(m, "reorder_level")).length;
  const stockValue = statRows.reduce((sum, m) => sum + n(m, "stock_quantity") * n(m, "cost_price"), 0);

  const create = useSave(
    async () => {
      const { error } = await supabase.from("medicines").insert({
        name: form.name,
        unit: form.unit || null,
        cost_price: Number(form.cost_price) || 0,
        selling_price: Number(form.selling_price) || 0,
        stock_quantity: Number(form.stock_quantity) || 0,
        reorder_level: Number(form.reorder_level) || 0,
        expiry_date: form.expiry_date || null,
        batch_number: form.batch_number || null,
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

  const addStock = useSave(
    async () => {
      if (!receive) return null;
      const row = list.rows.find((m) => s(m, "id") === receive.id);
      const qty = Number(receive.qty) || 0;
      const { error } = await supabase
        .from("medicines")
        .update({ stock_quantity: n(row, "stock_quantity") + qty })
        .eq("id", receive.id);
      if (error) throw new Error(error.message);
      await supabase.from("stock_movements").insert({
        medicine_id: receive.id,
        movement_type: "purchase",
        quantity: qty,
        created_by: user?.id ?? null,
      });
      return null;
    },
    { invalidate: [["inventory"], ["inventory-stats"]], successMessage: t("saved"), onDone: () => setReceive(null) },
  );

  const rows = list.rows;

  return (
    <div>
      <PageHeader title={t("inventory")} subtitle={t("stock_overview")}>
        <Input
          placeholder={t("search")}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          className="w-48"
        />
        <ExportButtons rows={rows} filename="roshan-inventory" />
        {can("pharmacy.manage") ? (
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
                  <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label={t("unit")}>
                  <Input value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} />
                </Field>
                <Field label={t("batch_number")}>
                  <Input
                    dir="ltr"
                    value={form.batch_number}
                    onChange={(e) => setForm({ ...form, batch_number: e.target.value })}
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
                <Field label={t("stock")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.stock_quantity}
                    onChange={(e) => setForm({ ...form, stock_quantity: e.target.value })}
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
                <Field label={t("expiry_date")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={form.expiry_date}
                    onChange={(e) => setForm({ ...form, expiry_date: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!form.name || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

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
            <Table>
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
                      <TableCell dir="ltr" className={low ? "font-semibold text-destructive" : undefined}>
                        {n(m, "stock_quantity")}
                      </TableCell>
                      <TableCell>{money(n(m, "selling_price"), currency)}</TableCell>
                      <TableCell dir="ltr">{s(m, "expiry_date") ? formatDate(s(m, "expiry_date")) : "—"}</TableCell>
                      <TableCell className="no-print text-end">
                        {can("pharmacy.manage") ? (
                          <Button variant="outline" size="sm" onClick={() => setReceive({ id: s(m, "id"), qty: "0" })}>
                            {t("receive_stock")}
                          </Button>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
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

      <Dialog open={Boolean(receive)} onOpenChange={(o) => (o ? null : setReceive(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("receive_stock")}</DialogTitle>
          </DialogHeader>
          <Field label={t("quantity")}>
            <Input
              type="number"
              dir="ltr"
              value={receive?.qty ?? ""}
              onChange={(e) => setReceive(receive ? { ...receive, qty: e.target.value } : receive)}
            />
          </Field>
          <DialogFooter>
            <Button variant="outline" onClick={() => setReceive(null)}>
              {t("cancel")}
            </Button>
            <Button disabled={addStock.isPending} onClick={() => addStock.mutate(undefined as never)}>
              {addStock.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
