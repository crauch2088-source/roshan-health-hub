import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const API_VERSION = "2022-11-28";
const REPOSITORY_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const COMMIT_PATTERN = /^[a-f0-9]{40}$/i;

function required(value, name) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`Missing required snapshot setting: ${name}`);
  }
  return value.trim();
}

function safeText(value, maxLength = 200) {
  return typeof value === "string" ? value.slice(0, maxLength) : "";
}

/**
 * Collect a minimal, sanitized view of the trusted main branch's live GitHub state.
 * PR bodies, comments, user profiles, workflow logs, and artifact contents are never fetched.
 */
export async function createLiveStateSnapshot({
  env = process.env,
  fetchImpl = globalThis.fetch,
  now = () => new Date(),
} = {}) {
  const token = required(env.GH_TOKEN, "GH_TOKEN");
  const repository = required(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY");
  const commitSha = required(env.SNAPSHOT_SHA ?? env.GITHUB_SHA, "SNAPSHOT_SHA");
  const ref = required(env.SNAPSHOT_REF ?? env.GITHUB_REF, "SNAPSHOT_REF");

  if (!REPOSITORY_PATTERN.test(repository)) {
    throw new Error("Invalid GITHUB_REPOSITORY; expected owner/repository");
  }
  if (!COMMIT_PATTERN.test(commitSha)) {
    throw new Error("Invalid SNAPSHOT_SHA; expected a 40-character commit SHA");
  }
  if (ref !== "refs/heads/main") {
    throw new Error("Live state snapshots are restricted to refs/heads/main");
  }
  if (typeof fetchImpl !== "function") {
    throw new Error("A fetch implementation is required");
  }

  const headers = {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": API_VERSION,
  };
  const request = async (path) => {
    const response = await fetchImpl(
      `https://api.github.com/repos/${repository}/${path}`,
      { method: "GET", headers },
    );
    if (!response.ok) {
      throw new Error(`GitHub API request failed (${response.status}) for ${path.split("?")[0]}`);
    }
    return response.json();
  };

  const [pullRequests, workflowRunResponse] = await Promise.all([
    request("pulls?state=open&per_page=100"),
    request("actions/runs?branch=main&per_page=20"),
  ]);

  if (!Array.isArray(pullRequests) || !Array.isArray(workflowRunResponse.workflow_runs)) {
    throw new Error("GitHub API returned an unexpected live-state response");
  }

  return {
    schema_version: 1,
    generated_at: now().toISOString(),
    repository,
    branch: "main",
    commit_sha: commitSha,
    trigger: safeText(env.GITHUB_EVENT_NAME, 80),
    open_pull_requests: pullRequests.map((pr) => ({
      number: Number.isInteger(pr.number) ? pr.number : null,
      title: safeText(pr.title),
      draft: Boolean(pr.draft),
      updated_at: safeText(pr.updated_at, 40),
      head_ref: safeText(pr.head?.ref, 120),
      head_sha: safeText(pr.head?.sha, 40),
      base_ref: safeText(pr.base?.ref, 120),
      url: safeText(pr.html_url, 300),
    })),
    recent_workflow_runs: workflowRunResponse.workflow_runs.slice(0, 20).map((run) => ({
      id: Number.isInteger(run.id) ? run.id : null,
      name: safeText(run.name),
      event: safeText(run.event, 80),
      status: safeText(run.status, 40),
      conclusion: safeText(run.conclusion, 40),
      branch: safeText(run.head_branch, 120),
      head_sha: safeText(run.head_sha, 40),
      created_at: safeText(run.created_at, 40),
      url: safeText(run.html_url, 300),
    })),
    data_scope: {
      pull_request_bodies_included: false,
      comments_included: false,
      workflow_logs_included: false,
      secrets_or_artifacts_downloaded: false,
      hosted_database_accessed: false,
    },
  };
}

async function main() {
  const outputPath = process.argv[2];
  if (!outputPath) {
    throw new Error("Usage: node scripts/build-live-state-snapshot.mjs <output-path>");
  }
  const snapshot = await createLiveStateSnapshot();
  const destination = resolve(outputPath);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, `${JSON.stringify(snapshot, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  process.stdout.write("Sanitized GitHub live-state snapshot created.\n");
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : "";
if (invokedPath === import.meta.url) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
