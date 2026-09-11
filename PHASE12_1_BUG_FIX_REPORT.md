# Phase 12.1 — Critical Bug Fixes Report

## Scope
Production bug fixes only. No redesigns, no new features, no new SQL/migrations.

## Bug 1 — New Visit dialog broken (PatientPicker + form controls)

### Root cause
1. **Z-index stacking conflict:** Dialog overlay/content use `z-[9998]` / `z-[9999]`. Nested portaled controls (Popover for PatientPicker, Select dropdowns, DropdownMenu) used `z-50`, so they rendered under the dialog overlay. Result on mobile: unusable search field, keyboard/focus issues, non-responsive Department/Doctor/Visit Type controls, overlay intercepting clicks.
2. **Invalid CSS variable width** on PatientPicker: `w-[--radix-popover-trigger-width]` (broken) instead of `w-[var(--radix-popover-trigger-width)]`. Caused incorrect search field width and compressed layout.

### Fix
- Raised Popover, Select, and DropdownMenu content to `z-[10050]` (above Dialog).
- Corrected PatientPicker width to valid CSS var syntax + mobile max-width clamp.
- Added `onOpenAutoFocus` handling so CommandInput receives focus without fighting the parent Dialog focus trap on mobile.

### Expected result after fix
Patients → Search → New Visit → search/select patient in PatientPicker → select Department/Doctor/Visit Type → Save → visit created, queue invalidated, dialog closes, Clinic link available on the visits row. No blocked controls; no overlay intercepting clicks.

---

## Bug 2 — Clinic icon missing from navigation

### Root cause
Clinic was absent from the central nav config (`NAV_GROUPS` in `src/config/nav.ts`). Route (`/clinic`), i18n key (`clinic`), and permission (`emr.read`) already existed. NavRail, mobile navigation, and Command Palette all read from `NAV_GROUPS` / `flatNavItems()`, so Clinic was missing everywhere.

### Fix
- Added Clinic nav item: `{ to: "/clinic", key: "clinic", perm: "emr.read", icon: "Stethoscope" }`.
- Added `HeartPulse` to icon map; assigned it to Followups so Clinic owns Stethoscope.
- Single entry only (no duplicates).

### Coverage
- NavRail — via `NAV_GROUPS`
- Mobile Navigation — via `NAV_GROUPS` (More sheet)
- Command Palette — via `flatNavItems()`
- Quick Actions — intentionally not a create-action target (create flows only)

---

## Bug 3 — Patient → Visit → Queue → Clinic flow

### Status
Path already existed and works after Bug 1/2 fixes:
1. Patients → New Visit (`/visits?patient=<id>`) opens dialog with patient pre-selected.
2. Save inserts visit (DB generates queue_number / queue ticket via existing trigger).
3. Visits table row has Clinic link → `/clinic/$visitId`.
4. Clinic also reachable from restored nav item.

No duplicate visit/queue creation paths introduced. No dead buttons in this chain.

---

## Modified files
- `src/components/ui/popover.tsx`
- `src/components/ui/select.tsx`
- `src/components/ui/dropdown-menu.tsx`
- `src/components/patient-picker.tsx`
- `src/config/nav.ts`
- `src/lib/nav-icons.tsx`

## What was not done
- No new SQL or migrations.
- No duplicate routes, permissions, or i18n keys.
- No UI redesign.
- No Phase 13 or new features.

## Remaining limitations (browser-only verification)
- Live mobile keyboard, focus trap, and touch interaction could not be exercised in this sandbox (no running app / device).
- Queue ticket creation still depends on a PostgreSQL trigger assumed present in the live DB (referenced by comments and invalidation keys; trigger SQL not in the provided migration set). No new SQL was added per instructions.
