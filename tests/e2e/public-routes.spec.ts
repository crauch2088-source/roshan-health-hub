import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const widths = [320, 360, 390, 430] as const;
const trustedToken = process.env.VERCEL_TRUSTED_OIDC_TOKEN;

async function protectPreviewRequests(page: Page) {
  if (!trustedToken) return;

  const configuredBaseURL = process.env.BASE_URL ?? "http://127.0.0.1:5173";
  const targetOrigin = new URL(configuredBaseURL).origin;

  await page.route("**/*", async (route) => {
    const requestURL = new URL(route.request().url());
    if (requestURL.origin !== targetOrigin) {
      await route.continue();
      return;
    }

    await route.continue({
      headers: {
        ...route.request().headers(),
        "x-vercel-trusted-oidc-idp-token": trustedToken,
        "x-vercel-set-bypass-cookie": "true",
      },
    });
  });
}

async function expectNoHorizontalOverflow(page: Page) {
  const overflow = await page.evaluate(
    () =>
      Math.max(document.documentElement.scrollWidth, document.body?.scrollWidth ?? 0) >
      window.innerWidth + 1,
  );
  expect(overflow, "page should not overflow horizontally").toBe(false);
}

async function expectNoPublicErrorDisclosure(page: Page) {
  const bodyText = await page.locator("body").innerText();
  expect(bodyText).not.toMatch(
    /PostgrestError|PGRST\d+|permission denied|JWT expired|stack trace|SUPABASE_SERVICE_ROLE_KEY|service_role/i,
  );
}

async function expectAccessible(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  expect(
    results.violations.map(
      (violation) =>
        violation.id +
        " (" +
        (violation.impact ?? "unknown") +
        "): " +
        violation.nodes.map((node) => node.target.join(" ")).join(", "),
    ),
    "public route should have no WCAG 2.1 A/AA automated violations",
  ).toEqual([]);
}

for (const width of widths) {
  test.describe("public route acceptance at " + width + "px", () => {
    test.beforeEach(async ({ page }) => {
      await page.setViewportSize({ width, height: 844 });
      await protectPreviewRequests(page);
    });

    test("root recovers to an intentional public route", async ({ page }) => {
      await page.goto("/", { waitUntil: "domcontentloaded" });

      await expect
        .poll(() => new URL(page.url()).pathname, { timeout: 12_000 })
        .toMatch(/^\/(auth|setup)$/);

      await expectNoHorizontalOverflow(page);
      await expectNoPublicErrorDisclosure(page);
    });

    test("Arabic and English sign-in routes are accessible and usable", async ({ page }) => {
      const pageErrors: string[] = [];
      page.on("pageerror", (error) => pageErrors.push(error.message));

      await page.goto("/auth", { waitUntil: "domcontentloaded" });

      await expect(page.getByRole("button", { name: /تسجيل الدخول|sign in/i })).toBeVisible();
      await expect(page.locator('input[type="email"]')).toHaveAttribute("autocomplete", "username");
      await expect(page.locator('input[type="password"]')).toHaveAttribute(
        "autocomplete",
        "current-password",
      );

      await expect(page.locator("html")).toHaveAttribute("lang", "ar");
      await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
      await expectNoHorizontalOverflow(page);
      await expectNoPublicErrorDisclosure(page);
      await expectAccessible(page);

      await page.getByRole("button", { name: /english/i }).click();
      await expect(page.locator("html")).toHaveAttribute("lang", "en");
      await expect(page.locator("html")).toHaveAttribute("dir", "ltr");
      await expectNoHorizontalOverflow(page);
      await expectAccessible(page);
      expect(pageErrors).toEqual([]);
    });

    test("setup recovery page does not leak provider errors and meets WCAG AA", async ({
      page,
    }) => {
      await page.goto("/setup", { waitUntil: "domcontentloaded" });

      await expect(page.locator("body")).toContainText(
        /التهيئة الأولى للنظام|first.time setup|setup/i,
      );
      await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
      await expectNoHorizontalOverflow(page);
      await expectNoPublicErrorDisclosure(page);
      await expectAccessible(page);
    });

    test("protected dashboard redirects unauthenticated visitors", async ({ page }) => {
      await page.goto("/dashboard", { waitUntil: "domcontentloaded" });

      await expect
        .poll(() => new URL(page.url()).pathname, { timeout: 12_000 })
        .toMatch(/^\/(auth|setup)$/);
    });
  });
}
