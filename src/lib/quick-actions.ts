const FLAG_PREFIX = "roshan:quick-action:";
const QUICK_ACTION_EVENT = "roshan:quick-action";

export type QuickActionKey = "new_patient" | "new_visit" | "new_invoice" | "new_lab_order";
export type QuickAction = {
  key: QuickActionKey;
  labelKey: string;
  to: string;
  icon: string;
  readPermission: string;
  permission: string;
};

export const QUICK_ACTIONS: QuickAction[] = [
  {
    key: "new_patient",
    labelKey: "new_patient",
    to: "/patients",
    icon: "UserRound",
    readPermission: "patients.read",
    permission: "patients.create",
  },
  {
    key: "new_visit",
    labelKey: "new_visit",
    to: "/visits",
    icon: "ClipboardList",
    readPermission: "visits.read",
    permission: "visits.create",
  },
  {
    key: "new_invoice",
    labelKey: "new_invoice",
    to: "/billing",
    icon: "Receipt",
    readPermission: "billing.read",
    permission: "billing.create",
  },
  {
    key: "new_lab_order",
    labelKey: "new_lab_order",
    to: "/visits",
    icon: "FlaskConical",
    readPermission: "visits.read",
    permission: "lab.create",
  },
];

/** Require both route visibility and the permission needed to create the record. */
export function getAvailableQuickActions(can: (permission: string) => boolean): QuickAction[] {
  return QUICK_ACTIONS.filter((action) => can(action.readPermission) && can(action.permission));
}

/**
 * Store a one-shot action before navigation and broadcast it for routes that are
 * already mounted. This keeps creation state inside each destination page.
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
