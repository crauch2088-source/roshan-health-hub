import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const rootPath = decodeURIComponent(new URL("../", import.meta.url).pathname);
const srcRoot = join(rootPath, "src");
const dbRoot = join(rootPath, "db");
const baseline = readFileSync(join(dbRoot, "baseline/0000_roshan_pg17_baseline_v112.sql"), "utf8");

function walk(dir: string, extensions: string[], out: string[] = []): string[] {
  for (const item of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, item.name);
    if (item.isDirectory()) {
      walk(path, extensions, out);
    } else if (extensions.some((extension) => item.name.endsWith(extension))) {
      out.push(path);
    }
  }
  return out;
}

test("QA-only view security reconciliation is scoped, idempotent and fail-closed", () => {
  const qaPatch = readFileSync(
    join(dbRoot, "qa/20261030_restore_security_invoker_on_qa_views.sql"),
    "utf8",
  );

  assert.match(qaPatch, /QA-only/i);
  assert.match(qaPatch, /hopfohcnrtbiqjkgeukz/);
  assert.match(qaPatch, /BEGIN;[\s\S]*COMMIT;/);
  for (const view of [
    "cashbox_balance",
    "follow_ups",
    "v_patient_receivables",
    "v_supplier_outstanding",
  ]) {
    assert.match(
      qaPatch,
      new RegExp(
        `ALTER\\s+VIEW\\s+public\\.${view}\\s+SET\\s*\\(\\s*security_invoker\\s*=\\s*true\\s*\\)`,
        "i",
      ),
    );
  }
  assert.match(qaPatch, /missing_views IS NOT NULL[\s\S]*RAISE EXCEPTION/);
});

test("canonical PostgreSQL baseline preserves caller RLS on exposed views", () => {
  const protectedViews = [
    "cashbox_balance",
    "follow_ups",
    "v_patient_receivables",
    "v_supplier_outstanding",
  ];

  for (const view of protectedViews) {
    assert.match(
      baseline,
      new RegExp(
        `CREATE\\s+OR\\s+REPLACE\\s+VIEW\\s+public\\.${view}\\s+WITH\\s*\\(\\s*security_invoker\\s*=\\s*true\\s*\\)\\s+AS`,
        "i",
      ),
      `Baseline view public.${view} must apply caller permissions and RLS`,
    );
  }

  assert.match(baseline, /DO \$roshan_security_invoker_guard\$/);
  assert.match(baseline, /missing_views IS NOT NULL[\s\S]*RAISE EXCEPTION/);
});

test("literal permission codes are declared or explicitly tracked as catalog-only", () => {
  const appSource = walk(srcRoot, [".ts", ".tsx", ".js", ".jsx"])
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
  const sqlSource = walk(dbRoot, [".sql"])
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
  const used = new Set<string>();
  const declared = new Set<string>();

  for (const match of appSource.matchAll(
    /\b(?:can|app_has_perm)\s*\(\s*['"`]([a-z0-9_.-]+)['"`]/gi,
  )) {
    used.add(match[1]);
  }
  for (const match of sqlSource.matchAll(/['"]([a-z][a-z0-9_.-]+)['"]/gi)) {
    declared.add(match[1]);
  }

  // The canonical v112 CI baseline is schema-only and intentionally omits permission rows.
  // visits.delete is used by the existing visits UI but has no tracked seed in the historical SQL archive;
  // its presence in the live permissions catalog requires a separate permitted read-only check.
  const catalogOnly = new Set(["visits.delete"]);
  const missing = [...used].filter((code) => !declared.has(code) && !catalogOnly.has(code));
  assert.deepEqual(
    missing,
    [],
    `Permission references absent from tracked SQL: ${missing.join(", ")}`,
  );
});

test("literal Supabase table references exist in canonical public baseline", () => {
  const appSource = walk(srcRoot, [".ts", ".tsx", ".js", ".jsx"])
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
  const objects = new Set<string>();
  const queried = new Set<string>();

  for (const match of baseline.matchAll(
    /CREATE\s+(?:(?:OR\s+REPLACE)\s+)?(?:TABLE|VIEW)\s+public\.([a-z_][a-z0-9_]*)/gi,
  )) {
    objects.add(match[1].toLowerCase());
  }
  for (const match of appSource.matchAll(/\.from\(\s*["'`]([a-z_][a-z0-9_]*)["'`]\s*\)/gi)) {
    queried.add(match[1].toLowerCase());
  }
  const missing = [...queried].filter((name) => !objects.has(name));
  assert.deepEqual(missing, [], `Tables/views absent from baseline: ${missing.join(", ")}`);
});

test("malformed newline-suffixed Vercel config is absent and canonical config keeps both settings", () => {
  assert.equal(existsSync(join(rootPath, "vercel.json\n")), false);
  const config = JSON.parse(readFileSync(join(rootPath, "vercel.json"), "utf8"));
  assert.ok(Array.isArray(config.rewrites));
  assert.equal(typeof config.ignoreCommand, "string");
});
