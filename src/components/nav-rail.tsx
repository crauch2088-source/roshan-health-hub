import { Link, useLocation } from "@tanstack/react-router";
import { ChevronsLeft, ChevronsRight, Star } from "lucide-react";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { HOME_ITEM, NAV_GROUPS, type NavConfigItem } from "@/config/nav";
import { useNavPreferences } from "@/hooks/use-nav-preferences";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { railTooltipSide } from "@/lib/nav-layout";
import { getNavIcon } from "@/lib/nav-icons";
import { isNavItemActive } from "@/lib/nav-active";
import { cn } from "@/lib/utils";

function RailLink({
  item,
  collapsed,
  active,
  onNavigate,
  trailing,
  markCurrent = true,
}: {
  item: NavConfigItem;
  collapsed: boolean;
  active: boolean;
  onNavigate?: (() => void) | undefined;
  trailing?: ReactNode | undefined;
  /** false for the Favorites shortcuts, so a page is announced as current once. */
  markCurrent?: boolean;
}) {
  const { t, lang } = useLang();
  const Icon = getNavIcon(item.icon);
  const hasTrailing = Boolean(trailing) && !collapsed;

  const link = (
    <Link
      to={item.to}
      onClick={onNavigate}
      aria-current={active && markCurrent ? "page" : undefined}
      // Collapsed links are icon-only: without this they have no accessible name
      // (the tooltip only describes the link while it is open).
      aria-label={collapsed ? t(item.key) : undefined}
      className={cn(
        "group/link relative flex min-h-9 items-center gap-2.5 rounded-md px-2.5 py-2 text-sm font-medium outline-none transition-[background-color,color,transform] duration-150 active:translate-y-px",
        "focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:ring-offset-1 focus-visible:ring-offset-sidebar",
        collapsed && "justify-center px-2",
        hasTrailing && "pe-9",
        active
          ? "bg-sidebar-accent font-semibold text-sidebar-accent-foreground"
          : "text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
      )}
    >
      <span
        aria-hidden
        className={cn(
          "absolute inset-y-2 -start-2.5 w-[3px] rounded-full bg-sidebar-primary transition-opacity duration-150",
          active ? "opacity-100" : "opacity-0",
        )}
      />
      <Icon
        className={cn(
          "size-4 shrink-0 transition-colors",
          active
            ? "text-sidebar-primary"
            : "text-sidebar-foreground/70 group-hover/link:text-sidebar-accent-foreground",
        )}
      />
      {!collapsed ? <span className="truncate">{t(item.key)}</span> : null}
    </Link>
  );

  const body = collapsed ? (
    <Tooltip delayDuration={150}>
      <TooltipTrigger asChild>{link}</TooltipTrigger>
      <TooltipContent side={railTooltipSide(lang)} sideOffset={8} className="font-medium">
        {t(item.key)}
      </TooltipContent>
    </Tooltip>
  ) : (
    link
  );

  // The trailing control (pin/unpin) is a real <button>, so it must be a
  // SIBLING of the link, never nested inside an anchor.
  if (!hasTrailing) return body;

  return (
    <div className="relative">
      {body}
      <span className="absolute end-1 top-1/2 -translate-y-1/2">{trailing}</span>
    </div>
  );
}

export function NavRail({
  collapsed,
  onToggleCollapsed,
  onNavigate,
}: {
  collapsed: boolean;
  onToggleCollapsed: () => void;
  onNavigate?: () => void;
}) {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const { favorites, toggleFavorite } = useNavPreferences();

  const favoriteItems = NAV_GROUPS.flatMap((g) => g.items).filter(
    (item) => can(item.perm) && favorites.includes(item.to),
  );

  return (
    <TooltipProvider delayDuration={150}>
      <div className="flex h-full flex-col">
        <ScrollArea className="flex-1">
          <nav className="space-y-5 p-2.5" aria-label={t("main_navigation")}>
            <RailLink
              item={HOME_ITEM}
              collapsed={collapsed}
              active={isNavItemActive(location.pathname, HOME_ITEM.to)}
              onNavigate={onNavigate}
            />

            {favoriteItems.length > 0 ? (
              <div
                className={cn(
                  "space-y-0.5",
                  !collapsed &&
                    "rounded-lg border border-sidebar-border bg-sidebar-accent/40 p-1.5",
                )}
              >
                {!collapsed ? (
                  <p className="px-2 pb-1.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-sidebar-foreground/60 rtl:text-[11px] rtl:normal-case rtl:tracking-normal">
                    {t("favorites")}
                  </p>
                ) : null}
                {favoriteItems.map((item) => (
                  <RailLink
                    key={`fav-${item.to}`}
                    item={item}
                    collapsed={collapsed}
                    active={isNavItemActive(location.pathname, item.to)}
                    onNavigate={onNavigate}
                    markCurrent={false}
                  />
                ))}
              </div>
            ) : null}

            {NAV_GROUPS.map((group) => {
              const items = group.items.filter((item) => can(item.perm));
              if (items.length === 0) return null;
              return (
                <div key={group.group} className="space-y-0.5">
                  {!collapsed ? (
                    <p className="px-2.5 pb-1.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-sidebar-foreground/60 rtl:text-[11px] rtl:normal-case rtl:tracking-normal">
                      {t(group.group)}
                    </p>
                  ) : (
                    <div className="mx-auto my-1 h-px w-6 bg-sidebar-border/80" aria-hidden />
                  )}
                  {items.map((item) => {
                    const pinned = favorites.includes(item.to);
                    return (
                      <div key={item.to} className="group relative">
                        <RailLink
                          item={item}
                          collapsed={collapsed}
                          active={isNavItemActive(location.pathname, item.to)}
                          onNavigate={onNavigate}
                          trailing={
                            item.favoritable !== false ? (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.preventDefault();
                                  e.stopPropagation();
                                  toggleFavorite(item.to);
                                }}
                                className={cn(
                                  "flex size-8 shrink-0 items-center justify-center rounded-md transition-[opacity,background-color] hover:bg-sidebar-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring",
                                  pinned
                                    ? "opacity-100 text-amber-500"
                                    : "opacity-0 text-sidebar-foreground/50 group-hover:opacity-70 group-focus-within:opacity-70 hover:!opacity-100 focus-visible:!opacity-100 [@media(hover:none)]:opacity-70",
                                )}
                                aria-label={pinned ? t("unpin") : t("pin")}
                                aria-pressed={pinned}
                              >
                                <Star className={cn("size-3.5", pinned && "fill-current")} />
                              </button>
                            ) : null
                          }
                        />
                      </div>
                    );
                  })}
                </div>
              );
            })}
          </nav>
        </ScrollArea>

        <div className="hidden border-t border-sidebar-border p-2 lg:block">
          <Button
            variant="ghost"
            size="sm"
            className="w-full justify-center text-sidebar-foreground/70 hover:text-sidebar-foreground"
            onClick={onToggleCollapsed}
            aria-label={collapsed ? t("expand_sidebar") : t("collapse_sidebar")}
          >
            {collapsed ? (
              lang === "ar" ? (
                <ChevronsLeft className="size-4" />
              ) : (
                <ChevronsRight className="size-4" />
              )
            ) : (
              <>
                {lang === "ar" ? (
                  <ChevronsRight className="size-4" />
                ) : (
                  <ChevronsLeft className="size-4" />
                )}{" "}
                {t("collapse_sidebar")}
              </>
            )}
          </Button>
        </div>
      </div>
    </TooltipProvider>
  );
}
