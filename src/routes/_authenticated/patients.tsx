import { createFileRoute, Link } from "@tanstack/react-router";
import { Phone, Plus, Search } from "lucide-react";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  Field,
  Loading,
  PageHeader,
  Pager,
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
import { useAuth } from "@/lib/auth";
import {
  rpc,
  s,
  usePagedRows,
  useSave,
  type Row,
} from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, formatDate } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/patients")({
  head: () => ({
    meta: [
      {
        title: "Patients — ROSHAN Medical Center",
      },
      {
        name: "description",
        content:
          "Search, register and open patient charts.",
      },
      {
        property: "og:title",
        content: "Patients — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Search, register and open patient charts.",
      },
    ],
  }),
  component: PatientsPage,
});

const PAGE_SIZE = 20;

/**
 * Keeps free-text search safe to embed in a PostgREST `.or()` filter string.
 */
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
  const { t } = useLang();
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
        .select(
          "id, mrn, full_name, phone, gender, date_of_birth, national_id, created_at",
          {
            count: "exact",
          },
        )
        .is("deleted_at", null);

      const term = sanitizeSearch(search);

      if (term) {
        q = q.or(
          `full_name.ilike.%${term}%,phone.ilike.%${term}%,mrn.ilike.%${term}%,national_id.ilike.%${term}%`,
        );
      }

      return q
        .order("created_at", {
          ascending: false,
        })
        .range(from, to);
    },
    page,
    PAGE_SIZE,
  );

  const create = useSave(
    async () => {
      if (!form.full_name.trim()) {
        throw new Error(t("full_name"));
      }

      const mrn = await rpc<string>("next_mrn");

      const { error } = await supabase
        .from("patients")
        .insert({
          mrn,
          full_name: form.full_name.trim(),
          phone: form.phone || null,
          gender: form.gender || null,
          date_of_birth:
            form.date_of_birth || null,
          national_id:
            form.national_id || null,
        });

      if (error) {
        throw new Error(error.message);
      }

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
      <PageHeader
        title={t("patients")}
        subtitle={t("register_patient")}
      >
        {can("patients.create") ? (
          <Dialog
            open={open}
            onOpenChange={setOpen}
          >
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" />
                {t("add")}
              </Button>
            </DialogTrigger>

            <DialogContent>
              <DialogHeader>
                <DialogTitle>
                  {t("register_patient")}
                </DialogTitle>
              </DialogHeader>

              <div className="grid gap-4 sm:grid-cols-2">
                <Field
                  label={`${t("full_name")} *`}
                  className="sm:col-span-2"
                >
                  <Input
                    value={form.full_name}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        full_name:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("phone")}>
                  <Input
                    dir="ltr"
                    value={form.phone}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        phone:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field label={t("gender")}>
                  <Select
                    value={form.gender}
                    onValueChange={(value) =>
                      setForm({
                        ...form,
                        gender: value,
                      })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>

                    <SelectContent>
                      <SelectItem value="male">
                        {t("male")}
                      </SelectItem>

                      <SelectItem value="female">
                        {t("female")}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </Field>

                <Field label={t("dob")}>
                  <Input
                    type="date"
                    dir="ltr"
                    value={
                      form.date_of_birth
                    }
                    onChange={(e) =>
                      setForm({
                        ...form,
                        date_of_birth:
                          e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={t("national_id")}
                >
                  <Input
                    dir="ltr"
                    value={form.national_id}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        national_id:
                          e.target.value,
                      })
                    }
                  />
                </Field>
              </div>

              <DialogFooter>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() =>
                    setOpen(false)
                  }
                >
                  {t("cancel")}
                </Button>

                <Button
                  type="button"
                  disabled={
                    !form.full_name.trim() ||
                    create.isPending
                  }
                  onClick={() =>
                    create.mutate(
                      undefined as never,
                    )
                  }
                >
                  {create.isPending
                    ? t("saving")
                    : t("save")}
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
            <Empty />
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>
                      {t("mrn")}
                    </TableHead>

                    <TableHead>
                      {t("full_name")}
                    </TableHead>

                    <TableHead>
                      {t("phone")}
                    </TableHead>

                    <TableHead>
                      {t("age")}
                    </TableHead>

                    <TableHead>
                      {t("date")}
                    </TableHead>
                  </TableRow>
                </TableHeader>

                <TableBody>
                  {rows.map((patient) => {
                    const patientId = s(
                      patient,
                      "id",
                    );

                    return (
                      <TableRow
                        key={patientId}
                      >
                        <TableCell
                          dir="ltr"
                          className="font-mono text-xs"
                        >
                          {s(
                            patient,
                            "mrn",
                          ) || "—"}
                        </TableCell>

                        <TableCell className="font-medium">
                          <Link
                            to="/patients/$patientId"
                            params={{
                              patientId,
                            }}
                            className="inline-flex cursor-pointer items-center text-primary hover:underline"
                          >
                            {s(
                              patient,
                              "full_name",
                            )}
                          </Link>
                        </TableCell>

                        <TableCell dir="ltr">
                          {s(
                            patient,
                            "phone",
                          ) ? (
                            <span className="flex items-center gap-1">
                              <Phone className="size-3" />
                              {s(
                                patient,
                                "phone",
                              )}
                            </span>
                          ) : (
                            "—"
                          )}
                        </TableCell>

                        <TableCell>
                          {calcAge(
                            s(
                              patient,
                              "date_of_birth",
                            ),
                          ) ?? "—"}
                        </TableCell>

                        <TableCell dir="ltr">
                          {formatDate(
                            s(
                              patient,
                              "created_at",
                            ),
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
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
            onPrev={() =>
              setPage((current) =>
                Math.max(1, current - 1),
              )
            }
            onNext={() =>
              setPage((current) =>
                current + 1,
              )
            }
          />
        </CardContent>
      </Card>
    </div>
  );
}