import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const skills = [
  "roshan-engineering-orchestrator",
  "roshan-architecture",
  "roshan-database",
  "roshan-clinical-safety",
  "roshan-security",
  "roshan-pharmacy-laboratory",
  "roshan-qa",
  "roshan-release",
  "roshan-minimal-change",
];

function readSkill(name) {
  const path = join(root, ".agents", "skills", name, "SKILL.md");
  assert.ok(existsSync(path), "missing skill: " + name);
  return readFileSync(path, "utf8");
}

test("Roshan skill inventory and frontmatter are complete", () => {
  for (const name of skills) {
    const content = readSkill(name);
    assert.match(content, /^---\nname: [a-z0-9-]+\ndescription: .+\n---\n/m);
    assert.match(content, new RegExp("^name: " + name + "$", "m"));
    assert.ok(content.length > 250, "skill is unexpectedly empty: " + name);
  }
});

test("orchestrator routes work and preserves authority boundaries", () => {
  const content = readSkill("roshan-engineering-orchestrator");
  for (const term of [
    "roshan-database",
    "roshan-clinical-safety",
    "roshan-security",
    "roshan-pharmacy-laboratory",
    "roshan-qa",
    "roshan-release",
    "docs/MASTER_PLAN.md",
    "Completion report",
  ]) {
    assert.ok(content.includes(term), "orchestrator missing contract: " + term);
  }
});

test("Graphify is conditionally routed and remains a non-authoritative local aid", () => {
  const orchestrator = readSkill("roshan-engineering-orchestrator");
  const architecture = readSkill("roshan-architecture");
  for (const term of [
    "Cross-layer flows",
    "Broad refactors",
    "current branch",
    "small isolated edit",
    "Graphify is an aid, never a blocker",
    "--code-only",
    "Production PostgreSQL",
    "RLS/grants",
  ]) {
    assert.ok(orchestrator.includes(term), "Graphify routing contract missing: " + term);
  }
  assert.match(architecture, /verify Graphify findings against actual source/i);
  assert.match(architecture, /never connect the graph tool to Production PostgreSQL/i);
  assert.match(architecture, /not authoritative for SQL\/RLS\/grants/i);
});

test("clinical, database, security and pharmacy skills retain hard safety contracts", () => {
  const clinical = readSkill("roshan-clinical-safety");
  const database = readSkill("roshan-database");
  const security = readSkill("roshan-security");
  const pharmacy = readSkill("roshan-pharmacy-laboratory");
  assert.match(clinical, /Never invent, infer, silently normalize/);
  assert.match(clinical, /Do not infer route from dosage form/);
  assert.match(clinical, /clinician review and explicit confirmation/);
  assert.match(database, /Never use Production as a test database/);
  assert.match(database, /fixed safe search_path/);
  assert.match(database, /FORCE RLS/);
  assert.match(
    security,
    /A hidden button, route guard, client filter, or TypeScript type is not authorization/,
  );
  assert.match(security, /branch access/);
  assert.match(pharmacy, /approved verification RPC/);
  assert.match(pharmacy, /aggregate stock/);
});

test("minimal-change policy cannot weaken safety, security, or test coverage", () => {
  const content = readSkill("roshan-minimal-change");
  assert.match(content, /Simplicity never permits weakening/);
  assert.match(content, /Do not reduce test coverage/);
  assert.match(content, /without reducing security or clinical assurance/);
});

test("system documentation records inspirations and authority boundaries", () => {
  const docs = readFileSync(join(root, "docs/ROSHAN_AGENT_SKILLS_SYSTEM.md"), "utf8");
  assert.match(docs, /Addy Osmani/);
  assert.match(docs, /Ponytail/);
  assert.match(docs, /docs\/MASTER_PLAN\.md/);
  assert.match(docs, /Skills never authorize production operations/);
  assert.match(docs, /No frontend dependency/);
  assert.match(docs, /AGENT_TOOLING_RESEARCH_2026-11-04\.md/);
});

test("agent operating references exist and route to one canonical source of truth", () => {
  const required = [
    "docs/PROJECT_STATE.md",
    "docs/TASK_REGISTRY.md",
    "docs/AGENT_TASK_CONTRACT_TEMPLATE.md",
    "docs/AGENT_EXECUTION_PROTOCOL.md",
    "docs/VERIFICATION_MATRIX.md",
  ];
  for (const path of required) {
    assert.ok(existsSync(join(root, path)), "missing operating reference: " + path);
  }
  const agents = readFileSync(join(root, "AGENTS.md"), "utf8");
  const start = readFileSync(join(root, "docs/AGENT_START_HERE.md"), "utf8");
  const protocol = readFileSync(join(root, "docs/AGENT_EXECUTION_PROTOCOL.md"), "utf8");
  const registry = readFileSync(join(root, "docs/TASK_REGISTRY.md"), "utf8");
  const state = readFileSync(join(root, "docs/PROJECT_STATE.md"), "utf8");
  const matrix = readFileSync(join(root, "docs/VERIFICATION_MATRIX.md"), "utf8");
  for (const term of [
    "docs/PROJECT_STATE.md",
    "docs/AGENT_EXECUTION_PROTOCOL.md",
    "docs/TASK_REGISTRY.md",
  ]) {
    assert.ok(agents.includes(term), "AGENTS.md missing route: " + term);
    assert.ok(start.includes(term), "start guide missing route: " + term);
  }
  assert.match(registry, /Canonical backlog:.*GitHub Issues and Pull Requests/);
  assert.match(registry, /not a second backlog/);
  assert.match(state, /Refresh protocol/);
  assert.match(state, /STALE/);
  assert.match(protocol, /independent reviewer/);
  assert.match(protocol, /never create synthetic.*Production/i);
  assert.match(matrix, /SKIP/);
  assert.match(matrix, /clinical acceptance/i);
});
