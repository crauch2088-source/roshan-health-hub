/**
 * The one active-route matcher shared by the desktop rail, the mobile bottom
 * bar, the More sheet, the breadcrumbs and the command palette. Pure and
 * dependency-free so it can be unit tested with `node --test`.
 */

/** Path only: no query string or hash, and no trailing slash (except "/"). */
export function normalizePath(path: string): string {
  const clean = (path.split(/[?#]/)[0] ?? "").replace(/\/+$/, "");
  return clean === "" ? "/" : clean;
}

/**
 * True for the exact route and for nested/detail routes (/patients/123), but
 * never for a sibling that merely shares a prefix (/lab-catalog is not /lab).
 */
export function isNavItemActive(pathname: string, to: string): boolean {
  const current = normalizePath(pathname);
  const target = normalizePath(to);
  return current === target || current.startsWith(`${target}/`);
}

/** The most specific matching item (longest path wins), or undefined. */
export function matchNavItem<T extends { to: string }>(
  pathname: string,
  items: readonly T[],
): T | undefined {
  let best: T | undefined;
  for (const item of items) {
    if (!isNavItemActive(pathname, item.to)) continue;
    if (!best || normalizePath(item.to).length > normalizePath(best.to).length) best = item;
  }
  return best;
}
