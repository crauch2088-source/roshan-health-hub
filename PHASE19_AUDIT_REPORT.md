# Phase 19 — Repository Audit + Production Excellence

Branch: `phase19-production-excellence`, created from `phase18-production-ux` tip (`945166b`).

## 1. Full repository audit — what was checked and its status

| Area | Status found | Evidence |
|---|---|---|
| Route protection (all 27 content routes under `src/routes/_authenticated/`) | **Clean.** Every content route wraps itself in `<PermissionGate perm="...">`. Only `route.tsx` (the pathless `_authenticated` layout itself, which handles session/auth, not per-page permission) has no PermissionGate — expected. | Verified via `GITHUB_SEARCH_CODE` for `PermissionGate` scoped to `src/routes/_authenticated`, diffed against the full route file list from the repo tree. |
| Exports (Reports, Clinic, Lab, Pharmacy, and every other screen using `<ExportButtons>`) | **Broken, now fixed.** See below. | Read `src/lib/db.ts` `csvExport()` and traced how `ExportButtons` is called across screens with joined relation data. |
| Prescription workflow (PrescriptionTab) | **Missing context, now fixed.** Same class of bug as LaboratoryTab.tsx, fixed in Phase 18. | Read the full component. |
| Laboratory workflow (LaboratoryTab) | Already fixed in Phase 18 (`9036ae7`) — verified still in place, not re-touched. | Re-read the file on this branch. |
| Dashboard, Navigation, Command Palette, Mobile Navigation, Tables | Already brought to a solid standard in Phase 18 — re-verified present on this branch, not re-touched. | Spot-checked import/behavior of the Phase 18 diffs. |
| Inventory, Insurance, Reports (non-export parts), Analytics, Finance, Permissions internals, Patient Timeline | **Not deeply audited this pass.** insurance.tsx (~36KB) and inventory.tsx (~40KB) were opened and structurally scanned (tabs, route guard, imports) but not read line-by-line for the class of bug found elsewhere. Analytics, Finance, and the permissions table/RLS were not opened at all this session. | See "Remaining risks" below. |

## 2 & 7 — Prescription workflow / production hardening

**Commit `993059e`** — `src/features/clinic/consultation/components/PrescriptionTab.tsx`

Root cause: PrescriptionTab only rendered the "write a new prescription" builder, with no query against `prescriptions` scoped to the visit. A doctor had no way to see a prescription already written earlier in the same visit — a real duplicate-prescription and duplicate-dispensing-charge risk, and the exact bug already found and fixed in LaboratoryTab.tsx during Phase 18.

Fix: added a query using the same `prescriptions` + `prescription_items(medicines)` shape the Pharmacy dispense queue already uses, filtered by the existing `visit_id` column (already written by this same file's own insert — not a new/guessed column). Rendered as a read-only "already written this visit" list above the builder. Not linked to a detail page, because no per-prescription route exists in the app (only the `/pharmacy` list) — adding one would be a new route, out of scope for a no-schema/no-new-route pass.

## 5 & 7 — Reports & Analytics / systemic export bug

**Commit `65ee707`** — `src/lib/db.ts`

Root cause: `csvExport()` rendered every cell with `String(v ?? "")`. Virtually every screen (Reports, Clinic, Lab, Pharmacy, Billing, etc.) passes Supabase rows straight into `<ExportButtons>`, including their nested joined relations (`departments`, `patients`, `lab_order_items`, `prescription_items`, ...). `String({...})` on any of those produced the literal text `"[object Object]"` in the exported CSV instead of the actual name/value — a genuinely broken export on every screen that joins a relation, verified by reading the call sites, not assumed.

Fix: `cellText()`/`relationLabel()` — for a joined object, look for a human label (`full_name`/`name`/`name_ar`/`label`/`title`, falling back to `id`); for an array of joined rows, join their labels with `"; "`. One change in the shared helper fixes every export button in the app.

## Remaining risks (not verified this pass)

- **Inventory** (suppliers, batches, FEFO): opened and structurally scanned only. The FEFO dispense logic itself (`dispensePrescriptionFefo` in `lib/pharmacy.ts`) was **not** re-read this session — per the explicit instruction to preserve FEFO logic, it was left untouched rather than risk-auditing it without a full read.
- **Insurance** (companies/plans/memberships/claims/prior authorizations): opened and structurally scanned only (4 tabs, route guard confirmed present). Claim visibility/status workflow was not traced end-to-end.
- **Analytics.tsx / Finance.tsx / Accounting.tsx**: not opened this session at all.
- **Permissions/RLS**: verified only that every route-level component is wrapped in `PermissionGate`; did not verify the underlying Supabase RLS policies or the permissions table itself for leaks.
- **Patient Timeline**: there is no dedicated `Timeline` component (confirmed via repo-wide code search) — it's a section inside `patients_.$patientId.tsx`, which was read in Phase 18 for its action buttons but not re-audited here for timeline-specific issues.

A pilot-readiness call should wait until at least Inventory/FEFO, Insurance claims, and Analytics/Finance get the same read-the-actual-code treatment given to Lab/Prescription/Dashboard/Tables across Phases 18-19.
