import { useNavigate } from "@tanstack/react-router";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

import { GlobalSearchDialog } from "@/components/global-search-dialog";

type CommandPaletteContextValue = {
  open: boolean;
  setOpen: (open: boolean) => void;
};

const CommandPaletteContext = createContext<CommandPaletteContextValue | null>(null);

/**
 * Mounted once near the root of the authenticated app. Listens for
 * Ctrl+K / Cmd+K anywhere in the app and owns the single instance of
 * <GlobalSearchDialog>. Also registers a few navigation shortcuts that
 * mirror high-traffic destinations (fail closed if the user lacks access —
 * the target page PermissionGate still applies).
 */
export function CommandPaletteProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();

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

      const map: Record<string, string> = {
        d: "/dashboard",
        p: "/patients",
        v: "/visits",
        a: "/appointments",
        b: "/billing",
        l: "/lab",
        h: "/pharmacy",
      };
      const path = map[e.key.toLowerCase()];
      if (path) {
        e.preventDefault();
        void navigate({ to: path });
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [navigate]);

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
