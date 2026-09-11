import { createFileRoute, Link } from "@tanstack/react-router";
import { Phone, Plus, Search } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader, Pager, PermissionGate } from "@/components/kit";
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
import { useAuth } from "@/lib/auth";
import { rpc, s, usePagedRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, formatDate } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients")({
  head: () => ({
    meta: [
      { title: "Patients — ROSHAN Medical Center" },
      { name: "description", content: "Search, register and open patient charts." },
      { property: "og:title", content: "Patients — ROSHAN Medical Center" },
      { property: "og:description", content: "Search, register and open patient charts." },
    ],
  }),
  component: PatientsPage,
});

const PAGE_SIZE = 20;

/** Keeps free-text search safe to embed in a PostgREST `.or()` filter string. */
function sanitizeSearch(term: string): string {
  return term.replace(/[,()%]/g, "").trim();
}

function emptyForm() {
  return {
    full_name: "",
    phone: "",
    gender: "male",
    date_of_birth: "",
    national_id: "",
  };
}

function PatientsPage() {
  return (
    <PermissionGate perm="patients.read">
      <PatientsPageInner />
    </PermissionGate>
  );
}

function PatientsPageInner() {
  const { t, lang } = useLang();
  const { can } = useAuth();

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(emptyForm());

  const list = usePagedRows<Row[]>(
    ["patients", search],
    ({ from, to }) => {
      let q = supabase
        .from("patients")
        .select("id, mrn, full_name, phone, gender, date_of_birth, national_id, created_at", {
          count: "exact",
        })
        .is("deleted_at", null);

      const term = sanitizeSearch(search);
      if (term) {
        q = q.or(`full_name.ilike.%${term}%,phone.ilike.%${term}%,mrn.ilike.%${term}%,national_id.ilike.%${term}%`);
      }

      return q.order("created_at", { ascending: false }).range(from, to);
    },
    page,
    PAGE_SIZE,
  );

  const create = useSave(
    async () => {
      if (!form.full_name.trim()) throw new Error(t("full_name"));

      // MRNs are generated the same way as invoice/queue numbers elsewhere
      // in the app: a server-side RPC, never guessed on the client.
      const mrn = await rpc<string>("next_mrn");

      const { error } = await supabase.from("patients").insert({
        mrn,
        full_name: form.full_name.trim(),
        phone: form.phone || null,
        gender: form.gender || null,
        date_of_birth: form.date_of_birth || null,
        national_id: form.national_id || null,
      });
      if (error) throw new Error(error.message);
      return null;
    },
    {
      invalidate: [["patients"]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);
        setForm(emptyForm());
      },
    },
  );

  const rows = list.rows;

  return (
    <div>
      <PageHeader title={t("patients")} subtitle={t("register_patient")}>
        {can("patients.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent className="max-h-[90vh] overflow-y-auto">
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
                <Field label={t("phone")}>
                  <Input dir="ltr" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </Field>
                <Field label={t("gender")}>
                  <Select value={form.gender} onValueChange={(v) => setForm({ ...form, gender: v })}>
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
                <Field label={t("national_id")}>
                  <Input
                    dir="ltr"
                    value={form.national_id}
                    onChange={(e) => setForm({ ...form, national_id: e.target.value })}
                  />
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button disabled={!form.full_name.trim() || create.isPending} onClick={() => create.mutate(undefined as never)}>
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <div className="relative mb-4">
        <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          placeholder={t("search")}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          className="ps-9"
        />
      </div>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty title={t("no_data")} description={lang === "ar" ? "لا يوجد مرضى مطابقون. أضف مريضاً جديداً أو غيّر البحث." : "No matching patients. Add a new patient or refine your search."} />
          ) : (
            <div className="overflow-x-auto">
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("mrn")}</TableHead>
                    <TableHead>{t("full_name")}</TableHead>
                    <TableHead>{t("phone")}</TableHead>
                    <TableHead>{t("age")}</TableHead>
                    <TableHead>{t("date")}</TableHead>
                    <TableHead className="no-print" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((p) => (
                    <TableRow key={s(p, "id")}>
                      <TableCell dir="ltr" className="font-mono text-xs">
                        {s(p, "mrn") || "—"}
                      </TableCell>
                      <TableCell className="font-medium">
                        <Link
                          to="/patients/$patientId"
                          params={{ patientId: s(p, "id") }}
                          className="hover:underline"
                        >
                          {s(p, "full_name")}
                        </Link>
                      </TableCell>
                      <TableCell dir="ltr">
                        {s(p, "phone") ? (
                          <span className="flex items-center gap-1">
                            <Phone className="size-3" /> {s(p, "phone")}
                          </span>
                        ) : (
                          "—"
                        )}
                      </TableCell>
                      <TableCell>{calcAge(s(p, "date_of_birth")) ?? "—"}</TableCell>
                      <TableCell dir="ltr">{formatDate(s(p, "created_at"))}</TableCell>
                      <TableCell className="no-print text-end">
                        {can("visits.create") ? (
                          <Link
                            to="/visits"
                            search={{ patient: s(p, "id") }}
                            className="inline-flex h-8 items-center justify-center gap-1.5 whitespace-nowrap rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground shadow transition-colors hover:bg-primary/90"
                            title={t("new_visit")}
                          >
                            <Plus className="size-3.5" /> {t("new_visit")}
                          </Link>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
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