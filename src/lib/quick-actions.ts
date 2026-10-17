import { navPermissionForRoute } from "@/config/nav";

const FLAG_PREFIX = "roshan:quick-action:";
const QUICK_ACTION_EVENT = "roshan:quick-action";

export type QuickActionKey = "new_patient" | "new_visit" | "new_invoice";
export type QuickAction = { key: QuickActionKey; labelKey: string; to: string; icon: string; permission: string };

export const QUICK_ACTIONS: QuickAction[] = [
  { key: "new_patient", labelKey: "new_patient", to: "/patients", icon: "UserRound", permission: "patients.create" },
  { key: "new_visit", labelKey: "new_visit", to: "/visits", icon: "ClipboardList", permission: "visits.create" },
  { key: "new_invoice", labelKey: "new_invoice", to: "/billing", icon: "Receipt", permission: "billing.create" },
];

/** Require both route visibility and the permission needed to create the record. */
export function getAvailableQuickActions(can: (permission: string) => boolean): QuickAction[] {
  return QUICK_ACTIONS.filter((action) => {
    const readPermission = navPermissionForRoute(action.to);
    return Boolean(readPermission && can(readPermission) && can(action.permission));
  });
}

/**
 * The command palette navigates to a plain route (e.g. /patients) — it has
 * no reference to that page's local dialog state. So it "arms" a one-shot
 * flag in sessionStorage before navigating; the destination page checks
 * (and immediately clears) that flag on mount and opens its own create
 * dialog. This avoids a second, parallel "create patient" implementation
 * living inside the palette itself.
 */
export function armQuickAction(key: QuickActionKey): void {
  try {
    window.sessionStorage.setItem(FLAG_PREFIX + key, "1");
  } catch {
    // Best-effort — the event below still works when the destination is already mounted.
  }
  try {
    window.dispatchEvent(new CustomEvent(QUICK_ACTION_EVENT, { detail: key }));
  } catch {
    // Server rendering and restricted browser contexts can lack CustomEvent.
  }
}

export function consumeQuickAction(key: QuickActionKey): boolean {
  try {
    const flag = window.sessionStorage.getItem(FLAG_PREFIX + key);
    if (flag) window.sessionStorage.removeItem(FLAG_PREFIX + key);
    return Boolean(flag);
  } catch {
    return false;
  }
}


/** Consume a pending action on mount and also handle actions triggered while this route is already open. */
export function listenForQuickAction(key: QuickActionKey, onAction: () => void): () => void {
  if (typeof window === "undefined") return () => undefined;
  const consume = () => {
    if (consumeQuickAction(key)) onAction();
  };
  const onEvent = (event: Event) => {
    if ((event as CustomEvent<QuickActionKey>).detail !== key) return;
    consumeQuickAction(key);
    onAction();
  };
  consume();
  window.addEventListener(QUICK_ACTION_EVENT, onEvent);
  return () => window.removeEventListener(QUICK_ACTION_EVENT, onEvent);
}
