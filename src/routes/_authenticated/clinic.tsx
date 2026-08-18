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
        content:
          "Doctor consultation and patient management.",
      },
      {
        property: "og:title",
        content:
          "Clinic — ROSHAN Medical Center",
      },
      {
        property: "og:description",
        content:
          "Doctor consultation and patient management.",
      },
    ],
  }),
  component: ClinicPage,
});

function ClinicPage() {
  const { lang } = useLang();

  const [date, setDate] = useStateSafe(todayISO());
  const [filterMyPatients, setFilterMyPatients] =
    useStateSafe(false);

  const visits = useRows(
    ["clinic-visits", date, filterMyPatients],
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
        .gte(
          "created_at",
          `${date}T00:00:00`,
        )
        .lte(
          "created_at",
          `${date}T23:59:59`,
        )
        .is("deleted_at", null)
        .order("created_at", {
          ascending: true,
        }),
  );

  const rows = (visits.data ?? []) as Row[];

  if (visits.isLoading) {
    return <Loading />;
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={
          lang === "ar"
            ? "العيادة"
            : "Clinic"
        }
        subtitle={formatDate(date)}
      >
        <div className="flex items-center gap-2 flex-wrap">
          <Button
            variant={
              filterMyPatients
                ? "default"
                : "outline"
            }
            size="sm"
            type="button"
            onClick={() =>
              setFilterMyPatients(
                !filterMyPatients,
              )
            }
          >
            {lang === "ar"
              ? "مرضاي فقط"
              : "My Patients"}
          </Button>

          <Input
            type="date"
            dir="ltr"
            value={date}
            onChange={(e) =>
              setDate(e.target.value)
            }
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
                    {lang === "ar"
                      ? "المريض"
                      : "Patient"}
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
                    {lang === "ar"
                      ? "الحالة"
                      : "Status"}
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
                  const patient = rel(
                    visit,
                    "patients",
                  );

                  const department = rel(
                    visit,
                    "departments",
                  );

                  const patientId = s(
                    patient,
                    "id",
                  );

                  const visitId = s(
                    visit,
                    "id",
                  );

                  const dob =
                    s(patient, "date_of_birth") ||
                    s(patient, "dob");

                  const ageVal = calcAge(dob);

                  const ageStr =
                    ageVal !== null
                      ? `${ageVal} yrs`
                      : "—";

                  /*
                   * IMPORTANT:
                   *
                   * Navigation is now done with a real
                   * TanStack Router <Link>.
                   *
                   * This avoids relying on onClick/useNavigate
                   * for opening the consultation.
                   */
                  const consultationPath =
                    visitId
                      ? "/clinic/$visitId"
                      : null;

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
                      <TableCell className="font-medium whitespace-nowrap">
                        {s(
                          patient,
                          "full_name",
                        ) || "—"}

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

                      <TableCell className="whitespace-nowrap text-muted-foreground text-xs">
                        {ageStr}{" "}
                        {s(
                          patient,
                          "gender",
                        )
                          ? `(${s(
                              patient,
                              "gender",
                            )})`
                          : ""}
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

                      <TableCell>
                        <StatusBadge
                          status={s(
                            visit,
                            "status",
                          )}
                        />
                      </TableCell>

                      <TableCell className="text-end whitespace-nowrap">
                        {consultationPath ? (
                          <Button
                            asChild
                            type="button"
                            size="sm"
                          >
                            <Link
                              to={
                                "/clinic/$visitId"
                              }
                              params={{
                                visitId,
                              }}
                            >
                              {lang === "ar"
                                ? "فتح"
                                : "Open"}
                            </Link>
                          </Button>
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

/*
 * Small local helpers to keep the component
 * independent from React import style.
 *
 * We intentionally keep these typed simply because
 * the project already uses its own state patterns.
 */

import { useState } from "react";

function useStateSafe<T>(
  initialValue: T,
) {
  return useState<T>(initialValue);
}