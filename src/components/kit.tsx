import { Loader2, AlertTriangle, Inbox, Printer, FileDown, ShieldOff } from "lucide-react";
import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/lib/auth";
import { csvExport, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { cn } from "@/lib/utils";

export function PageHeader({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children?: ReactNode;
}) {
  return (
    <div className="no-print mb-6 flex flex-wrap items-end justify-between gap-3 border-b border-border/60 pb-4">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">{title}</h1>
        {subtitle ? <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p> : null}
      </div>
      <div className="flex flex-wrap items-center gap-2">{children}</div>
    </div>
  );
}

export function Loading() {
  const { t } = useLang();
  return (
    <div className="flex items-center gap-2 p-8 text-sm text-muted-foreground" role="status">
      <Loader2 className="size-4 animate-spin" /> {t("loading")}
    </div>
  );
}

/** Skeleton rows for table/list areas — used where a spinner alone reads as "stuck" on slower connections. */
export function LoadingRows({ count = 4 }: { count?: number }) {
  return (
    <div className="space-y-2 p-4" role="status">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="h-10 w-full animate-pulse rounded-md bg-muted/60" />
      ))}
    </div>
  );
}

export function ErrorBox({ error }: { error: unknown }) {
  if (!error) return null;
  const message = error instanceof Error ? error.message : String(error);
  return (
    <div className="mb-4 flex items-start gap-2 rounded-lg border border-destructive/40 bg-destructive/15 p-3 text-sm text-destructive">
      <AlertTriangle className="mt-0.5 size-4 shrink-0" />
      <span className="break-words">{message}</span>
    </div>
  );
}

export function Empty({
  label,
  title,
  description,
  action,
  icon,
}: {
  label?: string;
  title?: string;
  description?: string;
  action?: ReactNode;
  icon?: ReactNode;
}) {
  const { t } = useLang();
  const heading = title ?? label ?? t("no_data");
  return (
    <div
      className="flex flex-col items-center gap-3 px-6 py-12 text-center"
      role="status"
      aria-live="polite"
    >
      <div className="flex size-12 items-center justify-center rounded-full bg-muted/80 text-muted-foreground">
        {icon ?? <Inbox className="size-5" aria-hidden />}
      </div>
      <div className="space-y-1">
        <p className="text-sm font-medium text-foreground">{heading}</p>
        {description ? (
          <p className="max-w-sm text-xs text-muted-foreground">{description}</p>
        ) : null}
      </div>
      {action ? <div className="pt-1">{action}</div> : null}
    </div>
  );
}

/** Full-page access denied state used by PermissionGate. */
export function Forbidden({ message }: { message?: string }) {
  const { t, lang } = useLang();
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center gap-4 px-4 text-center">
      <div className="flex size-14 items-center justify-center rounded-full bg-destructive/10 text-destructive">
        <ShieldOff className="size-6" aria-hidden />
      </div>
      <div className="space-y-1.5">
        <h2 className="text-lg font-semibold tracking-tight">
          {lang === "ar" ? "غير مصرح" : "Access denied"}
        </h2>
        <p className="max-w-md text-sm text-muted-foreground">
          {message ?? t("no_permission")}
        </p>
      </div>
      <Button asChild variant="outline" size="sm">
        <Link to="/dashboard">{lang === "ar" ? "العودة للرئيسية" : "Back to dashboard"}</Link>
      </Button>
    </div>
  );
}

/**
 * Gate that renders children only when the user holds the required permission.
 * Fails closed while permissions are loading or when the user lacks access.
 */
export function PermissionGate({
  perm,
  children,
  fallback,
}: {
  perm: string | string[];
  children: ReactNode;
  fallback?: ReactNode;
}) {
  const { can, permissionsReady, loading } = useAuth();

  if (loading || !permissionsReady) {
    return <Loading />;
  }

  const required = Array.isArray(perm) ? perm : [perm];
  const allowed = required.some((p) => can(p));

  if (!allowed) {
    return <>{fallback ?? <Forbidden />}</>;
  }

  return <>{children}</>;
}

/** Lightweight page-level skeleton for first paint. */
export function PageSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div className="space-y-6 p-1" role="status" aria-busy="true">
      <div className="space-y-2">
        <div className="h-7 w-48 animate-pulse rounded-md bg-muted/70" />
        <div className="h-4 w-72 animate-pulse rounded-md bg-muted/50" />
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-20 animate-pulse rounded-xl bg-muted/60" />
        ))}
      </div>
      <LoadingRows count={rows} />
    </div>
  );
}

export function StatCard({
  label,
  value,
  hint,
  tone = "default",
  icon,
}: {
  label: string;
  value: ReactNode;
  hint?: string;
  tone?: "default" | "primary" | "success" | "warning" | "destructive";
  icon?: ReactNode;
}) {
  const tones: Record<string, string> = {
    default: "text-foreground",
    primary: "text-primary",
    success: "text-success",
    warning: "text-warning",
    destructive: "text-destructive",
  };
  const iconTones: Record<string, string> = {
    default: "bg-accent text-foreground",
    primary: "bg-primary/10 text-primary",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning",
    destructive: "bg-destructive/10 text-destructive",
  };
  return (
    <Card className="overflow-hidden border-border/70 shadow-sm transition-shadow duration-200 hover:shadow-md">
      <CardContent className="flex items-center justify-between gap-3 p-4">
        <div className="min-w-0">
          <p className="truncate text-xs font-medium text-muted-foreground">{label}</p>
          <p className={cn("mt-1 text-2xl font-bold tabular-nums leading-tight", tones[tone])}>{value}</p>
          {hint ? <p className="mt-0.5 text-xs text-muted-foreground">{hint}</p> : null}
        </div>
        {icon ? <div className={cn("shrink-0 rounded-xl p-2.5", iconTones[tone])}>{icon}</div> : null}
      </CardContent>
    </Card>
  );
}

export function Field({
  label,
  children,
  hint,
  className,
}: {
  label: string;
  children: ReactNode;
  hint?: string;
  className?: string;
}) {
  return (
    <div className={cn("space-y-1.5", className)}>
      <Label className="text-xs font-medium text-muted-foreground">{label}</Label>
      {children}
      {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

// Status color scale used by every StatusBadge across the app. Kept as one
// map so a new workflow status (e.g. Phase 5's insurance claim states)
// gets a color by being added here once, not per-screen.
const statusTones: Record<string, string> = {
  // generic clinical/queue
  waiting: "bg-warning/15 text-warning border-warning/30",
  pending: "bg-warning/15 text-warning border-warning/30",
  in_progress: "bg-primary/15 text-primary border-primary/30",
  collected: "bg-primary/15 text-primary border-primary/30",
  completed: "bg-success/15 text-success border-success/30",
  verified: "bg-success/15 text-success border-success/30",
  dispensed: "bg-success/15 text-success border-success/30",
  scheduled: "bg-primary/15 text-primary border-primary/30",
  // billing / finance
  paid: "bg-success/15 text-success border-success/30",
  partial: "bg-warning/15 text-warning border-warning/30",
  unpaid: "bg-destructive/15 text-destructive border-destructive/30",
  open: "bg-warning/15 text-warning border-warning/30",
  reversed: "bg-muted text-muted-foreground",
  // generic negative/neutral
  cancelled: "bg-muted text-muted-foreground",
  no_show: "bg-muted text-muted-foreground",
  missed: "bg-destructive/15 text-destructive border-destructive/30",
  inactive: "bg-muted text-muted-foreground",
  active: "bg-success/15 text-success border-success/30",
  suspended: "bg-warning/15 text-warning border-warning/30",
  expired: "bg-destructive/15 text-destructive border-destructive/30",
  // insurance claim workflow (Phase 5)
  draft: "bg-muted text-muted-foreground",
  submitted: "bg-primary/15 text-primary border-primary/30",
  under_review: "bg-primary/15 text-primary border-primary/30",
  approved: "bg-success/15 text-success border-success/30",
  partially_approved: "bg-warning/15 text-warning border-warning/30",
  rejected: "bg-destructive/15 text-destructive border-destructive/30",
};

export function StatusBadge({ status }: { status: string }) {
  const { t } = useLang();
  const key = (status || "").toLowerCase();
  return (
    <Badge variant="outline" className={cn("font-medium transition-colors", statusTones[key] ?? "")}>
      {t(key) === key ? status || "—" : t(key)}
    </Badge>
  );
}

export function ExportButtons({ rows, filename }: { rows: Row[]; filename: string }) {
  const { t } = useLang();
  return (
    <div className="no-print flex gap-2">
      <Button variant="outline" size="sm" onClick={() => csvExport(rows, filename)}>
        <FileDown className="size-4" /> {t("export_excel")}
      </Button>
      <Button variant="outline" size="sm" onClick={() => window.print()}>
        <Printer className="size-4" /> {t("print")}
      </Button>
    </div>
  );
}

export function PrintButton() {
  const { t } = useLang();
  return (
    <Button variant="outline" size="sm" className="no-print" onClick={() => window.print()}>
      <Printer className="size-4" /> {t("print")}
    </Button>
  );
}

/** Prev/next pagination bar for tables driven by usePagedRows(). */
export function Pager({
  page,
  pageCount,
  count,
  pageSize,
  hasPrev,
  hasNext,
  onPrev,
  onNext,
  isFetching,
}: {
  page: number;
  pageCount: number | null;
  count: number | null;
  pageSize: number;
  hasPrev: boolean;
  hasNext: boolean;
  onPrev: () => void;
  onNext: () => void;
  isFetching?: boolean;
}) {
  const { t } = useLang();
  return (
    <div className="no-print flex flex-wrap items-center justify-between gap-3 border-t p-3 text-sm text-muted-foreground">
      <span>
        {count != null
          ? `${t("page")} ${page} ${t("of")} ${pageCount ?? 1} · ${count} ${t("records")}`
          : `${t("page")} ${page}`}
      </span>
      <div className="flex items-center gap-2">
        <Button variant="outline" size="sm" disabled={!hasPrev || isFetching} onClick={onPrev}>
          {t("previous")}
        </Button>
        <Button variant="outline" size="sm" disabled={!hasNext || isFetching} onClick={onNext}>
          {t("next")}
        </Button>
      </div>
    </div>
  );
}

export function SectionTitle({ children }: { children: ReactNode }) {
  return <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-primary">{children}</h2>;
}
