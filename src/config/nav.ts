/**
 * Central navigation configuration — Phase 2. Every top-level route the
 * app links to lives here once, as data, so the rail, the mobile nav, the
 * command palette, and favorites/recents all read the same source instead
 * of each hard-coding its own list.
 */

export type NavConfigItem = {
  to: string;
  key: string;
  perm?: string;
  icon: string;
  /** false = shown in nav, but not offered as a favorite (e.g. Home). */
  favoritable?: boolean;
};

export type NavGroup = {
  group: string;
  items: NavConfigItem[];
};

export const HOME_ITEM: NavConfigItem = {
  to: "/dashboard",
  key: "dashboard",
  perm: "dashboard.read",
  icon: "LayoutDashboard",
  favoritable: false,
};

// Phase 20 — regrouped for clearer information architecture. Every `to`,
// `perm`, and `icon` value below is unchanged from before this pass, so
// routes, permission gates, deep links, and favorites (which key off `to`,
// not group) are unaffected — only which named group an item renders under
// in the NavRail/mobile "More" sheet changes.
export const NAV_GROUPS: NavGroup[] = [
  {
    group: "clinical",
    items: [
      { to: "/patients", key: "patients", perm: "patients.read", icon: "UserRound" },
      { to: "/visits", key: "visits", perm: "visits.read", icon: "ClipboardList" },
      { to: "/queue", key: "queue", perm: "queue.read", icon: "ListOrdered" },
      // Clinic lists visits for consultation. Gate on visits.read (not emr.read)
      // so reception and clinical roles both see it — same access as the Clinic
      // links already shown on the Visits table. Writing clinical notes remains
      // protected by emr RLS on clinical_notes / vitals tables.
      { to: "/clinic", key: "clinic", perm: "visits.read", icon: "Stethoscope" },
      { to: "/appointments", key: "appointments", perm: "appointments.read", icon: "CalendarDays" },
      { to: "/followups", key: "followups", perm: "followups.read", icon: "HeartPulse" },
      { to: "/certificates", key: "certificates", perm: "certificates.read", icon: "FileText" },
    ],
  },
  {
    // Was 3 separate top-level groups (pharmacy, laboratory, and insurance
    // living inside the old 8-item "finance" group) — merged into one
    // clinical-support group, the way these services are actually used
    // together around a visit.
    group: "clinical_services",
    items: [
      { to: "/pharmacy", key: "pharmacy", perm: "pharmacy.read", icon: "Pill" },
      { to: "/inventory", key: "inventory", perm: "pharmacy.read", icon: "Warehouse" },
      { to: "/lab", key: "laboratory", perm: "lab.read", icon: "FlaskConical" },
      { to: "/lab-catalog", key: "lab_catalog", perm: "lab_admin.read", icon: "ScrollText" },
      { to: "/insurance", key: "insurance", perm: "insurance.read", icon: "ShieldCheck" },
    ],
  },
  {
    group: "finance",
    items: [
      { to: "/billing", key: "billing", perm: "billing.read", icon: "Receipt" },
      { to: "/finance", key: "finance_hub", perm: "cashbox.read", icon: "Wallet" },
      { to: "/accounting", key: "accounting", perm: "accounting.read", icon: "Landmark" },
      { to: "/expenses", key: "expenses", perm: "accounting.read", icon: "Banknote" },
      { to: "/partners", key: "partners", perm: "partners.read", icon: "Handshake" },
    ],
  },
  {
    // Reports/Analytics were previously stranded inside "finance" even
    // though they cover clinical volume and lab activity too, not just
    // money — split out as their own group.
    group: "reporting",
    items: [
      { to: "/reports", key: "reports", perm: "reports.read", icon: "BarChart3" },
      { to: "/analytics", key: "analytics", perm: "reports.read", icon: "Activity" },
    ],
  },
  {
    group: "administration",
    items: [
      { to: "/users", key: "users", perm: "users.read", icon: "Users" },
      { to: "/audit", key: "audit_log", perm: "audit.read", icon: "ScrollText" },
      { to: "/settings", key: "settings", perm: "settings.read", icon: "Settings" },
    ],
  },
];

/** Back-compat export — some older code may still import the flat shape. */
export const NAV: NavGroup[] = NAV_GROUPS;

export function flatNavItems(): NavConfigItem[] {
  return NAV_GROUPS.flatMap((g) => g.items);
}

export default NAV_GROUPS;
