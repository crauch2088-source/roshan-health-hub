# Phase 20B — Real Implementation Report

Branch: `phase20-complete-ui-redesign`, continuing from `4187c59`.

## Commits this pass

| Commit | Area | Files |
|---|---|---|
| `2107d79` | feat(app-shell) | src/components/app-shell.tsx |
| `db67c69` | fix(tables) | src/components/ui/table.tsx |

(Priority 3 patient-workspace investigation below found no safe, verified
change to make - explained rather than forced.)

## Real findings and fixes

### Priority 1 — AppShell (`2107d79`)
**Verified bug:** `SearchTrigger` (opens the command palette) was
`hidden ... sm:flex` in the header - below the `sm` breakpoint, i.e. on
every phone, it didn't render. Checked `MobileBottomNav` directly: it has
a quick-actions FAB and a "More" sheet, but no search entry point either.
Net effect: mobile users had **no way to open global/patient/MRN/phone
search at all** - Ctrl+K doesn't help without a keyboard.
**Fix:** the button now always renders - icon-only below `md`, full
"Search everywhere / Ctrl K" label from `md` up - using the same
icon-only touch-target pattern already used by the language toggle and
mobile sign-out button beside it.

Collapsed-mode tooltips, active-state indicators, and transitions in
NavRail were re-checked and are already correct from Phase 18 - not
touched, per "no placeholder redesigns."

### Priority 2 — Table system (`db67c69`)
**Verified bug:** `TableHead`'s default alignment was the physical
`text-left`, which ignores `dir`. The app sets
`document.documentElement.dir = "rtl"` for Arabic, and every high-volume
table (Patients, Visits, Queue, Lab, Pharmacy, Billing, Insurance,
Reports) shares this one component - so column headers stayed pinned
left even in the RTL Arabic layout, inconsistent with the `text-start`/
`text-end` convention already used correctly elsewhere in the codebase
(e.g. patients_.$patientId.tsx, PrescriptionTab.tsx).
**Fix:** `text-left` -> `text-start`. One change, every table using this
component is corrected.

Density, sticky-header offset (fixed in Phase 18), hover state, and
selected-row state (`data-[state=selected]:bg-primary/8`) were checked
and already correct.

### Priority 3 — Patient workspace: investigated, no change made
Checked for the brief's "allergies/chronic conditions in the patient
header" ask. Searched the whole repo for where allergy information
actually lives: it exists only inside `ClinicalNoteTab.tsx`, i.e. as
free-text captured per-visit in the clinical note, not as a persistent
patient-level column. There is no single authoritative "this patient's
allergies" field to surface on a patient-level header - each visit's
note could say something different, and picking one visit's note to
promote to a persistent alert would be inventing a data model the
database doesn't have. Per "do not invent database fields" / "do not
guess database columns," this was left alone rather than built on a
guess. If patient-level allergy/chronic-condition flags are wanted, that
needs a real column added to `patients` first - a schema decision, not
a UI one, and out of scope for this phase's rules.

New Visit / New Invoice quick actions on the patient chart were already
added in Phase 18 and re-verified present; not duplicated.

## Remaining risks / not covered this pass
- Priority 4 (clinic workflow dead-ends), Priority 5 (mobile dialog/sheet
  overflow), Priority 6 (kit.tsx StatCard/PageHeader/etc. visual
  language), and Priority 7 (performance) were not investigated this
  session - each needs the same read-first treatment as above, not a
  batch pass.
- The patient workspace itself (tabs, timeline, summary card layout)
  was read but not restructured - no verified defect was found in its
  current layout, only the missing-column question above.

## Production-readiness assessment
Not a full redesign yet - two real, verified defects fixed this pass (one
of them, the RTL header bug, meaningful since Arabic is this app's
default language). The rest of the 7-priority list in this phase's brief
remains open and should be worked the same way: read the actual
component, confirm a real defect, fix it, commit - not applied as a
batch.
