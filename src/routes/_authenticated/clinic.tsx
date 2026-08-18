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
      { title: "Clinic — ROSHAN Medical Center" },
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

  const [date, setDate] = useState(todayISO());
  const [filterMyPatients, setFilterMyPatients] = useState(false);

  const visits = useRows(
    ["clinic-visits", date, filterMyPatients],
    () =>
      supabase
        .from("visits")
        .select(
          "id, visit_number, status, created_at, patients(id, full_name, mrn, dob, gender), departments(name, name_ar), users(full_name)",
        )
        .gte("created_at", `${date}T00:00:00`)
        .lte("created_at", `${date}T23:59:59`)
        .is("deleted_at", null)
        .order("created_at", { ascending: true }),
  );

  const rows = (visits.data ?? []) as Row[];

  if (visits.isLoading) {
    return <Loading />;
  }

  return (
    <div>
      <PageHeader
        title={lang === "ar" ? "العيادة" : "Clinic"}
        subtitle={formatDate(date)}
      >
        <div className="flex items-center gap-2 flex-wrap">
          <Button
            variant={filterMyPatients ? "default" : "outline"}
            size="sm"
            type="button"
            onClick={() => setFilterMyPatients(!filterMyPatients)}
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
                    {lang === "ar" ? "العمر / الجنس" : "Age / Gender"}
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

                  const dob = s(patient, "dob");
                  const ageVal = calcAge(dob);

                  const ageStr =
                    ageVal !== null ? `${ageVal} yrs` : "—";

                  return (
                    <TableRow key={visitId}>
                      <TableCell className="font-medium whitespace-nowrap">
                        {s(patient, "full_name") || "—"}

                        <span
                          className="ms-2 text-xs text-muted-foreground"
                          dir="ltr"
                        >
                          {s(patient, "mrn")}
                        </span>
                      </TableCell>

                      <TableCell className="whitespace-nowrap text-muted-foreground text-xs">
                        {ageStr}{" "}
                        {s(patient, "gender")
                          ? `(${s(patient, "gender")})`
                          : ""}
                      </TableCell>

                      <TableCell className="whitespace-nowrap">
                        {lang === "ar"
                          ? s(department, "name_ar") ||
                            s(department, "name") ||
                            "—"
                          : s(department, "name") || "—"}
                      </TableCell>

                      <TableCell>
                        <StatusBadge status={s(visit, "status")} />
                      </TableCell>

                      <TableCell className="text-end whitespace-nowrap">
                        {visitId ? (
                          <Button
                            asChild
                            type="button"
                            size="sm"
                          >
                            <Link
                              to="/clinic/$visitId"
                              params={{ visitId }}
                            >
                              {lang === "ar" ? "فتح" : "Open"}
                            </Link>
                          </Button>
                        ) : (
                          <Button
                            type="button"
                            size="sm"
                            disabled
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