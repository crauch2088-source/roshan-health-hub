import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  ExportButtons,
  Loading,
  PageHeader,
  StatusBadge,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
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
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/followups")({
  head: () => ({
    meta: [
      { title: "Follow-ups — ROSHAN Medical Center" },
      {
        name: "description",
        content:
          "Track scheduled patient follow-up visits and contact status.",
      },
      {
        property: "og:title",
        content: "Follow-ups — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Track scheduled patient follow-up visits and contact status.",
      },
    ],
  }),
  component: FollowupsPage,
});

function FollowupsPage() {
  const { t } = useLang();
  const { can } = useAuth();

  const [from, setFrom] = useState(todayISO());
  const [to, setTo] = useState(todayISO());
  const [open, setOpen] = useState(false);
  const [patientSearch, setPatientSearch] = useState("");

  const [form, setForm] = useState({
    patient_id: "",
    patient_name: "",
    followup_date: todayISO(),
    reason: "",
  });

  /*
   * IMPORTANT:
   * followups has TWO foreign-key relationships to users:
   *
   *   followups_created_by_fkey
   *   followups_updated_by_fkey
   *
   * Therefore users(full_name) is ambiguous in PostgREST.
   *
   * We explicitly select the creator relationship because the
   * "Doctor" column represents the user who created the follow-up.
   */
  const list = useRows(["followups", from, to], () =>
    supabase
      .from("followups")
      .select(
        "*, patients(id, full_name, phone, mrn), users!followups_created_by_fkey(full_name)",
      )
      .gte("followup_date", from)
      .lte("followup_date", to)
      .is("deleted_at", null)
      .order("followup_date", { ascending: true }),
  );

  const patients = useRows(
    ["followup-patients", patientSearch],
    () => {
      const term = patientSearch.replace(/[,()%]/g, "").trim();

      let query = supabase
        .from("patients")
        .select("id, full_name, mrn, phone")
        .is("deleted_at", null);

      if (term) {
        query = query.or(
          `full_name.ilike.%${term}%,mrn.ilike.%${term}%,phone.ilike.%${term}%`,
        );
      }

      return query.order("full_name", { ascending: true }).limit(20);
    },
    { enabled: open },
  );

  const create = useSave(
    async () => {
      if (!form.patient_id) {
        throw new Error(t("patient"));
      }

      const { error } = await supabase.from("followups").insert({
        patient_id: form.patient_id,
        followup_date: form.followup_date,
        reason: form.reason.trim() || null,
        status: "pending",
      });

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["followups", from, to]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);

        setForm({
          patient_id: "",
          patient_name: "",
          followup_date: todayISO(),
          reason: "",
        });

        setPatientSearch("");
      },
    },
  );

  const mark = useSave<{ id: string; status: string }>(
    async ({ id, status }) => {
      const { error } = await supabase
        .from("followups")
        .update({ status })
        .eq("id", id);

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["followups", from, to]],
      successMessage: t("saved"),
    },
  );

  const rows = (list.data ?? []) as Row[];

  if (list.isLoading) {
    return <Loading />;
  }

  return (
    <div>
      <PageHeader
        title={t("followups")}
        subtitle={`${formatDate(from)} — ${formatDate(to)}`}
      >
        <Input
          type="date"
          dir="ltr"
          value={from}
          onChange={(e) => setFrom(e.target.value)}
          className="w-40"
        />

        <Input
          type="date"
          dir="ltr"
          value={to}
          onChange={(e) => setTo(e.target.value)}
          className="w-40"
        />

        <ExportButtons
          rows={rows}
          filename={`roshan-followups-${from}`}
        />

        {can("followups.create") ? (
          <Button size="sm" onClick={() => setOpen(true)}>
            {t("add")} {t("followups")}
          </Button>
        ) : null}
      </PageHeader>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("patient")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("doctor")}</TableHead>
                  <TableHead>{t("notes")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                  <TableHead className="no-print" />
                </TableRow>
              </TableHeader>

              <TableBody>
                {rows.map((f) => {
                  const p = rel(f, "patients");

                  const creator = rel(f, "users");

                  const status = s(f, "status") || "pending";

                  return (
                    <TableRow key={s(f, "id")}>
                      <TableCell dir="ltr">
                        {formatDate(s(f, "followup_date"))}
                      </TableCell>

                      <TableCell className="font-medium">
                        {s(p, "id") ? (
                          <Link
                            to="/patients/$patientId"
                            params={{
                              patientId: s(p, "id"),
                            }}
                            className="hover:underline"
                          >
                            {s(p, "full_name")}
                          </Link>
                        ) : (
                          "—"
                        )}
                      </TableCell>

                      <TableCell dir="ltr">
                        {s(p, "phone") || "—"}
                      </TableCell>

                      <TableCell>
                        {s(creator, "full_name") || "—"}
                      </TableCell>

                      <TableCell className="max-w-[16rem] truncate">
                        {s(f, "reason") || s(f, "notes") || "—"}
                      </TableCell>

                      <TableCell>
                        <StatusBadge status={status} />
                      </TableCell>

                      <TableCell className="no-print text-end">
                        {can("visits.update") && status !== "completed" ? (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() =>
                              mark.mutate({
                                id: s(f, "id"),
                                status: "completed",
                              })
                            }
                          >
                            {t("mark_done")}
                          </Button>
                        ) : null}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog
        open={open}
        onOpenChange={(value) => {
          setOpen(value);

          if (!value) {
            setForm({
              patient_id: "",
              patient_name: "",
              followup_date: todayISO(),
              reason: "",
            });

            setPatientSearch("");
          }
        }}
      >
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {t("add")} {t("followups")}
            </DialogTitle>
          </DialogHeader>

          <div className="grid gap-4">
            <div className="grid gap-2">
              <label className="text-sm font-medium">
                {t("patient")}
              </label>

              <Input
                placeholder={t("search")}
                value={form.patient_name || patientSearch}
                onChange={(e) => {
                  setForm({
                    ...form,
                    patient_id: "",
                    patient_name: "",
                  });

                  setPatientSearch(e.target.value);
                }}
              />

              {form.patient_id ? (
                <div className="rounded-md border bg-muted/30 px-3 py-2 text-sm">
                  {form.patient_name}
                </div>
              ) : (
                <div className="max-h-40 overflow-y-auto rounded-md border">
                  {((patients.data ?? []) as Row[]).map((patient) => (
                    <button
                      type="button"
                      key={s(patient, "id")}
                      className="block w-full border-b px-3 py-2 text-start text-sm last:border-0 hover:bg-muted"
                      onClick={() => {
                        setForm({
                          ...form,
                          patient_id: s(patient, "id"),
                          patient_name: s(patient, "full_name"),
                        });

                        setPatientSearch("");
                      }}
                    >
                      {s(patient, "full_name")}{" "}
                      {s(patient, "mrn")
                        ? `(${s(patient, "mrn")})`
                        : ""}
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div className="grid gap-2">
              <label className="text-sm font-medium">
                {t("due_date")}
              </label>

              <Input
                type="date"
                dir="ltr"
                value={form.followup_date}
                onChange={(e) =>
                  setForm({
                    ...form,
                    followup_date: e.target.value,
                  })
                }
              />
            </div>

            <div className="grid gap-2">
              <label className="text-sm font-medium">
                {t("reason")}
              </label>

              <Textarea
                value={form.reason}
                onChange={(e) =>
                  setForm({
                    ...form,
                    reason: e.target.value,
                  })
                }
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setOpen(false)}
            >
              {t("cancel")}
            </Button>

            <Button
              disabled={
                !form.patient_id ||
                !form.followup_date ||
                create.isPending
              }
              onClick={() =>
                create.mutate(undefined as never)
              }
            >
              {create.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}