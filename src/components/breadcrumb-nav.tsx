import { Link, useLocation } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { flatNavItems, HOME_ITEM } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { matchNavItem, normalizePath } from "@/lib/nav-active";

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
  const current = matchNavItem(location.pathname, items);

  if (!current) return null;

  const onSection = normalizePath(location.pathname) === normalizePath(current.to);

  return (
    <nav
      className="no-print flex min-w-0 items-center text-sm text-muted-foreground"
      aria-label={t("breadcrumb")}
    >
      <ol className="flex min-w-0 items-center gap-1">
        {can(HOME_ITEM.perm) ? (
          <li className="hidden items-center gap-1 sm:flex">
            <Link
              to={HOME_ITEM.to}
              className="rounded-sm hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              {t(HOME_ITEM.key)}
            </Link>
            <Chevron className="size-3.5 shrink-0" aria-hidden />
          </li>
        ) : null}
        <li className="min-w-0">
          <Link
            to={current.to}
            aria-current={onSection ? "page" : undefined}
            className="block truncate rounded-sm font-medium text-foreground hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {t(current.key)}
          </Link>
        </li>
      </ol>
    </nav>
  );
}
