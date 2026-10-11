import { Link, useLocation, useNavigate } from "@tanstack/react-router";
import { Grid2x2, ListOrdered, Pill, Plus, UserRound } from "lucide-react";
import { useState } from "react";

import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { HOME_ITEM, NAV_GROUPS } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { getNavIcon } from "@/lib/nav-icons";
import { isNavItemActive } from "@/lib/nav-active";
import { armQuickAction, QUICK_ACTIONS } from "@/lib/quick-actions";
import { cn } from "@/lib/utils";

// The four destinations reception/clinical staff reach for constantly.
// Everything else — settings, reports, suppliers, etc. — lives in More.
const PRIMARY_MOBILE_ROUTES = ["/dashboard", "/patients", "/visits", "/pharmacy"];
const PRIMARY_ICONS: Record<string, typeof UserRound> = {
  "/dashboard": Grid2x2,
  "/patients": UserRound,
  "/visits": ListOrdered,
  "/pharmacy": Pill,
};

export function MobileBottomNav() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [moreOpen, setMoreOpen] = useState(false);
  const [fabOpen, setFabOpen] = useState(false);
  const direction = lang === "ar" ? "rtl" : "ltr";

  const allItems = [HOME_ITEM, ...NAV_GROUPS.flatMap((g) => g.items)];
  const primary = PRIMARY_MOBILE_ROUTES.map((to) => allItems.find((i) => i.to === to)).filter(
    (item): item is (typeof allItems)[number] => Boolean(item && can(item.perm)),
  );
  const availableActions = QUICK_ACTIONS.filter((action) => {
    const destination = allItems.find((item) => item.to === action.to);
    return destination ? can(destination.perm) : false;
  });
  const moreActive = NAV_GROUPS.some((group) =>
    group.items.some(
      (item) =>
        !PRIMARY_MOBILE_ROUTES.includes(item.to) &&
        can(item.perm) &&
        isNavItemActive(location.pathname, item.to),
    ),
  );

  return (
    <>
      {/* Floating quick action button — sits just above the bottom bar,
          reuses the exact same armQuickAction() flow as the desktop
          command palette's Quick Actions group (single implementation). */}
      {availableActions.length > 0 ? (
        <div className="no-print fixed inset-x-0 bottom-[calc(4.25rem+env(safe-area-inset-bottom))] z-30 flex justify-end px-4 lg:hidden">
          <Sheet open={fabOpen} onOpenChange={setFabOpen}>
            <SheetTrigger asChild>
              <button
                type="button"
                aria-label={t("quick_actions")}
                className="flex size-12 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-lg shadow-primary/25 transition-transform focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:ring-offset-2 active:scale-95"
              >
                <Plus className="size-6" />
              </button>
            </SheetTrigger>
            <SheetContent side="bottom" className="rounded-t-2xl" dir={direction}>
              <SheetTitle className="mb-2">{t("quick_actions")}</SheetTitle>
              <div className="grid grid-cols-2 gap-2 pb-4">
                {availableActions.map((action) => {
                  const Icon = getNavIcon(action.icon);
                  return (
                    <button
                      key={action.key}
                      type="button"
                      className="flex min-h-14 items-center gap-2.5 rounded-lg border border-border/70 p-3 text-start text-sm font-medium transition-colors hover:bg-accent active:scale-[0.98]"
                      onClick={() => {
                        armQuickAction(action.key);
                        setFabOpen(false);
                        void navigate({ to: action.to });
                      }}
                    >
                      <Icon className="size-4 text-primary" />
                      {t(action.labelKey)}
                    </button>
                  );
                })}
              </div>
            </SheetContent>
          </Sheet>
        </div>
      ) : null}

      <nav
        className="no-print fixed inset-x-0 bottom-0 z-30 grid min-h-16 grid-cols-5 items-center border-t border-border/70 bg-card/95 px-1 pb-[env(safe-area-inset-bottom)] shadow-[0_-8px_24px_-20px_var(--foreground)] backdrop-blur-xl lg:hidden"
        aria-label={t("navigation")}
      >
        {primary.map((item) => {
          const Icon = PRIMARY_ICONS[item.to] ?? getNavIcon(item.icon);
          const active = isNavItemActive(location.pathname, item.to);
          return (
            <Link
              key={item.to}
              to={item.to}
              aria-current={active ? "page" : undefined}
              className="flex min-h-14 min-w-0 flex-col items-center justify-center gap-0.5 rounded-md px-1 py-1.5 text-[10px] font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40"
            >
              <span
                className={cn(
                  "flex h-7 w-10 items-center justify-center rounded-full transition-colors",
                  active ? "bg-primary/12 text-primary" : "text-muted-foreground",
                )}
              >
                <Icon className="size-5" />
              </span>
              <span
                className={cn(
                  "max-w-full truncate",
                  active ? "text-primary" : "text-muted-foreground",
                )}
              >
                {t(item.key)}
              </span>
            </Link>
          );
        })}

        <Sheet open={moreOpen} onOpenChange={setMoreOpen}>
          <SheetTrigger asChild>
            <button
              type="button"
              aria-current={moreActive ? "page" : undefined}
              className={cn(
                "flex min-h-14 min-w-0 flex-col items-center justify-center gap-0.5 rounded-md px-1 py-1.5 text-[10px] font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40",
                moreActive ? "text-primary" : "text-muted-foreground",
              )}
            >
              <span
                className={cn(
                  "flex h-7 w-10 items-center justify-center rounded-full",
                  moreActive && "bg-primary/12",
                )}
              >
                <Grid2x2 className="size-5" />
              </span>
              {t("more")}
            </button>
          </SheetTrigger>
          <SheetContent
            side="bottom"
            className="max-h-[75vh] overflow-y-auto rounded-t-2xl"
            dir={direction}
          >
            <SheetTitle className="sr-only">{t("more")}</SheetTitle>
            <div className="space-y-5 pb-4 pt-2">
              {NAV_GROUPS.map((group) => {
                const items = group.items.filter((i) => can(i.perm));
                if (items.length === 0) return null;
                return (
                  <div key={group.group}>
                    <p className="mb-1.5 px-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                      {t(group.group)}
                    </p>
                    <div className="grid grid-cols-4 gap-2">
                      {items.map((item) => {
                        const Icon = getNavIcon(item.icon);
                        const active = isNavItemActive(location.pathname, item.to);
                        return (
                          <Link
                            key={item.to}
                            to={item.to}
                            onClick={() => setMoreOpen(false)}
                            aria-current={active ? "page" : undefined}
                            className={cn(
                              "flex min-h-20 flex-col items-center justify-center gap-1 rounded-lg border border-border/70 p-2.5 text-center text-[11px] font-medium transition-colors hover:bg-accent active:scale-[0.98]",
                              active && "border-primary/40 bg-primary/10 text-primary",
                            )}
                          >
                            <Icon className="size-5" />
                            <span className="line-clamp-2">{t(item.key)}</span>
                          </Link>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
          </SheetContent>
        </Sheet>
      </nav>
    </>
  );
}
