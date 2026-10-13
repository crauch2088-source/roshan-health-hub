import { Link, useLocation } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Fragment } from "react";

import { flatNavItems, HOME_ITEM, NAV_GROUPS } from "@/config/nav";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";
import { matchNavItem, normalizePath } from "@/lib/nav-active";
import { navTrail } from "@/lib/nav-layout";

/**
 * Home › Module › Section › Details. The module is a plain label (modules have no
 * route); the detail step appears on nested routes such as /patients/<id>. Below
 * `sm` only the section (and detail) remain, so the trail never wraps or clips.
 *
 * Sections the user cannot read are never linked here: the trail must not offer a
 * jump that the destination PermissionGate will refuse.
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
  const moduleKey = NAV_GROUPS.find((g) => g.items.some((i) => i.to === current.to))?.group;
  const steps = navTrail({
    hasHome: can(HOME_ITEM.perm),
    moduleKey,
    sectionTo: current.to,
    onSection,
  });
  const last = steps.length - 1;

  const linkCls =
    "rounded-sm outline-none transition-colors hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring";

  return (
    <nav className="no-print min-w-0 text-sm text-muted-foreground" aria-label={t("breadcrumb")}>
      <ol className="flex min-w-0 items-center gap-1.5">
        {steps.map((step, i) => {
          const isLast = i === last;
          // Home and module are context, not needed on a phone.
          const hideOnPhone = step.kind === "home" || step.kind === "module";
          return (
            <Fragment key={step.kind}>
              <li
                className={`min-w-0 items-center gap-1.5 ${hideOnPhone ? "hidden sm:flex" : "flex"} ${
                  step.kind === "module" ? "hidden md:flex" : ""
                }`}
              >
                {step.kind === "home" ? (
                  <Link to={HOME_ITEM.to} className={linkCls}>
                    {t(HOME_ITEM.key)}
                  </Link>
                ) : step.kind === "module" ? (
                  <span>{t(moduleKey ?? "")}</span>
                ) : step.kind === "section" ? (
                  <Link
                    to={current.to}
                    aria-current={isLast ? "page" : undefined}
                    className={`block truncate ${linkCls} ${isLast ? "font-semibold text-foreground" : ""}`}
                  >
                    {t(current.key)}
                  </Link>
                ) : (
                  <span aria-current="page" className="truncate font-semibold text-foreground">
                    {t("details")}
                  </span>
                )}
                {!isLast ? (
                  <Chevron
                    className={`size-3.5 shrink-0 text-muted-foreground/60 ${
                      step.kind === "home" ? "hidden sm:block" : ""
                    } ${step.kind === "module" ? "hidden md:block" : ""}`}
                    aria-hidden
                  />
                ) : null}
              </li>
            </Fragment>
          );
        })}
      </ol>
    </nav>
  );
}
