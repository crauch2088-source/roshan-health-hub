import { Link, useLocation, useNavigate } from "@tanstack/react-router";
import { Grid2x2, ListOrdered, Pill, Plus, UserRound } from "lucide-react";
import { useState } from "react";

import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { HOME_ITEM, NAV_GROUPS } from "@/config/nav";
import { useNavPreferences } from "@/hooks/use-nav-preferences";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { getNavIcon } from "@/lib/nav-icons";
import { armQuickAction, QUICK_ACTIONS } from "@/lib/quick-actions";
import { cn } from "@/lib/utils";

// Sensible defaults for staff who haven't pinned anything yet.
// Everything else — settings, reports, suppliers, etc. — lives in More.
const DEFAULT_MOBILE_ROUTES = ["/patients", "/visits", "/pharmacy"];
const PRIMARY_ICONS: Record<string, typeof UserRound> = {
  "/dashboard": Grid2x2,
  "/patients": UserRound,
  "/visits": ListOrdered,
  "/pharmacy": Pill,
};

function isActive(pathname: string, to: string): boolean {
  return pathname === to || pathname.startsWith(`${to}/`);
}

export function MobileBottomNav() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const { favorites } = useNavPreferences();
  const [moreOpen, setMoreOpen] = useState(false);
  const [fabOpen, setFabOpen] = useState(false);
  const direction = lang === "ar" ? "rtl" : "ltr";

  const allItems = [HOME_ITEM, ...NAV_GROUPS.flatMap((g) => g.items)];

  // Dashboard is always first. The next 3 slots prefer whatever the user
  // has pinned as a favorite (same favorites list the NavRail and command
  // palette already use) — so pinning Queue or Clinic on desktop actually
  // shortens the path on mobile too, instead of leaving pins as a
  // desktop-only feature. Falls back to the previous fixed defaults for
  // anyone who hasn't pinned anything, so today's behavior is unchanged.
  const pinnedRoutes = favorites.filter((to) => to !== HOME_ITEM.to);
  const primaryRoutes = [
    HOME_ITEM.to,
    ...[...pinnedRoutes, ...DEFAULT_MOBILE_ROUTES].filter(
      (to, idx, arr) => arr.indexOf(to) === idx,
    ),
  ].slice(0, 4);
  const primary = primaryRoutes
    .map((to) => allItems.find((i) => i.to === to))
    .filter((i): i is NonNullable<typeof i> => Boolean(i) && can(i!.perm));
  const availableActions = QUICK_ACTIONS.filter((a) => can(allItems.find((i) => i.to === a.to)?.perm ?? ""));

  return (
    <>
      {/* Floating quick action button — sits just above the bottom bar,
          reuses the exact same armQuickAction() flow as the desktop
          command palette's Quick Actions group (single implementation). */}
      {availableActions.length > 0 ? (
        <div className="no-print fixed inset-x-0 bottom-[68px] z-30 flex justify-end px-4 lg:hidden">
          <Sheet open={fabOpen} onOpenChange={setFabOpen}>
            <SheetTrigger asChild>
              <button
                type="button"
                aria-label={t("quick_actions")}
                className="flex size-14 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-lg shadow-primary/30 transition-transform active:scale-95"
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
                      className="flex min-h-14 items-center gap-2.5 rounded-xl border p-3 text-start text-sm font-medium hover:bg-accent active:scale-[0.98]"
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
        className="no-print fixed inset-x-0 bottom-0 z-30 flex items-center justify-around border-t bg-card/95 py-1 pb-[max(0.25rem,env(safe-area-inset-bottom))] backdrop-blur lg:hidden"
        aria-label={t("navigation")}
      >
        {primary.map((item) => {
          const Icon = PRIMARY_ICONS[item.to] ?? getNavIcon(item.icon);
          const active = isActive(location.pathname, item.to);
          return (
            <Link
              key={item.to}
              to={item.to}
              aria-current={active ? "page" : undefined}
              className="flex min-h-14 min-w-14 flex-col items-center justify-center gap-0.5 px-2 py-1.5 text-[11px] font-medium"
            >
              <span
                className={cn(
                  "flex size-9 items-center justify-center rounded-full transition-colors",
                  active ? "bg-primary/15 text-primary" : "text-muted-foreground",
                )}
              >
                <Icon className="size-5" />
              </span>
              <span className={active ? "text-primary" : "text-muted-foreground"}>{t(item.key)}</span>
            </Link>
          );
        })}


        <Sheet open={moreOpen} onOpenChange={setMoreOpen}>
          <SheetTrigger asChild>
            <button
              type="button"
              className="flex min-h-14 min-w-14 flex-col items-center justify-center gap-0.5 px-2 py-1.5 text-[11px] font-medium text-muted-foreground"
            >
              <span className="flex size-9 items-center justify-center rounded-full">
                <Grid2x2 className="size-5" />
              </span>
              {t("more")}
            </button>
          </SheetTrigger>
          <SheetContent side="bottom" className="max-h-[75vh] overflow-y-auto rounded-t-2xl" dir={direction}>
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
                        const active = isActive(location.pathname, item.to);
                        return (
                          <Link
                            key={item.to}
                            to={item.to}
                            onClick={() => setMoreOpen(false)}
                            aria-current={active ? "page" : undefined}
                            className={cn(
                              "flex min-h-16 flex-col items-center justify-center gap-1 rounded-xl border p-2.5 text-center text-[11px] font-medium transition-colors hover:bg-accent active:scale-[0.98]",
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
