import assert from "node:assert/strict";
import { test } from "node:test";

import { getAllowedBrowserTargetOrigin } from "../scripts/validate-browser-e2e-target.mjs";

const acceptedTargets = [
  "https://roshan-health-hub.vercel.app",
  "https://roshan-health-hub-roshan45.vercel.app",
  "https://roshan-health-hub-git-feat-browser-acceptance-a-f795c6-roshan45.vercel.app",
  "https://roshan-health-hub-git-main-roshan45.vercel.app",
  "https://roshan-health-moxakfer3-roshan45.vercel.app",
];
for (const target of acceptedTargets) {
  test("accepts verified Roshan deployment " + target, () => {
    assert.equal(getAllowedBrowserTargetOrigin(target), new URL(target).origin);
  });
}
const rejectedTargets = [
  "https://other-project-roshan45.vercel.app",
  "https://roshan-health-hub.vercel.app.attacker.invalid",
  "https://roshan-health-hub-git-main-otherteam.vercel.app",
  "https://roshan-health-12345678-roshan45.vercel.app",
  "http://roshan-health-hub.vercel.app",
  "https://user:pass@roshan-health-hub.vercel.app",
  "https://roshan-health-hub.vercel.app:8443",
  "https://roshan-health-hub.vercel.app/auth",
  "https://roshan-health-hub.vercel.app/?bypass=1",
  "https://roshan-health-hub.vercel.app/#fragment",
  "not a URL",
  "",
];
for (const target of rejectedTargets) {
  test("rejects untrusted or non-exact target " + JSON.stringify(target), () => {
    assert.throws(() => getAllowedBrowserTargetOrigin(target));
  });
}
