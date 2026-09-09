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
import { getNavIcon } from "@/lib/nav-icons";
import { cn } from "@/lib/utils";

function isActive(pathname: string, to: string): boolean {
  return pathname === to || pathname.startsWith(`${to}/`);
}

function RailLink({
  item,
  collapsed,
  active,
  onNavigate,
  trailing,
}: {
  item: NavConfigItem;
  collapsed: boolean;
  active: boolean;
  onNavigate?: () => void;
  trailing?: ReactNode;
}) {
  const { t } = useLang();
  const Icon = getNavIcon(item.icon);

  const link = (
    <Link
      to={item.to}
      onClick={onNavigate}
      className={cn(
        "flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm font-medium transition-colors",
        collapsed && "justify-center px-2",
        active
          ? "bg-sidebar-primary text-sidebar-primary-foreground"
          : "text-sidebar-foreground/85 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
      )}
    >
      <Icon className="size-4 shrink-0" />
      {!collapsed ? <span className="truncate">{t(item.key)}</span> : null}
      {!collapsed ? trailing : null}
    </Link>
  );

  if (!collapsed) return link;

  return (
    <Tooltip delayDuration={200}>
      <TooltipTrigger asChild>{link}</TooltipTrigger>
      <TooltipContent side="end">{t(item.key)}</TooltipContent>
    </Tooltip>
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
  const { t } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const { favorites, toggleFavorite } = useNavPreferences();

  const favoriteItems = NAV_GROUPS.flatMap((g) => g.items)
    .filter((item) => can(item.perm) && favorites.includes(item.to));

  return (
    <TooltipProvider delayDuration={200}>
      <div className="flex h-full flex-col">
      <ScrollArea className="flex-1">
        <nav className="space-y-4 p-3">
          <RailLink
            item={HOME_ITEM}
            collapsed={collapsed}
            active={isActive(location.pathname, HOME_ITEM.to)}
            onNavigate={onNavigate}
          />

          {favoriteItems.length > 0 ? (
            <div>
              {!collapsed ? (
                <p className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-sidebar-foreground/50">
                  {t("favorites")}
                </p>
              ) : null}
              <div className="space-y-0.5">
                {favoriteItems.map((item) => (
                  <RailLink
                    key={`fav-${item.to}`}
                    item={item}
                    collapsed={collapsed}
                    active={isActive(location.pathname, item.to)}
                    onNavigate={onNavigate}
                  />
                ))}
              </div>
            </div>
          ) : null}

          {NAV_GROUPS.map((group) => {
            const items = group.items.filter((item) => can(item.perm));
            if (items.length === 0) return null;
            return (
              <div key={group.group}>
                {!collapsed ? (
                  <p className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-sidebar-foreground/50">
                    {t(group.group)}
                  </p>
                ) : null}
                <div className="space-y-0.5">
                  {items.map((item) => {
                    const pinned = favorites.includes(item.to);
                    return (
                      <div key={item.to} className="group relative">
                        <RailLink
                          item={item}
                          collapsed={collapsed}
                          active={isActive(location.pathname, item.to)}
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
                                className="ms-auto shrink-0 rounded p-0.5 opacity-0 group-hover:opacity-100"
                                aria-label={pinned ? t("unpin") : t("pin")}
                              >
                                <Star className={cn("size-3.5", pinned ? "fill-current text-amber-400" : "")} />
                              </button>
                            ) : null
                          }
                        />
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </nav>
      </ScrollArea>

      <div className="hidden border-t border-sidebar-border p-2 lg:block">
        <Button variant="ghost" size="sm" className="w-full justify-center" onClick={onToggleCollapsed}>
          {collapsed ? (
            <ChevronsRight className="size-4" />
          ) : (
            <>
              <ChevronsLeft className="size-4" /> {t("collapse_sidebar")}
            </>
          )}
        </Button>
      </div>
      </div>
    </TooltipProvider>
  );
}
