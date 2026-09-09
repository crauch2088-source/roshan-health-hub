import {
  Activity,
  BarChart3,
  Banknote,
  CalendarDays,
  ClipboardList,
  FileText,
  FlaskConical,
  Handshake,
  Landmark,
  LayoutDashboard,
  ListOrdered,
  Pill,
  Receipt,
  ScrollText,
  Settings,
  Stethoscope,
  UserRound,
  Users,
  Warehouse,
  Wallet,
  type LucideIcon,
} from "lucide-react";

/**
 * Maps the icon *names* stored in config/nav.ts (plain strings, so they're
 * safe to serialize/log) to the actual lucide components. Add new icons
 * here, not by importing lucide directly in nav.ts.
 */
const NAV_ICONS: Record<string, LucideIcon> = {
  Activity,
  BarChart3,
  Banknote,
  CalendarDays,
  ClipboardList,
  FileText,
  FlaskConical,
  Handshake,
  Landmark,
  LayoutDashboard,
  ListOrdered,
  Pill,
  Receipt,
  ScrollText,
  Settings,
  Stethoscope,
  UserRound,
  Users,
  Warehouse,
  Wallet,
};

export function getNavIcon(name: string | undefined): LucideIcon {
  if (!name) return Activity;
  return NAV_ICONS[name] ?? Activity;
}

export default NAV_ICONS;
