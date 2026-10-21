import { useLocation } from "@tanstack/react-router";
import { useAuth } from "@/lib/auth";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

const LEGACY_FAVORITES_KEY = "roshan:nav:favorites";
const LEGACY_RECENTS_KEY = "roshan:nav:recents";
const favoritesKey = (userId: string) => `roshan:nav:favorites:${userId}`;
const recentsKey = (userId: string) => `roshan:nav:recents:${userId}`;
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
  const { user } = useAuth();
  const userId = user?.id ?? null;
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);
  const [favorites, setFavorites] = useState<string[]>([]);
  const [recents, setRecents] = useState<RecentPage[]>([]);

  useEffect(() => {
    try {
      window.localStorage.removeItem(LEGACY_FAVORITES_KEY);
      window.localStorage.removeItem(LEGACY_RECENTS_KEY);
    } catch {
      // Storage may be unavailable; user-scoped state remains empty until loaded.
    }
  }, []);

  useEffect(() => {
    if (!userId) {
      setFavorites([]);
      setRecents([]);
      setLoadedUserId(null);
      return;
    }
    setFavorites(readList(favoritesKey(userId), [] as string[]));
    setRecents(readList(recentsKey(userId), [] as RecentPage[]));
    setLoadedUserId(userId);
  }, [userId]);

  useEffect(() => {
    if (!userId || loadedUserId !== userId) return;
    const to = location.pathname;
    setRecents((prev) => {
      const next = [{ to, visitedAt: Date.now() }, ...prev.filter((r) => r.to !== to)].slice(
        0,
        MAX_RECENTS,
      );
      writeList(recentsKey(userId), next);
      return next;
    });
    // Only the path and current user should re-trigger this.
  }, [location.pathname, userId, loadedUserId]);

  const toggleFavorite = useCallback(
    (to: string) => {
      if (!userId || loadedUserId !== userId) return;
      setFavorites((prev) => {
        const next = prev.includes(to) ? prev.filter((f) => f !== to) : [...prev, to];
        writeList(favoritesKey(userId), next);
        return next;
      });
    },
    [userId, loadedUserId],
  );

  const visibleFavorites = useMemo(
    () => (userId && loadedUserId === userId ? favorites : []),
    [userId, loadedUserId, favorites],
  );
  const visibleRecents = useMemo(
    () => (userId && loadedUserId === userId ? recents : []),
    [userId, loadedUserId, recents],
  );
  const isFavorite = useCallback(
    (to: string) => visibleFavorites.includes(to),
    [visibleFavorites],
  );

  const value = useMemo(
    () => ({ favorites: visibleFavorites, recents: visibleRecents, toggleFavorite, isFavorite }),
    [visibleFavorites, visibleRecents, toggleFavorite, isFavorite],
  );

  return <NavPreferencesContext.Provider value={value}>{children}</NavPreferencesContext.Provider>;
}

export function useNavPreferences(): NavPreferences {
  const ctx = useContext(NavPreferencesContext);
  if (!ctx) throw new Error("useNavPreferences must be used within NavPreferencesProvider");
  return ctx;
}
