import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const nav = read("../src/config/nav.ts");
const i18n = read("../src/lib/i18n.tsx");
const quickActions = read("../src/lib/quick-actions.ts");
const mobileNav = read("../src/components/mobile-bottom-nav.tsx");
const appShell = read("../src/components/app-shell.tsx");
const kit = read("../src/components/kit.tsx");
const dialog = read("../src/components/ui/dialog.tsx");
const routeMatrix = read("../docs/UX_ROUTE_ACCEPTANCE_MATRIX_2026-10-27.md");

const routeFiles = readdirSync(new URL("../src/routes/_authenticated/", import.meta.url)).filter(
  (name) => name.endsWith(".tsx") && name !== "route.tsx",
);
const publicFiles = ["index.tsx", "auth.tsx", "setup.tsx"];
const entries = [...nav.matchAll(/to:\s*"([^"]+)",\s*key:\s*"([^"]+)",\s*perm:\s*"([^"]+)"/g)].map(
  (match) => ({ to: match[1], key: match[2], perm: match[3] }),
);

const detailRoutes = [
  { to: "/patients/$patientId", file: "patients_.$patientId.tsx", permission: "patients.read" },
  { to: "/clinic/$visitId", file: "clinic_.$visitId.tsx", permission: "visits.read" },
  { to: "/lab/$orderId", file: "lab_.$orderId.tsx", permission: "lab.read" },
  { to: "/billing/$invoiceId", file: "billing_.$invoiceId.tsx", permission: "billing.read" },
] as const;

function sourceForRoute(to: string) {
  if (to === "/dashboard") return "../src/routes/_authenticated/dashboard.tsx";
  const name = to.slice(1).replace(/\/\$/g, "_.$").replaceAll("/", "-");
  return "../src/routes/_authenticated/" + name + ".tsx";
}

test("UX acceptance matrix stays in sync with every route file and navigation destination", () => {
  for (const name of routeFiles) {
    assert.ok(
      routeMatrix.includes("src/routes/_authenticated/" + name),
      "Acceptance matrix is missing authenticated route file " + name,
    );
  }
  for (const name of publicFiles) {
    assert.ok(
      routeMatrix.includes("src/routes/" + name),
      "Acceptance matrix is missing public route file " + name,
    );
  }
  for (const entry of entries) {
    assert.ok(
      routeMatrix.includes("| `" + entry.to + "` |"),
      "Acceptance matrix is missing navigation destination " + entry.to,
    );
  }
  assert.match(routeMatrix, /NOT TESTED/);
  assert.match(routeMatrix, /BLOCKED\/DEFERRED/);
});

test("Phase 42 inventories all real page routes and verifies nav permission gates", () => {
  for (const name of publicFiles) {
    assert.ok(read("../src/routes/" + name).length > 0);
  }
  assert.ok(
    routeFiles.length >= 25,
    "Authenticated page inventory should contain at least 25 routes; found " + routeFiles.length,
  );
  for (const detail of [
    "patients_.$patientId.tsx",
    "billing_.$invoiceId.tsx",
    "lab_.$orderId.tsx",
    "clinic_.$visitId.tsx",
  ]) {
    assert.ok(routeFiles.includes(detail), "Missing detail route " + detail);
  }
  for (const entry of entries) {
    const source = read(sourceForRoute(entry.to));
    assert.ok(
      source.includes('PermissionGate perm="' + entry.perm + '"'),
      entry.to + " must be guarded by " + entry.perm,
    );
  }
  assert.match(read("../src/routes/_authenticated/route.tsx"), /useAuth|redirect|beforeLoad/);
});

test("detail routes enforce explicit read permissions and the acceptance matrix documents each guard", () => {
  for (const detail of detailRoutes) {
    const source = read("../src/routes/_authenticated/" + detail.file);
    assert.match(
      source,
      new RegExp('<PermissionGate\\s+perm="' + detail.permission + '"'),
      detail.to + " must enforce " + detail.permission,
    );
    const row = routeMatrix.split("\n").find((line) => line.startsWith("| `" + detail.to + "` |"));
    assert.ok(row, "Acceptance matrix is missing detail route " + detail.to);
    assert.ok(
      row.includes("`" + detail.permission + "`"),
      detail.to + " must list its configured permission",
    );
    assert.ok(
      row.includes("SOURCE-GUARDED"),
      detail.to + " must be marked SOURCE-GUARDED after the source assertion",
    );
  }
});

test("navigation and quick-action keys have distinct, non-empty Arabic and English translations", () => {
  const dict = new Map(
    [...i18n.matchAll(/^\s*([a-zA-Z0-9_]+):\s*\{\s*ar:\s*"([^"]+)",\s*en:\s*"([^"]+)"/gm)].map(
      (match) => [match[1], { ar: match[2].trim(), en: match[3].trim() }],
    ),
  );
  const keys = new Set(
    [...nav.matchAll(/key:\s*"([^"]+)"/g)]
      .map((match) => match[1])
      .concat(
        [...nav.matchAll(/group:\s*"([^"]+)"/g)].map((match) => match[1]),
        [...quickActions.matchAll(/labelKey:\s*"([^"]+)"/g)].map((match) => match[1]),
      ),
  );
  for (const key of keys) {
    const value = dict.get(key);
    assert.ok(value && value.ar && value.en, "Missing Arabic/English translation for " + key);
    assert.notEqual(value.ar, value.en, "Unexpected identical Arabic/English text for " + key);
  }
});

test("mobile ergonomics, skip link, LTR token and dialog accessibility contracts are present", () => {
  assert.match(mobileNav, /grid-cols-3 gap-2 min-\[360px\]:grid-cols-4/);
  assert.match(appShell, /skip_to_content/);
  assert.match(appShell, /id="main-content"/);
  assert.match(appShell, /<div className="min-w-0 flex-1 overflow-hidden">\s*<BreadcrumbNav \/>/);
  assert.match(kit, /export function LtrText/);
  assert.match(kit, /dir="ltr" className=\{cn\("inline-block font-mono tabular-nums"/);
  assert.match(kit, /break-words text-sm font-semibold text-foreground/);
  assert.match(dialog, /aria-label="Close dialog \/ إغلاق النافذة"/);
  assert.doesNotMatch(dialog, /sr-only">Close</);
  assert.match(dialog, /sticky bottom-0/);
});

test("primary clinical and financial pages explicitly handle LTR identifiers", () => {
  const pages = [
    "patients.tsx",
    "patients_.$patientId.tsx",
    "visits.tsx",
    "clinic.tsx",
    "billing.tsx",
    "billing_.$invoiceId.tsx",
    "lab.tsx",
    "lab_.$orderId.tsx",
    "certificates.tsx",
  ];
  for (const page of pages) {
    const source = read("../src/routes/_authenticated/" + page);
    assert.match(
      source,
      /dir="ltr"|<LtrText|<bdi dir="ltr">/,
      page + " must render identifiers in LTR context",
    );
  }
});

test("Phase 44 public auth/setup pages use POST forms, skip links, semantic main landmarks and secure setup-denial handling", () => {
  const authPage = read("../src/routes/auth.tsx");
  const setupPage = read("../src/routes/setup.tsx");

  for (const [page, id] of [
    [authPage, "auth-card"],
    [setupPage, "setup-card"],
  ] as const) {
    assert.match(page, /<form method="POST" onSubmit=\{submit\}/);
    assert.match(page, /href="#/);
    assert.match(page, /skip_to_content/);
    assert.match(page, new RegExp('<main\\s+id="' + id + '"'));
  }

  assert.match(
    setupPage,
    /e instanceof Error && \/permission denied\/i\.test\(e\.message\)[\s\S]*?setRequired\(false\)[\s\S]*?return;/,
    "permission-denied from setup_required must mark setup as not required without exposing an error",
  );
  assert.match(
    setupPage,
    /setCheckFailed\(true\)/,
    "non-permission setup-status errors must enter the retry state without changing denial handling",
  );

  for (const [field, autoComplete] of [
    ["full_name", "name"],
    ["email", "email"],
    ["phone", "tel"],
    ["password", "new-password"],
  ] as const) {
    const start = setupPage.indexOf(`<Field label={t("${field}")}>`);
    assert.notEqual(start, -1, `setup field ${field} must remain present`);
    const end = setupPage.indexOf("</Field>", start);
    assert.ok(end > start, `setup field ${field} must have a closing field wrapper`);
    assert.match(
      setupPage.slice(start, end),
      new RegExp(`autoComplete="${autoComplete}"`),
      `setup field ${field} must expose the ${autoComplete} autocomplete token`,
    );
  }
});

test("public setup does not misreport a failed status check as complete and offers retry", () => {
  const setupPage = read("../src/routes/setup.tsx");
  const failureBranch = setupPage.indexOf("checkFailed ? (");
  const completedBranch = setupPage.indexOf(": !required ? (");

  assert.ok(failureBranch >= 0, "setup status failure must have its own UI state");
  assert.ok(
    completedBranch > failureBranch,
    "failure state must be checked before setup-complete state",
  );
  assert.match(setupPage, /setCheckFailed\(true\)/, "non-permission RPC failures must be recorded");
  assert.match(
    setupPage,
    /onClick=\{\(\) => void checkSetupRequired\(\)\}/,
    "staff must be able to retry the status check",
  );
  assert.match(
    setupPage.slice(failureBranch, completedBranch),
    /t\("retry"\)/,
    "retry action must have a localized label",
  );
});

test("public root routes setup-status failures to the setup retry path", () => {
  const landingPage = read("../src/routes/index.tsx");

  assert.match(
    landingPage,
    /\.catch\(\(\) => \{[\s\S]*?void navigate\(\{ to: "\/setup", replace: true \}\);/,
    "root must route a failed setup-status check to the recovery screen, not hide setup on sign-in",
  );
});

test("public auth preserves a first-run recovery path when setup status cannot be checked", () => {
  const authPage = read("../src/routes/auth.tsx");
  const failureBranch = authPage.indexOf("setupCheckFailed ? (");
  const setupNeededBranch = authPage.indexOf("setupNeeded ? (");

  assert.ok(failureBranch >= 0, "auth must expose the status-check failure state");
  assert.ok(
    setupNeededBranch > failureBranch,
    "failure recovery must not depend on a successful check",
  );
  assert.match(authPage, /catch\(\(\) => setSetupCheckFailed\(true\)\)/);
  assert.match(
    authPage,
    /onClick=\{\(\) => void navigate\(\{ to: "\/setup" \}\)\}/,
    "auth must link to setup's safe retry/completion state",
  );
});

test("public setup never passes backend error text to the rendered ErrorBox", () => {
  const setupPage = read("../src/routes/setup.tsx");
  const errorAssignments = Array.from(
    setupPage.matchAll(/setError\(([\s\S]*?)\);/g),
    ([, expression]) => expression.trim(),
  );

  assert.match(setupPage, /<ErrorBox error=\{error\} \/>/);
  assert.ok(errorAssignments.length > 0, "setup error state remains explicitly controlled");
  assert.ok(
    errorAssignments.every(
      (expression) => expression === "null" || expression.startsWith('lang === "ar"'),
    ),
    "only cleared state or fixed localized copy may reach the public setup ErrorBox",
  );
  assert.doesNotMatch(setupPage, /throw new Error\(suErr\.message\)|\$\{siErr\.message\}/);
  assert.match(
    setupPage,
    /console\.warn\("\[public\/setup\] status check failed; server details suppressed"\)/,
  );
  assert.match(
    setupPage,
    /console\.warn\("\[public\/setup\] first-run submission failed; server details suppressed"\)/,
  );
});

test("public auth does not pass backend error text to its rendered ErrorBox", () => {
  const authPage = read("../src/routes/auth.tsx");
  const errorAssignments = Array.from(
    authPage.matchAll(/setError\(([\s\S]*?)\);/g),
    ([, expression]) => expression.trim(),
  );

  assert.match(authPage, /<ErrorBox error=\{error\} \/>/);
  assert.ok(errorAssignments.length > 0, "auth error state remains explicitly controlled");
  assert.ok(
    errorAssignments.every(
      (expression) => expression === "null" || expression.startsWith('lang === "ar"'),
    ),
    "only cleared state or fixed localized copy may reach the public auth ErrorBox",
  );
  assert.doesNotMatch(authPage, /new Error\(e[23]\.message\)/);
  assert.match(
    authPage,
    /console\.warn\(`\[public\/auth\] \$\{mode\} failed; server details suppressed`\)/,
  );
});
