# Phase 12.1 — Real Fix Report (post–failed z-index-only attempt)

## 1. Original symptoms

### Bug 1 — New Visit dialog (mobile)
- PatientPicker/search area too narrow / wrong layout
- Keyboard opens but search is unusable
- Patient results not reliably selectable
- Department / Doctor / Visit Type do not respond to touch
- Invisible layer appears to intercept pointer events
- Form partially unusable after focusing search
- Save can toast success without a clean completed workflow

### Bug 2 — Clinic missing from navigation
- Clinic icon still absent after previous nav config change

### Bug 3 — End-to-end workflow
- Patients → New Visit → Save → Queue → Clinic must complete cleanly

---

## 2. Previous attempted fix (Phase 12.1 first pass)

- Raised Popover / Select / DropdownMenu to `z-[10050]`
- Changed PatientPicker width to `w-[var(--radix-popover-trigger-width)]`
- Added Clinic to `NAV_GROUPS` with `perm: "emr.read"` and `Stethoscope` icon

Those changes **are present** in the latest GitHub ZIP. They did **not** fix production.

---

## 3. Why the previous fix did NOT solve it

### Bug 1
1. **Z-index alone cannot fix modal Dialog pointer-events.**  
   When a modal Radix Dialog is open, `body` is given `pointer-events: none`. Dialog content restores `pointer-events: auto` for itself only. **Portaled** Popover/Select content is a sibling under `body`, so it inherits `pointer-events: none`. Raising z-index makes the layer *visible* on top but still non-interactive — matching “invisible layer intercepting clicks.”

2. **`--radix-popover-trigger-width` is never set by Radix Popover.**  
   Select sets trigger width CSS variables in popper mode; Popover does not. Using that variable produces an invalid/zero width → narrow search panel on mobile.

3. **Controlled Select `value=""` breaks Radix Select.**  
   Department and Doctor used `value={form.department_id}` / `value={form.doctor_id}` where the empty form state is `""`. Radix Select requires `undefined` for the placeholder state; `""` leaves the control in a broken controlled state (opens poorly / ignores interaction).

4. **Non-modal Popover inside modal Dialog** fights focus on mobile (keyboard + FocusScope).

### Bug 2
Clinic was added with `perm: "emr.read"`. Seeded **reception** role modules are:

`dashboard, patients, visits, queue, appointments, billing, payments, attachments, followups`

**No `emr` module for reception.** Nav filters with `can(item.perm)`, so Clinic is removed before render for the role that runs New Visit / Queue. Admin/GP/specialist have `emr`; reception does not. Visits table already links to `/clinic/$visitId` without requiring `emr.read`.

---

## 4. Actual root causes

| Bug | Root cause |
|-----|------------|
| 1a | Portaled overlays inherit `body { pointer-events: none }` under modal Dialog |
| 1b | Popover width bound to unset CSS variable |
| 1c | Select controlled with `value=""` |
| 1d | Non-modal Popover + Dialog focus trap on mobile |
| 2 | Clinic gated on `emr.read`; reception (and any role without emr) never sees it |

---

## 5. Exact files changed

- `src/components/ui/popover.tsx`
- `src/components/ui/select.tsx`
- `src/components/ui/dropdown-menu.tsx`
- `src/components/patient-picker.tsx`
- `src/routes/_authenticated/visits.tsx`
- `src/config/nav.ts`

---

## 6. Exact fixes applied

### pointer-events restoration (shared primitives)
- PopoverContent, SelectContent, DropdownMenuContent / SubContent: add **`pointer-events-auto`** in addition to `z-[10050]`.

### PatientPicker
- `modal` Popover for correct focus with parent Dialog.
- Measure trigger width via ref + ResizeObserver (do not rely on unset CSS var).
- `collisionPadding={12}`, mobile max-width, deferred focus to CommandInput.
- `onCloseAutoFocus` preventDefault to avoid Dialog jump on mobile.
- Keep unified search (name / MRN / phone / national ID), debounce, preselect, add-patient link.

### New Visit Selects
- `value={form.department_id || undefined}` and `value={form.doctor_id || undefined}`.

### Dialog mobile sizing
- `max-h-[min(90dvh,90vh)]`, `w-[calc(100%-1.5rem)]`, `overscroll-contain`.

### Clinic navigation
- Change permission from `emr.read` → **`visits.read`** (single entry, no duplicate route/permission/i18n).
- Clinical note **writes** remain protected by existing emr RLS on clinical tables.

---

## 7. Regression checks

- Single Clinic nav entry (`"/clinic"` count = 1)
- NavRail / mobile More / Command Palette still use `NAV_GROUPS` / `flatNavItems()` only
- PatientPicker still uses `patientPickerQuery` + debounce
- No new SQL, routes, permissions, or i18n keys
- Visit create mutation unchanged (patient_id required; department/doctor optional; fee → invoice as before)

---

## 8. Workflow verification (source)

1. Patients → New Visit (`/visits?patient=<id>`) opens dialog, preselects patient  
2. PatientPicker modal + measured width + pointer-events-auto → searchable/selectable  
3. Department/Doctor Select with `undefined` empty value → interactive  
4. Save → insert visit → optional invoice → invalidate visits/queue/invoices → close dialog  
5. Visits row Clinic link → `/clinic/$visitId`  
6. Nav Clinic (`visits.read`) → `/clinic` list → open consultation  

Queue ticket still depends on existing live DB trigger (not in repo SQL); frontend invalidates `["queue", date]` as before.

---

## 9. Clinic navigation / permission verification

| Role (seed) | `visits.read` | Clinic nav visible? |
|-------------|---------------|---------------------|
| reception   | yes           | yes (after fix)     |
| gp / specialist / dentist | yes | yes |
| admin       | yes           | yes |
| pharmacist  | no            | no (correct)        |

Icon: `Stethoscope` mapped in `nav-icons.tsx`. Pipeline: `NAV_GROUPS` → `can(perm)` → NavRail / mobile / `flatNavItems()` command palette.

---

## 10. Remaining browser-only limitations

- Cannot exercise real mobile Safari/Chrome touch + keyboard in this sandbox.
- Queue ticket creation still assumes the live PostgreSQL trigger; no new migration added.
- If a deployed DB has customized `role_permissions` without `visits.read` for a given role, Clinic will still be hidden for that role (by design of the permission system).
