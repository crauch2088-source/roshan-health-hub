import { useNavigate } from "@tanstack/react-router";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

import { GlobalSearchDialog } from "@/components/global-search-dialog";
import { flatNavItems } from "@/config/nav";
import { useAuth } from "@/lib/auth";

type CommandPaletteContextValue = {
  open: boolean;
  setOpen: (open: boolean) => void;
};

const CommandPaletteContext = createContext<CommandPaletteContextValue | null>(null);

/** Keyboard shortcut → route. Permission is resolved from the shared nav config. */
const SHORTCUT_ROUTES: Record<string, string> = {
  d: "/dashboard",
  p: "/patients",
  v: "/visits",
  a: "/appointments",
  b: "/billing",
  l: "/lab",
  h: "/pharmacy",
};

/**
 * Mounted once near the root of the authenticated app. Listens for
 * Ctrl+K / Cmd+K anywhere in the app and owns the single instance of
 * <GlobalSearchDialog>. Also registers a few navigation shortcuts that
 * mirror high-traffic destinations. Shortcuts fail closed: a user without
 * the module's read permission simply does not move, instead of landing on
 * an access-denied screen.
 */
export function CommandPaletteProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const { can } = useAuth();

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null;
      const typing =
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable);

      // Ctrl/Cmd+K — toggle global search
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((prev) => !prev);
        return;
      }

      // Navigation shortcuts only when not typing in a field
      if (typing) return;
      if (!(e.metaKey || e.ctrlKey) || !e.shiftKey) return;

      const path = SHORTCUT_ROUTES[e.key.toLowerCase()];
      if (!path) return;
      const perm = flatNavItems().find((item) => item.to === path)?.perm;
      if (perm && !can(perm)) return;
      e.preventDefault();
      void navigate({ to: path });
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [navigate, can]);


  return (
    <CommandPaletteContext.Provider value={{ open, setOpen }}>
      {children}
      <GlobalSearchDialog open={open} onOpenChange={setOpen} />
    </CommandPaletteContext.Provider>
  );
}

export function useCommandPalette(): CommandPaletteContextValue {
  const ctx = useContext(CommandPaletteContext);
  if (!ctx) throw new Error("useCommandPalette must be used within CommandPaletteProvider");
  return ctx;
}
