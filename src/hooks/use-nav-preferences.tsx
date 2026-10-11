import { useLocation } from "@tanstack/react-router";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

const FAVORITES_KEY = "roshan:nav:favorites";
const RECENTS_KEY = "roshan:nav:recents";
const MAX_RECENTS = 6;

export type RecentPage = { to: string; visitedAt: number };

type NavPreferences = {
  favorites: string[];
  recents: RecentPage[];
  toggleFavorite: (to: string) => void;
  isFavorite: (to: string) => boolean;
};

const NavPreferencesContext = createContext<NavPreferences | null>(null);

function readList<T>(key: string, fallback: T): T {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function writeList<T>(key: string, value: T) {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage can be unavailable (private mode, quota) — favorites/recents
    // are a convenience, not something worth surfacing an error for.
  }
}

/**
 * Tracks pinned pages and recently-visited pages, both purely client-side
 * (per browser/device, not synced through Supabase — nothing clinical is
 * stored here). Mounted once in app-shell so the rail, mobile nav, and the
 * command palette all read the same state.
 */
export function NavPreferencesProvider({ children }: { children: ReactNode }) {
  const location = useLocation();
  const [favorites, setFavorites] = useState<string[]>(() => readList(FAVORITES_KEY, [] as string[]));
  const [recents, setRecents] = useState<RecentPage[]>(() => readList(RECENTS_KEY, [] as RecentPage[]));

  useEffect(() => {
    const to = location.pathname;
    setRecents((prev) => {
      const next = [{ to, visitedAt: Date.now() }, ...prev.filter((r) => r.to !== to)].slice(0, MAX_RECENTS);
      writeList(RECENTS_KEY, next);
      return next;
    });
    // Only the path should re-trigger this, not a new `location` object.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname]);

  const toggleFavorite = useCallback((to: string) => {
    setFavorites((prev) => {
      const next = prev.includes(to) ? prev.filter((f) => f !== to) : [...prev, to];
      writeList(FAVORITES_KEY, next);
      return next;
    });
  }, []);

  const isFavorite = useCallback((to: string) => favorites.includes(to), [favorites]);

  const value = useMemo(
    () => ({ favorites, recents, toggleFavorite, isFavorite }),
    [favorites, recents, toggleFavorite, isFavorite],
  );

  return <NavPreferencesContext.Provider value={value}>{children}</NavPreferencesContext.Provider>;
}

export function useNavPreferences(): NavPreferences {
  const ctx = useContext(NavPreferencesContext);
  if (!ctx) throw new Error("useNavPreferences must be used within NavPreferencesProvider");
  return ctx;
}
