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
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { rel, s, useRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { useAuth } from "@/lib/auth";
import { calcAge, formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/clinic")({
  head: () => ({
    meta: [
      {
        title: "Clinic — ROSHAN Medical Center",
      },
      {
        name: "description",
        content: "Doctor consultation and patient management.",
      },
      {
        property: "og:title",
        content: "Clinic — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content: "Doctor consultation and patient management.",
      },
    ],
  }),
  component: ClinicPage,
});

function ClinicPage() {
  const { lang } = useLang();
  const { user } = useAuth();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");

  const [date, setDate] = useState<string>(todayISO());
  const [filterMyPatients, setFilterMyPatients] =
    useState<boolean>(false);

  const nextDate = (() => { const d = new Date(`${date}T00:00:00+02:00`); d.setDate(d.getDate()+1); return d.toISOString(); })();

  const visits = useRows(
    ["clinic-visits", date, filterMyPatients, user?.id ?? ""],
    () =>
      supabase
        .from("visits")
        .select(
          `
            id,
            visit_number,
            status,
            created_at,
            visit_date,
            patient_id,
            doctor_id,
            patients(
              id,
              full_name,
              mrn,
              patient_number,
              phone,
              date_of_birth,
              dob,
              gender
            ),
            departments(
              name,
              name_ar
            ),
            users(
              full_name
            )
          `,
        )
        .gte("visit_date", new Date(`${date}T00:00:00+02:00`).toISOString())
        .lt("visit_date", nextDate)
        .is("deleted_at", null)
        .order("visit_date", { ascending: true }),
  );

  const rows = ((visits.data ?? []) as Row[]).filter((visit) => {
    if (filterMyPatients && user?.id && s(visit, "doctor_id") !== user.id) return false;
    if (status !== "all" && s(visit, "status") !== status) return false;
    const term = search.trim().toLowerCase();
    if (!term) return true;
    const patient = rel(visit, "patients");
    const dept = rel(visit, "departments");
    return `${s(patient, "full_name")} ${s(patient, "mrn")} ${s(patient, "patient_number")} ${s(patient, "phone")} ${s(visit, "visit_number")} ${s(dept, "name")} ${s(dept, "name_ar")}`.toLowerCase().includes(term);
  });

  if (visits.isLoading) {
    return <Loading />;
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={lang === "ar" ? "العيادة" : "Clinic"}
        subtitle={formatDate(date)}
      >
        <div className="flex flex-wrap items-center gap-2">
          <Input value={search} onChange={(e)=>setSearch(e.target.value)} placeholder={lang==="ar"?"ابحث عن المريض":"Search patient"} className="w-52"/>
          <select className="rounded-md border bg-background px-3 py-2 text-sm" value={status} onChange={(e)=>setStatus(e.target.value)}><option value="all">{lang==="ar"?"كل الحالات":"All statuses"}</option><option value="waiting">Waiting</option><option value="in_progress">In progress</option><option value="completed">Completed</option></select>
          <Button
            variant={filterMyPatients ? "default" : "outline"}
            size="sm"
            type="button"
            onClick={() =>
              setFilterMyPatients((current) => !current)
            }
          >
            {lang === "ar" ? "مرضاي فقط" : "My Patients"}
          </Button>

          <Input
            type="date"
            dir="ltr"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-40"
          />

          <ExportButtons
            rows={rows}
            filename={`roshan-clinic-${date}`}
          />
        </div>
      </PageHeader>

      <ErrorBox error={visits.error} />

      <Card>
        <CardContent className="overflow-x-auto p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>
                    {lang === "ar" ? "المريض" : "Patient"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "العمر / الجنس"
                      : "Age / Gender"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar"
                      ? "القسم"
                      : "Department"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar" ? "الحالة" : "Status"}
                  </TableHead>

                  <TableHead className="text-end">
                    {lang === "ar"
                      ? "الإجراء"
                      : "Action"}
                  </TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {rows.map((visit) => {
                  const patient = rel(visit, "patients");
                  const department = rel(
                    visit,
                    "departments",
                  );

                  const patientId = s(patient, "id");
                  const visitId = s(visit, "id");

                  const dob =
                    s(patient, "date_of_birth") ||
                    s(patient, "dob");

                  const ageVal = calcAge(dob);

                  const ageStr =
                    ageVal !== null
                      ? `${ageVal} yrs`
                      : "—";

                  /*
                   * IMPORTANT
                   * =========
                   *
                   * We deliberately use a normal HTML <a>
                   * instead of:
                   *
                   * <Button asChild>
                   *   <Link ... />
                   * </Button>
                   *
                   * This completely avoids Radix Slot /
                   * pointer-events / nested component issues.
                   *
                   * The target route is:
                   * /clinic/{visitId}
                   */

                  const clinicUrl = visitId
                    ? `/clinic/${encodeURIComponent(visitId)}`
                    : "";

                  return (
                    <TableRow
                      key={
                        visitId ||
                        `${patientId}-${s(
                          visit,
                          "created_at",
                        )}`
                      }
                    >
                      {/* PATIENT */}
                      <TableCell className="whitespace-nowrap font-medium">
                        {s(patient, "full_name") ||
                          "—"}

                        {s(patient, "mrn") ? (
                          <span
                            className="ms-2 text-xs text-muted-foreground"
                            dir="ltr"
                          >
                            {s(patient, "mrn")}
                          </span>
                        ) : null}
                      </TableCell>

                      {/* AGE / GENDER */}
                      <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                        {ageStr}

                        {s(patient, "gender")
                          ? ` (${s(
                              patient,
                              "gender",
                            )})`
                          : ""}
                      </TableCell>

                      {/* DEPARTMENT */}
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

                      {/* STATUS */}
                      <TableCell>
                        <StatusBadge
                          status={s(
                            visit,
                            "status",
                          )}
                        />
                      </TableCell>

                      {/* ACTION */}
                      <TableCell className="whitespace-nowrap text-end">
                        {visitId ? (
                          <a
                            href={clinicUrl}
                            className="
                              inline-flex
                              h-8
                              items-center
                              justify-center
                              gap-2
                              whitespace-nowrap
                              rounded-md
                              bg-primary
                              px-3
                              text-xs
                              font-medium
                              text-primary-foreground
                              shadow
                              transition-colors
                              hover:bg-primary/90
                              focus-visible:outline-none
                              focus-visible:ring-1
                              focus-visible:ring-ring
                              cursor-pointer
                            "
                            title={
                              lang === "ar"
                                ? `فتح زيارة ${s(
                                    visit,
                                    "visit_number",
                                  )}`
                                : `Open visit ${s(
                                    visit,
                                    "visit_number",
                                  )}`
                            }
                          >
                            {lang === "ar"
                              ? "فتح"
                              : "Open"}
                          </a>
                        ) : (
                          <Button
                            type="button"
                            size="sm"
                            disabled
                            title={
                              lang === "ar"
                                ? "معرّف الزيارة غير موجود"
                                : "Visit ID is missing"
                            }
                          >
                            {lang === "ar"
                              ? "فتح"
                              : "Open"}
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