// Small pure layout rules for the navigation chrome, kept out of the components so they can
// be unit tested with `node --test` (see tests/nav-layout.test.ts).

/** The rail sits at the inline-start edge: right in Arabic (RTL), left in English (LTR). */
export function railTooltipSide(lang: string): "left" | "right" {
  // A tooltip must open towards the page content, i.e. away from the rail's edge.
  return lang === "ar" ? "left" : "right";
}

/** One equal column per visible primary destination, plus the More button. */
export function bottomBarColumns(primaryCount: number): string {
  const count = Math.max(0, Math.floor(primaryCount)) + 1;
  return `repeat(${count}, minmax(0, 1fr))`;
}

/**
 * The mobile bottom bar has room for four destinations plus More. Pick the first
 * `max` entries of `priority` the user may open, so a pharmacist or lab assistant
 * (who cannot open Patients/Visits) still gets their own module on the bar instead
 * of a bar that is mostly empty. Permissions are only *read* here: whatever is not
 * picked stays reachable through More, and routes are still gated by PermissionGate.
 */
export function pickPrimaryRoutes(
  priority: readonly string[],
  isAllowed: (to: string) => boolean,
  max = 4,
): string[] {
  const picked: string[] = [];
  for (const to of priority) {
    if (picked.length >= max) break;
    if (!picked.includes(to) && isAllowed(to)) picked.push(to);
  }
  return picked;
}

export type NavTrailStep = { kind: "home" | "module" | "section" | "detail"; to?: string };

/**
 * Structure of the header breadcrumb: Home › Module › Section › (Detail).
 * Module is a label only (modules have no route of their own). The detail step
 * appears on nested routes such as /patients/<id>.
 */
export function navTrail(opts: {
  hasHome: boolean;
  moduleKey: string | undefined;
  sectionTo: string;
  onSection: boolean;
}): NavTrailStep[] {
  const steps: NavTrailStep[] = [];
  if (opts.hasHome) steps.push({ kind: "home", to: "/dashboard" });
  if (opts.moduleKey) steps.push({ kind: "module" });
  steps.push({ kind: "section", to: opts.sectionTo });
  if (!opts.onSection) steps.push({ kind: "detail" });
  return steps;
}
