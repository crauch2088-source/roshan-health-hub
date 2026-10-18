import { useNavigate } from "@tanstack/react-router";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

import { GlobalSearchDialog } from "@/components/global-search-dialog";
import { navPermissionForRoute } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { resolveKeyboardShortcut } from "@/lib/keyboard-shortcuts";

type CommandPaletteContextValue = {
  open: boolean;
  setOpen: (open: boolean) => void;
};

const CommandPaletteContext = createContext<CommandPaletteContextValue | null>(null);

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
      const typing = Boolean(
        target &&
          (target.tagName === "INPUT" ||
            target.tagName === "TEXTAREA" ||
            target.tagName === "SELECT" ||
            target.isContentEditable),
      );
      const action = resolveKeyboardShortcut(
        {
          code: e.code,
          ctrlKey: e.ctrlKey,
          metaKey: e.metaKey,
          shiftKey: e.shiftKey,
          altKey: e.altKey,
          isComposing: e.isComposing,
          repeat: e.repeat,
          typing,
        },
        can,
        navPermissionForRoute,
      );
      if (action.type === "none") return;
      e.preventDefault();
      if (action.type === "search") {
        setOpen((prev) => !prev);
        return;
      }
      void navigate({ to: action.path });
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
