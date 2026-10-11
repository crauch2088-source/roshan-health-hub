import { useNavigate } from "@tanstack/react-router";
import { LogOut, Languages, Search, UserRound } from "lucide-react";
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
import { cn } from "@/lib/utils";

const RAIL_COLLAPSED_KEY = "roshan:nav:rail-collapsed";

function Brand({ collapsed }: { collapsed: boolean }) {
  const { t } = useLang();
  return (
    <div className={cn("flex h-16 items-center gap-2.5 px-3", collapsed && "justify-center px-2")}>
      <img
        src="/roshan-logo.png"
        alt={t("app_name")}
        className="size-9 shrink-0 rounded-md bg-sidebar-accent object-contain p-0.5"
      />
      {!collapsed ? (
        <div className="min-w-0">
          <p className="truncate text-sm font-bold text-sidebar-foreground">ROSHAN</p>
          <p className="truncate text-[11px] text-sidebar-foreground/60">{t("app_name")}</p>
        </div>
      ) : null}
    </div>
  );
}

function SearchTrigger() {
  const { t } = useLang();
  const { setOpen } = useCommandPalette();
  return (
    <Button
      variant="outline"
      size="sm"
      className="hidden min-w-40 justify-between gap-2 border-border/70 bg-background/70 text-muted-foreground shadow-xs sm:flex"
      onClick={() => setOpen(true)}
    >
      <Search className="size-4" />
      <span className="hidden md:inline">{t("search_everywhere")}</span>
      <kbd className="ms-auto hidden rounded border border-border/70 bg-muted/70 px-1.5 py-0.5 font-mono text-[10px] md:inline">
        Ctrl K
      </kbd>
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
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:start-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground"
      >
        {t("skip_to_content")}
      </a>
      <aside className={cnRail(collapsed)} aria-label={t("navigation")}>
        <Brand collapsed={collapsed} />
        <div className="min-h-0 flex-1">
          <NavRail collapsed={collapsed} onToggleCollapsed={toggleCollapsed} />
        </div>

        <div
          className={
            collapsed
              ? "border-t border-sidebar-border/70 p-2"
              : "border-t border-sidebar-border/70 p-3"
          }
        >
          {!collapsed ? (
            <>
              <div className="mb-2 flex min-w-0 items-center gap-2.5">
                <span className="flex size-8 shrink-0 items-center justify-center rounded-md bg-sidebar-accent text-sidebar-foreground">
                  <UserRound className="size-4" />
                </span>
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-sidebar-foreground">
                    {user?.full_name ?? "—"}
                  </p>
                  <p className="truncate text-xs text-sidebar-foreground/60">
                    {user?.role_name ?? ""}
                  </p>
                </div>
              </div>
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

      <div className="flex min-w-0 flex-1 flex-col pb-[calc(4rem+env(safe-area-inset-bottom))] lg:pb-0">
        <header className="no-print sticky top-0 z-20 flex h-14 items-center gap-2 border-b border-border/70 bg-background/90 px-3 backdrop-blur-xl sm:gap-3 sm:px-5">
          <img src="/roshan-logo.png" alt="" className="size-8 shrink-0 object-contain lg:hidden" />
          <BreadcrumbNav />
          <div className="min-w-0 flex-1" />
          <SearchTrigger />
          <Button
            variant="outline"
            size="sm"
            onClick={toggle}
            aria-label={lang === "ar" ? "Switch to English" : "التبديل إلى العربية"}
          >
            <Languages className="size-4" />
            <span className="hidden sm:inline">{lang === "ar" ? "English" : "العربية"}</span>
          </Button>
          <Separator orientation="vertical" className="mx-1 hidden h-6 sm:block" />
          <Button
            variant="ghost"
            size="sm"
            className="lg:hidden"
            onClick={handleSignOut}
            aria-label={t("sign_out")}
          >
            <LogOut className="size-4" />
          </Button>
        </header>

        <main
          id="main-content"
          className="mx-auto w-full min-w-0 max-w-[1600px] flex-1 p-3 sm:p-5 lg:p-7"
        >
          {children}
        </main>
      </div>

      <MobileBottomNav />
    </div>
  );
}

function cnRail(collapsed: boolean): string {
  return cn(
    "no-print sticky top-0 hidden h-dvh shrink-0 flex-col border-e border-sidebar-border/60 bg-sidebar lg:flex transition-[width] duration-200 ease-out",
    collapsed ? "w-[4.25rem]" : "w-60",
  );
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
