import { Loader2, AlertTriangle, Inbox, Printer, FileDown } from "lucide-react";
import type { ReactNode } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
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
    <div className="no-print mb-6 flex flex-wrap items-end justify-between gap-3">
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
    <div className="flex items-center gap-2 p-8 text-sm text-muted-foreground">
      <Loader2 className="size-4 animate-spin" /> {t("loading")}
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

export function Empty({ label }: { label?: string }) {
  const { t } = useLang();
  return (
    <div className="flex flex-col items-center gap-2 p-10 text-center text-sm text-muted-foreground">
      <Inbox className="size-6" />
      {label ?? t("no_data")}
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
  return (
    <Card className="overflow-hidden">
      <CardContent className="flex items-center justify-between gap-3 p-4">
        <div className="min-w-0">
          <p className="truncate text-xs font-medium text-muted-foreground">{label}</p>
          <p className={cn("mt-1 text-2xl font-bold tabular-nums", tones[tone])}>{value}</p>
          {hint ? <p className="mt-0.5 text-xs text-muted-foreground">{hint}</p> : null}
        </div>
        {icon ? <div className="shrink-0 rounded-lg bg-accent p-2 text-primary">{icon}</div> : null}
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

const statusTones: Record<string, string> = {
  waiting: "bg-warning/15 text-warning border-warning/30",
  pending: "bg-warning/15 text-warning border-warning/30",
  in_progress: "bg-primary/15 text-primary border-primary/30",
  collected: "bg-primary/15 text-primary border-primary/30",
  completed: "bg-success/15 text-success border-success/30",
  verified: "bg-success/15 text-success border-success/30",
  dispensed: "bg-success/15 text-success border-success/30",
  paid: "bg-success/15 text-success border-success/30",
  partial: "bg-warning/15 text-warning border-warning/30",
  unpaid: "bg-destructive/15 text-destructive border-destructive/30",
  open: "bg-warning/15 text-warning border-warning/30",
  cancelled: "bg-muted text-muted-foreground",
  no_show: "bg-muted text-muted-foreground",
  missed: "bg-destructive/15 text-destructive border-destructive/30",
};

export function StatusBadge({ status }: { status: string }) {
  const { t } = useLang();
  const key = (status || "").toLowerCase();
  return (
    <Badge variant="outline" className={cn("font-medium", statusTones[key] ?? "")}>
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

export function SectionTitle({ children }: { children: ReactNode }) {
  return <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-primary">{children}</h2>;
}
