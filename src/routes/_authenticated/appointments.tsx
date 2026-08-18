import { createFileRoute } from "@tanstack/react-router";
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
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/appointments")({
  head: () => ({
    meta: [
      { title: "Appointments — ROSHAN Medical Center" },
      {
        name: "description",
        content: "Manage patient appointments and scheduling.",
      },
      {
        property: "og:title",
        content: "Appointments — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content: "Manage patient appointments and scheduling.",
      },
    ],
  }),
  component: AppointmentsPage,
});

function AppointmentsPage() {
  const { lang } = useLang();

  const [date, setDate] = useState(todayISO());
  const [open, setOpen] = useState(false);

  const [form, setForm] = useState({
    patient_id: "",
    doctor_id: "",
    department_id: "",
    appointment_date: todayISO(),
    appointment_time: "09:00",
    notes: "",
  });

  const appointments = useRows(["appointments", date], () =>
    supabase
      .from("appointments")
      .select(
        "id, appointment_date, appointment_time, status, notes, patients(id, full_name, mrn), users(full_name), departments(name, name_ar)",
      )
      .gte("appointment_date", `${date}T00:00:00`)
      .lte("appointment_date", `${date}T23:59:59`)
      .is("deleted_at", null)
      .order("appointment_date", { ascending: true }),
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
      .is("deleted_at", null),
  );

  const doctors = useRows(["doctors"], () =>
    supabase
      .from("users")
      .select("id, full_name, roles(code)")
      .eq("active", true)
      .is("deleted_at", null),
  );

  /*
   * CREATE APPOINTMENT
   *
   * Important:
   * created_by must be the currently authenticated user's UUID.
   * This is required by the appointments INSERT RLS policy.
   */
  const create = useSave(
    async () => {
      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser();

      if (authError) {
        throw new Error(authError.message);
      }

      if (!user?.id) {
        throw new Error(
          lang === "ar"
            ? "انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى."
            : "Your login session has expired. Please sign in again.",
        );
      }

      if (!form.patient_id) {
        throw new Error(
          lang === "ar"
            ? "يرجى اختيار المريض."
            : "Please select a patient.",
        );
      }

      const appointmentDateTime =
        `${form.appointment_date}T${form.appointment_time}:00`;

      const { error } = await supabase.from("appointments").insert({
        patient_id: form.patient_id,
        doctor_id: form.doctor_id || null,
        department_id: form.department_id || null,

        appointment_date: appointmentDateTime,

        /*
         * Keep appointment_time populated because the database
         * contains this dedicated column as well.
         */
        appointment_time: form.appointment_time,

        status: "scheduled",
        notes: form.notes || null,

        /*
         * REQUIRED BY RLS
         */
        created_by: user.id,
      });

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["appointments", date]],

      successMessage:
        lang === "ar"
          ? "تم حفظ الموعد بنجاح"
          : "Appointment saved successfully",

      onDone: () => {
        setOpen(false);

        setForm({
          patient_id: "",
          doctor_id: "",
          department_id: "",
          appointment_date: todayISO(),
          appointment_time: "09:00",
          notes: "",
        });
      },
    },
  );

  /*
   * SOFT DELETE
   */
  const deleteAppointment = useSave(
    async (id: string) => {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!user?.id) {
        throw new Error(
          lang === "ar"
            ? "انتهت جلسة تسجيل الدخول."
            : "Your login session has expired.",
        );
      }

      const { error } = await supabase
        .from("appointments")
        .update({
          deleted_at: new Date().toISOString(),
          deleted_by: user.id,
          updated_by: user.id,
        })
        .eq("id", id);

      if (error) {
        throw new Error(error.message);
      }

      return null;
    },
    {
      invalidate: [["appointments", date]],
      successMessage: lang === "ar" ? "تم حذف الموعد" : "Appointment deleted",
    },
  );

  const rows = (appointments.data ?? []) as Row[];

  const doctorRows = ((doctors.data ?? []) as Row[]).filter((doctor) => {
    const roleCode = s(rel(doctor, "roles"), "code").toLowerCase();

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

  if (appointments.isLoading) {
    return <Loading />;
  }

  return (
    <div>
      <PageHeader
        title={lang === "ar" ? "المواعيد" : "Appointments"}
        subtitle={formatDate(date)}
      >
        <Input
          type="date"
          dir="ltr"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className="w-40"
        />

        <ExportButtons
          rows={rows}
          filename={`roshan-appointments-${date}`}
        />

        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm">
              <Plus className="size-4" />
              {lang === "ar" ? "ميعاد جديد" : "New Appointment"}
            </Button>
          </DialogTrigger>

          <DialogContent className="max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>
                {lang === "ar"
                  ? "حجز ميعاد جديد"
                  : "New Appointment"}
              </DialogTitle>
            </DialogHeader>

            <div className="grid gap-4">
              <Field
                label={
                  lang === "ar"
                    ? "المريض *"
                    : "Patient *"
                }
              >
                <Select
                  value={form.patient_id}
                  onValueChange={(value) =>
                    setForm({
                      ...form,
                      patient_id: value,
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue
                      placeholder={
                        lang === "ar"
                          ? "اختر المريض..."
                          : "Select patient..."
                      }
                    />
                  </SelectTrigger>

                  <SelectContent className="max-h-72">
                    {((patients.data ?? []) as Row[]).map(
                      (patient) => (
                        <SelectItem
                          key={s(patient, "id")}
                          value={s(patient, "id")}
                        >
                          {s(patient, "full_name")} —{" "}
                          {s(patient, "mrn")}
                        </SelectItem>
                      ),
                    )}
                  </SelectContent>
                </Select>
              </Field>

              <Field
                label={
                  lang === "ar"
                    ? "الطبيب"
                    : "Doctor"
                }
              >
                <Select
                  value={form.doctor_id}
                  onValueChange={(value) =>
                    setForm({
                      ...form,
                      doctor_id: value,
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue
                      placeholder={
                        lang === "ar"
                          ? "بدون"
                          : "None"
                      }
                    />
                  </SelectTrigger>

                  <SelectContent>
                    {doctorRows.map((doctor) => (
                      <SelectItem
                        key={s(doctor, "id")}
                        value={s(doctor, "id")}
                      >
                        {s(doctor, "full_name")}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>

              <Field
                label={
                  lang === "ar"
                    ? "القسم"
                    : "Department"
                }
              >
                <Select
                  value={form.department_id}
                  onValueChange={(value) =>
                    setForm({
                      ...form,
                      department_id: value,
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue
                      placeholder={
                        lang === "ar"
                          ? "بدون"
                          : "None"
                      }
                    />
                  </SelectTrigger>

                  <SelectContent>
                    {((departments.data ?? []) as Row[]).map(
                      (department) => (
                        <SelectItem
                          key={s(department, "id")}
                          value={s(department, "id")}
                        >
                          {lang === "ar"
                            ? s(department, "name_ar") ||
                              s(department, "name")
                            : s(department, "name")}
                        </SelectItem>
                      ),
                    )}
                  </SelectContent>
                </Select>
              </Field>

              <div className="grid grid-cols-2 gap-2">
                <Field
                  label={
                    lang === "ar"
                      ? "تاريخ الموعد"
                      : "Appointment Date"
                  }
                >
                  <Input
                    type="date"
                    dir="ltr"
                    value={form.appointment_date}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        appointment_date: e.target.value,
                      })
                    }
                  />
                </Field>

                <Field
                  label={
                    lang === "ar"
                      ? "الوقت"
                      : "Time"
                  }
                >
                  <Input
                    type="time"
                    dir="ltr"
                    value={form.appointment_time}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        appointment_time: e.target.value,
                      })
                    }
                  />
                </Field>
              </div>

              <Field
                label={
                  lang === "ar"
                    ? "ملاحظات"
                    : "Notes"
                }
              >
                <Textarea
                  rows={2}
                  value={form.notes}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      notes: e.target.value,
                    })
                  }
                />
              </Field>
            </div>

            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setOpen(false)}
              >
                {lang === "ar"
                  ? "إلغاء"
                  : "Cancel"}
              </Button>

              <Button
                disabled={
                  !form.patient_id ||
                  create.isPending
                }
                onClick={() =>
                  create.mutate(undefined as never)
                }
              >
                {create.isPending
                  ? lang === "ar"
                    ? "جاري الحفظ..."
                    : "Saving..."
                  : lang === "ar"
                    ? "حفظ"
                    : "Save"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </PageHeader>

      <ErrorBox
        error={
          appointments.error ??
          patients.error ??
          departments.error ??
          doctors.error
        }
      />

      <Card>
        <CardContent className="p-0 overflow-x-auto">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>
                    {lang === "ar"
                      ? "المريض"
                      : "Patient"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "الطبيب"
                      : "Doctor"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "القسم"
                      : "Department"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "التاريخ"
                      : "Date"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "الوقت"
                      : "Time"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "الحالة"
                      : "Status"}
                  </TableHead>

                  <TableHead className="text-end">
                    {lang === "ar"
                      ? "الإجراءات"
                      : "Actions"}
                  </TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {rows.map((item) => {
                  const patient = rel(item, "patients");
                  const doctor = rel(item, "users");
                  const department = rel(
                    item,
                    "departments",
                  );

                  const dateVal =
                    s(item, "appointment_date") || "";

                  const [datePart, timePart] =
                    dateVal.includes("T")
                      ? dateVal.split("T")
                      : [dateVal, ""];

                  const storedAppointmentTime =
                    s(item, "appointment_time");

                  const formattedTime =
                    storedAppointmentTime
                      ? storedAppointmentTime.substring(
                          0,
                          5,
                        )
                      : timePart
                        ? timePart.substring(0, 5)
                        : "—";

                  return (
                    <TableRow
                      key={s(item, "id")}
                    >
                      <TableCell className="font-medium whitespace-nowrap">
                        {s(
                          patient,
                          "full_name",
                        ) || "—"}

                        <span
                          className="ms-2 text-xs text-muted-foreground"
                          dir="ltr"
                        >
                          {s(patient, "mrn")}
                        </span>
                      </TableCell>

                      <TableCell className="whitespace-nowrap">
                        {s(
                          doctor,
                          "full_name",
                        ) || "—"}
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
                            ) ||
                            "—"
                          : s(
                              department,
                              "name",
                            ) || "—"}
                      </TableCell>

                      <TableCell
                        dir="ltr"
                        className="whitespace-nowrap font-mono text-xs"
                      >
                        {datePart || "—"}
                      </TableCell>

                      <TableCell
                        dir="ltr"
                        className="whitespace-nowrap font-mono text-xs font-bold text-primary"
                      >
                        {formattedTime}
                      </TableCell>

                      <TableCell>
                        <StatusBadge
                          status={s(
                            item,
                            "status",
                          )}
                        />
                      </TableCell>

                      <TableCell className="text-end whitespace-nowrap">
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-destructive hover:text-destructive"
                          disabled={
                            deleteAppointment.isPending
                          }
                          onClick={() => {
                            if (
                              confirm(
                                lang === "ar"
                                  ? "هل أنت متأكد من حذف هذا الموعد؟"
                                  : "Are you sure you want to delete this appointment?",
                              )
                            ) {
                              deleteAppointment.mutate(
                                s(item, "id"),
                              );
                            }
                          }}
                        >
                          <Trash2 className="size-4" />
                        </Button>
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