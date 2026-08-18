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
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
import { useAuth } from "@/lib/auth";

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

  const [date, setDate] = useState(todayISO());
  const [filterMyPatients, setFilterMyPatients] = useState(false);

  /*
   * IMPORTANT
   *
   * We deliberately use the authenticated Supabase user's UUID
   * through auth_user_id -> users.id relationship.
   *
   * The visits.doctor_id column may contain the application users.id,
   * not auth.uid().
   */
  const currentAuthUserId = user?.auth_user_id
    ? String(user.auth_user_id)
    : "";

  /*
   * First get the application user record associated with
   * the currently authenticated Supabase user.
   *
   * This makes "My Patients" reliable and avoids confusing
   * auth.users.id with public.users.id.
   */
  const currentUserQ = useRows<Row[]>(
    ["current-app-user", currentAuthUserId],
    () =>
      supabase
        .from("users")
        .select("id, auth_user_id, full_name, role_id, active")
        .eq("auth_user_id", currentAuthUserId)
        .eq("active", true)
        .limit(1),
    {
      enabled: Boolean(currentAuthUserId),
    },
  );

  const currentAppUser =
    ((currentUserQ.data ?? []) as Row[])[0];

  const currentAppUserId = s(
    currentAppUser,
    "id",
  );

  /*
   * Fetch today's visits.
   *
   * IMPORTANT:
   * We use visit_date rather than created_at for the clinic
   * day filter. A visit created shortly before/after midnight
   * should belong to its actual visit date.
   */
  const visits = useRows(
    [
      "clinic-visits",
      date,
      filterMyPatients,
      currentAppUserId,
    ],
    () => {
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
              id,
              full_name
            )
          `,
        )
        .eq("visit_date", date)
        .is("deleted_at", null)
        .order("created_at", {
          ascending: true,
        });

      /*
       * Only apply the doctor filter when:
       *
       * 1. "My Patients" is enabled
       * 2. We actually know the application users.id
       */
      if (filterMyPatients && currentAppUserId) {
        query = query.eq(
          "doctor_id",
          currentAppUserId,
        );
      }

      return query;
    },
  );

  const rows = (visits.data ?? []) as Row[];

  if (
    visits.isLoading ||
    (filterMyPatients &&
      currentUserQ.isLoading)
  ) {
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
        <div className="flex flex-wrap items-center gap-2">
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
                (value) => !value,
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

      <ErrorBox
        error={
          visits.error ??
          currentUserQ.error
        }
      />

      <Card>
        <CardContent className="overflow-x-auto p-0">
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
                  /*
                   * Explicitly convert the visit id to a string.
                   *
                   * This is the critical value used by the
                   * /clinic/$visitId route.
                   */
                  const visitId = s(
                    visit,
                    "id",
                  ).trim();

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

                  const dob =
                    s(
                      patient,
                      "date_of_birth",
                    ) ||
                    s(patient, "dob");

                  const ageVal = calcAge(dob);

                  const ageStr =
                    ageVal !== null
                      ? `${ageVal} yrs`
                      : "—";

                  const gender =
                    s(patient, "gender");

                  /*
                   * We do NOT use Button asChild here.
                   *
                   * The Link itself is the clickable element.
                   * This removes Radix Slot from the navigation
                   * path and eliminates a possible event/DOM issue.
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
                      <TableCell className="whitespace-nowrap font-medium">
                        {s(
                          patient,
                          "full_name",
                        ) || "—"}

                        {s(
                          patient,
                          "mrn",
                        ) ? (
                          <span
                            className="ms-2 text-xs text-muted-foreground"
                            dir="ltr"
                          >
                            {s(
                              patient,
                              "mrn",
                            )}
                          </span>
                        ) : null}
                      </TableCell>

                      <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                        {ageStr}

                        {gender
                          ? ` (${gender})`
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

                      <TableCell className="whitespace-nowrap text-end">
                        {visitId ? (
                          <Link
                            to="/clinic/$visitId"
                            params={{
                              visitId,
                            }}
                            className="inline-flex h-8 cursor-pointer items-center justify-center gap-2 whitespace-nowrap rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground shadow transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                            title={
                              lang === "ar"
                                ? "فتح الاستشارة"
                                : "Open consultation"
                            }
                          >
                            {lang === "ar"
                              ? "فتح"
                              : "Open"}
                          </Link>
                        ) : (
                          <span
                            className="inline-flex h-8 items-center justify-center rounded-md border border-input px-3 text-xs text-muted-foreground opacity-50"
                            title={
                              lang === "ar"
                                ? "معرّف الزيارة غير موجود"
                                : "Visit ID is missing"
                            }
                          >
                            {lang === "ar"
                              ? "فتح"
                              : "Open"}
                          </span>
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