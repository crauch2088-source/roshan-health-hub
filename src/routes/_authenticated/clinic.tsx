import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";

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

  const [date, setDate] = useState<string>(todayISO());
  const [filterMyPatients, setFilterMyPatients] =
    useState<boolean>(false);

  const visits = useRows(
    ["clinic-visits", date, filterMyPatients],

    async () => {
      let query = supabase
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
        .is("deleted_at", null)
        .order("created_at", {
          ascending: true,
        });

      /*
       * Use visit_date when available.
       *
       * This is safer for the clinic because a visit created
       * around midnight should belong to its actual visit date,
       * not necessarily the created_at date.
       */
      query = query
        .gte("visit_date", date)
        .lte("visit_date", date);

      /*
       * "My Patients" filter.
       *
       * We intentionally do not apply it unless we have a
       * valid authenticated user, because doctor_id may be
       * NULL for newly created visits.
       */
      if (filterMyPatients) {
        const {
          data: { user },
        } = await supabase.auth.getUser();

        if (user?.id) {
          query = query.eq("doctor_id", user.id);
        }
      }

      return query;
    },
  );

  const rows = (visits.data ?? []) as Row[];

  if (visits.isLoading) {
    return <Loading />;
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={lang === "ar" ? "العيادة" : "Clinic"}
        subtitle={formatDate(date)}
      >
        <div className="flex items-center gap-2 flex-wrap">
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
            onChange={(event) => {
              setDate(event.target.value);
            }}
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
        <CardContent className="p-0 overflow-x-auto">
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
                    {lang === "ar" ? "القسم" : "Department"}
                  </TableHead>

                  <TableHead>
                    {lang === "ar" ? "الحالة" : "Status"}
                  </TableHead>

                  <TableHead className="text-end">
                    {lang === "ar" ? "الإجراء" : "Action"}
                  </TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {rows.map((visit) => {
                  const patient = rel(visit, "patients");
                  const department = rel(visit, "departments");

                  const patientId = s(patient, "id");
                  const visitId = s(visit, "id");

                  const dob =
                    s(patient, "date_of_birth") ||
                    s(patient, "dob");

                  const ageVal = calcAge(dob);

                  const ageStr =
                    ageVal !== null ? `${ageVal} yrs` : "—";

                  /*
                   * ==================================================
                   * IMPORTANT
                   * ==================================================
                   *
                   * Do NOT use Button asChild here.
                   *
                   * The actual navigation element is a native
                   * TanStack Router <Link>.
                   *
                   * This guarantees that clicking "Open" invokes
                   * the router directly.
                   */

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
                      <TableCell className="font-medium whitespace-nowrap">
                        {s(patient, "full_name") || "—"}

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
                      <TableCell className="whitespace-nowrap text-muted-foreground text-xs">
                        {ageStr}

                        {s(patient, "gender")
                          ? ` (${s(patient, "gender")})`
                          : ""}
                      </TableCell>

                      {/* DEPARTMENT */}
                      <TableCell className="whitespace-nowrap">
                        {lang === "ar"
                          ? s(department, "name_ar") ||
                            s(department, "name") ||
                            "—"
                          : s(department, "name") || "—"}
                      </TableCell>

                      {/* STATUS */}
                      <TableCell>
                        <StatusBadge
                          status={s(visit, "status")}
                        />
                      </TableCell>

                      {/* ACTION */}
                      <TableCell className="text-end whitespace-nowrap">
                        {visitId ? (
                          /*
                           * REAL ROUTER LINK
                           *
                           * We deliberately don't wrap this in
                           * <Button asChild>.
                           */
                          <Link
                            to="/clinic/$visitId"
                            params={{
                              visitId: visitId,
                            }}
                            preload="intent"
                            className="
                              inline-flex
                              h-9
                              items-center
                              justify-center
                              rounded-md
                              bg-primary
                              px-3
                              text-sm
                              font-medium
                              text-primary-foreground
                              shadow
                              transition-colors
                              hover:bg-primary/90
                              focus-visible:outline-none
                              focus-visible:ring-2
                              focus-visible:ring-ring
                              focus-visible:ring-offset-2
                              disabled:pointer-events-none
                              disabled:opacity-50
                            "
                          >
                            {lang === "ar" ? "فتح" : "Open"}
                          </Link>
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
                            {lang === "ar" ? "فتح" : "Open"}
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