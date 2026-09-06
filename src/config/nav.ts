export type NavConfigItem = {
  to: string;
  key: string;
  perm?: string;
  icon?: string;
};

export const NAV: { group: string; items: NavConfigItem[] }[] = [
  {
    group: "dashboard",
    items: [
      { to: "/dashboard", key: "dashboard", perm: "dashboard.read", icon: "LayoutDashboard" },
    ],
  },
  {
    group: "patients",
    items: [
      { to: "/patients", key: "patients", perm: "patients.read", icon: "UserRound" },
      { to: "/visits", key: "visits", perm: "visits.read", icon: "ClipboardList" },
      { to: "/queue", key: "queue", perm: "queue.read", icon: "ListOrdered" },
      { to: "/appointments", key: "appointments", perm: "appointments.read", icon: "CalendarDays" },
    ],
  },
  {
    group: "pharmacy",
    items: [
      { to: "/pharmacy", key: "pharmacy", perm: "pharmacy.read", icon: "Pill" },
      { to: "/inventory", key: "inventory", perm: "pharmacy.read", icon: "Warehouse" },
    ],
  },
  {
    group: "laboratory",
    items: [
      { to: "/lab", key: "laboratory", perm: "lab.read", icon: "FlaskConical" },
      { to: "/lab-catalog", key: "lab_catalog", perm: "lab_admin.read", icon: "ScrollText" },
    ],
  },
  {
    group: "billing",
    items: [
      { to: "/billing", key: "billing", perm: "billing.read", icon: "Receipt" },
      { to: "/accounting", key: "accounting", perm: "accounting.read", icon: "Landmark" },
      { to: "/expenses", key: "expenses", perm: "accounting.read", icon: "Wallet" },
      { to: "/reports", key: "reports", perm: "reports.read", icon: "BarChart3" },
    ],
  },
  {
    group: "settings",
    items: [
      { to: "/users", key: "users", perm: "users.read", icon: "Users" },
      { to: "/settings", key: "settings", perm: "settings.read", icon: "Settings" },
    ],
  },
];

export default NAV;
