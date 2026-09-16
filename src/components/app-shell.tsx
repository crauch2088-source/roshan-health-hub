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
  // Was `hidden ... sm:flex` — below the sm breakpoint (any phone) this
  // button, and with it the only way to open the command palette, simply
  // didn't render. Ctrl+K doesn't help on a touchscreen either, and the
  // mobile bottom nav has no search entry point of its own, so mobile
  // users had zero access to global/patient search. Now always renders,
  // as an icon-only button on narrow screens and the full labeled button
  // from md up.
  return (
    <Button
      variant="outline"
      size="sm"
      className="gap-2 text-muted-foreground"
      onClick={() => setOpen(true)}
      aria-label={t("search_everywhere")}
    >
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
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:start-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground"
      >
        {t("skip_to_content")}
      </a>
      <aside
        className={cnRail(collapsed)}
        aria-label={t("navigation")}
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

      <div className="flex min-w-0 flex-1 flex-col pb-[calc(5.5rem+env(safe-area-inset-bottom))] lg:pb-0">
        <header className="no-print sticky top-0 z-20 flex h-14 items-center gap-2 border-b bg-card/85 px-3 backdrop-blur-md supports-[backdrop-filter]:bg-card/70 sm:gap-3 sm:px-4">
          <img src="/roshan-logo.png" alt="" className="size-8 shrink-0 object-contain lg:hidden" />
          <BreadcrumbNav />
          <div className="min-w-0 flex-1" />
          <SearchTrigger />
          <Button variant="outline" size="sm" onClick={toggle} aria-label={lang === "ar" ? "Switch to English" : "التبديل إلى العربية"}>
            <Languages className="size-4" />
            <span className="hidden sm:inline">{lang === "ar" ? "English" : "العربية"}</span>
          </Button>
          <Separator orientation="vertical" className="mx-1 hidden h-6 sm:block" />
          <Button variant="ghost" size="sm" className="lg:hidden" onClick={handleSignOut} aria-label={t("sign_out")}>
            <LogOut className="size-4" />
          </Button>
        </header>

        <main id="main-content" className="min-w-0 flex-1 p-4 md:p-6 lg:p-8">{children}</main>
      </div>


      <MobileBottomNav />
    </div>
  );
}

function cnRail(collapsed: boolean): string {
  return [
    "no-print sticky top-0 hidden h-screen shrink-0 flex-col bg-sidebar lg:flex transition-[width] duration-200 ease-in-out",
    collapsed ? "w-[4.25rem]" : "w-64",
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
