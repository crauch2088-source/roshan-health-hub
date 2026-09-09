import { Link, useLocation } from "@tanstack/react-router";
import { Grid2x2, ListOrdered, Pill, UserRound } from "lucide-react";
import { useState } from "react";

import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { HOME_ITEM, NAV_GROUPS } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { getNavIcon } from "@/lib/nav-icons";
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

function isActive(pathname: string, to: string): boolean {
  return pathname === to || pathname.startsWith(`${to}/`);
}

export function MobileBottomNav() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const [moreOpen, setMoreOpen] = useState(false);
  const direction = lang === "ar" ? "rtl" : "ltr";

  const allItems = [HOME_ITEM, ...NAV_GROUPS.flatMap((g) => g.items)];
  const primary = PRIMARY_MOBILE_ROUTES.map((to) => allItems.find((i) => i.to === to)).filter(
    (i): i is NonNullable<typeof i> => Boolean(i) && can(i!.perm),
  );

  return (
    <nav className="no-print fixed inset-x-0 bottom-0 z-30 flex items-center justify-around border-t bg-card/95 py-1.5 backdrop-blur lg:hidden">
      {primary.map((item) => {
        const Icon = PRIMARY_ICONS[item.to] ?? getNavIcon(item.icon);
        const active = isActive(location.pathname, item.to);
        return (
          <Link
            key={item.to}
            to={item.to}
            className={cn(
              "flex flex-col items-center gap-0.5 px-3 py-1 text-[11px] font-medium",
              active ? "text-primary" : "text-muted-foreground",
            )}
          >
            <Icon className="size-5" />
            {t(item.key)}
          </Link>
        );
      })}

      <Sheet open={moreOpen} onOpenChange={setMoreOpen}>
        <SheetTrigger asChild>
          <button
            type="button"
            className="flex flex-col items-center gap-0.5 px-3 py-1 text-[11px] font-medium text-muted-foreground"
          >
            <Grid2x2 className="size-5" />
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
                      return (
                        <Link
                          key={item.to}
                          to={item.to}
                          onClick={() => setMoreOpen(false)}
                          className="flex flex-col items-center gap-1 rounded-lg border p-2.5 text-center text-[11px] font-medium hover:bg-accent"
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
  );
}
