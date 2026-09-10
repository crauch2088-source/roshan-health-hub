import { useNavigate } from "@tanstack/react-router";
import { LogOut, Languages, Search } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";

import { BreadcrumbNav } from "@/components/breadcrumb-nav";
import { CommandPaletteProvider, useCommandPalette } from "@/components/command-palette-provider";
import { MobileBottomNav } from "@/components/mobile-bottom-nav";
import { NavRail } from "@/components/nav-rail";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { NavPreferencesProvider } from "@/hooks/use-nav-preferences";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";

const RAIL_COLLAPSED_KEY = "roshan:nav:rail-collapsed";

function Brand({ collapsed }: { collapsed: boolean }) {
  const { t } = useLang();
  return (
    <div className="flex items-center gap-2.5 border-b border-sidebar-border px-4 py-3.5">
      <img src="/roshan-logo.png" alt={t("app_name")} className="size-9 shrink-0 rounded-md bg-white object-contain p-0.5" />
      {!collapsed ? (
        <div className="min-w-0">
          <p className="truncate text-sm font-bold text-sidebar-foreground">{t("app_name")}</p>
          <p className="truncate text-[11px] text-sidebar-foreground/60">ERP / EMR</p>
        </div>
      ) : null}
    </div>
  );
}

function SearchTrigger() {
  const { t } = useLang();
  const { setOpen } = useCommandPalette();
  return (
    <Button variant="outline" size="sm" className="hidden gap-2 text-muted-foreground sm:flex" onClick={() => setOpen(true)}>
      <Search className="size-4" />
      <span className="hidden md:inline">{t("search_everywhere")}</span>
      <kbd className="ms-1 hidden rounded border bg-muted px-1.5 py-0.5 font-mono text-[10px] md:inline">Ctrl K</kbd>
    </Button>
  );
}

function Shell({ children }: { children: ReactNode }) {
  const { toggle, lang, t } = useLang();
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = useState(false);

  const direction = lang === "ar" ? "rtl" : "ltr";

  useEffect(() => {
    try {
      setCollapsed(window.localStorage.getItem(RAIL_COLLAPSED_KEY) === "1");
    } catch {
      // ignore — default expanded
    }
  }, []);

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(RAIL_COLLAPSED_KEY, next ? "1" : "0");
      } catch {
        // non-fatal
      }
      return next;
    });
  }

  async function handleSignOut() {
    await signOut();
    void navigate({ to: "/auth", replace: true });
  }

  return (
    <div className="flex min-h-screen bg-background" dir={direction}>
      <aside
        className={cnRail(collapsed)}
      >
        <Brand collapsed={collapsed} />
        <div className="min-h-0 flex-1">
          <NavRail collapsed={collapsed} onToggleCollapsed={toggleCollapsed} />
        </div>
        <div className={collapsed ? "border-t border-sidebar-border p-2" : "border-t border-sidebar-border p-3"}>
          {!collapsed ? (
            <>
              <p className="truncate text-sm font-medium text-sidebar-foreground">{user?.full_name ?? "—"}</p>
              <p className="truncate text-xs text-sidebar-foreground/60">{user?.role_name ?? ""}</p>
            </>
          ) : null}
          <Button
            variant="secondary"
            size="sm"
            className={collapsed ? "mt-0 w-full justify-center px-0" : "mt-2 w-full"}
            onClick={handleSignOut}
          >
            <LogOut className="size-4" /> {!collapsed ? t("sign_out") : null}
          </Button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col pb-16 lg:pb-0">
        <header className="no-print sticky top-0 z-20 flex items-center gap-3 border-b bg-card/90 px-4 py-2.5 backdrop-blur">
          <img src="/roshan-logo.png" alt="" className="size-8 object-contain lg:hidden" />
          <BreadcrumbNav />
          <div className="flex-1" />
          <SearchTrigger />
          <Button variant="outline" size="sm" onClick={toggle}>
            <Languages className="size-4" /> {lang === "ar" ? "English" : "العربية"}
          </Button>
          <Separator orientation="vertical" className="mx-1 hidden h-6 sm:block" />
          <Button variant="ghost" size="sm" className="lg:hidden" onClick={handleSignOut}>
            <LogOut className="size-4" />
          </Button>
        </header>

        <main className="min-w-0 flex-1 p-4 md:p-6">{children}</main>
      </div>

      <MobileBottomNav />
    </div>
  );
}

function cnRail(collapsed: boolean): string {
  return [
    "no-print sticky top-0 hidden h-screen shrink-0 flex-col bg-sidebar lg:flex transition-[width] duration-200 ease-in-out",
    collapsed ? "w-16" : "w-64",
  ].join(" ");
}

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <NavPreferencesProvider>
      <CommandPaletteProvider>
        <Shell>{children}</Shell>
      </CommandPaletteProvider>
    </NavPreferencesProvider>
  );
}
