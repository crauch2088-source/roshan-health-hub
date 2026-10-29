import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { z } from "zod/v3";

type LockPackage = { version?: string };
type Lockfile = { packages: Record<string, LockPackage> };
type PackageManifest = { dependencies: { zod: string } };

const packageJson = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as PackageManifest;
const lockfile = JSON.parse(
  readFileSync(new URL("../package-lock.json", import.meta.url), "utf8"),
) as Lockfile;
const dependabotConfig = readFileSync(
  new URL("../.github/dependabot.yml", import.meta.url),
  "utf8",
);
const aiAssistantFunctions = readFileSync(
  new URL("../src/lib/ai/assistant.functions.ts", import.meta.url),
  "utf8",
);

function compareVersions(left: string, right: string): number {
  const a = left.split(".").map(Number);
  const b = right.split(".").map(Number);
  for (let index = 0; index < 3; index += 1) {
    const delta = (a[index] ?? 0) - (b[index] ?? 0);
    if (delta !== 0) return delta;
  }
  return 0;
}

function getLockedVersions(packageName: string): string[] {
  return Object.entries(lockfile.packages).flatMap(([path, entry]) => {
    const matches =
      path === `node_modules/${packageName}` || path.endsWith(`/node_modules/${packageName}`);
    return matches && typeof entry.version === "string" ? [entry.version] : [];
  });
}

test("all locked Zod packages include the memory-exhaustion security fix", () => {
  assert.equal(packageJson.dependencies.zod, "^4.6.7");
  const versions = getLockedVersions("zod");
  assert.ok(versions.length >= 1, "expected at least one locked Zod package");
  assert.ok(
    versions.every((version) => compareVersions(version, "4.6.6") >= 0),
    `vulnerable Zod version found: ${versions.join(", ")}`,
  );
});

test("any locked fast-uri package includes the URI parsing security fixes", () => {
  const versions = getLockedVersions("fast-uri");
  assert.ok(
    versions.length === 0 || versions.every((version) => compareVersions(version, "3.1.9") >= 0),
    `vulnerable fast-uri version found: ${versions.join(", ")}`,
  );
});

test("all locked seroval packages include the 1.6.11 serialization security fixes", () => {
  const versions = getLockedVersions("seroval");
  assert.ok(versions.length >= 1, "expected at least one locked seroval package");
  assert.ok(
    versions.every((version) => compareVersions(version, "1.6.11") >= 0),
    `vulnerable seroval version found: ${versions.join(", ")}`,
  );
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
  for (const path of [
    "../src/routes/_authenticated/-users.server.ts",
    "../src/lib/ai/assistant.functions.ts",
  ]) {
    const source = readFileSync(new URL(path, import.meta.url), "utf8");
    assert.match(source, /from ["']zod\/v3["']/);
  }
});

test("AI server functions use TanStack Start's supported validator API", () => {
  assert.equal(
    (aiAssistantFunctions.match(/\.validator\(/g) ?? []).length,
    4,
    "all four read-only assistant functions must validate input",
  );
  assert.doesNotMatch(
    aiAssistantFunctions,
    /\.inputValidator\(/,
    "TanStack Start 1.169 removes the deprecated inputValidator method",
  );
});

test("Dependabot defers known-incompatible major updates until their migration is tested", () => {
  const npmUpdates = dependabotConfig.split("\n  - package-ecosystem: github-actions")[0];
  for (const dependencyName of [
    "typescript",
    "react-day-picker",
    "recharts",
    "eslint-plugin-react-hooks",
  ]) {
    assert.match(
      npmUpdates,
      new RegExp(
        `- dependency-name:\\s*${dependencyName}\\s*\\n\\s+update-types:\\s*\\n\\s+- .*version-update:semver-major`,
      ),
      `${dependencyName} major updates must stay deferred until compatibility is tested`,
    );
  }
});
