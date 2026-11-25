import assert from "node:assert/strict";
import { test } from "node:test";
import { createLiveStateSnapshot } from "../scripts/build-live-state-snapshot.mjs";

const baseEnv = {
  GH_TOKEN: "synthetic-token-never-real",
  GITHUB_REPOSITORY: "example/roshan",
  SNAPSHOT_SHA: "a".repeat(40),
  SNAPSHOT_REF: "refs/heads/main",
  GITHUB_EVENT_NAME: "workflow_run",
};

function mockFetch(responses) {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    const key = url.includes("/pulls?") ? "pulls" : "runs";
    const response = responses[key];
    return {
      ok: response.ok ?? true,
      status: response.status ?? 200,
      json: async () => response.body,
    };
  };
  return { fetchImpl, calls };
}

test("live snapshot is main-only and rejects other refs before network access", async () => {
  let called = false;
  await assert.rejects(
    createLiveStateSnapshot({
      env: { ...baseEnv, SNAPSHOT_REF: "refs/heads/feature/untrusted" },
      fetchImpl: async () => {
        called = true;
      },
    }),
    /restricted to refs\/heads\/main/,
  );
  assert.equal(called, false);
});

test("snapshot fetches only open PR metadata and recent workflow-run metadata", async () => {
  const { fetchImpl, calls } = mockFetch({
    pulls: {
      body: [
        {
          number: 254,
          title: "Context snapshot",
          body: "UNTRUSTED_BODY_MUST_NOT_BE_INCLUDED",
          draft: true,
          updated_at: "2026-11-15T20:00:00Z",
          head: { ref: "chore/context", sha: "b".repeat(40) },
          base: { ref: "main" },
          html_url: "https://github.com/example/roshan/pull/254",
        },
      ],
    },
    runs: {
      body: {
        workflow_runs: [
          {
            id: 123,
            name: "CI",
            event: "push",
            status: "completed",
            conclusion: "success",
            head_branch: "main",
            head_sha: "a".repeat(40),
            created_at: "2026-11-15T20:00:00Z",
            html_url: "https://github.com/example/roshan/actions/runs/123",
            logs_url: "UNTRUSTED_LOGS_MUST_NOT_BE_INCLUDED",
          },
        ],
      },
    },
  });

  const snapshot = await createLiveStateSnapshot({
    env: baseEnv,
    fetchImpl,
    now: () => new Date("2026-11-15T21:00:00.000Z"),
  });

  assert.equal(snapshot.generated_at, "2026-11-15T21:00:00.000Z");
  assert.equal(snapshot.commit_sha, baseEnv.SNAPSHOT_SHA);
  assert.equal(snapshot.open_pull_requests[0].number, 254);
  assert.equal(Object.hasOwn(snapshot.open_pull_requests[0], "title"), false);
  assert.equal(Object.hasOwn(snapshot.open_pull_requests[0], "head_ref"), false);
  assert.equal(Object.hasOwn(snapshot.open_pull_requests[0], "base_ref"), false);
  assert.equal(snapshot.recent_workflow_runs[0].conclusion, "success");
  assert.equal(JSON.stringify(snapshot).includes("UNTRUSTED"), false);
  assert.equal(JSON.stringify(snapshot).includes("synthetic-token"), false);
  assert.equal(calls.length, 2);
  for (const call of calls) {
    assert.equal(call.options.method, "GET");
    assert.equal(call.options.headers.Authorization, "Bearer synthetic-token-never-real");
    assert.equal(call.options.headers["X-GitHub-Api-Version"], "2022-11-28");
  }
  assert.deepEqual(snapshot.data_scope, {
    pull_request_bodies_included: false,
    comments_included: false,
    workflow_logs_included: false,
    secrets_or_artifacts_downloaded: false,
    hosted_database_accessed: false,
  });
});

test("snapshot rejects malformed repository and commit identifiers", async () => {
  await assert.rejects(
    createLiveStateSnapshot({
      env: { ...baseEnv, GITHUB_REPOSITORY: "https://evil.invalid/x" },
    }),
    /Invalid GITHUB_REPOSITORY/,
  );
  await assert.rejects(
    createLiveStateSnapshot({
      env: { ...baseEnv, SNAPSHOT_SHA: "not-a-sha" },
    }),
    /Invalid SNAPSHOT_SHA/,
  );
});

test("API failures fail closed without copying response bodies into logs", async () => {
  const { fetchImpl } = mockFetch({
    pulls: {
      ok: false,
      status: 403,
      body: { message: "PRIVATE_ERROR_BODY" },
    },
    runs: { body: { workflow_runs: [] } },
  });
  await assert.rejects(createLiveStateSnapshot({ env: baseEnv, fetchImpl }), (error) => {
    assert.match(error.message, /403/);
    assert.equal(error.message.includes("PRIVATE_ERROR_BODY"), false);
    return true;
  });
});

test("the live-state snapshot remains read-only and free of database access", async () => {
  const { fetchImpl } = mockFetch({
    pulls: { body: [] },
    runs: { body: { workflow_runs: [] } },
  });
  const snapshot = await createLiveStateSnapshot({ env: baseEnv, fetchImpl });
  assert.equal(snapshot.data_scope.hosted_database_accessed, false);
  assert.equal(snapshot.data_scope.secrets_or_artifacts_downloaded, false);
});

test("workflow_dispatch and workflow_run cannot create a snapshot from a non-main ref", async () => {
  const { readFile } = await import("node:fs/promises");
  const workflow = await readFile(".github/workflows/repomix-snapshot.yml", "utf8");
  assert.match(workflow, /if: github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /github\.event\.workflow_run\.event == 'push'/);
  assert.match(
    workflow,
    /github\.event\.workflow_run\.head_repository\.full_name == github\.repository/,
  );
  assert.match(workflow, /github\.event\.workflow_run\.head_branch == 'main'/);
});

test("Repomix excludes private keys, local credentials, cloud auth and Terraform state", async () => {
  const { readFile } = await import("node:fs/promises");
  const workflow = await readFile(".github/workflows/repomix-snapshot.yml", "utf8");
  const ignoreLine = workflow.split("\n").find((line) => line.includes("--ignore"));
  assert.ok(ignoreLine, "Repomix must use an explicit ignore list");
  for (const pattern of [
    "**/*.pem",
    "**/*.key",
    "**/*.p12",
    "**/*.pfx",
    "**/.npmrc",
    "**/.netrc",
    "**/.ssh/**",
    "**/.aws/**",
    "**/.azure/**",
    "**/.config/gcloud/**",
    "**/supabase/.temp/**",
    "**/terraform.tfstate*",
    "**/*service-account*.json",
    "**/*firebase-adminsdk*.json",
    "**/credentials*",
  ]) {
    assert.ok(ignoreLine.includes(pattern), `Repomix ignore list is missing ${pattern}`);
  }
});
