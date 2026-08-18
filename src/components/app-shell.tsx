import { Link, useLocation, useNavigate } from "@tanstack/react-router";
import {
  Activity,
  BarChart3,
  Banknote,
  CalendarDays,
  ClipboardList,
  FileText,
  FlaskConical,
  Handshake,
  LayoutDashboard,
  ListOrdered,
  LogOut,
  Menu,
  Pill,
  Receipt,
  ScrollText,
  Settings as SettingsIcon,
  Stethoscope,
  Users,
  UserRound,
  Warehouse,
  Wallet,
  Languages,
} from "lucide-react";
import { useState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { cn } from "@/lib/utils";

type NavItem = { to: string; key: string; icon: ReactNode; perm: string };

const NAV: { group: string; items: NavItem[] }[] = [
  {
    group: "dashboard",
    items: [
      { to: "/dashboard", key: "dashboard", icon: <LayoutDashboard className="size-4" />, perm: "dashboard.read" },
    ],
  },
  {
    group: "patients",
    items: [
      { to: "/patients", key: "patients", icon: <UserRound className="size-4" />, perm: "patients.read" },
      { to: "/visits", key: "visits", icon: <ClipboardList className="size-4" />, perm: "visits.read" },
      { to: "/queue", key: "queue", icon: <ListOrdered className="size-4" />, perm: "queue.read" },
      { to: "/appointments", key: "appointments", icon: <CalendarDays className="size-4" />, perm: "appointments.read" },
    ],
  },
  {
    group: "clinic",
    items: [
      { to: "/clinic", key: "clinic", icon: <Stethoscope className="size-4" />, perm: "emr.read" },
      { to: "/followups", key: "followups", icon: <Activity className="size-4" />, perm: "followups.read" },
      { to: "/certificates", key: "certificates", icon: <FileText className="size-4" />, perm: "certificates.read" },
    ],
  },
  {
    group: "laboratory",
    items: [
      { to: "/lab", key: "laboratory", icon: <FlaskConical className="size-4" />, perm: "lab.read" },
      { to: "/lab-catalog", key: "lab_catalog", icon: <ScrollText className="size-4" />, perm: "lab_admin.read" },
    ],
  },
  {
    group: "pharmacy",
    items: [
      { to: "/pharmacy", key: "pharmacy", icon: <Pill className="size-4" />, perm: "pharmacy.read" },
      { to: "/inventory", key: "inventory", icon: <Warehouse className="size-4" />, perm: "pharmacy.read" },
    ],
  },
  {
    group: "billing",
    items: [
      { to: "/billing", key: "billing", icon: <Receipt className="size-4" />, perm: "billing.read" },
      { to: "/accounting", key: "accounting", icon: <Banknote className="size-4" />, perm: "accounting.read" },
      { to: "/expenses", key: "expenses", icon: <Wallet className="size-4" />, perm: "accounting.read" },
      { to: "/partners", key: "partners", icon: <Handshake className="size-4" />, perm: "partners.read" },
      { to: "/reports", key: "reports", icon: <BarChart3 className="size-4" />, perm: "reports.read" },
    ],
  },
  {
    group: "settings",
    items: [
      { to: "/users", key: "users", icon: <Users className="size-4" />, perm: "users.read" },
      { to: "/settings", key: "settings", icon: <SettingsIcon className="size-4" />, perm: "settings.read" },
      { to: "/audit", key: "audit_log", icon: <ScrollText className="size-4" />, perm: "audit.read" },
    ],
  },
];

function NavLinks({ onNavigate }: { onNavigate?: () => void }) {
  const { t } = useLang();
  const { can, isSuperAdmin } = useAuth();
  const location = useLocation();

  return (
    <nav className="space-y-4 p-3">
      {NAV.map((section) => {
        const items = section.items.filter((i) => isSuperAdmin || can(i.perm));

        if (!items.length) return null;
        return (
          <div key={section.group}>
            <p className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-sidebar-foreground/50">
              {t(section.group)}
            </p>
            <div className="space-y-0.5">
              {items.map((item) => {
                const active =
                  location.pathname === item.to || location.pathname.startsWith(`${item.to}/`);
                return (
                  <Link
                    key={item.to}
                    to={item.to}
                    onClick={onNavigate}
                    className={cn(
                      "flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm font-medium transition-colors",
                      active
                        ? "bg-sidebar-primary text-sidebar-primary-foreground"
                        : "text-sidebar-foreground/85 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                    )}
                  >
                    {item.icon}
                    <span className="truncate">{t(item.key)}</span>
                  </Link>
                );
              })}
            </div>
          </div>
        );
      })}
    </nav>
  );
}

function Brand() {
  const { t } = useLang();
  return (
    <div className="flex items-center gap-2.5 border-b border-sidebar-border px-4 py-3.5">
      <img
        src="/roshan-logo.png"
        alt={t("app_name")}
        className="size-9 rounded-md bg-white object-contain p-0.5"
      />
      <div className="min-w-0">
        <p className="truncate text-sm font-bold text-sidebar-foreground">{t("app_name")}</p>
        <p className="truncate text-[11px] text-sidebar-foreground/60">ERP / EMR</p>
      </div>
    </div>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const { t, toggle, lang } = useLang();
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  async function handleSignOut() {
    await signOut();
    void navigate({ to: "/auth", replace: true });
  }

  return (
    <div className="flex min-h-screen bg-background">
      <aside className="no-print sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-sidebar lg:flex">
        <Brand />
        <ScrollArea className="flex-1">
          <NavLinks />
        </ScrollArea>
        <div className="border-t border-sidebar-border p-3">
          <p className="truncate text-sm font-medium text-sidebar-foreground">
            {user?.full_name ?? "—"}
          </p>
          <p className="truncate text-xs text-sidebar-foreground/60">{user?.role_name ?? ""}</p>
          <Button variant="secondary" size="sm" className="mt-2 w-full" onClick={handleSignOut}>
            <LogOut className="size-4" /> {t("sign_out")}
          </Button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="no-print sticky top-0 z-20 flex items-center gap-2 border-b bg-card/90 px-4 py-2.5 backdrop-blur">
          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="lg:hidden">
                <Menu className="size-5" />
              </Button>
            </SheetTrigger>
            <SheetContent side={lang === "ar" ? "right" : "left"} className="w-72 bg-sidebar p-0">
              <SheetTitle className="sr-only">{t("app_name")}</SheetTitle>
              <Brand />
              <ScrollArea className="h-[calc(100vh-8rem)]">
                <NavLinks onNavigate={() => setOpen(false)} />
              </ScrollArea>
            </SheetContent>
          </Sheet>

          <img src="/roshan-logo.png" alt="" className="size-8 object-contain lg:hidden" />
          <div className="flex-1" />
          <Button variant="outline" size="sm" onClick={toggle}>
            <Languages className="size-4" /> {lang === "ar" ? "English" : "العربية"}
          </Button>
          <Separator orientation="vertical" className="mx-1 h-6" />
          <Button variant="ghost" size="sm" className="lg:hidden" onClick={handleSignOut}>
            <LogOut className="size-4" />
          </Button>
        </header>

        <main className="min-w-0 flex-1 p-4 md:p-6">{children}</main>
      </div>
    </div>
  );
}
