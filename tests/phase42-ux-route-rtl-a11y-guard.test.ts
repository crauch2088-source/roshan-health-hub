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

const routeFiles = readdirSync(new URL("../src/routes/_authenticated/", import.meta.url)).filter(
  (name) => name.endsWith(".tsx") && name !== "route.tsx",
);
const publicFiles = ["index.tsx", "auth.tsx", "setup.tsx"];
const entries = [...nav.matchAll(/to:\s*"([^"]+)",\s*key:\s*"([^"]+)",\s*perm:\s*"([^"]+)"/g)].map(
  (match) => ({ to: match[1], key: match[2], perm: match[3] }),
);

function sourceForRoute(to: string) {
  if (to === "/dashboard") return "../src/routes/_authenticated/dashboard.tsx";
  const name = to.slice(1).replace(/\/\$/g, "_.$").replaceAll("/", "-");
  return "../src/routes/_authenticated/" + name + ".tsx";
}

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
    /permission denied\/i\.test\(e\.message\)[\s\S]*?setRequired\(false\)[\s\S]*?return;[\s\S]*?setError\(e\.message\)/,
    "permission-denied from setup_required must mark setup as not required without exposing an error",
  );
});
