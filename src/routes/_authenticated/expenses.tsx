import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader, StatCard } from "@/components/kit";
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
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { n, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { EXPENSE_CATEGORIES, formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/expenses")({
  head: () => ({
    meta: [
      { title: "Expenses — ROSHAN Medical Center" },
      { name: "description", content: "Record and review operating expenses by category and date." },
      { property: "og:title", content: "Expenses — ROSHAN Medical Center" },
      { property: "og:description", content: "Record and review operating expenses by category and date." },
    ],
  }),
  component: ExpensesPage,
});

function ExpensesPage() {
  const { t } = useLang();
  const { can, user } = useAuth();
  const { currency } = useSettings();
  const [month, setMonth] = useState(todayISO().slice(0, 7));
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<{
    category: string;
    amount: string;
    description: string;
    expense_date: string;
  }>({
    category: EXPENSE_CATEGORIES[0] ?? "other",
    amount: "0",
    description: "",
    expense_date: todayISO(),
  });

  const list = useRows(["expenses", month], () =>
    supabase
      .from("expenses")
      .select("*")
      .gte("expense_date", `${month}-01`)
      .lte("expense_date", `${month}-31`)
      .is("deleted_at", null)
      .order("expense_date", { ascending: false }),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("expenses").insert({
        category: form.category,
        amount: Number(form.amount) || 0,
        description: form.description || null,
        expense_date: form.expense_date,
        created_by: user?.id ?? null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["expenses", month], ["acc-expenses"]], successMessage: t("saved"), onDone: () => setOpen(false) },
  );

  const rows = (list.data ?? []) as Row[];
  const total = rows.reduce((sum, r) => sum + n(r, "amount"), 0);
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("expenses")} subtitle={month}>
        <Input type="month" dir="ltr" value={month} onChange={(e) => setMonth(e.target.value)} className="w-40" />
        <ExportButtons rows={rows} filename={`roshan-expenses-${month}`} />
        {can("accounting.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("expenses")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={t("category")}>
                  <Select value={form.category} onValueChange={(v) => setForm({ ...form, category: v })}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {EXPENSE_CATEGORIES.map((c) => (
                        <SelectItem key={c} value={c}>
                          {t(c)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("amount")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.amount}
                    onChange={(e) => setForm({ ...form, amount: e.target.value })}
                  />
                </Field>
                <Field label={t("date")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={form.expense_date}
                    onChange={(e) => setForm({ ...form, expense_date: e.target.value })}
                  />
                </Field>
                <Field label={t("description")}>
                  <Textarea
                    rows={2}
                    value={form.description}
                    onChange={(e) => setForm({ ...form, description: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={list.error} />

      <div className="mb-4 grid gap-4 sm:grid-cols-2">
        <StatCard label={t("total")} value={money(total, currency)} />
        <StatCard label={t("records")} value={String(rows.length)} />
      </div>

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("category")}</TableHead>
                  <TableHead>{t("description")}</TableHead>
                  <TableHead>{t("amount")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((e) => (
                  <TableRow key={s(e, "id")}>
                    <TableCell dir="ltr">{formatDate(s(e, "expense_date"))}</TableCell>
                    <TableCell>{t(s(e, "category"))}</TableCell>
                    <TableCell>{s(e, "description") || "—"}</TableCell>
                    <TableCell>{money(n(e, "amount"), currency)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
