import { createFileRoute } from "@tanstack/react-router";
import { Pencil, Plus } from "lucide-react";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  ExportButtons,
  Field,
  Loading,
  PageHeader,
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
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { b, n, rel, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/lab-catalog")({
  head: () => ({
    meta: [
      { title: "Test catalogue — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Manage laboratory tests, prices, units and reference ranges.",
      },
      { property: "og:title", content: "Test catalogue — ROSHAN Medical Center" },
      {
        property: "og:description",
        content: "Manage laboratory tests, prices, units and reference ranges.",
      },
    ],
  }),
  component: LabCatalogPage,
});

const blank = {
  name: "",
  name_ar: "",
  category: "",
  unit: "",
  price: "0",
  normal_min: "",
  normal_max: "",
  reference_range: "",
};

function LabCatalogPage() {
  return (
    <PermissionGate perm="lab_admin.read">
      <LabCatalogPageInner />
    </PermissionGate>
  );
}

function LabCatalogPageInner() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(blank);
  const [search, setSearch] = useState("");

  const tests = useRows(["lab-catalog"], () =>
    supabase
      .from("lab_tests")
      .select("*")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const create = useSave(
    async () => {
      const { error } = await supabase.from("lab_tests").insert({
        name: form.name,
        name_ar: form.name_ar || null,
        category: form.category || null,
        unit: form.unit || null,
        price: Number(form.price) || 0,
        normal_min: form.normal_min === "" ? null : Number(form.normal_min),
        normal_max: form.normal_max === "" ? null : Number(form.normal_max),
        reference_range: form.reference_range || null,
        active: true,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-catalog"], ["lab-tests"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm(blank);
      },
    },
  );

  const toggle = useSave<{ id: string; active: boolean }>(
    async ({ id, active }) => {
      const { error } = await supabase.from("lab_tests").update({ active }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["lab-catalog"], ["lab-tests"]] },
  );

  const update = useSave<{ id: string }>(
    async ({ id }) => {
      const { error } = await supabase
        .from("lab_tests")
        .update({
          name: form.name,
          name_ar: form.name_ar || null,
          category: form.category || null,
          unit: form.unit || null,
          price: Number(form.price) || 0,
          normal_min: form.normal_min === "" ? null : Number(form.normal_min),
          normal_max: form.normal_max === "" ? null : Number(form.normal_max),
          reference_range: form.reference_range || null,
        })
        .eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-catalog"], ["lab-tests"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setEditingId(null);
        setForm(blank);
      },
    },
  );

  const rows = ((tests.data ?? []) as Row[]).filter((x) =>
    `${s(x, "name")} ${s(x, "name_ar")} ${s(x, "code")} ${s(x, "category")}`
      .toLowerCase()
      .includes(search.trim().toLowerCase()),
  );
  if (tests.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("lab_catalog")} subtitle={t("tests_and_prices")}>
        <Input
          placeholder={t("search")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full sm:w-48"
        />
        <ExportButtons rows={rows} filename="roshan-lab-catalog" />
        {can("lab_admin.manage") ? (
          <Dialog
            open={open}
            onOpenChange={(value) => {
              setOpen(value);
              if (!value) {
                setEditingId(null);
                setForm(blank);
              }
            }}
          >
            <DialogTrigger asChild>
              <Button
                size="sm"
                onClick={() => {
                  setEditingId(null);
                  setForm(blank);
                }}
              >
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>{editingId ? t("edit") : t("lab_catalog")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={`${t("name")} (EN) *`}>
                  <Input
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                  />
                </Field>
                <Field label={`${t("name")} (AR)`}>
                  <Input
                    value={form.name_ar}
                    onChange={(e) => setForm({ ...form, name_ar: e.target.value })}
                  />
                </Field>
                <Field label={t("category")}>
                  <Input
                    value={form.category}
                    onChange={(e) => setForm({ ...form, category: e.target.value })}
                  />
                </Field>
                <Field label={t("unit")}>
                  <Input
                    dir="ltr"
                    value={form.unit}
                    onChange={(e) => setForm({ ...form, unit: e.target.value })}
                  />
                </Field>
                <Field label={t("price")}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.price}
                    onChange={(e) => setForm({ ...form, price: e.target.value })}
                  />
                </Field>
                <Field label={t("reference_range")}>
                  <Input
                    dir="ltr"
                    value={form.reference_range}
                    onChange={(e) => setForm({ ...form, reference_range: e.target.value })}
                  />
                </Field>
                <Field label={`${t("normal_min")}`}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.normal_min}
                    onChange={(e) => setForm({ ...form, normal_min: e.target.value })}
                  />
                </Field>
                <Field label={`${t("normal_max")}`}>
                  <Input
                    type="number"
                    dir="ltr"
                    value={form.normal_max}
                    onChange={(e) => setForm({ ...form, normal_max: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button
                  disabled={!form.name || create.isPending || update.isPending}
                  onClick={() =>
                    editingId ? update.mutate({ id: editingId }) : create.mutate(undefined as never)
                  }
                >
                  {create.isPending || update.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={tests.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("name")}</TableHead>
                  <TableHead>{t("category")}</TableHead>
                  <TableHead>{t("unit")}</TableHead>
                  <TableHead>{t("reference_range")}</TableHead>
                  <TableHead>{t("price")}</TableHead>
                  <TableHead className="no-print">{t("active")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((x) => (
                  <TableRow key={s(x, "id")}>
                    <TableCell className="font-medium">
                      {lang === "ar" ? s(x, "name_ar") || s(x, "name") : s(x, "name")}
                    </TableCell>
                    <TableCell>{s(x, "category") || "—"}</TableCell>
                    <TableCell dir="ltr">{s(x, "unit") || "—"}</TableCell>
                    <TableCell dir="ltr">
                      {s(x, "reference_range") ||
                        (s(x, "normal_min") && s(x, "normal_max")
                          ? `${s(x, "normal_min")} - ${s(x, "normal_max")}`
                          : "—")}
                    </TableCell>
                    <TableCell>{money(n(x, "price"), currency)}</TableCell>
                    <TableCell className="no-print">
                      <Switch
                        checked={b(x, "active")}
                        disabled={!can("lab_admin.manage")}
                        onCheckedChange={(v) => toggle.mutate({ id: s(x, "id"), active: v })}
                      />
                    </TableCell>
                    <TableCell className="no-print text-end">
                      {can("lab_admin.manage") ? (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => {
                            setEditingId(s(x, "id"));
                            setForm({
                              name: s(x, "name"),
                              name_ar: s(x, "name_ar"),
                              category: s(x, "category"),
                              unit: s(x, "unit"),
                              price: s(x, "price") || "0",
                              normal_min: s(x, "normal_min"),
                              normal_max: s(x, "normal_max"),
                              reference_range: s(x, "reference_range"),
                            });
                            setOpen(true);
                          }}
                        >
                          <Pencil className="size-4" /> {t("edit")}
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
      <LabParametersAndRanges />
    </div>
  );
}

function LabParametersAndRanges() {
  const { can } = useAuth();
  const parameters = useRows(["lab-parameters"], () =>
    supabase
      .from("lab_parameters")
      .select("*, lab_tests(name,name_ar)")
      .is("deleted_at", null)
      .order("display_order", { ascending: true }),
  );
  const ranges = useRows(["lab-reference-ranges"], () =>
    supabase
      .from("lab_reference_ranges")
      .select("*, lab_parameters(name,unit)")
      .is("deleted_at", null)
      .order("min_age", { ascending: true }),
  );
  const tests = useRows(["lab-catalog-tests-for-parameters"], () =>
    supabase.from("lab_tests").select("id,name,name_ar").is("deleted_at", null).order("name"),
  );
  const [parameter, setParameter] = useState({
    test_id: "",
    name: "",
    code: "",
    unit: "",
    data_type: "numeric",
    reference_text: "",
  });
  const [range, setRange] = useState({
    parameter_id: "",
    gender: "",
    min_age: "",
    max_age: "",
    lower_limit: "",
    upper_limit: "",
    text_reference: "",
    unit: "",
  });

  const saveParameter = useSave(
    async () => {
      if (!parameter.test_id || !parameter.name.trim()) {
        throw new Error("Choose a test and enter a parameter name.");
      }
      const { error } = await supabase.from("lab_parameters").insert({
        test_id: parameter.test_id,
        name: parameter.name.trim(),
        code: parameter.code.trim() || null,
        unit: parameter.unit.trim() || null,
        data_type: parameter.data_type,
        reference_text: parameter.reference_text.trim() || null,
        active: true,
        is_active: true,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-parameters"]],
      successMessage: "Parameter saved",
      onDone: () =>
        setParameter({
          test_id: "",
          name: "",
          code: "",
          unit: "",
          data_type: "numeric",
          reference_text: "",
        }),
    },
  );

  const saveRange = useSave(
    async () => {
      if (!range.parameter_id) {
        throw new Error("Choose a laboratory parameter.");
      }
      const { error } = await supabase.from("lab_reference_ranges").insert({
        parameter_id: range.parameter_id,
        gender: range.gender || null,
        min_age: range.min_age === "" ? null : Number(range.min_age),
        max_age: range.max_age === "" ? null : Number(range.max_age),
        lower_limit: range.lower_limit === "" ? null : Number(range.lower_limit),
        upper_limit: range.upper_limit === "" ? null : Number(range.upper_limit),
        text_reference: range.text_reference.trim() || null,
        unit: range.unit.trim() || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["lab-reference-ranges"]],
      successMessage: "Reference range saved",
      onDone: () =>
        setRange({
          parameter_id: "",
          gender: "",
          min_age: "",
          max_age: "",
          lower_limit: "",
          upper_limit: "",
          text_reference: "",
          unit: "",
        }),
    },
  );

  const setActive = useSave<{ id: string; active: boolean }>(
    async ({ id, active }) => {
      const { error } = await supabase
        .from("lab_parameters")
        .update({ active, is_active: active })
        .eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["lab-parameters"]] },
  );
  const archiveRange = useSave<{ id: string }>(
    async ({ id }) => {
      const { error } = await supabase
        .from("lab_reference_ranges")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["lab-reference-ranges"]] },
  );

  const parameterRows = (parameters.data ?? []) as Row[];
  const rangeRows = (ranges.data ?? []) as Row[];
  const testRows = (tests.data ?? []) as Row[];

  return (
    <div className="mt-6 grid gap-4">
      <Card>
        <CardContent className="grid gap-3 p-4">
          <h2 className="text-lg font-semibold">Laboratory parameters / معلمات التحليل</h2>
          <div className="grid gap-2 sm:grid-cols-3">
            <Field label="Test">
              <select
                className="h-10 rounded-md border bg-background px-3 text-sm"
                value={parameter.test_id}
                onChange={(e) => setParameter({ ...parameter, test_id: e.target.value })}
              >
                <option value="">Select test</option>
                {testRows.map((test) => (
                  <option key={s(test, "id")} value={s(test, "id")}>
                    {s(test, "name")}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Parameter name">
              <Input
                value={parameter.name}
                onChange={(e) => setParameter({ ...parameter, name: e.target.value })}
              />
            </Field>
            <Field label="Code">
              <Input
                dir="ltr"
                value={parameter.code}
                onChange={(e) => setParameter({ ...parameter, code: e.target.value })}
              />
            </Field>
            <Field label="Unit">
              <Input
                dir="ltr"
                value={parameter.unit}
                onChange={(e) => setParameter({ ...parameter, unit: e.target.value })}
              />
            </Field>
            <Field label="Data type">
              <select
                className="h-10 rounded-md border bg-background px-3 text-sm"
                value={parameter.data_type}
                onChange={(e) => setParameter({ ...parameter, data_type: e.target.value })}
              >
                <option value="numeric">Numeric</option>
                <option value="text">Text / qualitative</option>
                <option value="boolean">Boolean</option>
              </select>
            </Field>
            <Field label="Reference text">
              <Input
                value={parameter.reference_text}
                onChange={(e) => setParameter({ ...parameter, reference_text: e.target.value })}
              />
            </Field>
          </div>
          <Button
            disabled={!can("lab_admin.manage") || saveParameter.isPending}
            onClick={() => saveParameter.mutate(undefined as never)}
          >
            Add parameter
          </Button>
          {parameters.error ? <ErrorBox error={parameters.error} /> : null}
          <Table density="compact">
            <TableHeader>
              <TableRow>
                <TableHead>Parameter</TableHead>
                <TableHead>Test</TableHead>
                <TableHead>Type / unit</TableHead>
                <TableHead>Active</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {parameterRows.map((item) => (
                <TableRow key={s(item, "id")}>
                  <TableCell>{s(item, "name")}</TableCell>
                  <TableCell>{s(rel(item, "lab_tests"), "name")}</TableCell>
                  <TableCell dir="ltr">
                    {s(item, "data_type")} / {s(item, "unit")}
                  </TableCell>
                  <TableCell>
                    <Switch
                      checked={b(item, "active") && b(item, "is_active")}
                      disabled={!can("lab_admin.manage")}
                      onCheckedChange={(active) => setActive.mutate({ id: s(item, "id"), active })}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="grid gap-3 p-4">
          <h2 className="text-lg font-semibold">Reference ranges / النطاقات المرجعية</h2>
          <div className="grid gap-2 sm:grid-cols-4">
            <Field label="Parameter">
              <select
                className="h-10 rounded-md border bg-background px-3 text-sm"
                value={range.parameter_id}
                onChange={(e) => setRange({ ...range, parameter_id: e.target.value })}
              >
                <option value="">Select parameter</option>
                {parameterRows.map((item) => (
                  <option key={s(item, "id")} value={s(item, "id")}>
                    {s(item, "name")}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Sex">
              <select
                className="h-10 rounded-md border bg-background px-3 text-sm"
                value={range.gender}
                onChange={(e) => setRange({ ...range, gender: e.target.value })}
              >
                <option value="">Any</option>
                <option value="male">Male</option>
                <option value="female">Female</option>
                <option value="other">Other</option>
              </select>
            </Field>
            <Field label="Min age">
              <Input
                type="number"
                dir="ltr"
                value={range.min_age}
                onChange={(e) => setRange({ ...range, min_age: e.target.value })}
              />
            </Field>
            <Field label="Max age">
              <Input
                type="number"
                dir="ltr"
                value={range.max_age}
                onChange={(e) => setRange({ ...range, max_age: e.target.value })}
              />
            </Field>
            <Field label="Lower limit">
              <Input
                type="number"
                dir="ltr"
                value={range.lower_limit}
                onChange={(e) => setRange({ ...range, lower_limit: e.target.value })}
              />
            </Field>
            <Field label="Upper limit">
              <Input
                type="number"
                dir="ltr"
                value={range.upper_limit}
                onChange={(e) => setRange({ ...range, upper_limit: e.target.value })}
              />
            </Field>
            <Field label="Unit">
              <Input
                dir="ltr"
                value={range.unit}
                onChange={(e) => setRange({ ...range, unit: e.target.value })}
              />
            </Field>
            <Field label="Text reference">
              <Input
                value={range.text_reference}
                onChange={(e) => setRange({ ...range, text_reference: e.target.value })}
              />
            </Field>
          </div>
          <Button
            disabled={!can("lab_admin.manage") || saveRange.isPending}
            onClick={() => saveRange.mutate(undefined as never)}
          >
            Add reference range
          </Button>
          {ranges.error ? <ErrorBox error={ranges.error} /> : null}
          <Table density="compact">
            <TableHeader>
              <TableRow>
                <TableHead>Parameter</TableHead>
                <TableHead>Sex / age</TableHead>
                <TableHead>Numeric range</TableHead>
                <TableHead>Text reference / unit</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rangeRows.map((item) => (
                <TableRow key={s(item, "id")}>
                  <TableCell>{s(rel(item, "lab_parameters"), "name")}</TableCell>
                  <TableCell>
                    {s(item, "gender") || "Any"} / {s(item, "min_age") || "0"}–
                    {s(item, "max_age") || "∞"}
                  </TableCell>
                  <TableCell dir="ltr">
                    {s(item, "lower_limit") || s(item, "min_value")} –{" "}
                    {s(item, "upper_limit") || s(item, "max_value")}
                  </TableCell>
                  <TableCell>
                    {s(item, "text_reference") || s(item, "text_value") || "—"} / {s(item, "unit")}
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={!can("lab_admin.manage")}
                      onClick={() => archiveRange.mutate({ id: s(item, "id") })}
                    >
                      Archive
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
