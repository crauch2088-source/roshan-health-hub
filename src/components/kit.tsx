import {
  Loader2,
  AlertTriangle,
  Inbox,
  Printer,
  FileDown,
  ShieldOff,
  ChevronLeft,
  ChevronRight,
  Search,
  X,
} from "lucide-react";
import { cloneElement, isValidElement, useId, type ReactElement, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { csvExport, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/** Stable left-to-right rendering for identifiers, codes and numeric tokens in either UI language. */
export function LtrText({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <span dir="ltr" className={cn("inline-block font-mono tabular-nums", className)}>
      {children}
    </span>
  );
}

export function PageHeader({
  title,
  subtitle,
  eyebrow,
  children,
}: {
  title: string;
  subtitle?: string;
  /** Small module label above the title (e.g. "Clinical"). */
  eyebrow?: string;
  children?: ReactNode;
}) {
  return (
    <header className="no-print mb-5 grid grid-cols-1 items-end gap-3 border-b border-border pb-4 sm:mb-6 sm:grid-cols-[minmax(0,1fr)_auto]">
      <div className="min-w-0 space-y-1">
        {eyebrow ? (
          <p className="text-xs font-bold text-primary rtl:tracking-normal sm:tracking-wide">
            {eyebrow}
          </p>
        ) : null}
        <h1 className="truncate text-xl font-extrabold tracking-tight text-foreground rtl:tracking-normal sm:text-2xl">
          {title}
        </h1>
        {subtitle ? <p className="max-w-2xl text-sm text-muted-foreground">{subtitle}</p> : null}
      </div>
      {children ? (
        <div className="flex w-full flex-wrap items-center gap-2 sm:w-auto sm:justify-end [&>*]:max-w-full">
          {children}
        </div>
      ) : null}
    </header>
  );
}

export function Loading() {
  const { t } = useLang();
  return (
    <div
      className="flex min-h-24 items-center justify-center gap-2 p-6 text-sm text-muted-foreground"
      role="status"
      aria-live="polite"
    >
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

export function ErrorBox({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const { t } = useLang();
  if (!error) return null;
  const message = error instanceof Error ? error.message : String(error);
  return (
    <div
      role="alert"
      className="mb-4 flex items-start gap-2.5 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive"
    >
      <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
      <span className="min-w-0 flex-1 break-words">{message}</span>
      {onRetry ? (
        <Button type="button" variant="outline" size="sm" className="shrink-0" onClick={onRetry}>
          {t("retry")}
        </Button>
      ) : null}
    </div>
  );
}

/** Empty result of an active search or filter: offers to clear it. */
export function NoResults({ onClear }: { onClear?: () => void }) {
  const { t } = useLang();
  return (
    <Empty
      icon={<Search className="size-5" aria-hidden />}
      title={t("no_results")}
      action={
        onClear ? (
          <Button type="button" variant="outline" size="sm" onClick={onClear}>
            {t("clear")}
          </Button>
        ) : undefined
      }
    />
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
      className="flex flex-col items-center gap-3 px-5 py-10 text-center sm:py-12"
      role="status"
      aria-live="polite"
    >
      <div className="flex size-11 items-center justify-center rounded-lg bg-muted/80 text-muted-foreground">
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
        <p className="max-w-md text-sm text-muted-foreground">{message ?? t("no_permission")}</p>
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
    <div className="space-y-5 p-1" role="status" aria-busy="true">
      <div className="space-y-2">
        <div className="h-7 w-48 max-w-full animate-pulse rounded-md bg-muted/70" />
        <div className="h-4 w-72 max-w-full animate-pulse rounded-md bg-muted/50" />
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-20 animate-pulse rounded-lg bg-muted/60" />
        ))}
      </div>
      <LoadingRows count={rows} />
    </div>
  );
}

const metricTones: Record<string, string> = {
  default: "text-foreground",
  primary: "text-primary",
  success: "text-success",
  warning: "text-warning",
  destructive: "text-destructive",
};

type MetricProps = {
  label: string;
  value: ReactNode;
  hint?: string;
  tone?: "default" | "primary" | "success" | "warning" | "destructive";
  icon?: ReactNode;
};

/** One figure inside a MetricStrip: hairline-separated, no card chrome of its own. */
export function Metric({ label, value, hint, tone = "default", icon }: MetricProps) {
  return (
    <div className="flex min-w-0 flex-col gap-1 border-s border-t border-border p-3.5 max-sm:[&:nth-child(odd):last-child]:col-span-2 sm:p-4">
      <div className="flex items-center justify-between gap-2 text-muted-foreground">
        <p className="truncate text-xs font-medium">{label}</p>
        {icon ? <span className="shrink-0 [&_svg]:size-4">{icon}</span> : null}
      </div>
      <p
        className={cn(
          "truncate text-xl font-extrabold tabular-nums leading-tight sm:text-2xl",
          metricTones[tone],
        )}
      >
        {value}
      </p>
      {hint ? <p className="truncate text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

/**
 * Summary figures as one joined surface instead of a grid of separate cards.
 * Internal dividers come from each Metric's own start/top border; the outer
 * edge is clipped, so any number of metrics wraps cleanly at every width.
 */
export function MetricStrip({
  children,
  cols = "sm:grid-cols-3 xl:grid-cols-4",
  label,
}: {
  children: ReactNode;
  cols?: string;
  label?: string;
}) {
  return (
    <div
      role={label ? "group" : undefined}
      aria-label={label}
      className="overflow-hidden rounded-xl border border-border bg-card"
    >
      <div className={cn("-ms-px -mt-px grid grid-cols-2", cols)}>{children}</div>
    </div>
  );
}

/** Standalone metric (kept for pages that place a single figure). */
export function StatCard(props: MetricProps) {
  return (
    <div className="overflow-hidden rounded-xl border border-border bg-card">
      <div className="-ms-px -mt-px">
        <Metric {...props} />
      </div>
    </div>
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
  const uid = useId();
  const labelId = `${uid}-label`;
  const hintId = `${uid}-hint`;

  // Plain text inputs and textareas get a real label association (click-to-focus,
  // accessible name) and their hint as a description. Composite controls such as
  // Select keep working as before; the labelled group below still names them.
  type ControlProps = { id?: string; "aria-describedby"?: string };
  const control =
    isValidElement(children) && (children.type === Input || children.type === Textarea)
      ? (children as ReactElement<ControlProps>)
      : null;
  const controlId = control ? (control.props.id ?? `${uid}-control`) : null;
  const rendered =
    control && controlId
      ? cloneElement(control, {
          id: controlId,
          ...(hint && !control.props["aria-describedby"] ? { "aria-describedby": hintId } : {}),
        })
      : children;

  return (
    <div className={cn("space-y-1.5", className)} role="group" aria-labelledby={labelId}>
      <Label
        id={labelId}
        {...(controlId ? { htmlFor: controlId } : {})}
        className="text-xs font-semibold text-foreground/80"
      >
        {label}
      </Label>
      {rendered}
      {hint ? (
        <p id={hintId} className="text-xs text-muted-foreground">
          {hint}
        </p>
      ) : null}
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
    <Badge
      variant="outline"
      className={cn(
        "gap-1.5 rounded-full px-2.5 font-medium transition-colors",
        statusTones[key] ?? "",
      )}
    >
      <span aria-hidden className="size-1.5 shrink-0 rounded-full bg-current" />
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
    <div className="no-print grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 border-t border-border/70 bg-muted/20 p-3 text-sm text-muted-foreground">
      <span>
        {count != null
          ? `${t("page")} ${page} ${t("of")} ${pageCount ?? 1} · ${count} ${t("records")}`
          : `${t("page")} ${page}`}
      </span>
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          disabled={!hasPrev || isFetching}
          onClick={onPrev}
          aria-label={t("previous")}
        >
          <ChevronLeft className="size-4 rtl:rotate-180" />{" "}
          <span className="hidden sm:inline">{t("previous")}</span>
        </Button>
        <Button
          variant="outline"
          size="sm"
          disabled={!hasNext || isFetching}
          onClick={onNext}
          aria-label={t("next")}
        >
          <span className="hidden sm:inline">{t("next")}</span>{" "}
          <ChevronRight className="size-4 rtl:rotate-180" />
        </Button>
      </div>
    </div>
  );
}

export function SectionTitle({ children }: { children: ReactNode }) {
  return (
    <h2 className="mb-3 mt-1 flex items-center gap-3 text-[13px] font-bold text-foreground">
      <span className="shrink-0">{children}</span>
      <span aria-hidden className="h-px flex-1 bg-border" />
    </h2>
  );
}

/**
 * The one surface for lists and tables: hairline border, no shadow, optional
 * title row with an icon, a count and a trailing action. Body is flush, so
 * tables and divided lists run edge to edge.
 */
export function DataPanel({
  title,
  icon,
  count,
  action,
  children,
  className,
}: {
  title?: string;
  icon?: ReactNode;
  count?: number | string | null;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn("min-w-0 overflow-hidden rounded-xl border border-border bg-card", className)}
    >
      {title ? (
        <header className="flex min-h-12 items-center justify-between gap-3 border-b border-border px-4 py-2.5">
          <h2 className="flex min-w-0 items-center gap-2 text-sm font-bold text-foreground">
            {icon ? <span className="shrink-0 [&_svg]:size-4">{icon}</span> : null}
            <span className="truncate">{title}</span>
            {count != null ? (
              <span className="shrink-0 rounded-full bg-muted px-2 py-0.5 text-[11px] font-semibold tabular-nums text-muted-foreground">
                {count}
              </span>
            ) : null}
          </h2>
          {action ? <div className="shrink-0">{action}</div> : null}
        </header>
      ) : null}
      {children}
    </section>
  );
}

/** Row of search and filter controls above a list. */
export function Toolbar({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("no-print flex flex-wrap items-center gap-2 sm:gap-3", className)}>
      {children}
    </div>
  );
}

/** Search box shared by list pages: leading icon, clear button, 44px touch height. */
export function SearchField({
  value,
  onChange,
  placeholder,
  label,
  className,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  className?: string;
}) {
  const { t } = useLang();
  return (
    <div className={cn("relative min-w-0 flex-1 basis-60", className)}>
      <Search
        aria-hidden
        className="pointer-events-none absolute start-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
      />
      <Input
        type="search"
        placeholder={placeholder ?? t("search")}
        aria-label={label ?? placeholder ?? t("search")}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-11 rounded-lg border-border bg-card ps-10 pe-10 text-sm [&::-webkit-search-cancel-button]:appearance-none"
      />
      {value ? (
        <button
          type="button"
          onClick={() => onChange("")}
          aria-label={t("clear")}
          className="absolute end-1 top-1/2 flex size-9 -translate-y-1/2 items-center justify-center rounded-md text-muted-foreground outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
        >
          <X className="size-4" aria-hidden />
        </button>
      ) : null}
    </div>
  );
}

/** Round initial (first letter of a name) used as the identity mark in lists and headers. */
export function InitialAvatar({ name, size = "md" }: { name: string; size?: "md" | "lg" }) {
  const initial = (name || "").trim().charAt(0).toUpperCase() || "•";
  return (
    <span
      aria-hidden
      className={cn(
        "flex shrink-0 items-center justify-center rounded-full bg-primary/10 font-bold text-primary",
        size === "lg" ? "size-14 text-xl" : "size-10 text-base",
      )}
    >
      {initial}
    </span>
  );
}

/** Phone list row: identity and context on the start side, one action on the end side. */
export function RecordRow({
  main,
  trailing,
  className,
}: {
  main: ReactNode;
  trailing?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 py-3.5",
        className,
      )}
    >
      <div className="min-w-0">{main}</div>
      {trailing ? <div className="shrink-0">{trailing}</div> : null}
    </div>
  );
}

/**
 * Identity strip for a record (patient, visit, order): who it is, the facts a
 * clinician scans first, and the actions that belong to the whole record.
 */
export function DetailHeader({
  name,
  facts,
  actions,
  eyebrow,
}: {
  name: string;
  facts: Array<{ label: string; value: ReactNode }>;
  actions?: ReactNode;
  eyebrow?: string;
}) {
  return (
    <header className="no-print mb-5 rounded-xl border border-border bg-card p-4 sm:p-5">
      <div className="flex flex-wrap items-start gap-4">
        <InitialAvatar name={name} size="lg" />
        <div className="min-w-0 flex-1 basis-56 space-y-1">
          {eyebrow ? <p className="text-xs font-bold text-primary">{eyebrow}</p> : null}
          <h1 className="break-words text-xl font-extrabold leading-tight tracking-tight rtl:tracking-normal sm:text-2xl">
            {name}
          </h1>
        </div>
        {actions ? (
          <div className="flex w-full flex-wrap items-center gap-2 sm:w-auto">{actions}</div>
        ) : null}
      </div>
      {facts.length > 0 ? (
        <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 border-t border-border pt-4 sm:grid-cols-[repeat(auto-fit,minmax(8rem,1fr))]">
          {facts.map((f) => (
            <div key={f.label} className="min-w-0">
              <dt className="text-xs font-medium text-muted-foreground">{f.label}</dt>
              <dd className="mt-0.5 break-words text-sm font-semibold text-foreground">
                {f.value}
              </dd>
            </div>
          ))}
        </dl>
      ) : null}
    </header>
  );
}
