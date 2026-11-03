import { appendFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ERROR_MESSAGE =
  "The target must be an exact HTTPS URL for a verified Roshan Health Hub deployment.";
const EXACT_HOSTS = new Set([
  "roshan-health-hub.vercel.app",
  "roshan-health-hub-roshan45.vercel.app",
]);
const PROJECT_DEPLOYMENT_HOSTS = [
  /^roshan-health-hub-git-[a-z0-9]+(?:-[a-z0-9]+)*-roshan45\.vercel\.app$/,
  /^roshan-health-[a-z0-9]{9}-roshan45\.vercel\.app$/,
];

export function getAllowedBrowserTargetOrigin(raw) {
  if (typeof raw !== "string" || raw.length === 0 || raw.trim() !== raw) {
    throw new Error(ERROR_MESSAGE);
  }

  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(ERROR_MESSAGE);
  }

  const hostname = url.hostname.toLowerCase();
  const trustedHost =
    EXACT_HOSTS.has(hostname) || PROJECT_DEPLOYMENT_HOSTS.some((pattern) => pattern.test(hostname));

  if (
    url.protocol !== "https:" ||
    url.username !== "" ||
    url.password !== "" ||
    url.port !== "" ||
    url.pathname !== "/" ||
    url.search !== "" ||
    url.hash !== "" ||
    !trustedHost
  ) {
    throw new Error(ERROR_MESSAGE);
  }

  return url.origin;
}

const currentFile = fileURLToPath(import.meta.url);
const invokedFile = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedFile === currentFile) {
  try {
    const origin = getAllowedBrowserTargetOrigin(process.env.INPUT_DEPLOYMENT_URL);
    if (!process.env.GITHUB_ENV) throw new Error(ERROR_MESSAGE);
    appendFileSync(process.env.GITHUB_ENV, "BASE_URL=" + origin + "\n", { encoding: "utf8" });
  } catch {
    console.error(ERROR_MESSAGE);
    process.exitCode = 1;
  }
}
