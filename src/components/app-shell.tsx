import { useNavigate } from "@tanstack/react-router";
import { LogOut, Languages, Search, UserRound, Plus } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";

import { AccountMenu } from "@/components/account-menu";
import { BreadcrumbNav } from "@/components/breadcrumb-nav";
import { CommandPaletteProvider, useCommandPalette } from "@/components/command-palette-provider";
import { MobileBottomNav } from "@/components/mobile-bottom-nav";
import { NavRail } from "@/components/nav-rail";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { NavPreferencesProvider } from "@/hooks/use-nav-preferences";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { getNavIcon } from "@/lib/nav-icons";
import { armQuickAction, getAvailableQuickActions } from "@/lib/quick-actions";

const RAIL_COLLAPSED_KEY = "roshan:nav:rail-collapsed";

function Brand({ collapsed }: { collapsed: boolean }) {
  const { t } = useLang();
  return (
    <div
      className={cn(
        "flex h-16 items-center gap-3 border-b border-sidebar-border/80 px-4",
        collapsed && "justify-center px-2",
      )}
    >
      <img src="/roshan-logo.png" alt={t("app_name")} className="size-9 shrink-0 object-contain" />
      {!collapsed ? (
        <div className="min-w-0 leading-tight">
          <p className="truncate font-display text-base font-extrabold text-sidebar-foreground">
            {t("app_short")}
          </p>
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
      aria-label={t("search_everywhere")}
    >
      <Search className="size-4" aria-hidden />
      <span className="hidden sm:inline">{t("search_everywhere")}</span>
      <kbd className="ms-auto hidden rounded border border-border/70 bg-muted/70 px-1.5 py-0.5 font-mono text-[10px] md:inline">
        Ctrl K
      </kbd>
    </Button>
  );
}

function DesktopQuickActions() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const navigate = useNavigate();
  const actions = getAvailableQuickActions(can);
  if (actions.length === 0) return null;

  return (
    <DropdownMenu dir={lang === "ar" ? "rtl" : "ltr"}>
      <DropdownMenuTrigger asChild>
        <Button
          size="sm"
          className="hidden shrink-0 gap-1.5 shadow-sm lg:inline-flex"
          aria-label={t("quick_actions")}
        >
          <Plus className="size-4" aria-hidden />
          <span>{t("quick_actions")}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel>{t("quick_actions")}</DropdownMenuLabel>
        <DropdownMenuSeparator />
        {actions.map((action) => {
          const Icon = getNavIcon(action.icon);
          return (
            <DropdownMenuItem
              key={action.key}
              className="min-h-10 gap-2"
              onSelect={() => {
                armQuickAction(action.key);
                void navigate({ to: action.to });
              }}
            >
              <Icon className="size-4 text-primary" aria-hidden />
              {t(action.labelKey)}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function MobileSearchButton() {
  const { t } = useLang();
  const { setOpen } = useCommandPalette();
  // The desktop trigger is hidden below `sm` and phones have no Ctrl+K, so
  // without this there is no way to open global search on a phone.
  return (
    <Button
      variant="ghost"
      size="sm"
      className="size-9 shrink-0 p-0 sm:hidden"
      onClick={() => setOpen(true)}
      aria-label={t("search_everywhere")}
    >
      <Search className="size-5" />
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
    <div className="roshan-app-background flex min-h-screen bg-background" dir={direction}>
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:start-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground"
      >
        {t("skip_to_content")}
      </a>
      <aside className={cnRail(collapsed)}>
        <Brand collapsed={collapsed} />
        <div className="min-h-0 flex-1">
          <NavRail collapsed={collapsed} onToggleCollapsed={toggleCollapsed} />
        </div>

        <div
          className={
            collapsed ? "border-t border-sidebar-border p-2" : "border-t border-sidebar-border p-3"
          }
        >
          {!collapsed ? (
            <>
              <div className="mb-2 flex min-w-0 items-center gap-2.5">
                <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-sidebar-accent text-sidebar-accent-foreground">
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
            aria-label={t("sign_out")}
          >
            <LogOut className="size-4" /> {!collapsed ? t("sign_out") : null}
          </Button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col pb-[calc(7.5rem+env(safe-area-inset-bottom))] lg:pb-0">
        <header className="no-print sticky top-0 z-20 flex h-16 min-w-0 items-center gap-1.5 border-b border-border/80 bg-card/85 px-2 shadow-sm backdrop-blur-xl sm:gap-3 sm:px-5 lg:px-7">
          <img src="/roshan-logo.png" alt="" className="size-7 shrink-0 object-contain lg:hidden" />
          <div className="min-w-0 flex-1 overflow-hidden">
            <BreadcrumbNav />
          </div>
          <div className="hidden min-w-0 flex-1 sm:block" />
          <DesktopQuickActions />
          <SearchTrigger />
          <MobileSearchButton />
          <Button
            variant="outline"
            size="sm"
            onClick={toggle}
            aria-label={lang === "ar" ? "Switch to English" : "التبديل إلى العربية"}
          >
            <Languages className="size-4" />
            <span className="hidden sm:inline">{lang === "ar" ? "English" : "العربية"}</span>
          </Button>
          <div className="shrink-0">
            <AccountMenu onSignOut={handleSignOut} />
          </div>
        </header>

        <main
          id="main-content"
          tabIndex={-1}
          className="roshan-main mx-auto w-full min-w-0 max-w-[1680px] flex-1 p-3 outline-none sm:p-5 lg:p-8"
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
    "no-print sticky top-0 z-30 hidden h-dvh shrink-0 flex-col border-e border-sidebar-border/80 bg-sidebar shadow-[0_12px_36px_-32px_oklch(0.2_0.04_245_/_0.45)] transition-[width] duration-200 ease-out lg:flex",
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
