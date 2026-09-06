import { useNavigate } from "@tanstack/react-router";
import {
  Clock,
  FlaskConical,
  History,
  Pill,
  Search,
  Sparkles,
  Star,
  Stethoscope,
  UserRound,
  X,
} from "lucide-react";
import { useMemo, useState } from "react";

import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { flatNavItems, HOME_ITEM, type NavConfigItem } from "@/config/nav";
import { useGlobalSearch } from "@/hooks/use-global-search";
import { useNavPreferences } from "@/hooks/use-nav-preferences";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { getNavIcon } from "@/lib/nav-icons";
import {
  clearRecentSearchTerms,
  clearSearchHistory,
  getRecentSearchTerms,
  getSearchHistory,
  pushRecentSearchTerm,
  pushSearchHistoryItem,
  type SearchResultItem,
} from "@/lib/search-service";
import { armQuickAction, QUICK_ACTIONS } from "@/lib/quick-actions";
import { cn } from "@/lib/utils";

const CATEGORY_ICON = {
  patient: UserRound,
  visit: Stethoscope,
  lab: FlaskConical,
  medicine: Pill,
} as const;

/** Small star toggle reused by every pinnable row (pages + favorites). */
function PinToggle({ pinned, onToggle, label }: { pinned: boolean; onToggle: () => void; label: string }) {
  return (
    <button
      type="button"
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        onToggle();
      }}
      aria-label={label}
      className="ms-auto shrink-0 rounded p-0.5 opacity-60 hover:opacity-100"
    >
      <Star className={cn("size-3.5", pinned ? "fill-current text-amber-500" : "text-muted-foreground")} />
    </button>
  );
}

export function GlobalSearchDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const navigate = useNavigate();
  const { favorites, recents, toggleFavorite } = useNavPreferences();

  const [query, setQuery] = useState("");
  const trimmed = query.trim();
  const hasQuery = trimmed.length >= 2;

  const { results, isSearching } = useGlobalSearch(query);
  const [recentTerms, setRecentTerms] = useState<string[]>(() => getRecentSearchTerms());
  const [history, setHistory] = useState<SearchResultItem[]>(() => getSearchHistory());

  const pages = useMemo(() => [HOME_ITEM, ...flatNavItems().filter((i) => i.to !== HOME_ITEM.to)], []);

  const visiblePages = useMemo(() => {
    const allowed = pages.filter((item) => can(item.perm));
    if (!trimmed) return [];
    const q = trimmed.toLowerCase();
    return allowed.filter((item) => t(item.key).toLowerCase().includes(q) || item.key.includes(q));
  }, [pages, can, trimmed, t]);

  const favoritePages = useMemo(
    () => pages.filter((item) => can(item.perm) && favorites.includes(item.to)),
    [pages, can, favorites],
  );

  function reset() {
    setQuery("");
  }

  function close() {
    onOpenChange(false);
    reset();
  }

  function goTo(to: string) {
    navigate({ to });
    close();
  }

  function selectResult(item: SearchResultItem) {
    pushSearchHistoryItem(item);
    if (trimmed) pushRecentSearchTerm(trimmed);
    setRecentTerms(getRecentSearchTerms());
    setHistory(getSearchHistory());
    goTo(item.to);
  }

  function selectQuickAction(actionKey: (typeof QUICK_ACTIONS)[number]["key"], to: string) {
    armQuickAction(actionKey);
    goTo(to);
  }

  function rerunRecentTerm(term: string) {
    setQuery(term);
  }

  function pinLabel(item: NavConfigItem) {
    return favorites.includes(item.to) ? t("unpin") : t("pin");
  }

  const noResults =
    hasQuery &&
    !isSearching &&
    visiblePages.length === 0 &&
    results.patients.length === 0 &&
    results.visits.length === 0 &&
    results.lab.length === 0 &&
    results.medicines.length === 0;

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        onOpenChange(next);
        if (!next) reset();
      }}
    >
      <DialogContent className="max-w-xl overflow-hidden p-0" dir={lang === "ar" ? "rtl" : "ltr"}>
        <DialogTitle className="sr-only">{t("search_everywhere")}</DialogTitle>
        <Command shouldFilter={false} className="flex h-full max-h-[70vh] flex-col overflow-hidden">
          <div className="flex items-center gap-2 border-b px-3">
            <Search className="size-4 shrink-0 opacity-50" />
            <input
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t("search_placeholder")}
              className="flex h-12 w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            />
            {query.length > 0 && (
              <button
                type="button"
                onClick={reset}
                className="rounded-sm p-1 text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                aria-label={t("clear")}
              >
                <X className="size-4" />
              </button>
            )}
          </div>

          <CommandList className="max-h-[60vh]">
            {!hasQuery && (
              <>
                {favoritePages.length > 0 && (
                  <CommandGroup heading={t("favorites")}>
                    {favoritePages.map((item) => {
                      const Icon = getNavIcon(item.icon);
                      return (
                        <CommandItem key={`fav:${item.to}`} value={`fav-${item.to}`} onSelect={() => goTo(item.to)}>
                          <Icon className="size-4" />
                          <span>{t(item.key)}</span>
                          <PinToggle pinned onToggle={() => toggleFavorite(item.to)} label={t("unpin")} />
                        </CommandItem>
                      );
                    })}
                  </CommandGroup>
                )}

                {recents.length > 0 && (
                  <CommandGroup heading={t("recent_pages")}>
                    {recents.map((r) => {
                      const item = pages.find((p) => p.to === r.to);
                      if (!item || !can(item.perm)) return null;
                      const Icon = getNavIcon(item.icon);
                      return (
                        <CommandItem key={`recent:${item.to}`} value={`recent-${item.to}`} onSelect={() => goTo(item.to)}>
                          <Clock className="size-4 text-muted-foreground" />
                          <span>{t(item.key)}</span>
                        </CommandItem>
                      );
                    })}
                  </CommandGroup>
                )}

                <CommandGroup heading={t("quick_actions")}>
                  {QUICK_ACTIONS.map((action) => {
                    const Icon = getNavIcon(action.icon);
                    return (
                      <CommandItem
                        key={action.key}
                        value={`qa-${action.key}`}
                        onSelect={() => selectQuickAction(action.key, action.to)}
                      >
                        <Sparkles className="size-4 text-primary" />
                        <span>{t(action.labelKey)}</span>
                        <Icon className="ms-auto size-3.5 text-muted-foreground" />
                      </CommandItem>
                    );
                  })}
                </CommandGroup>

                {history.length > 0 && (
                  <>
                    <CommandSeparator />
                    <CommandGroup heading={t("search_history")}>
                      {history.map((item) => {
                        const Icon = CATEGORY_ICON[item.category];
                        return (
                          <CommandItem
                            key={`hist:${item.key}`}
                            value={`hist-${item.key}`}
                            onSelect={() => selectResult(item)}
                          >
                            <History className="size-4 text-muted-foreground" />
                            <div className="flex min-w-0 flex-col">
                              <span className="truncate">{item.title}</span>
                              {item.subtitle && (
                                <span className="truncate text-xs text-muted-foreground">{item.subtitle}</span>
                              )}
                            </div>
                            <Icon className="ms-auto size-3.5 shrink-0 text-muted-foreground" />
                          </CommandItem>
                        );
                      })}
                      <CommandItem
                        value="clear-history"
                        onSelect={() => {
                          clearSearchHistory();
                          setHistory([]);
                        }}
                        className="text-muted-foreground"
                      >
                        <X className="size-4" />
                        <span>{t("clear")}</span>
                      </CommandItem>
                    </CommandGroup>
                  </>
                )}

                {recentTerms.length > 0 && (
                  <>
                    <CommandSeparator />
                    <CommandGroup heading={t("recent_searches")}>
                      {recentTerms.map((term) => (
                        <CommandItem key={`term:${term}`} value={`term-${term}`} onSelect={() => rerunRecentTerm(term)}>
                          <Search className="size-4 text-muted-foreground" />
                          <span>{term}</span>
                        </CommandItem>
                      ))}
                      <CommandItem
                        value="clear-recent-terms"
                        onSelect={() => {
                          clearRecentSearchTerms();
                          setRecentTerms([]);
                        }}
                        className="text-muted-foreground"
                      >
                        <X className="size-4" />
                        <span>{t("clear")}</span>
                      </CommandItem>
                    </CommandGroup>
                  </>
                )}
              </>
            )}

            {hasQuery && (
              <>
                {visiblePages.length > 0 && (
                  <CommandGroup heading={t("pages")}>
                    {visiblePages.map((item) => {
                      const Icon = getNavIcon(item.icon);
                      const favoritable = item.favoritable !== false;
                      return (
                        <CommandItem key={`page:${item.to}`} value={`page-${item.to}`} onSelect={() => goTo(item.to)}>
                          <Icon className="size-4" />
                          <span>{t(item.key)}</span>
                          {favoritable && (
                            <PinToggle
                              pinned={favorites.includes(item.to)}
                              onToggle={() => toggleFavorite(item.to)}
                              label={pinLabel(item)}
                            />
                          )}
                        </CommandItem>
                      );
                    })}
                  </CommandGroup>
                )}

                <ResultGroup heading={t("patient_result")} icon={CATEGORY_ICON.patient} items={results.patients} onSelect={selectResult} />
                <ResultGroup heading={t("visit_result")} icon={CATEGORY_ICON.visit} items={results.visits} onSelect={selectResult} />
                <ResultGroup heading={t("lab_result")} icon={CATEGORY_ICON.lab} items={results.lab} onSelect={selectResult} />
                <ResultGroup heading={t("medicine_result")} icon={CATEGORY_ICON.medicine} items={results.medicines} onSelect={selectResult} />

                {noResults && <CommandEmpty>{t("no_results")}</CommandEmpty>}
              </>
            )}
          </CommandList>

          <div className="flex items-center justify-between border-t px-3 py-2 text-[11px] text-muted-foreground">
            <span>{t("type_to_search")}</span>
            <span className="flex items-center gap-1">
              <kbd className="rounded border bg-muted px-1.5 py-0.5 font-mono">↑↓</kbd>
              <kbd className="rounded border bg-muted px-1.5 py-0.5 font-mono">Enter</kbd>
              <kbd className="rounded border bg-muted px-1.5 py-0.5 font-mono">Esc</kbd>
            </span>
          </div>
        </Command>
      </DialogContent>
    </Dialog>
  );
}

function ResultGroup({
  heading,
  icon: Icon,
  items,
  onSelect,
}: {
  heading: string;
  icon: (typeof CATEGORY_ICON)[keyof typeof CATEGORY_ICON];
  items: SearchResultItem[];
  onSelect: (item: SearchResultItem) => void;
}) {
  if (items.length === 0) return null;
  return (
    <CommandGroup heading={heading}>
      {items.map((item) => (
        <CommandItem key={item.key} value={item.key} onSelect={() => onSelect(item)}>
          <Icon className="size-4 text-muted-foreground" />
          <div className="flex min-w-0 flex-col">
            <span className="truncate">{item.title}</span>
            {item.subtitle && <span className="truncate text-xs text-muted-foreground">{item.subtitle}</span>}
          </div>
          {item.meta && <span className={cn("ms-auto text-xs text-muted-foreground")}>{item.meta}</span>}
        </CommandItem>
      ))}
    </CommandGroup>
  );
}
