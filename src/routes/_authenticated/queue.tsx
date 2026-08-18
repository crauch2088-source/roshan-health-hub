import { createFileRoute, Link } from "@tanstack/react-router";
import { Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import {
  Empty,
  ErrorBox,
  ExportButtons,
  Field,
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
import {
  n,
  rel,
  s,
  useRows,
  useSave,
  useSettings,
  type Row,
} from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/queue")({
  head: () => ({
    meta: [
      { title: "Visits — ROSHAN Medical Center" },
      {
        name: "description",
        content:
          "Register walk-in and scheduled visits and route patients to clinics.",
      },
      {
        property: "og:title",
        content: "Visits — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Register walk-in and scheduled visits and route patients to clinics.",
      },
    ],
  }),
  component: VisitsPage,
});

function VisitsPage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const { currency } = useSettings();

  const [date, setDate] = useState(todayISO());
  const [open, setOpen] = useState(false);

  const [form, setForm] = useState({
    patient_id: "",
    department_id: "",
    doctor_id: "",
    visit_type: "walk_in",
    consultation_fee: "0",
    notes: "",
  });

  /*
   * Visits for the selected day.
   *
   * queue_number is the daily queue position.
   * visit_number remains the permanent clinical visit identifier.
   */
  const visits = useRows(["visits", date], () =>
    supabase
      .from("visits")
      .select(
        "id, visit_number, queue_number, visit_date, status, visit_type, consultation_fee, notes, created_at, patients!visits_patient_id_fkey(id, full_name, mrn), departments!visits_department_id_fkey(name, name_ar), users!visits_doctor_id_fkey(full_name)",
      )
      .eq("visit_date", date)
      .is("deleted_at", null)
      .order("queue_number", {
        ascending: true,
        nullsFirst: false,
      })
      .order("created_at", {
        ascending: true,
      }),
  );

  const patients = useRows(["patients-lite"], () =>
    supabase
      .from("patients")
      .select("id, full_name, mrn")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(500),
  );

  const departments = useRows(["departments"], () =>
    supabase
      .from("departments")
      .select("id, name, name_ar")
      .is("deleted_at", null)
      .order("name", { ascending: true }),
  );

  const doctors = useRows(["doctors"], () =>
    supabase
      .from("users")
      .select("id, full_name, roles(code)")
      .eq("active", true)
      .is("deleted_at", null)
      .order("full_name", { ascending: true }),
  );

  /*
   * Create a visit and allocate the next daily queue number.
   */
  const create = useSave<void>(
    async () => {
      if (!form.patient_id) {
        throw new Error(
          `${t("patient")} is required.`,
        );
      }

      const { data, error } = await supabase.rpc(
        "next_queue_number",
        {
          _visit_date: date,
        },
      );

      if (error) {
        throw new Error(error.message);
      }

      const numericQueue = Number(data);

      if (
        !Number.isInteger(numericQueue) ||
        numericQueue <= 0
      ) {
        throw new Error(
          "Unable to generate a valid queue number.",
        );
      }

      const { error: insertError } =
        await supabase.from("visits").insert({
          patient_id: form.patient_id,
          department_id:
            form.department_id || null,
          doctor_id: form.doctor_id || null,
          visit_date: date,
          visit_type: form.visit_type,
          status: "waiting",
          consultation_fee:
            Number(form.consultation_fee) || 0,
          notes: form.notes || null,
          queue_number: numericQueue,
        });

      if (insertError) {
        throw new Error(insertError.message);
      }
    },
    {
      invalidate: [["visits", date]],
      successMessage: t("saved"),
      onDone: () => {
        setOpen(false);

        setForm({
          patient_id: "",
          department_id: "",
          doctor_id: "",
          visit_type: "walk_in",
          consultation_fee: "0",
          notes: "",
        });
      },
    },
  );

  /*
   * Soft-delete a visit.
   */
  const deleteVisit = useSave<string>(
    async (visitId) => {
      if (!can("visits.delete")) {
        throw new Error(
          "You do not have permission to delete visits.",
        );
      }

      const { error } = await supabase
        .from("visits")
        .update({
          deleted_at: new Date().toISOString(),
        })
        .eq("id", visitId);

      if (error) {
        throw new Error(error.message);
      }

      /*
       * Cancel an associated queue ticket if one exists.
       */
      const { error: queueError } =
        await supabase
          .from("queue_tickets")
          .update({
            status: "cancelled",
          })
          .eq("visit_id", visitId);

      if (queueError) {
        console.warn(
          "Queue ticket update failed:",
          queueError.message,
        );
      }
    },
    {
      invalidate: [["visits", date]],
      successMessage: t("deleted"),
    },
  );

  const rows = (visits.data ?? []) as Row[];

  const doctorRows = (
    (doctors.data ?? []) as Row[]
  ).filter((doctor) => {
    const roleCode = s(
      rel(doctor, "roles"),
      "code",
    ).toLowerCase();

    return (
      !roleCode ||
      [
        "gp",
        "dentist",
        "specialist",
        "doctor",
        "physician",
      ].includes(roleCode)
    );
  });

  if (visits.isLoading) {
    return <Loading />;
  }

  return (
    <div>
      <PageHeader
        title={t("visits")}
        subtitle={formatDate(date)}
      >
        <Input
          type="date"
          dir="ltr"
          value={date}
          onChange={(event) =>
            setDate(event.target.value)
          }
          className="w-40"
        />

        <ExportButtons
          rows={rows}
          filename={`roshan-visits-${date}`}
        />

        {can("visits.create") && (
          <Dialog
            open={open}
            onOpenChange={setOpen}
          >
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" />
                {t("new_visit")}
              </Button>
            </DialogTrigger>

            <DialogContent className="max-h-[90vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>
                  {t("new_visit")}
                </DialogTitle>
              </DialogHeader>

              <div className="grid gap-4">
                <Field
                  label={`${t("patient")} *`}
                >
                  <Select
                    value={form.patient_id}
                    onValueChange={(value) =>
                      setForm((current) => ({
                        ...current,
                        patient_id: value,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue
                        placeholder={t(
                          "search",
                        )}
                      />
                    </SelectTrigger>

                    <SelectContent className="max-h-72">
                      {(
                        (patients.data ??
                          []) as Row[]
                      ).map((patient) => (
                        <SelectItem
                          key={s(
                            patient,
                            "id",
                          )}
                          value={s(
                            patient,
                            "id",
                          )}
                        >
                          {s(
                            patient,
                            "full_name",
                          )}{" "}
                          —{" "}
                          {s(
                            patient,
                            "mrn",
                          )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>

                <Field
                  label={t("department")}
                >
                  <Select
                    value={
                      form.department_id
                    }
                    onValueChange={(value) =>
                      setForm((current) => ({
                        ...current,
                        department_id: value,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue
                        placeholder={t(
                          "none",
                        )}
                      />
                    </SelectTrigger>

                    <SelectContent>
                      {(
                        (departments.data ??
                          []) as Row[]
                      ).map((department) => (
                        <SelectItem
                          key={s(
                            department,
                            "id",
                          )}
                          value={s(
                            department,
                            "id",
                          )}
                        >
                          {lang === "ar"
                            ? s(
                                department,
                                "name_ar",
                              ) ||
                              s(
                                department,
                                "name",
                              )
                            : s(
                                department,
                                "name",
                              )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>

                <Field
                  label={t("doctor")}
                >
                  <Select
                    value={form.doctor_id}
                    onValueChange={(value) =>
                      setForm((current) => ({
                        ...current,
                        doctor_id: value,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue
                        placeholder={t(
                          "none",
                        )}
                      />
                    </SelectTrigger>

                    <SelectContent>
                      {doctorRows.map(
                        (doctor) => (
                          <SelectItem
                            key={s(
                              doctor,
                              "id",
                            )}
                            value={s(
                              doctor,
                              "id",
                            )}
                          >
                            {s(
                              doctor,
                              "full_name",
                            )}
                          </SelectItem>
                        ),
                      )}
                    </SelectContent>
                  </Select>
                </Field>

                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    label={t(
                      "visit_type",
                    )}
                  >
                    <Select
                      value={
                        form.visit_type
                      }
                      onValueChange={(value) =>
                        setForm((current) => ({
                          ...current,
                          visit_type: value,
                        }))
                      }
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>

                      <SelectContent>
                        <SelectItem value="walk_in">
                          {t("walk_in")}
                        </SelectItem>

                        <SelectItem value="scheduled">
                          {t("scheduled")}
                        </SelectItem>
                      </SelectContent>
                    </Select>
                  </Field>

                  <Field
                    label={t(
                      "consultation_fee",
                    )}
                  >
                    <Input
                      type="number"
                      dir="ltr"
                      min={0}
                      value={
                        form.consultation_fee
                      }
                      onChange={(event) =>
                        setForm((current) => ({
                          ...current,
                          consultation_fee:
                            event.target
                              .value,
                        }))
                      }
                    />
                  </Field>
                </div>

                <Field label={t("notes")}>
                  <Textarea
                    rows={2}
                    value={form.notes}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        notes:
                          event.target.value,
                      }))
                    }
                  />
                </Field>
              </div>

              <DialogFooter>
                <Button
                  variant="outline"
                  onClick={() =>
                    setOpen(false)
                  }
                >
                  {t("cancel")}
                </Button>

                <Button
                  disabled={
                    !form.patient_id ||
                    create.isPending ||
                    !can("visits.create")
                  }
                  onClick={() =>
                    create.mutate()
                  }
                >
                  {create.isPending
                    ? t("saving")
                    : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        )}
      </PageHeader>

      <ErrorBox error={visits.error} />

      <Card>
        <CardContent className="p-0 overflow-x-auto">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>
                    {t("patient")}
                  </TableHead>

                  <TableHead>
                    {t("queue_number")}
                  </TableHead>

                  <TableHead>
                    {t("department")}
                  </TableHead>

                  <TableHead>
                    {t("doctor")}
                  </TableHead>

                  <TableHead>
                    {t("consultation_fee")}
                  </TableHead>

                  <TableHead>
                    {t("status")}
                  </TableHead>

                  <TableHead className="text-end">
                    {t("actions")}
                  </TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {rows.map((visit) => {
                  const queueNumber = n(
                    visit,
                    "queue_number",
                  );

                  const patient = rel(
                    visit,
                    "patients",
                  );

                  const department = rel(
                    visit,
                    "departments",
                  );

                  const doctor = rel(
                    visit,
                    "users",
                  );

                  return (
                    <TableRow
                      key={s(
                        visit,
                        "id",
                      )}
                    >
                      <TableCell className="font-medium whitespace-nowrap">
                        {s(
                          patient,
                          "full_name",
                        )}

                        <span
                          className="ms-2 text-xs text-muted-foreground"
                          dir="ltr"
                        >
                          {s(
                            patient,
                            "mrn",
                          )}
                        </span>
                      </TableCell>

                      <TableCell
                        dir="ltr"
                        className="font-mono text-xs font-semibold"
                      >
                        {queueNumber > 0
                          ? `Q${String(
                              queueNumber,
                            ).padStart(
                              3,
                              "0",
                            )}`
                          : "—"}
                      </TableCell>

                      <TableCell className="whitespace-nowrap">
                        {lang === "ar"
                          ? s(
                              department,
                              "name_ar",
                            ) ||
                            s(
                              department,
                              "name",
                            )
                          : s(
                              department,
                              "name",
                            )}
                      </TableCell>

                      <TableCell className="whitespace-nowrap">
                        {s(
                          doctor,
                          "full_name",
                        ) || "—"}
                      </TableCell>

                      <TableCell className="whitespace-nowrap">
                        {money(
                          n(
                            visit,
                            "consultation_fee",
                          ),
                          currency,
                        )}
                      </TableCell>

                      <TableCell>
                        <StatusBadge
                          status={s(
                            visit,
                            "status",
                          )}
                        />
                      </TableCell>

                      <TableCell className="text-end space-x-1 space-x-reverse whitespace-nowrap">
                        <Button
                          asChild
                          variant="ghost"
                          size="sm"
                        >
                          <Link
                            to="/clinic/$visitId"
                            params={{
                              visitId: s(
                                visit,
                                "id",
                              ),
                            }}
                          >
                            {t("clinic")}
                          </Link>
                        </Button>

                        {can(
                          "visits.delete",
                        ) && (
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-destructive hover:text-destructive"
                            disabled={
                              deleteVisit.isPending
                            }
                            onClick={() => {
                              if (
                                window.confirm(
                                  t(
                                    "are_you_sure",
                                  ),
                                )
                              ) {
                                deleteVisit.mutate(
                                  s(
                                    visit,
                                    "id",
                                  ),
                                );
                              }
                            }}
                          >
                            <Trash2 className="size-4" />
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}