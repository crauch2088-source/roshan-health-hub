# Phase 18 — Production UX & Workflow Excellence
## Priorities 1–7 audit + fix report

Branch: `phase18-production-ux`
Continues from `6934861` (Priority 1, prior turn) through this session's `4560565`.

## Commits in this phase

| Priority | Commit | Files |
|---|---|---|
| 1 — Patient workflow | `6934861` fix(workflow): streamline patient journey | visits.tsx, ConsultationPage.tsx, billing.tsx, patients_.$patientId.tsx |
| 2 — Navigation | `b2d97bd` feat(nav): improve navigation experience | mobile-bottom-nav.tsx |
| 3 — Dashboard | `43c0f39` feat(dashboard): operational dashboard improvements | dashboard.tsx |
| 4 — Tables | `270576d` feat(tables): improve usability and density | components/ui/table.tsx |
| 5 — Clinical workflow | `9036ae7` feat(clinic): improve clinical workflow | features/clinic/consultation/components/LaboratoryTab.tsx |
| 6/7 — Reliability & hardening | `4560565` fix(reliability): harden async flows / perf(app) | components/ui/table.tsx, (audit of lib/db.ts) |

## Findings, root cause, and fix — by priority

### Priority 1 — Patient workflow
- **visits.tsx**: `?patient=<id>` deep-link from the patient chart was never cleared from the URL after being consumed. Root cause: the consuming `useEffect` set dialog state but never called `navigate()` to drop the search param. Refreshing `/visits` or navigating back to it re-ran the fetch and re-opened "New Visit" for a patient who may already have a visit. **Fixed** via `navigate({ search: {}, replace: true })` once consumed.
- **ConsultationPage.tsx**: "Finish visit" had no `onDone`. Root cause: the `useSave` call for the finish mutation only had `invalidate` + `successMessage`, no redirect. The doctor was left on a now-completed visit with only a manual "Clinic" breadcrumb link back to the queue — a dead end at the exact moment they need the next patient. **Fixed**: redirects to `/clinic` ~600ms after the success toast.
- **billing.tsx**: "New Invoice" was the only screen in the whole journey with no patient-context deep link (Visits/Followups/Clinic all have one via nav or existing routes). Root cause: no `validateSearch`/consuming effect existed. **Fixed** by mirroring the exact pattern already used in visits.tsx.
- **patients_.$patientId.tsx**: no "New Invoice" quick action existed next to "New Visit". **Fixed**: added it, wired to the new billing.tsx deep link.

### Priority 2 — Navigation & Command Palette
Audited NavRail, AppShell, CommandPaletteProvider, GlobalSearchDialog, MobileBottomNav, useNavPreferences. Most of this was already close to the Linear/Raycast bar targeted by this phase — collapsed-state tooltips, active-state accent bar, per-item pin/unpin, favorites + recent pages + quick actions + search history + visible keyboard hints (↑↓, Enter, Esc) in the command palette, and ≥44px mobile touch targets were all already present and were **not** re-implemented.
- **mobile-bottom-nav.tsx**: the 4 primary bottom-nav slots were a hardcoded array (`/dashboard, /patients, /visits, /pharmacy`) that never read `useNavPreferences().favorites` — the exact pin system the desktop rail and command palette already share. Pinning Queue or Clinic as a favorite on desktop had zero effect on mobile. **Fixed**: mobile nav now prefers the user's pinned favorites for its non-Dashboard slots, falling back to the previous defaults when nothing is pinned (existing behavior unchanged for anyone who hasn't used pins).

### Priority 3 — Dashboard
Queries already reused existing tables only (visits, patients, appointments, payments, expenses, lab_orders, prescriptions, followups, medicines, pharmacy_inventory, insurance_claims) — no new tables/columns needed for that part.
- Root cause of the "card wall" feeling: every section was informational but not actionable — clicking a lab-pending row, a follow-up row, or a visit row did nothing. Staff had to remember the patient's name, leave the dashboard, and search again elsewhere. **Fixed**: Visits Today rows → `/clinic/$visitId`; Pending Lab rows → `/lab/$orderId`; Follow-up rows → `/patients/$patientId` (required adding `id` to the existing `patients(full_name)` nested select, no new column); every section's `CardTitle` is now a link to its full list page.
- **Not fixed / flagged as remaining**: low-stock/expiring/expired medicine rows and insurance-claim rows still link to their list page rather than a per-record URL, because no per-record detail route exists yet for inventory batches or insurance claims (only `/inventory` and `/insurance` list routes) — adding one would mean introducing a new route, which is out of scope for this pass per "do not create duplicate routes."

### Priority 4 — Tables & data density
Row density (`density="compact"`), the shared `<Empty>` state, and the shared `<Pager>` + `usePagedRows()` pagination were already consistent app-wide.
- **components/ui/table.tsx**: `TableHeader` was `sticky top-0 z-10` unconditionally. Root cause: the app shell's own top bar is *also* `sticky top-0`, just at a higher z-index (`z-20`) and a fixed 56px (`h-14`) height. Both stuck to the same point in the same scroll container, so every table's header row rendered directly behind the app bar instead of just under it — on any list long enough to scroll, column labels vanished under the header instead of staying pinned. **Fixed**: offset changed to `top-14` so table headers stick just below the app bar, fixed once for every screen that uses this shared component.

### Priority 5 — Clinical workflow polish
- **LaboratoryTab.tsx** (inside Consultation): only showed the test picker for placing a *new* lab order — no visibility into orders already placed earlier in the same visit. Root cause: no query against `lab_orders` scoped to the current `visit_id`. A doctor had no way to see "already ordered" without leaving the consultation and searching the Lab page — the same "search again for the same patient" pattern targeted elsewhere in this phase, plus a real risk of a duplicate order and a duplicate charge on the invoice. **Fixed**: added a query using the exact same `lab_orders` + `lab_order_items(lab_tests)` shape already used by `routes/_authenticated/lab.tsx` (no new columns/relationships), rendered as a small list above the picker, each row linking to `/lab/$orderId`.
- ConsultationPage's "Finish visit" dead end and the Visits/Billing deep-link gaps were already covered under Priority 1 in this same branch and were not duplicated here.

### Priority 6 — Error handling & reliability
Audited `src/lib/db.ts` (`useRows`, `usePagedRows`, `useSave`, `rpc`, `csvExport`) — the shared data layer every screen in this phase touches. Found already solid: `useSave` wires `toast.error` on failure and `toast.success` + targeted cache invalidation on success; `useRows`/`usePagedRows` surface `.error` for the shared `<ErrorBox>` and disable retry so failures show immediately instead of silently retrying; `csvExport` guards the empty-rows case. Every screen read in this phase (dashboard, clinic, lab, billing, visits, followups) used the same `Loading` / `ErrorBox` / `Empty` pattern consistently. **No changes made** — didn't want to introduce a speculative rewrite of code with no verified defect.

### Priority 7 — Production hardening
- **components/ui/table.tsx**: the `stickyHeader` prop was dead code — confirmed via a repo-wide code search (`GITHUB_SEARCH_CODE`) that no screen anywhere in the repository ever passed it. It only ever set an unused `data-sticky-header` attribute with no matching CSS. **Fixed**: removed the prop and the attribute rather than leaving an unused, confusing knob in a shared component.
- No other dead code, duplicate queries, duplicate patient searches, stale permissions, or stale i18n keys were found and verified in the files read this phase. A full sweep of the remaining ~140 files not touched in this phase (inventory, insurance, reports, suppliers, settings, users/roles, appointments, queue, followups beyond the dashboard link, and all consultation tabs besides LaboratoryTab) was **not** performed and is the main remaining risk — see below.

## Remaining risks / not done in this phase
- Priorities 6 and 7 were audited at the shared-infrastructure level (`lib/db.ts`, `ui/table.tsx`) rather than screen-by-screen across all ~40+ routes. A dedicated pass over Inventory, Insurance, Reports, Suppliers, Settings, Users/Roles, Appointments, and Queue for the same class of issues found elsewhere (dead-end actions, missing context, duplicate patient search) has not been done.
- PrescriptionTab.tsx (the sibling of the LaboratoryTab.tsx fixed in Priority 5) was not audited for the same "no visibility into already-created records" pattern — worth checking next.
- Dashboard's low-stock/expiring/expired medicine and insurance-claim rows still lack per-record detail routes; adding those routes (out of scope here per the "no duplicate routes" rule without design input) would let those specific rows become clickable too.
- No new tables, columns, RPCs, permissions, i18n keys, or routes were introduced anywhere in this phase — every fix reused an existing route, column, or relationship that was verified in the code first.

## Recommendation
The patient-journey dead ends and the sticky-header regression were real, user-facing bugs worth fixing before a pilot. The areas audited and left untouched (NavRail, command palette, table density/pagination infra, the shared data layer) were already at a solid, production-appropriate standard from prior phases. Given the size of the remaining unaudited surface (Priority 6/7 across screens not yet read), a full production-pilot recommendation should wait for at least one more pass specifically over Inventory, Insurance, Reports, and the remaining consultation tabs, rather than being called ready end-to-end on the strength of this session alone.
