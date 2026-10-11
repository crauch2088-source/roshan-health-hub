# Final ROSHAN UI/UX freeze

## Outcome
Deliver one cohesive interface pass while preserving every existing route, permission, query, clinical workflow, financial workflow, and database contract. Also replace the disabled legacy browser key with the configured publishable environment variable.

## Implementation
1. **Foundation and shared controls**
   - Normalize spacing, radii, focus states, shadows, motion, cards, inputs, tabs, tables, dialogs, sheets, and command items through existing shared components and semantic tokens.
   - Make dialogs and sheets safe on small mobile viewports while preserving the existing portaled picker/select layering.
   - Improve shared page headers, loading skeletons, empty/error treatments, pagination, and field label association.

2. **Shell and navigation**
   - Refine the desktop rail, brand/account areas, active hierarchy, favorites, RTL collapse direction, collapsed tooltips, and search trigger.
   - Unify active-route matching across the rail, mobile navigation, breadcrumbs, and command palette.
   - Improve mobile bottom navigation, quick actions, touch targets, safe areas, and the complete module sheet without changing permission semantics.

3. **Priority experiences**
   - Recompose Patients as a modern searchable workspace with shared debounced MRN-first search, count, compact desktop rows, stacked mobile rows, contextual actions, and existing registration logic unchanged.
   - Polish the patient chart’s identity summary, actions, tabs, timeline, form grouping, tables, and mobile layout without changing reads or writes.
   - Rebalance the dashboard around attention-first workload, then summary metrics and operational sections, using the existing data hooks unchanged.
   - Polish the command palette’s search, groups, favorites, recents, quick actions, keyboard hints, and mobile sizing.

4. **Security compatibility and verification**
   - Read `VITE_SUPABASE_PUBLISHABLE_KEY` through `import.meta.env`, fail clearly when missing, keep the URL and auth options unchanged, and document only the variable name in `.env.example`.
   - Search for dead/duplicate navigation and patient search, duplicate translation keys, raw button-styled links, overflow risks, and unused imports.
   - Run typecheck, production build, lint, responsive authenticated browser checks where the external backend permits, and review diagnostics/diff.

## Technical constraints
- No schema, migration, RLS, auth-setting, permission, route, clinical, financial, insurance, or query-contract changes.
- No new UI library or competing design system.
- Git branch creation, commits, and pushes are left to the workspace’s managed Git layer; no stateful Git commands will be run.
