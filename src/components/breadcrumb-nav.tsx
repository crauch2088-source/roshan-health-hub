import { Link, useLocation } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { flatNavItems, HOME_ITEM } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";

/**
 * A single-level trail (Home / Current section) rather than a full path
 * parser — this app's routes are flat enough (/patients, /billing/:id)
 * that a deep breadcrumb would just repeat the page title. Detail routes
 * (e.g. /patients/$patientId) still show their parent section.
 *
 * Sections the user cannot read are never linked here: the trail must not
 * offer a jump that the destination PermissionGate will refuse.
 */
export function BreadcrumbNav() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const location = useLocation();
  const Chevron = lang === "ar" ? ChevronLeft : ChevronRight;

  if (location.pathname === HOME_ITEM.to) return null;

  const items = flatNavItems().filter((item) => can(item.perm));
  const current =
    items.find((item) => location.pathname === item.to) ??
    items.find((item) => location.pathname.startsWith(`${item.to}/`));

  if (!current) return null;

  const onSection = location.pathname === current.to;

  return (
    <nav className="no-print flex min-w-0 items-center gap-1 text-sm text-muted-foreground" aria-label={t("navigation")}>
      {can(HOME_ITEM.perm) ? (
        <>
          <Link to={HOME_ITEM.to} className="hidden rounded-sm hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:inline">
            {t(HOME_ITEM.key)}
          </Link>
          <Chevron className="hidden size-3.5 shrink-0 sm:inline" aria-hidden />
        </>
      ) : null}
      <Link
        to={current.to}
        aria-current={onSection ? "page" : undefined}
        className="truncate rounded-sm font-medium text-foreground hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {t(current.key)}
      </Link>
    </nav>
  );
}

