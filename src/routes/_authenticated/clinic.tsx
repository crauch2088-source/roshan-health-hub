import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

import {
  DataPanel,
  Empty,
  ErrorBox,
  ExportButtons,
  InitialAvatar,
  Metric,
  MetricStrip,
  NoResults,
  PageHeader,
  PageSkeleton,
  PermissionGate,
  RecordRow,
  SearchField,
  StatusBadge,
  Toolbar,
} from "@/components/kit";
import { Button } from "@/components/ui/button";
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
  return (
    <PermissionGate perm="visits.read">
      <ClinicPageInner />
    </PermissionGate>
  );
}

function ClinicPageInner() {
  const { lang } = useLang();
  const { user } = useAuth();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");

  const [date, setDate] = useState<string>(todayISO());
  const [filterMyPatients, setFilterMyPatients] = useState<boolean>(false);

  const nextDate = (() => {
    const d = new Date(`${date}T00:00:00+02:00`);
    d.setDate(d.getDate() + 1);
    return d.toISOString();
  })();

  const visits = useRows(["clinic-visits", date, filterMyPatients, user?.id ?? ""], () =>
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
              phone,
              date_of_birth,
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
    return `${s(patient, "full_name")} ${s(patient, "mrn")} ${s(patient, "phone")} ${s(visit, "visit_number")} ${s(dept, "name")} ${s(dept, "name_ar")}`
      .toLowerCase()
      .includes(term);
  });

  if (visits.isLoading) {
    return <PageSkeleton />;
  }

  const dayRows = (visits.data ?? []) as Row[];
  const countOf = (st: string) => dayRows.filter((v) => s(v, "status") === st).length;
  const filtered = search.trim() !== "" || status !== "all" || filterMyPatients;
  const clearFilters = () => {
    setSearch("");
    setStatus("all");
    setFilterMyPatients(false);
  };
  const deptName = (visit: Row) => {
    const department = rel(visit, "departments");
    return lang === "ar"
      ? s(department, "name_ar") || s(department, "name") || "—"
      : s(department, "name") || "—";
  };
  const openLabel = lang === "ar" ? "فتح" : "Open";
  const openTitle = (visit: Row) =>
    lang === "ar"
      ? `فتح زيارة ${s(visit, "visit_number")}`
      : `Open visit ${s(visit, "visit_number")}`;

  return (
    <div className="space-y-4">
      <PageHeader title={lang === "ar" ? "العيادة" : "Clinic"} subtitle={formatDate(date)}>
        <Input
          type="date"
          dir="ltr"
          aria-label={lang === "ar" ? "التاريخ" : "Date"}
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className="h-11 w-full sm:w-40"
        />
        <ExportButtons rows={rows} filename={`roshan-clinic-${date}`} />
      </PageHeader>

      <MetricStrip label={lang === "ar" ? "ملخص اليوم" : "Day summary"} cols="sm:grid-cols-4">
        <Metric label={lang === "ar" ? "الزيارات" : "Visits"} value={dayRows.length} />
        <Metric
          label={lang === "ar" ? "بانتظار" : "Waiting"}
          value={countOf("waiting")}
          tone={countOf("waiting") > 0 ? "warning" : "default"}
        />
        <Metric
          label={lang === "ar" ? "قيد المعالجة" : "In progress"}
          value={countOf("in_progress")}
          tone="primary"
        />
        <Metric
          label={lang === "ar" ? "مكتملة" : "Completed"}
          value={countOf("completed")}
          tone="success"
        />
      </MetricStrip>

      <Toolbar>
        <SearchField
          value={search}
          onChange={setSearch}
          placeholder={lang === "ar" ? "ابحث عن المريض" : "Search patient"}
        />
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger
            className="h-11 w-full sm:w-44"
            aria-label={lang === "ar" ? "الحالة" : "Status"}
          >
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{lang === "ar" ? "كل الحالات" : "All statuses"}</SelectItem>
            <SelectItem value="waiting">{lang === "ar" ? "بانتظار" : "Waiting"}</SelectItem>
            <SelectItem value="in_progress">
              {lang === "ar" ? "قيد المعالجة" : "In progress"}
            </SelectItem>
            <SelectItem value="completed">{lang === "ar" ? "مكتملة" : "Completed"}</SelectItem>
          </SelectContent>
        </Select>
        <Button
          variant={filterMyPatients ? "default" : "outline"}
          className="h-11"
          type="button"
          aria-pressed={filterMyPatients}
          onClick={() => setFilterMyPatients((current) => !current)}
        >
          {lang === "ar" ? "مرضاي فقط" : "My Patients"}
        </Button>
      </Toolbar>

      <ErrorBox error={visits.error} onRetry={() => void visits.refetch()} />

      <DataPanel>
        {rows.length === 0 && filtered ? (
          <NoResults onClear={clearFilters} />
        ) : rows.length === 0 ? (
          <Empty />
        ) : (
          <>
            <ul className="divide-y divide-border md:hidden">
              {rows.map((visit) => {
                const patient = rel(visit, "patients");
                const visitId = s(visit, "id");
                const ageVal = calcAge(s(patient, "date_of_birth"));
                return (
                  <li key={visitId || `${s(patient, "id")}-${s(visit, "created_at")}`}>
                    <RecordRow
                      main={
                        <div className="flex min-w-0 items-center gap-3">
                          <InitialAvatar name={s(patient, "full_name")} />
                          <div className="min-w-0">
                            <p className="truncate font-semibold">
                              {s(patient, "full_name") || "—"}
                            </p>
                            <p className="truncate text-xs text-muted-foreground">
                              <span dir="ltr">{s(patient, "mrn") || "—"}</span> · {deptName(visit)}
                              {ageVal !== null ? ` · ${ageVal} yrs` : ""}
                            </p>
                            <div className="mt-1.5">
                              <StatusBadge status={s(visit, "status")} />
                            </div>
                          </div>
                        </div>
                      }
                      trailing={
                        visitId ? (
                          <Link
                            to="/clinic/$visitId"
                            params={{ visitId }}
                            title={openTitle(visit)}
                            className="inline-flex h-11 min-w-16 items-center justify-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                          >
                            {openLabel}
                          </Link>
                        ) : null
                      }
                    />
                  </li>
                );
              })}
            </ul>
            <div className="hidden overflow-x-auto md:block">
              <Table density="compact">
                <TableHeader>
                  <TableRow>
                    <TableHead>{lang === "ar" ? "المريض" : "Patient"}</TableHead>
                    <TableHead>{lang === "ar" ? "العمر / الجنس" : "Age / Gender"}</TableHead>
                    <TableHead>{lang === "ar" ? "القسم" : "Department"}</TableHead>
                    <TableHead>{lang === "ar" ? "الحالة" : "Status"}</TableHead>
                    <TableHead className="text-end">
                      {lang === "ar" ? "الإجراء" : "Action"}
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((visit) => {
                    const patient = rel(visit, "patients");
                    const patientId = s(patient, "id");
                    const visitId = s(visit, "id");
                    const ageVal = calcAge(s(patient, "date_of_birth"));
                    const ageStr = ageVal !== null ? `${ageVal} yrs` : "—";
                    return (
                      <TableRow key={visitId || `${patientId}-${s(visit, "created_at")}`}>
                        <TableCell className="whitespace-nowrap font-medium">
                          {s(patient, "full_name") || "—"}
                          {s(patient, "mrn") ? (
                            <span className="ms-2 text-xs text-muted-foreground" dir="ltr">
                              {s(patient, "mrn")}
                            </span>
                          ) : null}
                        </TableCell>
                        <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                          {ageStr}
                          {s(patient, "gender") ? ` (${s(patient, "gender")})` : ""}
                        </TableCell>
                        <TableCell className="whitespace-nowrap">{deptName(visit)}</TableCell>
                        <TableCell>
                          <StatusBadge status={s(visit, "status")} />
                        </TableCell>
                        <TableCell className="whitespace-nowrap text-end">
                          {visitId ? (
                            <Link
                              to="/clinic/$visitId"
                              params={{ visitId }}
                              className="inline-flex h-8 items-center justify-center gap-2 whitespace-nowrap rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground shadow transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                              title={openTitle(visit)}
                            >
                              {openLabel}
                            </Link>
                          ) : (
                            <Button
                              type="button"
                              size="sm"
                              disabled
                              title={
                                lang === "ar" ? "معرّف الزيارة غير موجود" : "Visit ID is missing"
                              }
                            >
                              {openLabel}
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </>
        )}
      </DataPanel>
    </div>
  );
}
