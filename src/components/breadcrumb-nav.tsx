import { Link, useLocation } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { flatNavItems, HOME_ITEM } from "@/config/nav";
import { useLang } from "@/lib/i18n";

/**
 * A single-level trail (Home / Current section) rather than a full path
 * parser — this app's routes are flat enough (/patients, /billing/:id)
 * that a deep breadcrumb would just repeat the page title. Detail routes
 * (e.g. /patients/$patientId) still show their parent section.
 */
export function BreadcrumbNav() {
  const { t, lang } = useLang();
  const location = useLocation();
  const Chevron = lang === "ar" ? ChevronLeft : ChevronRight;

  if (location.pathname === HOME_ITEM.to) return null;

  const items = flatNavItems();
  const current =
    items.find((item) => location.pathname === item.to) ??
    items.find((item) => location.pathname.startsWith(`${item.to}/`));

  if (!current) return null;

  return (
    <nav className="no-print flex items-center gap-1 text-sm text-muted-foreground">
      <Link to={HOME_ITEM.to} className="hover:text-foreground">
        {t(HOME_ITEM.key)}
      </Link>
      <Chevron className="size-3.5" />
      <Link to={current.to} className="font-medium text-foreground hover:underline">
        {t(current.key)}
      </Link>
    </nav>
  );
}
