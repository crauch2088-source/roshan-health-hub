import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { z } from "zod/v3";

const packageJson = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
const lockfile = JSON.parse(readFileSync(new URL("../package-lock.json", import.meta.url), "utf8"));

function compareVersions(left: string, right: string): number {
  const a = left.split(".").map(Number);
  const b = right.split(".").map(Number);
  for (let index = 0; index < 3; index += 1) {
    const delta = (a[index] ?? 0) - (b[index] ?? 0);
    if (delta !== 0) return delta;
  }
  return 0;
}

test("all locked Zod packages include the memory-exhaustion security fix", () => {
  assert.equal(packageJson.dependencies.zod, "^4.6.7");
  const versions = Object.entries(lockfile.packages)
    .filter(([path, entry]: [string, any]) => entry.version && (path === "node_modules/zod" || path.endsWith("/node_modules/zod")))
    .map(([, entry]: [string, any]) => entry.version as string);
  assert.ok(versions.length >= 1, "expected at least one locked Zod package");
  assert.ok(versions.every((version) => compareVersions(version, "4.6.6") >= 0), `vulnerable Zod version found: ${versions.join(", ")}`);
});

test("all locked fast-uri packages include the URI parsing security fixes", () => {
  const versions = Object.entries(lockfile.packages)
    .filter(([path, entry]: [string, any]) => entry.version && (path === "node_modules/fast-uri" || path.endsWith("/node_modules/fast-uri")))
    .map(([, entry]: [string, any]) => entry.version as string);
  assert.ok(versions.length >= 1, "expected at least one locked fast-uri package");
  assert.ok(versions.every((version) => compareVersions(version, "3.1.9") >= 0), `vulnerable fast-uri version found: ${versions.join(", ")}`);
});

test("existing server validators retain Zod v3 behavior through the supported v3 entry point", () => {
  const schema = z.object({
    full_name: z.string().trim().min(1),
    email: z.string().trim().toLowerCase().email(),
  });
  assert.deepEqual(schema.parse({ full_name: " Roshan ", email: "CLINIC@example.test" }), {
    full_name: "Roshan",
    email: "clinic@example.test",
  });
  assert.equal(typeof schema["~standard"].validate, "function");
  for (const path of ["../src/routes/_authenticated/-users.server.ts", "../src/lib/ai/assistant.functions.ts"]) {
    const source = readFileSync(new URL(path, import.meta.url), "utf8");
    assert.match(source, /from ["']zod\/v3["']/);
  }
});
