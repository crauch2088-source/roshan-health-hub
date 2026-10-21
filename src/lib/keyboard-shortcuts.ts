export type TabNavigationDirection = "ltr" | "rtl";

/** Return the next tab index for an ARIA tablist key, or -1 when unhandled. */
export function resolveTabKeyNavigation(
  key: string,
  index: number,
  count: number,
  dir: TabNavigationDirection,
): number {
  if (count <= 0 || index < 0 || index >= count) return -1;
  if (key === "Home") return 0;
  if (key === "End") return count - 1;
  if (key === "ArrowUp") return (index - 1 + count) % count;
  if (key === "ArrowDown") return (index + 1) % count;
  if (key === "ArrowLeft") {
    return dir === "rtl" ? (index + 1) % count : (index - 1 + count) % count;
  }
  if (key === "ArrowRight") {
    return dir === "rtl" ? (index - 1 + count) % count : (index + 1) % count;
  }
  return -1;
}

export type KeyboardShortcutInput = {
  code: string;
  ctrlKey: boolean;
  metaKey: boolean;
  shiftKey: boolean;
  altKey: boolean;
  isComposing: boolean;
  repeat: boolean;
  typing: boolean;
};

export type KeyboardShortcutAction =
  { type: "none" } | { type: "search" } | { type: "navigate"; path: string };

/**
 * Resolve shortcuts from physical key codes rather than `event.key`, which
 * changes with the active keyboard layout (notably Arabic layouts).
 */
const SHORTCUT_ROUTES: Record<string, string> = {
  KeyD: "/dashboard",
  KeyP: "/patients",
  KeyV: "/visits",
  KeyA: "/appointments",
  KeyB: "/billing",
  KeyL: "/lab",
  KeyH: "/pharmacy",
};

export function resolveKeyboardShortcut(
  input: KeyboardShortcutInput,
  can: (permission: string) => boolean,
  permissionForRoute: (path: string) => string | undefined,
): KeyboardShortcutAction {
  if (input.isComposing || input.repeat) return { type: "none" };

  if ((input.metaKey || input.ctrlKey) && input.code === "KeyK") {
    return { type: "search" };
  }

  if (input.typing || !(input.metaKey || input.ctrlKey) || !input.shiftKey || input.altKey) {
    return { type: "none" };
  }

  const path = SHORTCUT_ROUTES[input.code];
  if (!path) return { type: "none" };

  const permission = permissionForRoute(path);
  if (!permission || !can(permission)) return { type: "none" };

  return { type: "navigate", path };
}
