const FLAG_PREFIX = "roshan:quick-action:";

export type QuickActionKey = "new_patient" | "new_visit" | "new_invoice" | "new_lab_order";

export const QUICK_ACTIONS: { key: QuickActionKey; labelKey: string; to: string; icon: string }[] = [
  { key: "new_patient", labelKey: "new_patient", to: "/patients", icon: "UserRound" },
  { key: "new_visit", labelKey: "new_visit", to: "/visits", icon: "ClipboardList" },
  { key: "new_invoice", labelKey: "new_invoice", to: "/billing", icon: "Receipt" },
  { key: "new_lab_order", labelKey: "new_lab_order", to: "/lab", icon: "FlaskConical" },
];

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
    // Best-effort — worst case the destination page just doesn't auto-open.
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
