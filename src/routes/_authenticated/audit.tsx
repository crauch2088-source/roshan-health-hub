import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Empty, ErrorBox, ExportButtons, Loading, PageHeader, Pager } from "@/components/kit";
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
import { rel, s, usePagedRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDateTime } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/audit")({
  head: () => ({
    meta: [
      { title: "Audit Log — ROSHAN Medical Center" },
      { name: "description", content: "Traceable record of system actions by user, table and time." },
      { property: "og:title", content: "Audit Log — ROSHAN Medical Center" },
      { property: "og:description", content: "Traceable record of system actions by user, table and time." },
    ],
  }),
  component: AuditPage,
});

const PAGE_SIZE = 50;

/** Keeps free-text search safe to embed in a PostgREST `.or()` filter string. */
function sanitizeSearch(term: string): string {
  return term.replace(/[,()%]/g, "").trim();
}

function AuditPage() {
  const { t } = useLang();
  const [page, setPage] = useState(1);
  const [q, setQ] = useState("");

  const list = usePagedRows<Row[]>(
    ["audit", q],
    ({ from, to }) => {
      let query = supabase
        .from("audit_logs")
        .select("id, action, table_name, created_at, users(full_name)", { count: "exact" });

      // Searches the audit log's own columns (action, table_name) at the
      // database level. Matching by the related user's name would require
      // an inner join filter that PostgREST can't combine cleanly with
      // this OR search, so that stays a visual column only, not a filter.
      const term = sanitizeSearch(q);
      if (term) {
        query = query.or(`action.ilike.%${term}%,table_name.ilike.%${term}%`);
      }

      return query.order("created_at", { ascending: false }).range(from, to);
    },
    page,
    PAGE_SIZE,
  );

  const rows = list.rows;

  // Export/print always reflects only the current page — this matches
  // what pagination means everywhere else in the app (billing, patients).
  return (
    <div>
      <PageHeader title={t("audit_log")} subtitle={t("recent_activity")}>
        <Input
          placeholder={t("search")}
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(1);
          }}
          className="w-56"
        />
        <ExportButtons rows={rows} filename="roshan-audit" />
      </PageHeader>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {list.isLoading ? (
            <Loading />
          ) : rows.length === 0 ? (
            <Empty />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("user")}</TableHead>
                  <TableHead>{t("action")}</TableHead>
                  <TableHead>{t("table")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={s(r, "id")}>
                    <TableCell dir="ltr">{formatDateTime(s(r, "created_at"))}</TableCell>
                    <TableCell>{s(rel(r, "users"), "full_name") || "—"}</TableCell>
                    <TableCell>{s(r, "action")}</TableCell>
                    <TableCell dir="ltr">{s(r, "table_name")}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
          <Pager
            page={list.page}
            pageCount={list.pageCount}
            count={list.count}
            pageSize={PAGE_SIZE}
            hasPrev={list.hasPrev}
            hasNext={list.hasNext}
            isFetching={list.isFetching}
            onPrev={() => setPage((p) => Math.max(1, p - 1))}
            onNext={() => setPage((p) => p + 1)}
          />
        </CardContent>
      </Card>
    </div>
  );
}