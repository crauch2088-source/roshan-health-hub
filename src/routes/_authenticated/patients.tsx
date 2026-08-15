import { createFileRoute, Link } from "@tanstack/react-router";
import { Plus, Search } from "lucide-react";
import { useMemo, useState } from "react";

import { Empty, ErrorBox, ExportButtons, Field, Loading, PageHeader } from "@/components/kit";
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
import { Textarea } from "@/components/ui/textarea";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { rpc, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { BLOOD_GROUPS, MARITAL, calcAge, formatDate } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients")({
  head: () => ({
    meta: [
      { title: "Patients — ROSHAN Medical Center" },
      { name: "description", content: "Patient registry, medical record numbers and demographics." },
      { property: "og:title", content: "Patients — ROSHAN Medical Center" },
      { property: "og:description", content: "Patient registry, medical record numbers and demographics." },
    ],
  }),
  component: PatientsPage,
});

const empty = {
  full_name: "",
  gender: "male",
  date_of_birth: "",
  phone: "",
  address: "",
  occupation: "",
  marital_status: "",
  blood_group: "",
  national_id: "",
  emergency_contact: "",
  email: "",
  notes: "",
};

function PatientsPage() {
  const { t } = useLang();
  const { can, user } = useAuth();
  const [term, setTerm] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(empty);

  const patients = useRows(["patients"], () =>
    supabase
      .from("patients")
      .select(
        "id, mrn, full_name, gender, date_of_birth, phone, address, blood_group, marital_status, occupation, national_id, created_at",
      )
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(500),
  );

  const rows = (patients.data ?? []) as Row[];

  const filtered = useMemo(() => {
    const q = term.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((r) =>
      [s(r, "full_name"), s(r, "mrn"), s(r, "phone"), s(r, "national_id")]
        .join(" ")
        .toLowerCase()
        .includes(q),
    );
  }, [rows, term]);

  const save = useSave(
    async () => {
      const mrn = await rpc<string>("next_mrn");
      const payload: Row = { ...form, mrn, registered_by: user?.id ?? null };
      if (!payload["date_of_birth"]) delete payload["date_of_birth"];
      for (const k of Object.keys(payload)) {
        if (payload[k] === "") delete payload[k];
      }
      const { error } = await supabase.from("patients").insert(payload);
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["patients"]],
      successMessage: t("saved"),
      onDone: () => {
        setForm(empty);
        setOpen(false);
      },
    },
  );

  if (patients.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("patients")} subtitle={`${filtered.length} ${t("records")}`}>
        <ExportButtons rows={filtered} filename="roshan-patients" />
        {can("patients.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("new_patient")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
              <DialogHeader>
                <DialogTitle>{t("register_patient")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={`${t("full_name")} *`} className="sm:col-span-2">
                  <Input
                    value={form.full_name}
                    onChange={(e) => setForm({ ...form, full_name: e.target.value })}
                  />
                </Field>
                <Field label={t("gender")}>
                  <Select
                    value={form.gender}
                    onValueChange={(v) => setForm({ ...form, gender: v })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="male">{t("male")}</SelectItem>
                      <SelectItem value="female">{t("female")}</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("dob")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={form.date_of_birth}
                    onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
                  />
                </Field>
                <Field label={t("phone")}>
                  <Input
                    dir="ltr"
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  />
                </Field>
                <Field label={t("email")}>
                  <Input
                    dir="ltr"
                    value={form.email}
                    onChange={(e) => setForm({ ...form, email: e.target.value })}
                  />
                </Field>
                <Field label={t("blood_group")}>
                  <Select
                    value={form.blood_group}
                    onValueChange={(v) => setForm({ ...form, blood_group: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")} />
                    </SelectTrigger>
                    <SelectContent>
                      {BLOOD_GROUPS.map((g) => (
                        <SelectItem key={g} value={g}>
                          {g}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("marital_status")}>
                  <Select
                    value={form.marital_status}
                    onValueChange={(v) => setForm({ ...form, marital_status: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")} />
                    </SelectTrigger>
                    <SelectContent>
                      {MARITAL.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("occupation")}>
                  <Input
                    value={form.occupation}
                    onChange={(e) => setForm({ ...form, occupation: e.target.value })}
                  />
                </Field>
                <Field label={t("address")}>
                  <Input
                    value={form.address}
                    onChange={(e) => setForm({ ...form, address: e.target.value })}
                  />
                </Field>
                <Field label="ID / National no.">
                  <Input
                    dir="ltr"
                    value={form.national_id}
                    onChange={(e) => setForm({ ...form, national_id: e.target.value })}
                  />
                </Field>
                <Field label={t("notes")} className="sm:col-span-2">
                  <Textarea
                    rows={2}
                    value={form.notes}
                    onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button
                  disabled={!form.full_name.trim() || save.isPending}
                  onClick={() => save.mutate(undefined as never)}
                >
                  {save.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={patients.error} />

      <Card>
        <CardContent className="p-0">
          <div className="no-print flex items-center gap-2 border-b p-3">
            <Search className="size-4 text-muted-foreground" />
            <Input
              placeholder={t("search")}
              value={term}
              onChange={(e) => setTerm(e.target.value)}
              className="max-w-sm border-0 shadow-none focus-visible:ring-0"
            />
          </div>
          {filtered.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("mrn")}</TableHead>
                  <TableHead>{t("full_name")}</TableHead>
                  <TableHead>{t("gender")}</TableHead>
                  <TableHead>{t("age")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((p) => (
                  <TableRow key={s(p, "id")}>
                    <TableCell dir="ltr" className="font-mono text-xs">
                      {s(p, "mrn")}
                    </TableCell>
                    <TableCell className="font-medium">{s(p, "full_name")}</TableCell>
                    <TableCell>{t(s(p, "gender"))}</TableCell>
                    <TableCell>{calcAge(s(p, "date_of_birth")) ?? "—"}</TableCell>
                    <TableCell dir="ltr">{s(p, "phone") || "—"}</TableCell>
                    <TableCell dir="ltr">{formatDate(s(p, "created_at"))}</TableCell>
                    <TableCell className="no-print text-end">
                      <Button asChild variant="ghost" size="sm">
                        <Link to="/patients/$patientId" params={{ patientId: s(p, "id") }}>
                          {t("edit")}
                        </Link>
                      </Button>
                    </TableCell>
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
