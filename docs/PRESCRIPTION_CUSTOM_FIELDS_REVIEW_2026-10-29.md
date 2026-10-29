# Prescription custom-fields PR #125 — branch refresh and exact-head evidence

## Scope and safety

PR [#125](https://github.com/crauch2088-source/roshan-health-hub/pull/125) makes the prescription composer accept clinician-entered dose text with a unit prompt, editable bilingual custom frequency/duration/form/route fields, stricter draft completeness for dosage form and route, and an explicit age-verification warning for unknown/invalid DOB. Its age calculation rejects impossible calendar dates such as `2026-02-30`. It does not add dose recommendations, dose calculations, or regimen defaults.

The PR was stale: head `0db773465e60eeab5c8296cf1c2e959eeaec892a`, based on main `e6ecc9cf171900791862a56be415c29bc5ceba7e`. GitHub's automatic branch update refused because `docs/MASTER_PLAN.md` conflicted. The conflict was resolved locally by retaining the prescription-specific historical sections and the current main Dependabot/Seroval evidence sections. A GitHub merge commit was then created with:

- Merge commit: [`76ec8c9d6ee4c9db6a8347f91b1ab3e14574f173`](https://github.com/crauch2088-source/roshan-health-hub/commit/76ec8c9d6ee4c9db6a8347f91b1ab3e14574f173)
- First parent (old PR head): `0db773465e60eeab5c8296cf1c2e959eeaec892a`
- Second parent (current main at refresh): `80fc494aee4d2bd8c98b3c5fd97502fa855d7260`
- Tree: `2087011edeb599f7c138389edb5cd375b9f6710e`, matching the locally resolved merge tree
- PR remains open; its five-file product/test diff is unchanged relative to current main.

## Exact-head checks

All 27 check runs on refreshed head `76ec8c9d6ee4c9db6a8347f91b1ab3e14574f173` completed with **26 success, one intentional skip, zero failures**.

- CI [40832478523](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478523) — succeeded, including install, `npm audit`, typecheck, lint, build, and the repository guard suite.
- PR dynamic workflow [40832474200](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832474200) — succeeded.
- Insurance claim UI validation [40832478469](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478469) — succeeded.
- Privileged-role guard [40832478513](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478513) — succeeded.
- Insurance claim integrity [40832478403](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478403) — succeeded.
- Prescription atomicity [40832478574](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478574) — succeeded.
- CodeQL check `123309795535` — succeeded, no new alerts.
- Vercel Preview Comments check `123309793761` — succeeded.
- The only skipped check is **Canonical PG17 baseline replay and authenticated clinical acceptance**. This remains explicitly deferred; it is not a clinical acceptance result.

## Preview and release gate

Vercel preview deployment [`dpl_E3DwtFMKE7j4Erz1kTmQv9KYWhcf`](https://vercel.com/roshan45/roshan-health-hub/E3DwtFMKE7j4Erz1kTmQv9KYWhcf) is `READY` on the exact refreshed head. Preview alias: `roshan-health-hub-git-fix-prescription-custom-f-e5d2fa-roshan45.vercel.app`. It is a preview, not production. No production database/Auth changes, patient/financial records, or production deployment were made as part of this branch refresh.

**Do not merge PR #125 yet.** It remains gated on authorized staff acceptance of the prescription workflow. Issue [#95](https://github.com/crauch2088-source/roshan-health-hub/issues/95) remains open. Browser/viewport, RTL/LTR, keyboard, and authenticated role acceptance remain NOT TESTED/BLOCKED. Clinical E2E remains deferred until a free isolated QA login path and a suitable synthetic clinician identity are available.

## Next task

Continue non-authenticated source-level UX review and prepare the authorized staff acceptance session. Keep PR #125 open until that gate is satisfied; do not convert green CI or a READY preview into a claim of clinical acceptance.
