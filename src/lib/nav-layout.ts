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
